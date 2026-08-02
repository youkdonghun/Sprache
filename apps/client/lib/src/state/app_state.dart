import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import '../backup/backup_archive.dart';
import '../data/database/app_database.dart';
import '../data/sample_content.dart';
import '../data/study_store.dart';
import '../domain/active_study_session.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/content_management.dart';
import '../domain/content_validation.dart';
import '../domain/course_path.dart';
import '../domain/daily_queue.dart';
import '../domain/duplicate_repair.dart';
import '../domain/import_distribution.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/learning_item_codec.dart';
import '../domain/library_search.dart';
import '../domain/progress.dart';
import '../domain/review_forecast.dart';
import '../domain/scheduler.dart';
import '../domain/session_enhancements.dart';
import '../domain/smart_collection.dart';
import '../domain/study_history.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../domain/study_session_builder.dart';
import '../domain/study_subject.dart';
import '../import/content_import_parser.dart';
import '../import/import_limits.dart';
import '../import/import_reconciler.dart';
import '../services/study_notification_service.dart';
import '../sync/pending_sync.dart';
import '../sync/sync_merge_report.dart';
import '../sync/snapshot_validator.dart';

const _noActiveSessionUpdate = Object();
const _noPendingSyncUpdate = Object();

enum ImportConflictPolicy { keepExisting, replaceExisting }

class ImportCommitResult {
  const ImportCommitResult({
    required this.added,
    required this.replaced,
    required this.skipped,
    this.stale = 0,
  });

  final int added;
  final int replaced;
  final int skipped;
  final int stale;

  int get saved => added + replaced;
}

class QuickContentSaveResult {
  const QuickContentSaveResult({
    required this.item,
    required this.mergedWithExisting,
    required this.addedMeaningCount,
    required this.undoToken,
    this.studyNow = false,
    this.favoriteAdded = false,
  });

  final LearningItem item;
  final bool mergedWithExisting;
  final int addedMeaningCount;
  final QuickContentUndoToken undoToken;
  final bool studyNow;
  final bool favoriteAdded;

  QuickContentSaveResult copyWith({bool? studyNow, bool? favoriteAdded}) =>
      QuickContentSaveResult(
        item: item,
        mergedWithExisting: mergedWithExisting,
        addedMeaningCount: addedMeaningCount,
        undoToken: undoToken,
        studyNow: studyNow ?? this.studyNow,
        favoriteAdded: favoriteAdded ?? this.favoriteAdded,
      );
}

class QuickContentUndoToken {
  const QuickContentUndoToken({
    required this.id,
    required this.expectedItem,
    required this.previousCustomItem,
    required this.previousTombstone,
  });

  final String id;
  final LearningItem expectedItem;
  final LearningItem? previousCustomItem;
  final DateTime? previousTombstone;
}

enum QuickContentUndoStatus { restored, conflict, alreadyUndone }

class AppState {
  const AppState({
    required this.selectedLanguage,
    required this.progress,
    required this.totalXp,
    required this.replicaId,
    required this.xpByReplica,
    required this.streakDays,
    required this.dailyXp,
    this.dailyXpByCourse = const {},
    this.dailyXpByCourseAndReplica = const {},
    required this.badges,
    required this.driveConnected,
    required this.isHydrated,
    required this.customItems,
    required this.customItemTombstones,
    required this.preferences,
    required this.recentSessions,
    required this.activeStudySession,
    required this.activeSessionChangedAt,
    required this.pendingSync,
    this.lastStudyDate,
  });

  factory AppState.initial() => const AppState(
    selectedLanguage: LanguageTag.english,
    progress: {},
    totalXp: 0,
    replicaId: '',
    xpByReplica: {},
    streakDays: 0,
    dailyXp: 0,
    dailyXpByCourse: {},
    dailyXpByCourseAndReplica: {},
    badges: {},
    driveConnected: false,
    isHydrated: false,
    customItems: [],
    customItemTombstones: {},
    preferences: StudyPreferences(),
    recentSessions: [],
    activeStudySession: null,
    activeSessionChangedAt: null,
    pendingSync: null,
    lastStudyDate: null,
  );

  final LanguageTag selectedLanguage;
  final Map<String, ProgressRecord> progress;
  final int totalXp;
  final String replicaId;
  final Map<String, int> xpByReplica;
  final int streakDays;
  final int dailyXp;
  final Map<String, int> dailyXpByCourse;
  final Map<String, Map<String, int>> dailyXpByCourseAndReplica;
  final Set<String> badges;
  final bool driveConnected;
  final bool isHydrated;
  final List<LearningItem> customItems;
  final Map<String, DateTime> customItemTombstones;
  final StudyPreferences preferences;
  final List<StudySessionSummary> recentSessions;
  final ActiveStudySession? activeStudySession;
  final DateTime? activeSessionChangedAt;
  final PendingSyncOperation? pendingSync;
  final DateTime? lastStudyDate;

  int get level => totalXp ~/ 500 + 1;
  int get levelXp => totalXp % 500;
  String get activeSubjectId => preferences.activeSubjectId.isEmpty
      ? languageSubjectId(selectedLanguage)
      : preferences.activeSubjectId;
  String get activeCourseId => courseIdForSubject(activeSubjectId);
  int get dailyGoal => preferences.dailyGoalFor(activeSubjectId);
  int get activeCourseDailyXp => dailyXpByCourse[activeCourseId] ?? 0;

  AppState copyWith({
    LanguageTag? selectedLanguage,
    Map<String, ProgressRecord>? progress,
    int? totalXp,
    String? replicaId,
    Map<String, int>? xpByReplica,
    int? streakDays,
    int? dailyXp,
    Map<String, int>? dailyXpByCourse,
    Map<String, Map<String, int>>? dailyXpByCourseAndReplica,
    Set<String>? badges,
    bool? driveConnected,
    bool? isHydrated,
    List<LearningItem>? customItems,
    Map<String, DateTime>? customItemTombstones,
    StudyPreferences? preferences,
    List<StudySessionSummary>? recentSessions,
    Object? activeStudySession = _noActiveSessionUpdate,
    Object? activeSessionChangedAt = _noActiveSessionUpdate,
    Object? pendingSync = _noPendingSyncUpdate,
    DateTime? lastStudyDate,
  }) {
    return AppState(
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      progress: progress ?? this.progress,
      totalXp: totalXp ?? this.totalXp,
      replicaId: replicaId ?? this.replicaId,
      xpByReplica: xpByReplica ?? this.xpByReplica,
      streakDays: streakDays ?? this.streakDays,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyXpByCourse: dailyXpByCourse ?? this.dailyXpByCourse,
      dailyXpByCourseAndReplica:
          dailyXpByCourseAndReplica ?? this.dailyXpByCourseAndReplica,
      badges: badges ?? this.badges,
      driveConnected: driveConnected ?? this.driveConnected,
      isHydrated: isHydrated ?? this.isHydrated,
      customItems: customItems ?? this.customItems,
      customItemTombstones: customItemTombstones ?? this.customItemTombstones,
      preferences: preferences ?? this.preferences,
      recentSessions: recentSessions ?? this.recentSessions,
      activeStudySession: identical(activeStudySession, _noActiveSessionUpdate)
          ? this.activeStudySession
          : activeStudySession as ActiveStudySession?,
      activeSessionChangedAt:
          identical(activeSessionChangedAt, _noActiveSessionUpdate)
          ? this.activeSessionChangedAt
          : activeSessionChangedAt as DateTime?,
      pendingSync: identical(pendingSync, _noPendingSyncUpdate)
          ? this.pendingSync
          : pendingSync as PendingSyncOperation?,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}

class LearningGroupWorkspaceSnapshot {
  const LearningGroupWorkspaceSnapshot({
    required this.subjectId,
    required this.items,
    required this.groups,
    required this.tombstones,
  });

  final String subjectId;
  final List<LearningItem> items;
  final List<LearningGroupDefinition> groups;
  final Map<String, DateTime> tombstones;
}

class AppController extends StateNotifier<AppState> {
  AppController(
    this._store, {
    this._notificationService = const DisabledStudyNotificationService(),
    this.importLimits = const ImportLimits(),
  }) : super(AppState.initial()) {
    unawaited(_hydrate());
  }

  final StudyStore _store;
  final StudyNotificationService _notificationService;
  final ImportLimits importLimits;
  final _scheduler = const ReviewScheduler();
  final _queueBuilder = const DailyQueueBuilder();
  final _sessionBuilder = const StudySessionBuilder();
  final _pathBuilder = const CoursePathBuilder();
  final _forecastBuilder = const ReviewForecastBuilder();
  final _contentValidator = const LearningContentValidator();
  final _duplicateRepairAnalyzer = const DuplicateRepairAnalyzer();
  final _importReconciler = const ImportReconciler();
  final _itemCodec = const LearningItemCodec();
  final _snapshotValidator = const SyncSnapshotValidator();
  final _syncMergeReporter = const SyncMergeReporter();
  Future<void> _persistenceWriteTail = Future<void>.value();
  int _syncSequence = 0;
  final Set<String> _undoneDuplicateRepairIds = <String>{};
  final Set<String> _undoneQuickContentSaveIds = <String>{};
  SyncMergeReport? lastMergeReport;

  Future<void> _hydrate() async {
    final results = await Future.wait([
      _store.loadProfile(),
      _store.loadCustomItems(),
      _store.loadCustomItemTombstones(),
      _store.loadPreferences(),
      _store.loadRecentSessions(),
      _store.loadActiveStudyState(),
      _store.loadPendingSnapshotSync(),
    ]);
    final profile = results[0] as StoredProfile;
    final customItems = results[1] as List<LearningItem>;
    final customItemTombstones = results[2] as Map<String, DateTime>;
    var preferences = results[3] as StudyPreferences;
    final recentSessions = results[4] as List<StudySessionSummary>;
    final activeStudyState = results[5] as StoredActiveStudyState;
    final pendingSync = results[6] as PendingSyncOperation?;
    var activeSubjectId = preferences.activeSubjectId.isEmpty
        ? languageSubjectId(profile.selectedLanguage)
        : preferences.activeSubjectId;
    var preferencesChanged = false;
    final visibleSubjects = _subjectsForPreferences(preferences)
        .where((subject) => !preferences.hiddenSubjectIds.contains(subject.id))
        .toList(growable: false);
    if (visibleSubjects.isEmpty) {
      preferences = preferences.copyWith(
        hiddenSubjectIds: const {},
        subjectVisibilityChangedAtById: const {},
      );
      activeSubjectId = languageSubjectId(profile.selectedLanguage);
      preferencesChanged = true;
    } else if (!visibleSubjects.any(
      (subject) => subject.id == activeSubjectId,
    )) {
      activeSubjectId = visibleSubjects.first.id;
      preferences = preferences.copyWith(
        activeSubjectId: activeSubjectId,
        activeSubjectChangedAt: DateTime.now().toUtc(),
      );
      preferencesChanged = true;
    }
    final legacyCurrentPlan = preferences.sessionPlan.subjectId.isEmpty;
    final hasLegacySavedPlans = preferences.savedSessionPlans.any(
      (plan) => plan.subjectId.isEmpty,
    );
    if (legacyCurrentPlan || hasLegacySavedPlans) {
      preferences = preferences.copyWith(
        sessionPlan: legacyCurrentPlan
            ? preferences.sessionPlan.copyWith(subjectId: activeSubjectId)
            : preferences.sessionPlan,
        savedSessionPlans: [
          for (final plan in preferences.savedSessionPlans)
            if (plan.subjectId.isEmpty)
              plan.copyWith(subjectId: activeSubjectId)
            else
              plan,
        ],
      );
      preferencesChanged = true;
    }
    final migratedGroups = _definitionsIncludingLegacyTags(
      preferences.learningGroups,
      customItems,
    );
    if (migratedGroups.length != preferences.learningGroups.length) {
      preferences = preferences.copyWith(learningGroups: migratedGroups);
      preferencesChanged = true;
    }
    if (preferencesChanged) {
      await _store.savePreferences(preferences);
    }
    final hydratedDailyXpByCourse = profile.dailyXpByCourse.isEmpty
        ? profile.dailyXp > 0
              ? {courseIdForSubject(activeSubjectId): profile.dailyXp}
              : const <String, int>{}
        : profile.dailyXpByCourse;
    final hydratedDailyXpLedger = _normalizeDailyXpLedger(
      legacyByCourse: hydratedDailyXpByCourse,
      ledger: profile.dailyXpByCourseAndReplica,
    );
    final derivedDailyXpByCourse = _dailyXpByCourseFromLedger(
      hydratedDailyXpLedger,
    );
    final hydratedXpByReplica = _normalizeXpLedger(
      totalXp: profile.totalXp,
      xpByReplica: profile.xpByReplica,
    );
    if (!mounted) return;
    state = state.copyWith(
      selectedLanguage: profile.selectedLanguage,
      progress: profile.progress,
      totalXp: _sumXpLedger(hydratedXpByReplica),
      replicaId: profile.replicaId,
      xpByReplica: hydratedXpByReplica,
      streakDays: profile.streakDays,
      dailyXp: _sumDailyXpByCourse(derivedDailyXpByCourse),
      dailyXpByCourse: derivedDailyXpByCourse,
      dailyXpByCourseAndReplica: hydratedDailyXpLedger,
      badges: profile.badges,
      driveConnected: profile.driveConnected,
      isHydrated: true,
      customItems: customItems,
      customItemTombstones: customItemTombstones,
      preferences: preferences,
      recentSessions: recentSessions,
      activeStudySession: activeStudyState.session,
      activeSessionChangedAt: activeStudyState.changedAt,
      pendingSync: pendingSync,
      lastStudyDate: profile.lastStudyDate,
    );
    unawaited(_reconcileStudyNotifications(preferences));
  }

  Future<StudyNotificationPermission>
  requestStudyNotificationPermission() async {
    final result = await setupStudyNotifications();
    return result.permission;
  }

  Future<StudyNotificationSetupResult> setupStudyNotifications() async {
    final permission = await _notificationService.requestPermission();
    final reconcileResult = await _reconcileStudyNotifications(
      state.preferences,
    );
    return StudyNotificationSetupResult(
      permission: permission,
      reconcileResult: reconcileResult,
    );
  }

  Future<StudyNotificationReconcileResult> _reconcileStudyNotifications(
    StudyPreferences preferences,
  ) {
    return _notificationService.reconcile(preferences.savedSessionPlans);
  }

  void _persist({bool queueSync = true}) {
    final snapshotState = state;
    final syncPayload = queueSync ? exportSyncSnapshot() : null;
    final pendingSync = syncPayload == null
        ? null
        : _newPendingSyncOperation(payload: syncPayload);
    _enqueueUnawaitedPersistenceWrite(() async {
      await _store.saveProfile(
        StoredProfile(
          selectedLanguage: snapshotState.selectedLanguage,
          totalXp: snapshotState.totalXp,
          replicaId: snapshotState.replicaId,
          xpByReplica: snapshotState.xpByReplica,
          streakDays: snapshotState.streakDays,
          dailyXp: snapshotState.dailyXp,
          dailyXpByCourse: snapshotState.dailyXpByCourse,
          dailyXpByCourseAndReplica: snapshotState.dailyXpByCourseAndReplica,
          badges: snapshotState.badges,
          driveConnected: snapshotState.driveConnected,
          progress: snapshotState.progress,
          lastStudyDate: snapshotState.lastStudyDate,
        ),
      );
      if (pendingSync != null) {
        await _replacePendingSyncSnapshot(pendingSync);
      }
    });
  }

  Future<PendingSyncOperation> queueSyncSnapshot({
    DateTime? now,
    Map<String, Object?>? payload,
  }) {
    final operation = _newPendingSyncOperation(now: now, payload: payload);
    return _serializePersistenceWrite(
      () => _replacePendingSyncSnapshot(operation),
    );
  }

  PendingSyncOperation _newPendingSyncOperation({
    DateTime? now,
    Map<String, Object?>? payload,
  }) {
    final createdAt = (now ?? DateTime.now()).toUtc();
    return PendingSyncOperation(
      operationId:
          'snapshot-${createdAt.microsecondsSinceEpoch}-${_syncSequence++}',
      entityType: PendingSyncEntityType.snapshot,
      entityId: 'state/snapshot.json',
      payload: payload ?? exportSyncSnapshot(),
      attempts: 0,
      nextAttemptAt: createdAt,
      createdAt: createdAt,
    );
  }

  Future<PendingSyncOperation> _replacePendingSyncSnapshot(
    PendingSyncOperation operation,
  ) async {
    await _store.replacePendingSnapshotSync(operation);
    if (mounted) state = state.copyWith(pendingSync: operation);
    return operation;
  }

  Future<T> _serializePersistenceWrite<T>(Future<T> Function() write) {
    final result = Completer<T>();
    _persistenceWriteTail = _persistenceWriteTail.then((_) async {
      try {
        result.complete(await write());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  void _enqueueUnawaitedPersistenceWrite(Future<void> Function() write) {
    unawaited(
      _serializePersistenceWrite(write).catchError((Object _, StackTrace _) {}),
    );
  }

  Future<void> flushPendingWrites() async {
    while (true) {
      final pending = _persistenceWriteTail;
      await pending;
      if (identical(pending, _persistenceWriteTail)) return;
    }
  }

  Future<void> _queueSyncIfDriveConnected({
    Map<String, Object?>? payload,
  }) async {
    // This queue lives in the local database. Keeping the newest snapshot even
    // while disconnected makes a later Drive connection upload the full state
    // without changing the active local-storage target.
    await queueSyncSnapshot(payload: payload);
  }

  Future<PendingSyncOperation?> markPendingSyncFailed(
    String operationId, {
    DateTime? now,
    Duration? minimumDelay,
  }) async {
    final current = state.pendingSync;
    if (current == null || current.operationId != operationId) return current;
    final failedAt = (now ?? DateTime.now()).toUtc();
    final attempts = current.attempts + 1;
    final backoff = pendingSyncBackoff(attempts);
    final retryDelay = minimumDelay != null && minimumDelay > backoff
        ? minimumDelay
        : backoff;
    final next = current.copyWith(
      attempts: attempts,
      nextAttemptAt: failedAt.add(retryDelay),
    );
    await _store.updatePendingSync(next);
    if (mounted && state.pendingSync?.operationId == operationId) {
      state = state.copyWith(pendingSync: next);
    }
    return next;
  }

  Future<void> completePendingSync(String operationId) async {
    await _store.deletePendingSync(operationId);
    if (mounted && state.pendingSync?.operationId == operationId) {
      state = state.copyWith(pendingSync: null);
    }
  }

  List<LearningItem> get courseItems {
    return itemsForSubject(state.activeSubjectId);
  }

  List<LearningItem> get allContentItems {
    final customIds = state.customItems.map((item) => item.id).toSet();
    return [
      ...state.customItems,
      ...sampleContent.where((item) => !customIds.contains(item.id)),
    ];
  }

  List<LearningItem> itemsForSubject(String subjectId) {
    final normalized = normalizeStudySubjectId(subjectId);
    return allContentItems
        .where((item) => item.effectiveSubjectId == normalized)
        .toList(growable: false);
  }

  List<StudySubject> get allSubjects {
    final byId = <String, StudySubject>{
      for (final subject in builtInLanguageSubjects) subject.id: subject,
      for (final subject in state.preferences.customSubjects)
        subject.id: subject,
    };
    return byId.values.toList(growable: false);
  }

  List<StudySubject> get availableSubjects => allSubjects
      .where(
        (subject) => !state.preferences.hiddenSubjectIds.contains(subject.id),
      )
      .toList(growable: false);

  List<StudySubject> get hiddenSubjects => allSubjects
      .where(
        (subject) => state.preferences.hiddenSubjectIds.contains(subject.id),
      )
      .toList(growable: false);

  StudySubject? subjectById(String subjectId) {
    final normalized = normalizeStudySubjectId(subjectId);
    for (final subject in allSubjects) {
      if (subject.id == normalized) return subject;
    }
    return null;
  }

  bool hasStudySubjectOverride(String subjectId) => state
      .preferences
      .customSubjects
      .any((subject) => subject.id == subjectId);

  StudySubject get activeSubject {
    return availableSubjects.firstWhere(
      (subject) => subject.id == state.activeSubjectId,
      orElse: () => availableSubjects.isNotEmpty
          ? availableSubjects.first
          : StudySubject.language(state.selectedLanguage),
    );
  }

  StudySessionPlan get activeSessionPlan {
    final plan = state.preferences.sessionPlan;
    return plan.subjectId == state.activeSubjectId
        ? plan
        : StudySessionPlan(subjectId: state.activeSubjectId);
  }

  List<StudySessionPlan> get activeSubjectSavedSessionPlans {
    final plans = state.preferences.savedSessionPlans
        .where((plan) => plan.subjectId == state.activeSubjectId)
        .toList(growable: false);
    return plans;
  }

  List<StudySessionPlan> get activeSubjectScheduledSessionPlans {
    final plans =
        activeSubjectSavedSessionPlans
            .where((plan) => plan.scheduledAt != null)
            .toList(growable: false)
          ..sort((left, right) {
            final scheduleOrder = left.scheduledAt!.compareTo(
              right.scheduledAt!,
            );
            if (scheduleOrder != 0) return scheduleOrder;
            return left.title.compareTo(right.title);
          });
    return plans;
  }

  List<LearningItem> get selectedItems =>
      courseItems.where(state.preferences.includes).toList(growable: false);

  CoursePathSnapshot get coursePath =>
      _pathBuilder.build(items: selectedItems, progress: state.progress);

  List<LearningItem> itemsForUnit(int unitIndex) {
    final path = coursePath;
    if (unitIndex < 0 || unitIndex >= path.units.length) return const [];
    return path.units[unitIndex].items;
  }

  List<String> get availableSessionTags {
    final values =
        selectedItems
            .expand((item) => item.tags)
            .where(
              (tag) =>
                  !tag.startsWith('unit-') &&
                  !tag.startsWith(learningGroupTagPrefix) &&
                  !tag.startsWith(importDistributionTagPrefix),
            )
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get availableSessionLevels {
    final values = selectedItems.map((item) => item.level).toSet().toList()
      ..sort();
    return values;
  }

  List<LearningGroupDefinition> get availableLearningGroupDefinitions {
    final definitions = _definitionsIncludingLegacyTags(
      state.preferences.learningGroups.where(
        (group) => group.subjectId == state.activeSubjectId,
      ),
      courseItems,
    );
    definitions.sort(_compareLearningGroupDefinitions);
    return List.unmodifiable(definitions);
  }

  List<String> get availableLearningGroups => [
    for (final group in availableLearningGroupDefinitions) group.name,
  ];

  LearningGroupDefinition? learningGroupDefinition(String groupName) {
    final normalized = normalizeLearningGroupName(groupName);
    for (final group in availableLearningGroupDefinitions) {
      if (group.name == normalized) return group;
    }
    return null;
  }

  LearningGroupWorkspaceSnapshot captureLearningGroupWorkspace(
    Iterable<String> itemIds,
  ) {
    final selectedIds = itemIds.toSet();
    final itemById = {for (final item in courseItems) item.id: item};
    final groups = state.preferences.learningGroups
        .where((group) => group.subjectId == state.activeSubjectId)
        .toList(growable: false);
    final groupIds = groups.map((group) => group.id).toSet();
    return LearningGroupWorkspaceSnapshot(
      subjectId: state.activeSubjectId,
      items: [for (final itemId in selectedIds) ?itemById[itemId]],
      groups: groups,
      tombstones: {
        for (final entry in state.preferences.learningGroupTombstones.entries)
          if (groupIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Future<void> restoreLearningGroupWorkspace(
    LearningGroupWorkspaceSnapshot snapshot,
  ) async {
    final changedAt = DateTime.now().toUtc();
    final currentById = {
      for (final item in [...sampleContent, ...state.customItems])
        item.id: item,
    };
    final customById = {for (final item in state.customItems) item.id: item};
    final restoredItems = <LearningItem>[];
    for (final before in snapshot.items) {
      final current = currentById[before.id] ?? before;
      final restored = _nextContentRevision(
        _contentValidator.ensureValid(before.copyWith(updatedAt: changedAt)),
        current,
      );
      customById[restored.id] = restored;
      restoredItems.add(restored);
    }
    if (restoredItems.isNotEmpty) {
      await _store.saveCustomItems(restoredItems);
    }
    final currentSubjectGroups = state.preferences.learningGroups
        .where((group) => group.subjectId == snapshot.subjectId)
        .toList(growable: false);
    final snapshotIds = snapshot.groups.map((group) => group.id).toSet();
    final nextTombstones = {...state.preferences.learningGroupTombstones};
    for (final current in currentSubjectGroups) {
      if (!snapshotIds.contains(current.id)) {
        nextTombstones[current.id] = changedAt;
      }
    }
    final restoredGroups = [
      for (final group in snapshot.groups) group.copyWith(updatedAt: changedAt),
    ];
    for (final group in restoredGroups) {
      nextTombstones.remove(group.id);
    }
    for (final entry in snapshot.tombstones.entries) {
      if (!snapshotIds.contains(entry.key)) {
        nextTombstones[entry.key] = entry.value;
      }
    }
    final nextPreferences = state.preferences.copyWith(
      learningGroups: [
        for (final group in state.preferences.learningGroups)
          if (group.subjectId != snapshot.subjectId) group,
        ...restoredGroups,
      ],
      learningGroupTombstones: nextTombstones,
    );
    state = state.copyWith(
      customItems: customById.values.toList(growable: false),
      preferences: nextPreferences,
    );
    await _store.savePreferences(nextPreferences);
    await _queueSyncIfDriveConnected();
  }

  List<LearningGroupSummary> get learningGroupSummaries => [
    for (final group in availableLearningGroups)
      summarizeLearningGroup(group, courseItems, state.progress),
  ];

  LearningGroupSummary? learningGroupSummary(String groupName) {
    final summary = summarizeLearningGroup(
      groupName,
      courseItems,
      state.progress,
    );
    return summary.totalCount == 0 && learningGroupDefinition(groupName) == null
        ? null
        : summary;
  }

  List<LearningItem> itemsForLearningGroup(String groupName) {
    final normalized = normalizeLearningGroupName(groupName);
    return courseItems
        .where((item) => learningGroupsOf(item).contains(normalized))
        .toList(growable: false);
  }

  Future<LearningGroupDefinition> createLearningGroup({
    required String name,
    String description = '',
    String colorKey = 'teal',
  }) async {
    final normalized = normalizeLearningGroupName(name);
    final existing = learningGroupDefinition(normalized);
    if (existing != null) {
      if (description.isEmpty && colorKey == existing.colorKey) return existing;
      final updated = existing.copyWith(
        description: description.isEmpty ? existing.description : description,
        colorKey: colorKey,
        updatedAt: DateTime.now().toUtc(),
      );
      await _upsertLearningGroupDefinition(updated);
      return updated;
    }
    final subjectGroups = availableLearningGroupDefinitions;
    final definition = LearningGroupDefinition(
      subjectId: state.activeSubjectId,
      name: normalized,
      description: description,
      colorKey: colorKey,
      sortOrder: subjectGroups.isEmpty
          ? 0
          : subjectGroups
                    .map((group) => group.sortOrder)
                    .reduce((left, right) => left > right ? left : right) +
                1,
    );
    await _upsertLearningGroupDefinition(definition);
    return definition;
  }

  Future<void> updateLearningGroupDefinition(
    LearningGroupDefinition definition,
  ) async {
    if (definition.subjectId != state.activeSubjectId) {
      throw const FormatException('현재 학습 주제의 그룹만 수정할 수 있습니다.');
    }
    await _upsertLearningGroupDefinition(
      definition.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> setLearningGroupPinned(String groupName, bool pinned) async {
    final definition = learningGroupDefinition(groupName);
    if (definition == null || definition.pinned == pinned) return;
    await _upsertLearningGroupDefinition(
      definition.copyWith(pinned: pinned, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> reorderLearningGroups(List<String> orderedNames) async {
    final normalizedOrder = [
      for (final name in orderedNames) normalizeLearningGroupName(name),
    ];
    final byName = {
      for (final group in availableLearningGroupDefinitions) group.name: group,
    };
    final now = DateTime.now().toUtc();
    var changed = false;
    final replacements = <String, LearningGroupDefinition>{};
    for (final (index, name) in normalizedOrder.indexed) {
      final current = byName[name];
      if (current == null) continue;
      if (current.sortOrder != index) changed = true;
      replacements[current.id] = current.copyWith(
        sortOrder: index,
        updatedAt: current.sortOrder == index ? current.updatedAt : now,
      );
    }
    if (!changed) return;
    final next = [
      for (final group in state.preferences.learningGroups)
        replacements[group.id] ?? group,
    ];
    await _saveLearningGroupDefinitions(next);
  }

  Future<void> _upsertLearningGroupDefinition(
    LearningGroupDefinition definition, {
    bool queueSync = true,
  }) async {
    final byId = {
      for (final group in state.preferences.learningGroups) group.id: group,
      definition.id: definition,
    };
    final tombstones = {...state.preferences.learningGroupTombstones}
      ..remove(definition.id);
    await _saveLearningGroupDefinitions(
      byId.values.toList(growable: false),
      tombstones: tombstones,
      queueSync: queueSync,
    );
  }

  Future<void> _saveLearningGroupDefinitions(
    List<LearningGroupDefinition> groups, {
    Map<String, DateTime>? tombstones,
    bool queueSync = true,
  }) async {
    final nextPreferences = state.preferences.copyWith(
      learningGroups: List.unmodifiable(groups),
      learningGroupTombstones:
          tombstones ?? state.preferences.learningGroupTombstones,
    );
    state = state.copyWith(preferences: nextPreferences);
    await _store.savePreferences(nextPreferences);
    if (queueSync) await _queueSyncIfDriveConnected();
  }

  Future<void> organizeItemsInLearningGroup(
    Iterable<String> itemIds,
    String groupName, {
    required bool copy,
  }) async {
    final selectedIds = itemIds.toSet();
    if (selectedIds.isEmpty) return;
    final normalizedGroup = normalizeLearningGroupName(groupName);
    if (learningGroupDefinition(normalizedGroup) == null) {
      await createLearningGroup(name: normalizedGroup);
    }
    final changedAt = DateTime.now().toUtc();
    final currentById = {for (final item in courseItems) item.id: item};
    final customById = {for (final item in state.customItems) item.id: item};
    final toSave = <LearningItem>[];
    for (final itemId in selectedIds) {
      final current = currentById[itemId];
      if (current == null) continue;
      final updated = _nextContentRevision(
        _contentValidator
            .ensureValid(
              current.copyWith(
                tags: tagsWithLearningGroup(
                  current.tags,
                  normalizedGroup,
                  keepExistingGroups: copy,
                ),
              ),
            )
            .copyWith(updatedAt: changedAt),
        customById[itemId] ?? current,
      );
      customById[itemId] = updated;
      toSave.add(updated);
    }
    if (toSave.isEmpty) return;
    await _store.saveCustomItems(toSave);
    if (!mounted) return;
    final tombstones = {...state.customItemTombstones};
    for (final item in toSave) {
      tombstones.remove(item.id);
    }
    await _store.saveCustomItemTombstones(tombstones);
    state = state.copyWith(
      customItems: customById.values.toList(growable: false),
      customItemTombstones: tombstones,
    );
    await _queueSyncIfDriveConnected();
  }

  Future<void> removeItemsFromLearningGroups(Iterable<String> itemIds) async {
    final selectedIds = itemIds.toSet();
    if (selectedIds.isEmpty) return;
    final changedAt = DateTime.now().toUtc();
    final currentById = {for (final item in courseItems) item.id: item};
    final customById = {for (final item in state.customItems) item.id: item};
    final toSave = <LearningItem>[];
    for (final itemId in selectedIds) {
      final current = currentById[itemId];
      if (current == null || learningGroupsOf(current).isEmpty) continue;
      final updated = _nextContentRevision(
        _contentValidator
            .ensureValid(
              current.copyWith(tags: tagsWithoutLearningGroups(current.tags)),
            )
            .copyWith(updatedAt: changedAt),
        customById[itemId] ?? current,
      );
      customById[itemId] = updated;
      toSave.add(updated);
    }
    if (toSave.isEmpty) return;
    await _store.saveCustomItems(toSave);
    if (!mounted) return;
    final tombstones = {...state.customItemTombstones};
    for (final item in toSave) {
      tombstones.remove(item.id);
    }
    await _store.saveCustomItemTombstones(tombstones);
    state = state.copyWith(
      customItems: customById.values.toList(growable: false),
      customItemTombstones: tombstones,
    );
    await _queueSyncIfDriveConnected();
  }

  Future<int> moveItemsToStudySubject(
    Iterable<String> itemIds,
    String targetSubjectId,
  ) async {
    final targetId = normalizeStudySubjectId(targetSubjectId);
    if (!availableSubjects.any((subject) => subject.id == targetId)) {
      throw FormatException('존재하지 않는 학습 주제입니다: $targetId');
    }
    final selectedIds = itemIds.toSet();
    if (selectedIds.isEmpty || targetId == state.activeSubjectId) return 0;
    final changedAt = DateTime.now().toUtc();
    final currentById = {for (final item in courseItems) item.id: item};
    final customById = {for (final item in state.customItems) item.id: item};
    final toSave = <LearningItem>[];
    for (final itemId in selectedIds) {
      final current = currentById[itemId];
      if (current == null) continue;
      final previous = customById[itemId] ?? current;
      final updated = _nextContentRevision(
        _contentValidator.ensureValid(
          current.copyWith(subjectId: targetId, updatedAt: changedAt),
        ),
        previous,
      );
      customById[itemId] = updated;
      toSave.add(updated);
    }
    if (toSave.isEmpty) return 0;
    await _store.saveCustomItems(toSave);
    if (!mounted) return 0;
    final tombstones = {...state.customItemTombstones};
    for (final item in toSave) {
      tombstones.remove(item.id);
    }
    await _store.saveCustomItemTombstones(tombstones);
    state = state.copyWith(
      customItems: customById.values.toList(growable: false),
      customItemTombstones: tombstones,
    );
    await _queueSyncIfDriveConnected();
    return toSave.length;
  }

  Future<int> renameLearningGroup(String previousName, String nextName) async {
    final previous = normalizeLearningGroupName(previousName);
    final next = normalizeLearningGroupName(nextName);
    if (previous == next) return itemsForLearningGroup(previous).length;
    final previousDefinition = learningGroupDefinition(previous);
    final existingTarget = learningGroupDefinition(next);
    final changed = await _rewriteLearningGroup(
      previous,
      (tags) => tagsRenamingLearningGroup(tags, previous, next),
    );
    final now = DateTime.now().toUtc();
    final definitions = <String, LearningGroupDefinition>{
      for (final group in state.preferences.learningGroups)
        if (group.id != previousDefinition?.id) group.id: group,
    };
    final nextDefinition =
        existingTarget ??
        (previousDefinition ??
                LearningGroupDefinition(
                  subjectId: state.activeSubjectId,
                  name: previous,
                ))
            .copyWith(name: next, updatedAt: now);
    definitions[nextDefinition.id] = nextDefinition;
    final tombstones = {...state.preferences.learningGroupTombstones};
    if (previousDefinition != null) {
      tombstones[previousDefinition.id] = now;
    }
    tombstones.remove(nextDefinition.id);
    await _saveLearningGroupDefinitions(
      definitions.values.toList(growable: false),
      tombstones: tombstones,
    );
    return changed;
  }

  Future<int> deleteLearningGroup(String groupName) async {
    final normalized = normalizeLearningGroupName(groupName);
    final definition = learningGroupDefinition(normalized);
    final changed = await _rewriteLearningGroup(
      normalized,
      (tags) => tagsWithoutLearningGroup(tags, normalized),
    );
    if (definition != null) {
      final now = DateTime.now().toUtc();
      final next = [
        for (final group in state.preferences.learningGroups)
          if (group.id != definition.id) group,
      ];
      await _saveLearningGroupDefinitions(
        next,
        tombstones: {
          ...state.preferences.learningGroupTombstones,
          definition.id: now,
        },
      );
    }
    return changed;
  }

  Future<int> _rewriteLearningGroup(
    String groupName,
    List<String> Function(Iterable<String> tags) rewriteTags,
  ) async {
    final groupedItems = itemsForLearningGroup(groupName);
    if (groupedItems.isEmpty) return 0;
    final changedAt = DateTime.now().toUtc();
    final customById = {for (final item in state.customItems) item.id: item};
    final toSave = <LearningItem>[];
    for (final current in groupedItems) {
      final previous = customById[current.id] ?? current;
      final updated = _nextContentRevision(
        _contentValidator
            .ensureValid(current.copyWith(tags: rewriteTags(current.tags)))
            .copyWith(updatedAt: changedAt),
        previous,
      );
      customById[current.id] = updated;
      toSave.add(updated);
    }
    await _store.saveCustomItems(toSave);
    if (!mounted) return toSave.length;
    final tombstones = {...state.customItemTombstones};
    for (final item in toSave) {
      tombstones.remove(item.id);
    }
    await _store.saveCustomItemTombstones(tombstones);
    state = state.copyWith(
      customItems: customById.values.toList(growable: false),
      customItemTombstones: tombstones,
    );
    await _queueSyncIfDriveConnected();
    return toSave.length;
  }

  StudySessionBuildResult previewSessionPlan(
    StudySessionPlan plan,
    DateTime now,
  ) {
    return _sessionBuilder.build(
      courseId: state.activeCourseId,
      localDate: now,
      items: selectedItems,
      progress: state.progress,
      plan: plan,
      averageSecondsPerItem: averageSecondsPerStudyItem,
      favoriteItemIds: state.preferences.favoriteItemIds,
      personalItemIds: state.customItems.map((item) => item.id).toSet(),
      recoveryItemsStudiedToday: _recoveryItemsStudiedToday(now),
    );
  }

  int _recoveryItemsStudiedToday(DateTime now) {
    final localNow = now.toLocal();
    return state.recentSessions
        .where((session) {
          if (!session.recordProgress ||
              !session.backlogRecovery ||
              session.courseId != state.activeCourseId) {
            return false;
          }
          final endedAt = session.endedAt.toLocal();
          return endedAt.year == localNow.year &&
              endedAt.month == localNow.month &&
              endedAt.day == localNow.day;
        })
        .fold<int>(
          0,
          (total, session) =>
              total +
              (session.itemIds.isEmpty
                  ? session.attempts
                  : session.itemIds.length),
        );
  }

  double get averageSecondsPerStudyItem {
    var weightedSeconds = 0.0;
    var attempts = 0;
    for (final session
        in state.recentSessions
            .where(
              (session) =>
                  session.courseId == state.activeCourseId &&
                  session.recordProgress &&
                  session.attempts > 0,
            )
            .take(10)) {
      final elapsedSeconds =
          session.endedAt.difference(session.startedAt).inMilliseconds / 1000;
      if (elapsedSeconds <= 0) continue;
      final perItem = (elapsedSeconds / session.attempts).clamp(5.0, 300.0);
      weightedSeconds += perItem * session.attempts;
      attempts += session.attempts;
    }
    if (attempts == 0) return 30;
    return (weightedSeconds / attempts).clamp(5.0, 300.0);
  }

  List<LearningItem> queue(
    DateTime now, {
    StudyMode? mode,
    int? unitIndex,
    StudySessionPlan? sessionPlan,
    int? itemLimit,
    StudyQueuePriority queuePriority = StudyQueuePriority.dueFirst,
    StudyHistoryFilter historyFilter = StudyHistoryFilter.all,
  }) {
    final effectiveItemLimit =
        (itemLimit ??
                sessionPlan?.itemLimit ??
                state.preferences.sessionItemLimit)
            .clamp(StudyLimits.minSessionItems, StudyLimits.maxSessionItems)
            .toInt();
    if (sessionPlan != null) {
      final effectivePlan = sessionPlan.copyWith(itemLimit: effectiveItemLimit);
      return previewSessionPlan(effectivePlan, now).items;
    }
    final selectedMode = mode ?? state.preferences.preferredMode;
    final sourceItems = unitIndex == null
        ? selectedItems
        : itemsForUnit(unitIndex);
    final filtered = sourceItems
        .where((item) {
          final progress = state.progress[item.id];
          final matchesMode = switch (selectedMode) {
            StudyMode.mixed || StudyMode.review || StudyMode.newItems => true,
            StudyMode.weak =>
              progress != null &&
                  progress.attempts > 0 &&
                  progress.accuracy < 0.7,
            StudyMode.favorites => state.preferences.isFavorite(item.id),
            StudyMode.words => item.kind == LearningItemKind.word,
            StudyMode.sentences => item.kind == LearningItemKind.sentence,
            StudyMode.meaning => item.capabilities.contains(
              ExerciseCapability.recognition,
            ),
            StudyMode.production => item.capabilities.contains(
              ExerciseCapability.production,
            ),
            StudyMode.cloze =>
              item.kind == LearningItemKind.sentence &&
                  item.sentenceTokens.length >= 2 &&
                  item.capabilities.contains(ExerciseCapability.cloze),
            StudyMode.sentenceOrder =>
              item.kind == LearningItemKind.sentence &&
                  item.sentenceTokens.length >= 2 &&
                  item.capabilities.contains(ExerciseCapability.sentenceOrder),
            StudyMode.listening => item.capabilities.contains(
              ExerciseCapability.listening,
            ),
            StudyMode.pronunciation => item.capabilities.contains(
              ExerciseCapability.listening,
            ),
          };
          if (!matchesMode) return false;
          return switch (historyFilter) {
            StudyHistoryFilter.all => true,
            StudyHistoryFilter.excludeCorrect =>
              progress == null || progress.correctCount == 0,
            StudyHistoryFilter.wrongOnly =>
              progress != null && progress.wrongCount > 0,
          };
        })
        .toList(growable: false);

    if (selectedMode == StudyMode.favorites) {
      filtered.sort((left, right) {
        final leftProgress = state.progress[left.id];
        final rightProgress = state.progress[right.id];
        if (leftProgress == null && rightProgress != null) return -1;
        if (leftProgress != null && rightProgress == null) return 1;
        if (leftProgress != null && rightProgress != null) {
          final accuracyOrder = leftProgress.accuracy.compareTo(
            rightProgress.accuracy,
          );
          if (accuracyOrder != 0) return accuracyOrder;
        }
        return right.priority.compareTo(left.priority);
      });
      return filtered.take(effectiveItemLimit).toList(growable: false);
    }

    if (selectedMode == StudyMode.weak) {
      filtered.sort((left, right) {
        final leftProgress = state.progress[left.id]!;
        final rightProgress = state.progress[right.id]!;
        final accuracyOrder = leftProgress.accuracy.compareTo(
          rightProgress.accuracy,
        );
        if (accuracyOrder != 0) return accuracyOrder;
        return right.priority.compareTo(left.priority);
      });
      return filtered.take(effectiveItemLimit).toList(growable: false);
    }

    final requestedNewLimit = itemLimit == null
        ? state.preferences.newItemLimit
        : effectiveItemLimit;
    final requestedReviewLimit = itemLimit == null
        ? state.preferences.reviewLimit
        : effectiveItemLimit;
    return _queueBuilder
        .build(
          courseId: state.activeCourseId,
          localDate: now,
          items: filtered,
          progress: state.progress,
          newItemLimit: selectedMode == StudyMode.review
              ? 0
              : requestedNewLimit,
          reviewLimit: selectedMode == StudyMode.newItems
              ? 0
              : requestedReviewLimit,
          queuePriority: queuePriority,
          sentenceRatio: selectedMode == StudyMode.words
              ? 0
              : selectedMode == StudyMode.sentences ||
                    selectedMode == StudyMode.cloze ||
                    selectedMode == StudyMode.sentenceOrder
              ? 1
              : state.preferences.sentenceRatio,
        )
        .take(effectiveItemLimit)
        .toList(growable: false);
  }

  ReviewForecast reviewForecast(DateTime now) => _forecastBuilder.build(
    progress: state.progress.values,
    itemIds: selectedItems.map((item) => item.id).toSet(),
    now: now,
  );

  void selectLanguage(LanguageTag language) {
    if (!language.available) return;
    final preferences = state.preferences.copyWith(
      activeSubjectId: languageSubjectId(language),
      activeSubjectChangedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      selectedLanguage: language,
      preferences: preferences,
    );
    _enqueueUnawaitedPersistenceWrite(
      () => _store.savePreferences(preferences),
    );
    _persist();
  }

  void selectSubject(String subjectId) {
    final normalized = normalizeStudySubjectId(subjectId);
    StudySubject? subject;
    for (final candidate in availableSubjects) {
      if (candidate.id == normalized) {
        subject = candidate;
        break;
      }
    }
    if (subject == null) {
      throw FormatException('존재하지 않는 학습 주제입니다: $normalized');
    }
    final preferences = state.preferences.copyWith(
      activeSubjectId: subject.id,
      activeSubjectChangedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      selectedLanguage: subject.isLanguage
          ? subject.contentLanguage
          : state.selectedLanguage,
      preferences: preferences,
    );
    final pendingSync = _newPendingSyncOperation();
    _enqueueUnawaitedPersistenceWrite(() async {
      await _store.savePreferences(preferences);
      await _replacePendingSyncSnapshot(pendingSync);
    });
    _persist(queueSync: false);
  }

  Future<StudySubject> upsertStudySubject(StudySubject subject) async {
    final normalized = StudySubject.fromJson(subject.toJson());
    final builtIn = builtInLanguageSubjects
        .where((item) => item.id == normalized.id)
        .firstOrNull;
    final validLanguageOverride =
        normalized.kind == StudySubjectKind.language && builtIn != null;
    if (normalized.kind != StudySubjectKind.general && !validLanguageOverride) {
      throw const FormatException('지원하는 기본 언어 주제만 수정할 수 있습니다.');
    }
    if (normalized.kind == StudySubjectKind.general && builtIn != null) {
      throw const FormatException('내장 언어 주제와 같은 ID를 사용할 수 없습니다.');
    }
    final now = DateTime.now().toUtc();
    final byId = {
      for (final current in state.preferences.customSubjects)
        current.id: current,
      normalized.id: normalized,
    };
    final hiddenSubjectIds = {...state.preferences.hiddenSubjectIds}
      ..remove(normalized.id);
    final preferences = state.preferences.copyWith(
      customSubjects: byId.values.toList(growable: false),
      hiddenSubjectIds: hiddenSubjectIds,
      subjectVisibilityChangedAtById: {
        ...state.preferences.subjectVisibilityChangedAtById,
        normalized.id: now,
      },
      activeSubjectId: normalized.id,
      activeSubjectChangedAt: now,
    );
    state = state.copyWith(
      selectedLanguage: normalized.isLanguage
          ? normalized.contentLanguage
          : state.selectedLanguage,
      preferences: preferences,
    );
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
    return normalized;
  }

  Future<void> hideStudySubject(String subjectId) async {
    final normalized = normalizeStudySubjectId(subjectId);
    if (!allSubjects.any((subject) => subject.id == normalized)) {
      throw FormatException('존재하지 않는 학습 주제입니다: $normalized');
    }
    final remaining = availableSubjects
        .where((subject) => subject.id != normalized)
        .toList(growable: false);
    if (remaining.isEmpty) {
      throw const FormatException('최소 한 개의 학습 주제는 남겨 두어야 합니다.');
    }
    final now = DateTime.now().toUtc();
    final nextSubject = state.activeSubjectId == normalized
        ? remaining.first
        : activeSubject;
    final preferences = state.preferences.copyWith(
      hiddenSubjectIds: {...state.preferences.hiddenSubjectIds, normalized},
      subjectVisibilityChangedAtById: {
        ...state.preferences.subjectVisibilityChangedAtById,
        normalized: now,
      },
      activeSubjectId: nextSubject.id,
      activeSubjectChangedAt: state.activeSubjectId == normalized
          ? now
          : state.preferences.activeSubjectChangedAt,
    );
    state = state.copyWith(
      selectedLanguage: nextSubject.isLanguage
          ? nextSubject.contentLanguage
          : state.selectedLanguage,
      preferences: preferences,
    );
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
  }

  Future<void> restoreStudySubject(String subjectId) async {
    final normalized = normalizeStudySubjectId(subjectId);
    final subject = allSubjects
        .where((candidate) => candidate.id == normalized)
        .firstOrNull;
    if (subject == null) {
      throw FormatException('복원할 학습 주제를 찾을 수 없습니다: $normalized');
    }
    final now = DateTime.now().toUtc();
    final hiddenSubjectIds = {...state.preferences.hiddenSubjectIds}
      ..remove(normalized);
    final preferences = state.preferences.copyWith(
      hiddenSubjectIds: hiddenSubjectIds,
      subjectVisibilityChangedAtById: {
        ...state.preferences.subjectVisibilityChangedAtById,
        normalized: now,
      },
      activeSubjectId: normalized,
      activeSubjectChangedAt: now,
    );
    state = state.copyWith(
      selectedLanguage: subject.isLanguage
          ? subject.contentLanguage
          : state.selectedLanguage,
      preferences: preferences,
    );
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
  }

  Future<void> resetStudySubjectOverride(String subjectId) async {
    final normalized = normalizeStudySubjectId(subjectId);
    if (!builtInLanguageSubjects.any((subject) => subject.id == normalized)) {
      throw const FormatException('기본 언어 주제만 초기 상태로 복원할 수 있습니다.');
    }
    final customSubjects = state.preferences.customSubjects
        .where((subject) => subject.id != normalized)
        .toList(growable: false);
    final preferences = state.preferences.copyWith(
      customSubjects: customSubjects,
    );
    state = state.copyWith(preferences: preferences);
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
  }

  ImportDistributionRule? importDistributionRuleFor(String key) {
    final normalized = normalizeImportDistributionKey(key);
    for (final rule in state.preferences.importDistributionRules) {
      if (rule.key == normalized) return rule;
    }
    return null;
  }

  Future<ImportDistributionRule> upsertImportDistributionRule({
    required String key,
    required String subjectId,
    String? groupName,
  }) async {
    final normalizedSubjectId = normalizeStudySubjectId(subjectId);
    if (!allSubjects.any((subject) => subject.id == normalizedSubjectId)) {
      throw FormatException('분배 대상 주제를 찾을 수 없습니다: $normalizedSubjectId');
    }
    final now = DateTime.now().toUtc();
    final previous = state.preferences.importDistributionRules
        .where((rule) => rule.key == normalizeImportDistributionKey(key))
        .firstOrNull;
    final rule = ImportDistributionRule(
      key: key,
      subjectId: normalizedSubjectId,
      groupName: groupName,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    final byKey = {
      for (final current in state.preferences.importDistributionRules)
        current.key: current,
      rule.key: rule,
    };
    final preferences = state.preferences.copyWith(
      importDistributionRules: byKey.values.toList(growable: false),
    );
    state = state.copyWith(preferences: preferences);
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
    return rule;
  }

  void completeOnboarding({
    required LanguageTag language,
    required int dailyGoal,
  }) {
    if (!language.available) return;
    state = state.copyWith(
      selectedLanguage: language,
      preferences: state.preferences.copyWith(
        onboardingCompleted: true,
        dailyGoal: dailyGoal.clamp(20, 500),
        dailyGoalsBySubject: {
          ...state.preferences.dailyGoalsBySubject,
          languageSubjectId(language): dailyGoal.clamp(20, 500),
        },
        dailyGoalChangedAtBySubject: {
          ...state.preferences.dailyGoalChangedAtBySubject,
          languageSubjectId(language): DateTime.now().toUtc(),
        },
        activeSubjectId: languageSubjectId(language),
        activeSubjectChangedAt: DateTime.now().toUtc(),
      ),
    );
    final preferences = state.preferences;
    _enqueueUnawaitedPersistenceWrite(
      () => _store.savePreferences(preferences),
    );
    _persist();
  }

  void updatePreferences(StudyPreferences preferences) {
    final timestamped = preferences.copyWith(
      settingsUpdatedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(preferences: timestamped);
    unawaited(_reconcileStudyNotifications(timestamped));
    final syncPayload = exportSyncSnapshot();
    final pendingSync = _newPendingSyncOperation(payload: syncPayload);
    _enqueueUnawaitedPersistenceWrite(() async {
      await _store.savePreferences(timestamped);
      await _replacePendingSyncSnapshot(pendingSync);
    });
  }

  void updateExperiencePreferences(AppExperiencePreferences preferences) {
    final changedAt = DateTime.now().toUtc();
    updatePreferences(
      state.preferences.copyWith(
        experience: preferences.copyWith(updatedAt: changedAt),
      ),
    );
  }

  void updateInteractionPreferences(StudyInteractionPreferences preferences) {
    final changedAt = DateTime.now().toUtc();
    updatePreferences(
      state.preferences.copyWith(
        interaction: preferences.copyWith(updatedAt: changedAt),
      ),
    );
  }

  void updateTtsRate(double rate) {
    final changedAt = DateTime.now().toUtc();
    updatePreferences(
      state.preferences.copyWith(
        ttsRate: rate.clamp(0.2, 0.8),
        interaction: state.preferences.interaction.copyWith(
          updatedAt: changedAt,
        ),
      ),
    );
  }

  void updateActiveDailyGoal(int goal) {
    updatePreferences(
      state.preferences.withDailyGoalForSubject(
        state.activeSubjectId,
        goal,
        changedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void updateSessionPlan(StudySessionPlan plan) {
    updatePreferences(
      state.preferences.copyWith(
        sessionPlan: plan.copyWith(
          subjectId: state.activeSubjectId,
          updatedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  StudySessionPlan saveSessionPlan(StudySessionPlan plan) {
    final now = DateTime.now().toUtc();
    final planId = plan.planId.isEmpty
        ? 'plan-${now.microsecondsSinceEpoch}'
        : plan.planId;
    final title = plan.title.trim().isEmpty
        ? '학습 계획 ${state.preferences.savedSessionPlans.length + 1}'
        : String.fromCharCodes(plan.title.trim().runes.take(60));
    final saved = plan.copyWith(
      planId: planId,
      subjectId: state.activeSubjectId,
      title: title,
      updatedAt: now,
    );
    final plansById = <String, StudySessionPlan>{
      for (final current in state.preferences.savedSessionPlans)
        current.planId: current,
      saved.planId: saved,
    };
    final plans = plansById.values.toList()..sort(_compareSavedSessionPlans);
    updatePreferences(
      state.preferences.copyWith(
        sessionPlan: saved,
        savedSessionPlans: plans.take(20).toList(growable: false),
      ),
    );
    return saved;
  }

  void deleteSavedSessionPlan(String planId) {
    final deletedAt = DateTime.now().toUtc();
    final plans = state.preferences.savedSessionPlans
        .where((plan) => plan.planId != planId)
        .toList(growable: false);
    final tombstoneEntries =
        {
            ...state.preferences.savedSessionPlanTombstones,
            planId: deletedAt,
          }.entries.toList()
          ..sort((left, right) => right.value.compareTo(left.value));
    final tombstones = {
      for (final entry in tombstoneEntries.take(100))
        entry.key: entry.value.toUtc(),
    };
    final current = state.preferences.sessionPlan;
    updatePreferences(
      state.preferences.copyWith(
        sessionPlan: current.planId == planId
            ? current.copyWith(planId: '', updatedAt: deletedAt)
            : current,
        savedSessionPlans: plans,
        savedSessionPlanTombstones: tombstones,
      ),
    );
  }

  StudySessionPlan? useSavedSessionPlan(StudySessionPlan plan) {
    StudySessionPlan? stored;
    for (final saved in state.preferences.savedSessionPlans) {
      if (saved.planId == plan.planId) {
        stored = saved;
        break;
      }
    }
    if (stored == null || stored.subjectId != state.activeSubjectId) {
      return null;
    }
    updatePreferences(state.preferences.copyWith(sessionPlan: stored));
    return stored;
  }

  StudySessionPlan? consumeScheduledSessionPlan(String planId) {
    StudySessionPlan? stored;
    for (final saved in state.preferences.savedSessionPlans) {
      if (saved.planId == planId) {
        stored = saved;
        break;
      }
    }
    if (stored == null || stored.subjectId != state.activeSubjectId) {
      return null;
    }
    final now = DateTime.now().toUtc();
    final consumed = stored.copyWith(scheduledAt: null, updatedAt: now);
    updatePreferences(
      state.preferences.copyWith(
        sessionPlan: consumed,
        savedSessionPlans: [
          for (final plan in state.preferences.savedSessionPlans)
            if (plan.planId == planId) consumed else plan,
        ],
      ),
    );
    return consumed;
  }

  StudySessionPlan? completeExamPlanForToday(
    String planId, {
    DateTime? completedAt,
  }) {
    final now = (completedAt ?? DateTime.now()).toUtc();
    return _updateSavedSessionPlan(planId, (plan) {
      final exam = plan.examSchedule;
      if (exam == null) {
        return plan.copyWith(scheduledAt: null, updatedAt: now);
      }
      final completedExam = exam.copyWith(
        lastCompletedAt: now,
        snoozedUntil: null,
        updatedAt: now,
      );
      final targetLocal = exam.targetDate.toLocal();
      final nowLocal = now.toLocal();
      final targetReached =
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day).compareTo(
            DateTime(targetLocal.year, targetLocal.month, targetLocal.day),
          ) >=
          0;
      return plan.copyWith(
        examSchedule: completedExam,
        scheduledAt: targetReached
            ? null
            : completedExam.nextStudyAt(now, tomorrow: true),
        updatedAt: now,
      );
    });
  }

  StudySessionPlan? snoozeSessionPlan(
    String planId, {
    Duration delay = const Duration(minutes: 10),
    DateTime? now,
  }) {
    final changedAt = (now ?? DateTime.now()).toUtc();
    final safeMinutes = delay.inMinutes.clamp(1, 24 * 60);
    final scheduledAt = changedAt.add(Duration(minutes: safeMinutes));
    return _updateSavedSessionPlan(planId, (plan) {
      return plan.copyWith(
        scheduledAt: scheduledAt,
        examSchedule: plan.examSchedule?.copyWith(
          snoozedUntil: scheduledAt,
          updatedAt: changedAt,
        ),
        updatedAt: changedAt,
      );
    });
  }

  StudySessionPlan? deferSessionPlanUntilTomorrow(
    String planId, {
    DateTime? now,
  }) {
    final changedAt = (now ?? DateTime.now()).toUtc();
    return _updateSavedSessionPlan(planId, (plan) {
      final exam = plan.examSchedule;
      final scheduledAt =
          exam?.nextStudyAt(changedAt, tomorrow: true) ??
          DateTime(
            changedAt.toLocal().year,
            changedAt.toLocal().month,
            changedAt.toLocal().day + 1,
            plan.scheduledAt?.toLocal().hour ?? 19,
            plan.scheduledAt?.toLocal().minute ?? 0,
          ).toUtc();
      return plan.copyWith(
        scheduledAt: scheduledAt,
        examSchedule: exam?.copyWith(
          snoozedUntil: scheduledAt,
          updatedAt: changedAt,
        ),
        updatedAt: changedAt,
      );
    });
  }

  StudySessionPlan? changeSessionPlanTime(
    String planId, {
    required int minuteOfDay,
    DateTime? now,
  }) {
    final changedAt = (now ?? DateTime.now()).toUtc();
    final safeMinute = minuteOfDay.clamp(0, 1439);
    return _updateSavedSessionPlan(planId, (plan) {
      final exam =
          (plan.examSchedule ??
                  ExamSchedule(
                    targetDate: changedAt.add(const Duration(days: 30)),
                  ))
              .copyWith(
                preferredMinuteOfDay: safeMinute,
                snoozedUntil: null,
                updatedAt: changedAt,
              );
      return plan.copyWith(
        examSchedule: exam,
        scheduledAt: exam.nextStudyAt(changedAt),
        updatedAt: changedAt,
      );
    });
  }

  StudySessionPlan? _updateSavedSessionPlan(
    String planId,
    StudySessionPlan Function(StudySessionPlan plan) update,
  ) {
    StudySessionPlan? current;
    for (final plan in state.preferences.savedSessionPlans) {
      if (plan.planId == planId) {
        current = plan;
        break;
      }
    }
    if (current == null || current.subjectId != state.activeSubjectId) {
      return null;
    }
    final next = update(current);
    updatePreferences(
      state.preferences.copyWith(
        sessionPlan: state.preferences.sessionPlan.planId == planId
            ? next
            : state.preferences.sessionPlan,
        savedSessionPlans: [
          for (final plan in state.preferences.savedSessionPlans)
            if (plan.planId == planId) next else plan,
        ],
      ),
    );
    return next;
  }

  List<LearningItem> get weakItems {
    final items = courseItems
        .where((item) {
          final progress = state.progress[item.id];
          return progress != null &&
              progress.attempts > 0 &&
              progress.accuracy < 0.7;
        })
        .toList(growable: false);
    return _sortSmartCollection(items);
  }

  List<LearningItem> get recentWrongItems {
    final items = courseItems
        .where((item) {
          final progress = state.progress[item.id];
          return progress?.lastResult == ReviewRating.again;
        })
        .toList(growable: false);
    return _sortSmartCollection(items);
  }

  List<LearningItem> _sortSmartCollection(List<LearningItem> items) {
    final sorted = [...items]
      ..sort((left, right) {
        final leftProgress = state.progress[left.id]!;
        final rightProgress = state.progress[right.id]!;
        final studiedOrder =
            (rightProgress.lastStudiedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
                .compareTo(
                  leftProgress.lastStudiedAt ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                );
        if (studiedOrder != 0) return studiedOrder;
        final accuracyOrder = leftProgress.accuracy.compareTo(
          rightProgress.accuracy,
        );
        if (accuracyOrder != 0) return accuracyOrder;
        return left.id.compareTo(right.id);
      });
    return List.unmodifiable(sorted);
  }

  List<SmartCollectionDefinition> get smartCollections {
    final values = state.preferences.smartCollections
        .where(
          (collection) =>
              collection.subjectId == state.activeSubjectId &&
              !state.preferences.smartCollectionTombstones.containsKey(
                collection.id,
              ),
        )
        .toList();
    values.sort((left, right) {
      final pinOrder = (right.pinned ? 1 : 0).compareTo(left.pinned ? 1 : 0);
      if (pinOrder != 0) return pinOrder;
      final updatedOrder = right.updatedAt.compareTo(left.updatedAt);
      if (updatedOrder != 0) return updatedOrder;
      return left.name.compareTo(right.name);
    });
    return List.unmodifiable(values);
  }

  List<LearningItem> itemsForSmartCollection(
    SmartCollectionDefinition collection, {
    DateTime? now,
  }) {
    if (collection.subjectId != state.activeSubjectId) return const [];
    final query = foldLibrarySearchText(collection.query);
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final items = courseItems.where((item) {
      if (collection.kinds.isNotEmpty &&
          !collection.kinds.contains(item.kind)) {
        return false;
      }
      if (collection.partsOfSpeech.isNotEmpty &&
          !collection.partsOfSpeech.contains(item.partOfSpeech)) {
        return false;
      }
      if (collection.levels.isNotEmpty &&
          !collection.levels.contains(item.level)) {
        return false;
      }
      if (collection.tags.isNotEmpty &&
          !collection.tags.every(item.tags.contains)) {
        return false;
      }
      if (collection.groupIds.isNotEmpty) {
        final itemGroupIds = {
          for (final name in learningGroupsOf(item))
            learningGroupDefinitionId(collection.subjectId, name),
        };
        if (itemGroupIds.intersection(collection.groupIds).isEmpty) {
          return false;
        }
      }
      final sourceId = item.source.sourceId ?? item.source.name;
      if (collection.sourceIds.isNotEmpty &&
          !collection.sourceIds.contains(sourceId) &&
          !collection.sourceIds.contains(item.source.name)) {
        return false;
      }
      final progress = state.progress[item.id];
      final effectiveStatus =
          state.preferences.excludedItemIds.contains(item.id)
          ? LearningStatus.suspended
          : progress?.status ?? LearningStatus.newItem;
      if (collection.learningStatuses.isNotEmpty &&
          !collection.learningStatuses.contains(effectiveStatus)) {
        return false;
      }
      if (collection.dueOnly &&
          (progress?.nextReviewAt == null ||
              progress!.nextReviewAt!.isAfter(effectiveNow))) {
        return false;
      }
      if (query.isNotEmpty) {
        final searchable = foldLibrarySearchText(
          [
            item.text,
            ...item.translations,
            ...item.acceptedAnswers,
            ...item.readings.map((reading) => reading.value),
            if (item.example != null) item.example!,
            if (item.exampleTranslation != null) item.exampleTranslation!,
            ...item.tags,
            item.level,
            item.partOfSpeech?.koreanLabel ?? '',
            item.source.name,
            item.source.sourceId ?? '',
            item.source.license,
            item.source.author ?? '',
          ].join(' '),
        );
        if (!query.split(' ').every(searchable.contains)) return false;
      }
      return true;
    }).toList();
    items.sort((left, right) {
      final leftProgress = state.progress[left.id];
      final rightProgress = state.progress[right.id];
      return switch (collection.sort) {
        SmartCollectionSort.alphabetical => foldLibrarySearchText(
          left.text,
        ).compareTo(foldLibrarySearchText(right.text)),
        SmartCollectionSort.updatedNewest =>
          (right.updatedAt ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
              .compareTo(
                left.updatedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              ),
        SmartCollectionSort.recentlyStudied =>
          (rightProgress?.lastStudiedAt ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
              .compareTo(
                leftProgress?.lastStudiedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              ),
        SmartCollectionSort.dueFirst =>
          (leftProgress?.nextReviewAt ?? DateTime.utc(9999, 12, 31)).compareTo(
            rightProgress?.nextReviewAt ?? DateTime.utc(9999, 12, 31),
          ),
        SmartCollectionSort.weakestFirst =>
          (leftProgress?.accuracy ?? 0).compareTo(rightProgress?.accuracy ?? 0),
      };
    });
    return List.unmodifiable(items);
  }

  Future<void> upsertSmartCollection(
    SmartCollectionDefinition collection,
  ) async {
    if (collection.subjectId != state.activeSubjectId) {
      throw ArgumentError('스마트 컬렉션은 현재 학습 주제 안에서만 저장할 수 있습니다.');
    }
    final changedAt = DateTime.now().toUtc();
    final normalized = collection.copyWith(updatedAt: changedAt);
    final values = <String, SmartCollectionDefinition>{
      for (final current in state.preferences.smartCollections)
        current.id: current,
      normalized.id: normalized,
    };
    final tombstones = {...state.preferences.smartCollectionTombstones}
      ..remove(normalized.id);
    updatePreferences(
      state.preferences.copyWith(
        smartCollections: values.values.toList(growable: false),
        smartCollectionTombstones: tombstones,
      ),
    );
  }

  Future<void> deleteSmartCollection(String id) async {
    final changedAt = DateTime.now().toUtc();
    updatePreferences(
      state.preferences.copyWith(
        smartCollections: state.preferences.smartCollections
            .where((collection) => collection.id != id)
            .toList(growable: false),
        smartCollectionTombstones: {
          ...state.preferences.smartCollectionTombstones,
          id: changedAt,
        },
      ),
    );
  }

  void toggleItemSelection(String itemId) {
    final excluded = {...state.preferences.excludedItemIds};
    if (!excluded.add(itemId)) excluded.remove(itemId);
    updatePreferences(
      state.preferences.copyWith(
        excludedItemIds: excluded,
        excludedItemChangedAtById: {
          ...state.preferences.excludedItemChangedAtById,
          itemId: DateTime.now().toUtc(),
        },
      ),
    );
  }

  void toggleFavorite(String itemId) {
    final favorites = {...state.preferences.favoriteItemIds};
    if (!favorites.add(itemId)) favorites.remove(itemId);
    updatePreferences(
      state.preferences.copyWith(
        favoriteItemIds: favorites,
        favoriteItemChangedAtById: {
          ...state.preferences.favoriteItemChangedAtById,
          itemId: DateTime.now().toUtc(),
        },
      ),
    );
  }

  bool hasCompletedMission(int unitIndex) =>
      state.preferences.hasCompletedMission(state.activeCourseId, unitIndex);

  int get completedMissionCount => List.generate(
    coursePath.units.length,
    (index) => index,
  ).where(hasCompletedMission).length;

  void completeMission(int unitIndex) {
    if (unitIndex < 0 || unitIndex >= coursePath.units.length) return;
    final completed = {...state.preferences.completedMissionIds}
      ..add('${state.activeCourseId}:$unitIndex');
    updatePreferences(
      state.preferences.copyWith(completedMissionIds: completed),
    );
  }

  void recordAnswer({
    required LearningItem item,
    required bool correct,
    required DateTime studiedAt,
    required String exerciseType,
    ReviewRating? rating,
    bool recordProgress = true,
  }) {
    if (!recordProgress) return;
    final current = state.progress[item.id] ?? ProgressRecord(itemId: item.id);
    final effectiveRating =
        rating ?? (correct ? ReviewRating.good : ReviewRating.again);
    final successful = effectiveRating != ReviewRating.again;
    final next = _scheduler.apply(
      current: current,
      rating: effectiveRating,
      studiedAt: studiedAt,
    );
    final xp = switch (effectiveRating) {
      ReviewRating.again => 5,
      ReviewRating.hard => 8,
      ReviewRating.good => 10,
      ReviewRating.easy => 15,
    };
    final replicaId = state.replicaId.isEmpty
        ? 'legacy-local'
        : state.replicaId;
    final nextXpByReplica = <String, int>{
      ...state.xpByReplica,
      replicaId: ((state.xpByReplica[replicaId] ?? 0) + xp).clamp(
        0,
        _maximumXp,
      ),
    };
    final nextTotalXp = _sumXpLedger(nextXpByReplica);
    final studiedDay = DateTime(studiedAt.year, studiedAt.month, studiedAt.day);
    final previousDay = state.lastStudyDate == null
        ? null
        : DateTime(
            state.lastStudyDate!.year,
            state.lastStudyDate!.month,
            state.lastStudyDate!.day,
          );
    final isSameDay = previousDay == studiedDay;
    final isOlderDay = previousDay != null && studiedDay.isBefore(previousDay);
    final isConsecutive =
        previousDay != null && studiedDay.difference(previousDay).inDays == 1;
    final nextDailyXpLedger = <String, Map<String, int>>{
      if (isSameDay || isOlderDay)
        for (final entry in state.dailyXpByCourseAndReplica.entries)
          entry.key: {...entry.value},
    };
    if (!isOlderDay) {
      final courseLedger = <String, int>{
        ...?nextDailyXpLedger[item.courseId],
        replicaId: ((nextDailyXpLedger[item.courseId]?[replicaId] ?? 0) + xp)
            .clamp(0, _maximumXp),
      };
      nextDailyXpLedger[item.courseId] = courseLedger;
    }
    final nextDailyXpByCourse = _dailyXpByCourseFromLedger(nextDailyXpLedger);
    final nextStreak = isSameDay || isOlderDay
        ? state.streakDays
        : isConsecutive
        ? state.streakDays + 1
        : 1;
    final nextBadges = {...state.badges};
    if (state.progress.isEmpty) {
      nextBadges.add('첫걸음');
    }
    if (nextTotalXp >= 100) {
      nextBadges.add('100 XP');
    }
    if (next.correctCount >= 3) {
      nextBadges.add('꾸준한 복습');
    }

    state = state.copyWith(
      progress: {...state.progress, item.id: next},
      totalXp: nextTotalXp,
      xpByReplica: Map.unmodifiable(nextXpByReplica),
      dailyXp: _sumDailyXpByCourse(nextDailyXpByCourse),
      dailyXpByCourse: nextDailyXpByCourse,
      dailyXpByCourseAndReplica: _freezeDailyXpLedger(nextDailyXpLedger),
      streakDays: nextStreak,
      badges: nextBadges,
      lastStudyDate: isOlderDay ? state.lastStudyDate : studiedDay,
    );
    unawaited(
      _store.saveStudyEvent(
        StudyEventEntry(
          eventId:
              '${studiedAt.toUtc().microsecondsSinceEpoch}-${item.id}-${next.attempts}',
          courseId: item.courseId,
          itemId: item.id,
          exerciseType: exerciseType,
          result: successful ? 'correct' : 'wrong',
          studiedAt: studiedAt,
        ),
      ),
    );
    _persist();
  }

  ProgressRecord previewReview({
    required LearningItem item,
    required ReviewRating rating,
    required DateTime studiedAt,
  }) {
    return _scheduler.apply(
      current: state.progress[item.id] ?? ProgressRecord(itemId: item.id),
      rating: rating,
      studiedAt: studiedAt,
    );
  }

  ActiveStudySession beginActiveStudySession({
    required String sessionId,
    required StudyMode mode,
    required int? unitIndex,
    required List<String> itemIds,
    required DateTime startedAt,
    String? courseId,
  }) {
    final session = ActiveStudySession.started(
      sessionId: sessionId,
      courseId: courseId ?? state.activeCourseId,
      mode: mode,
      unitIndex: unitIndex,
      itemIds: itemIds,
      startedAt: startedAt,
    );
    _activateStudySession(session);
    return session;
  }

  ActiveStudySession? updateActiveStudySession({
    required List<String> itemIds,
    required int currentIndex,
    required int correctCount,
    required int wrongCount,
    required int earnedXp,
    required DateTime updatedAt,
    Set<String> wrongItemIds = const {},
    Set<String> finalCorrectItemIds = const {},
    String? expectedSessionId,
  }) {
    final current = state.activeStudySession;
    if (current == null) return null;
    if (expectedSessionId != null && current.sessionId != expectedSessionId) {
      return null;
    }
    if (itemIds.length > StudyLimits.maxActiveQueueEntries) {
      throw ArgumentError(
        'Active queue cannot exceed '
        '${StudyLimits.maxActiveQueueEntries} entries.',
      );
    }
    final next = current.copyWith(
      itemIds: List.unmodifiable(itemIds),
      wrongItemIds: Set.unmodifiable(wrongItemIds),
      finalCorrectItemIds: Set.unmodifiable(finalCorrectItemIds),
      currentIndex: currentIndex,
      correctCount: correctCount,
      wrongCount: wrongCount,
      earnedXp: earnedXp,
      updatedAt: updatedAt.toUtc(),
    );
    _activateStudySession(next);
    return next;
  }

  ActiveStudySession? pauseActiveStudySession(
    DateTime occurredAt, {
    List<String>? itemIds,
    Set<String>? wrongItemIds,
    Set<String>? finalCorrectItemIds,
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    int? earnedXp,
    String? expectedSessionId,
  }) {
    final current = state.activeStudySession;
    if (current == null) return null;
    if (expectedSessionId != null && current.sessionId != expectedSessionId) {
      return null;
    }
    if (itemIds != null && itemIds.length > StudyLimits.maxActiveQueueEntries) {
      throw ArgumentError(
        'Active queue cannot exceed '
        '${StudyLimits.maxActiveQueueEntries} entries.',
      );
    }
    final updated = current.copyWith(
      itemIds: itemIds,
      wrongItemIds: wrongItemIds,
      finalCorrectItemIds: finalCorrectItemIds,
      currentIndex: currentIndex,
      correctCount: correctCount,
      wrongCount: wrongCount,
      earnedXp: earnedXp,
      updatedAt: occurredAt.toUtc(),
    );
    final next = updated.pause(occurredAt);
    _activateStudySession(next);
    return next;
  }

  ActiveStudySession? resumeActiveStudySession(
    DateTime occurredAt, {
    String? expectedSessionId,
  }) {
    final current = state.activeStudySession;
    if (current == null) return null;
    if (expectedSessionId != null && current.sessionId != expectedSessionId) {
      return null;
    }
    final next = current.resume(occurredAt);
    _activateStudySession(next);
    return next;
  }

  ActiveStudySession deriveActiveStudySession({
    required ActiveStudySession source,
    required String sessionId,
    required StudySessionOrigin origin,
    required List<String> itemIds,
    required DateTime startedAt,
  }) {
    final next = source.derive(
      newSessionId: sessionId,
      nextOrigin: origin,
      selectedItemIds: itemIds,
      startedAt: startedAt,
    );
    _activateStudySession(next);
    return next;
  }

  void _activateStudySession(ActiveStudySession session) {
    state = state.copyWith(
      activeStudySession: session,
      activeSessionChangedAt: session.updatedAt,
    );
    unawaited(() async {
      await _store.saveActiveStudySession(session);
      await _queueSyncIfDriveConnected();
    }());
  }

  bool clearActiveStudySession({
    DateTime? clearedAt,
    String? expectedSessionId,
  }) {
    final current = state.activeStudySession;
    if (expectedSessionId != null &&
        (current == null || current.sessionId != expectedSessionId)) {
      return false;
    }
    final changedAt = clearedAt ?? DateTime.now();
    state = state.copyWith(
      activeStudySession: null,
      activeSessionChangedAt: changedAt,
    );
    unawaited(() async {
      await _store.clearActiveStudySession(changedAt);
      await _queueSyncIfDriveConnected();
    }());
    return true;
  }

  Future<void> finishSession(StudySessionSummary session) async {
    if (!session.recordProgress) return;
    await _store.saveStudySession(session);
    if (!mounted) return;
    state = state.copyWith(
      recentSessions: [
        session,
        ...state.recentSessions
            .where((item) => item.sessionId != session.sessionId)
            .take(19),
      ],
    );
    await _queueSyncIfDriveConnected();
  }

  void setDriveConnected(bool connected) {
    state = state.copyWith(driveConnected: connected);
    _persist(queueSync: false);
  }

  ImportReview reviewImport(ImportPreview preview) {
    return _importReconciler.review(
      preview: preview,
      existingItems: [...state.customItems, ...sampleContent],
      replaceableItemIds: state.customItems.map((item) => item.id).toSet(),
    );
  }

  Future<ImportCommitRecord?> previousImportBySha256(String sha256) {
    return _store.findImportBySha256(sha256);
  }

  Future<ImportCommitResult> importItems(
    List<LearningItem> items, {
    ImportConflictPolicy conflictPolicy = ImportConflictPolicy.keepExisting,
  }) async {
    final existing = {for (final item in state.customItems) item.id: item};
    final existingByContentKey = {
      for (final item in state.customItems)
        _contentValidator.duplicateKey(item): item,
    };
    final resolutions = <ImportResolution>[];
    for (final item in items) {
      final current =
          existing[item.id] ??
          existingByContentKey[_contentValidator.duplicateKey(item)];
      resolutions.add(
        ImportResolution(
          incoming: item,
          action: current == null
              ? ImportReviewAction.add
              : conflictPolicy == ImportConflictPolicy.replaceExisting
              ? ImportReviewAction.replace
              : ImportReviewAction.skip,
          expectedExistingId: current?.id,
          expectedExistingSignature: current == null
              ? null
              : _importReconciler.signature(current),
        ),
      );
    }
    return _commitImportResolutions(resolutions, rejectedRows: 0);
  }

  Future<ImportCommitResult> importResolvedItems(
    Iterable<ImportResolution> resolutions, {
    required String fileName,
    required String sha256,
    required int rejectedRows,
  }) {
    return _commitImportResolutions(
      resolutions,
      fileName: fileName,
      sha256: sha256,
      rejectedRows: rejectedRows,
    );
  }

  Future<ImportCommitResult> _commitImportResolutions(
    Iterable<ImportResolution> resolutions, {
    String? fileName,
    String? sha256,
    required int rejectedRows,
  }) async {
    final changedAt = DateTime.now().toUtc();
    final existing = {for (final item in state.customItems) item.id: item};
    final allExisting = {for (final item in courseItems) item.id: item};
    final existingByContentKey = <String, LearningItem>{};
    for (final item in [...state.customItems, ...courseItems]) {
      existingByContentKey.putIfAbsent(
        _contentValidator.duplicateKey(item),
        () => item,
      );
    }
    final toSave = <LearningItem>[];
    final receiptChanges = <ImportBatchChange>[];
    var added = 0;
    var replaced = 0;
    var skipped = 0;
    var stale = 0;
    for (final resolution in resolutions) {
      if (resolution.action == ImportReviewAction.skip) {
        skipped++;
        continue;
      }
      final item = _contentValidator
          .ensureValid(resolution.incoming)
          .copyWith(updatedAt: changedAt);
      final contentKey = _contentValidator.duplicateKey(item);
      if (resolution.action == ImportReviewAction.add) {
        final collision = existing[item.id] ?? existingByContentKey[contentKey];
        if (collision != null) {
          stale++;
          continue;
        }
        added++;
        final versioned = _nextContentRevision(item, null);
        existing[versioned.id] = versioned;
        existingByContentKey[_contentValidator.duplicateKey(versioned)] =
            versioned;
        toSave.add(versioned);
        receiptChanges.add(
          ImportBatchChange(
            itemId: versioned.id,
            kind: ImportChangeKind.added,
            after: _itemCodec.toJson(versioned),
          ),
        );
        continue;
      }

      final expectedId = resolution.expectedExistingId;
      final current = expectedId == null
          ? null
          : existing[expectedId] ?? allExisting[expectedId];
      final expectedSignature = resolution.expectedExistingSignature;
      if (current == null ||
          expectedSignature == null ||
          _importReconciler.signature(current) != expectedSignature) {
        stale++;
        continue;
      }
      final semanticCollision = existingByContentKey[contentKey];
      if (semanticCollision != null && semanticCollision.id != current.id) {
        stale++;
        continue;
      }
      replaced++;
      final candidate = item.id == current.id
          ? item
          : item.copyWith(id: current.id);
      final versioned = _nextContentRevision(candidate, current);
      existingByContentKey.remove(_contentValidator.duplicateKey(current));
      existing[versioned.id] = versioned;
      allExisting[versioned.id] = versioned;
      existingByContentKey[_contentValidator.duplicateKey(versioned)] =
          versioned;
      toSave.add(versioned);
      receiptChanges.add(
        ImportBatchChange(
          itemId: versioned.id,
          kind: ImportChangeKind.replaced,
          before: _itemCodec.toJson(current),
          after: _itemCodec.toJson(versioned),
        ),
      );
    }
    importLimits.ensureDatasetItemCount(existing.length);
    final tombstones = {...state.customItemTombstones};
    for (final item in toSave) {
      tombstones.remove(item.id);
    }
    final record = fileName == null || sha256 == null
        ? null
        : ImportCommitRecord(
            importId:
                'import-${changedAt.microsecondsSinceEpoch}-${sha256.substring(0, sha256.length < 12 ? sha256.length : 12)}',
            fileName: fileName,
            sha256: sha256,
            importedRows: added + replaced,
            rejectedRows: rejectedRows + skipped + stale,
            importedAt: changedAt,
          );
    await _store.commitCustomItemImport(
      items: toSave,
      tombstones: tombstones,
      record: record,
    );
    final result = ImportCommitResult(
      added: added,
      replaced: replaced,
      skipped: skipped,
      stale: stale,
    );
    if (!mounted) return result;
    var preferences = state.preferences;
    if (record != null) {
      final destinationCounts = <String, int>{};
      for (final item in toSave) {
        final subjectId = item.effectiveSubjectId;
        final distributionKey = importDistributionKeyOf(item) ?? '';
        final identity = '$subjectId\u001F$distributionKey';
        destinationCounts[identity] = (destinationCounts[identity] ?? 0) + 1;
      }
      final destinations =
          [
            for (final entry in destinationCounts.entries)
              ImportReceiptDestination(
                subjectId: entry.key.split('\u001F').first,
                distributionKey: entry.key.split('\u001F').last,
                itemCount: entry.value,
              ),
          ]..sort((left, right) {
            final subjectOrder = left.subjectId.compareTo(right.subjectId);
            return subjectOrder != 0
                ? subjectOrder
                : left.distributionKey.compareTo(right.distributionKey);
          });
      final receipt = ImportBatchReceipt(
        importId: record.importId,
        fileName: record.fileName,
        subjectId: destinations.length == 1
            ? destinations.single.subjectId
            : state.activeSubjectId,
        distributionKey: destinations.length == 1
            ? destinations.single.distributionKey
            : '',
        addedCount: added,
        mergedCount: replaced,
        skippedCount: skipped + stale,
        errorCount: rejectedRows,
        changes: List.unmodifiable(receiptChanges),
        createdAt: changedAt,
        destinations: List.unmodifiable(destinations),
      );
      preferences = preferences.copyWith(
        settingsUpdatedAt: changedAt,
        importReceipts: [
          receipt,
          ...preferences.importReceipts
              .where((value) => value.importId != receipt.importId)
              .take(29),
        ],
      );
      await _store.savePreferences(preferences);
    }
    state = state.copyWith(
      customItems: existing.values.toList(growable: false),
      customItemTombstones: tombstones,
      preferences: preferences,
    );
    if (toSave.isNotEmpty) await _queueSyncIfDriveConnected();
    return result;
  }

  List<ImportBatchReceipt> get importReceipts =>
      List.unmodifiable(state.preferences.importReceipts);

  List<ImportMappingPreset> get importMappingPresets =>
      List.unmodifiable(state.preferences.importMappingPresets);

  Future<void> upsertImportMappingPreset(ImportMappingPreset preset) async {
    final changedAt = DateTime.now().toUtc();
    final normalized = ImportMappingPreset(
      id: preset.id,
      name: preset.name,
      columns: Map.unmodifiable(preset.columns),
      updatedAt: changedAt,
    );
    final values = <String, ImportMappingPreset>{
      for (final current in state.preferences.importMappingPresets)
        current.id: current,
      normalized.id: normalized,
    };
    updatePreferences(
      state.preferences.copyWith(
        importMappingPresets: values.values.toList(growable: false),
      ),
    );
  }

  Future<void> deleteImportMappingPreset(String id) async {
    updatePreferences(
      state.preferences.copyWith(
        importMappingPresets: state.preferences.importMappingPresets
            .where((preset) => preset.id != id)
            .toList(growable: false),
      ),
    );
  }

  ImportUndoPreview previewImportUndo(String importId) {
    final receipt = state.preferences.importReceipts
        .where((value) => value.importId == importId)
        .firstOrNull;
    if (receipt == null || !receipt.canUndo) {
      return const ImportUndoPreview(safeChangeCount: 0, conflicts: []);
    }
    final items = {for (final item in state.customItems) item.id: item};
    final conflicts = <ImportUndoConflict>[];
    var safeChangeCount = 0;
    for (final change in receipt.changes.reversed) {
      final current = items[change.itemId];
      final currentJson = current == null ? null : _itemCodec.toJson(current);
      final matchesImported =
          currentJson != null &&
          change.after != null &&
          jsonEncode(currentJson) == jsonEncode(change.after);
      if (matchesImported) {
        safeChangeCount++;
        continue;
      }
      conflicts.add(
        ImportUndoConflict(
          itemId: change.itemId,
          current: currentJson,
          imported: change.after,
          before: change.before,
        ),
      );
    }
    return ImportUndoPreview(
      safeChangeCount: safeChangeCount,
      conflicts: List.unmodifiable(conflicts),
    );
  }

  Future<ImportUndoResult> undoImport(String importId) async {
    final receipt = state.preferences.importReceipts
        .where((value) => value.importId == importId)
        .firstOrNull;
    if (receipt == null || !receipt.canUndo) {
      return const ImportUndoResult(
        restored: 0,
        removed: 0,
        skippedConflicts: 0,
      );
    }
    final changedAt = DateTime.now().toUtc();
    final items = {for (final item in state.customItems) item.id: item};
    final tombstones = {...state.customItemTombstones};
    var restored = 0;
    var removed = 0;
    var skipped = 0;
    for (final change in receipt.changes.reversed) {
      final current = items[change.itemId];
      if (current == null ||
          change.after == null ||
          jsonEncode(_itemCodec.toJson(current)) != jsonEncode(change.after)) {
        skipped++;
        continue;
      }
      if (change.kind == ImportChangeKind.added && change.before == null) {
        await _store.deleteCustomItem(change.itemId);
        items.remove(change.itemId);
        tombstones[change.itemId] = changedAt;
        removed++;
        continue;
      }
      final before = change.before;
      if (before == null) {
        skipped++;
        continue;
      }
      try {
        final restoredItem = _nextContentRevision(
          _itemCodec.fromJson(before).copyWith(updatedAt: changedAt),
          current,
        );
        await _store.saveCustomItems([restoredItem]);
        items[restoredItem.id] = restoredItem;
        tombstones.remove(restoredItem.id);
        restored++;
      } on FormatException {
        skipped++;
      }
    }
    await _store.saveCustomItemTombstones(tombstones);
    final preferences = state.preferences.copyWith(
      settingsUpdatedAt: changedAt,
      importReceipts: [
        for (final value in state.preferences.importReceipts)
          if (value.importId == importId)
            value.markUndone(changedAt)
          else
            value,
      ],
    );
    state = state.copyWith(
      customItems: items.values.toList(growable: false),
      customItemTombstones: tombstones,
      preferences: preferences,
    );
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
    return ImportUndoResult(
      restored: restored,
      removed: removed,
      skippedConflicts: skipped,
    );
  }

  ContentCorrection? contentCorrectionFor(String itemId) {
    final values =
        state.preferences.contentCorrections
            .where(
              (correction) =>
                  correction.itemId == itemId && !correction.resolved,
            )
            .toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return values.firstOrNull;
  }

  Future<void> upsertContentCorrection(ContentCorrection correction) async {
    final changedAt = DateTime.now().toUtc();
    final normalized = ContentCorrection(
      itemId: correction.itemId,
      field: correction.field,
      note: correction.note,
      proposedValue: correction.proposedValue,
      updatedAt: changedAt,
      resolved: correction.resolved,
    );
    final key = '${normalized.itemId}\u001F${normalized.field}';
    final values = <String, ContentCorrection>{
      for (final current in state.preferences.contentCorrections)
        '${current.itemId}\u001F${current.field}': current,
      key: normalized,
    };
    final tombstones = {...state.preferences.contentCorrectionTombstones}
      ..remove(key);
    updatePreferences(
      state.preferences.copyWith(
        contentCorrections: values.values.toList(growable: false),
        contentCorrectionTombstones: tombstones,
      ),
    );
  }

  Future<void> deleteContentCorrection({
    required String itemId,
    required String field,
  }) async {
    final key = '$itemId\u001F$field';
    final changedAt = DateTime.now().toUtc();
    updatePreferences(
      state.preferences.copyWith(
        contentCorrections: state.preferences.contentCorrections
            .where(
              (correction) =>
                  correction.itemId != itemId || correction.field != field,
            )
            .toList(growable: false),
        contentCorrectionTombstones: {
          ...state.preferences.contentCorrectionTombstones,
          key: changedAt,
        },
      ),
    );
  }

  Future<void> upsertCustomItem(LearningItem item) async {
    var normalized = _contentValidator
        .ensureValid(item)
        .copyWith(updatedAt: DateTime.now().toUtc());
    normalized = _nextContentRevision(
      normalized,
      customItemById(normalized.id),
    );
    final merged = <String, LearningItem>{
      for (final current in state.customItems) current.id: current,
      normalized.id: normalized,
    };
    await _store.saveCustomItems([normalized]);
    final tombstones = {...state.customItemTombstones}..remove(normalized.id);
    await _store.saveCustomItemTombstones(tombstones);
    if (!mounted) return;
    state = state.copyWith(
      customItems: merged.values.toList(growable: false),
      customItemTombstones: tombstones,
    );
    await _queueSyncIfDriveConnected();
  }

  LearningItem? findContentIdentityMatch(LearningItem candidate) {
    final identityKey = _contentValidator.identityKey(candidate);
    for (final item in [...state.customItems, ...sampleContent]) {
      if (_contentValidator.identityKey(item) == identityKey) return item;
    }
    return null;
  }

  DuplicateRepairCatalog duplicateRepairCatalog({String? subjectId}) {
    final scope = subjectId ?? state.activeSubjectId;
    return _duplicateRepairAnalyzer.analyze(
      state.customItems,
      subjectId: scope,
    );
  }

  Future<DuplicateRepairResult> mergeDuplicateCustomItems(
    DuplicateMergeRequest request,
  ) async {
    final affectedIds = request.allItemIds;
    if (affectedIds.length < 2 ||
        request.duplicateItemIds.contains(request.canonicalItemId)) {
      throw ArgumentError(
        'A duplicate repair needs one canonical item and at least one duplicate.',
      );
    }
    final byId = {
      for (final item in state.customItems)
        if (affectedIds.contains(item.id)) item.id: item,
    };
    if (byId.length != affectedIds.length) {
      throw StateError('Duplicate repair only supports existing user content.');
    }
    final originals = [for (final itemId in affectedIds) byId[itemId]!];
    final subjectIds = originals.map((item) => item.effectiveSubjectId).toSet();
    final languages = originals.map((item) => item.learningLanguage).toSet();
    if (subjectIds.length != 1 || languages.length != 1) {
      throw StateError('Duplicate content cannot be merged across subjects.');
    }
    final exactKeys = originals.map(_duplicateRepairAnalyzer.exactKey).toSet();
    final exactMatch = exactKeys.length == 1;
    if (!exactMatch) {
      if (!request.confirmedSimilarSuggestion || originals.length != 2) {
        throw StateError(
          'Near-similar content requires an explicit two-item confirmation.',
        );
      }
      final suggestion = _duplicateRepairAnalyzer
          .analyze(originals)
          .similarSuggestions
          .any(
            (group) => group.items
                .map((item) => item.id)
                .toSet()
                .containsAll(affectedIds),
          );
      if (!suggestion) {
        throw StateError(
          'The selected content is not a near-match suggestion.',
        );
      }
    }

    final canonical = byId[request.canonicalItemId]!;
    final changedAt = DateTime.now().toUtc();
    final merged = _nextContentRevision(
      _contentValidator.ensureValid(
        _mergeDuplicateContent(
          canonical: canonical,
          source: originals,
          fields: request.fields,
        ).copyWith(updatedAt: changedAt),
      ),
      canonical,
    );
    final removedIds = affectedIds.difference({canonical.id});
    final aliases = {for (final itemId in removedIds) itemId: canonical.id};
    final affectedProgress = [
      for (final itemId in affectedIds) state.progress[itemId],
    ].whereType<ProgressRecord>().toList(growable: false);
    final mergedProgress = _mergeDuplicateProgress(
      canonical.id,
      affectedProgress,
    );
    final nextProgress = {...state.progress}
      ..removeWhere((itemId, _) => affectedIds.contains(itemId));
    if (mergedProgress != null) {
      nextProgress[canonical.id] = mergedProgress;
    }
    final nextRecentSessions = [
      for (final session in state.recentSessions)
        remapSummaryItemIds(session, aliases),
    ];
    final nextActiveSession = state.activeStudySession == null
        ? null
        : remapActiveSessionItemIds(state.activeStudySession!, aliases);
    final nextPreferences = _remapDuplicatePreferences(
      state.preferences,
      aliases,
      affectedIds: affectedIds,
      changedAt: changedAt,
    );
    final nextTombstones = {...state.customItemTombstones}
      ..remove(canonical.id)
      ..addAll({for (final itemId in removedIds) itemId: changedAt});
    final nextItems = [
      for (final item in state.customItems)
        if (!affectedIds.contains(item.id)) item,
      merged,
    ];
    final originalTombstones = {
      for (final itemId in affectedIds)
        itemId: state.customItemTombstones[itemId],
    };
    final originalProgress = <String, ProgressRecord>{};
    for (final itemId in affectedIds) {
      final progress = state.progress[itemId];
      if (progress != null) originalProgress[itemId] = progress;
    }
    final token = DuplicateRepairUndoToken(
      repairId: 'duplicate-${changedAt.microsecondsSinceEpoch}-${canonical.id}',
      changedAt: changedAt,
      canonicalItemId: canonical.id,
      affectedItemIds: Set.unmodifiable(affectedIds),
      originalItems: List.unmodifiable(originals),
      expectedMergedItem: merged,
      originalProgress: Map.unmodifiable(originalProgress),
      expectedProgress: mergedProgress,
      originalPreferences: state.preferences,
      expectedPreferencesChangedAt: changedAt,
      originalRecentSessions: List.unmodifiable(state.recentSessions),
      expectedRecentSessions: List.unmodifiable(nextRecentSessions),
      originalActiveSession: state.activeStudySession,
      expectedActiveSession: nextActiveSession,
      originalTombstones: Map.unmodifiable(originalTombstones),
    );

    await _store.replaceCustomContent(
      items: nextItems,
      tombstones: nextTombstones,
    );
    await _store.replaceProgress(nextProgress);
    await _store.savePreferences(nextPreferences);
    await _store.replaceStudySessions(nextRecentSessions);
    if (nextActiveSession != null) {
      await _store.saveActiveStudySession(nextActiveSession);
    }
    if (!mounted) {
      throw StateError('AppController was disposed during duplicate repair.');
    }
    state = state.copyWith(
      customItems: List.unmodifiable(nextItems),
      customItemTombstones: Map.unmodifiable(nextTombstones),
      progress: Map.unmodifiable(nextProgress),
      preferences: nextPreferences,
      recentSessions: List.unmodifiable(nextRecentSessions),
      activeStudySession: nextActiveSession,
    );
    await _queueSyncIfDriveConnected();
    return DuplicateRepairResult(
      canonicalItem: merged,
      removedItemIds: Set.unmodifiable(removedIds),
      undoToken: token,
    );
  }

  Future<DuplicateRepairUndoResult> undoDuplicateRepair(
    DuplicateRepairUndoToken token,
  ) async {
    if (_undoneDuplicateRepairIds.contains(token.repairId)) {
      return const DuplicateRepairUndoResult(
        DuplicateRepairUndoStatus.alreadyUndone,
      );
    }
    if (!_duplicateRepairUndoStateMatches(token)) {
      return const DuplicateRepairUndoResult(
        DuplicateRepairUndoStatus.conflict,
      );
    }
    final nextItems = [
      for (final item in state.customItems)
        if (!token.affectedItemIds.contains(item.id)) item,
      ...token.originalItems,
    ];
    final nextTombstones = {...state.customItemTombstones}
      ..removeWhere((itemId, _) => token.affectedItemIds.contains(itemId));
    for (final entry in token.originalTombstones.entries) {
      if (entry.value != null) nextTombstones[entry.key] = entry.value!;
    }
    final nextProgress = {...state.progress}
      ..removeWhere((itemId, _) => token.affectedItemIds.contains(itemId))
      ..addAll(token.originalProgress);
    await _store.replaceCustomContent(
      items: nextItems,
      tombstones: nextTombstones,
    );
    await _store.replaceProgress(nextProgress);
    await _store.savePreferences(token.originalPreferences);
    await _store.replaceStudySessions(token.originalRecentSessions);
    if (token.originalActiveSession case final session?) {
      await _store.saveActiveStudySession(session);
    } else {
      await _store.clearActiveStudySession(DateTime.now().toUtc());
    }
    if (!mounted) {
      throw StateError(
        'AppController was disposed while undoing duplicate repair.',
      );
    }
    state = state.copyWith(
      customItems: List.unmodifiable(nextItems),
      customItemTombstones: Map.unmodifiable(nextTombstones),
      progress: Map.unmodifiable(nextProgress),
      preferences: token.originalPreferences,
      recentSessions: token.originalRecentSessions,
      activeStudySession: token.originalActiveSession,
      activeSessionChangedAt:
          token.originalActiveSession?.updatedAt ?? DateTime.now().toUtc(),
    );
    _undoneDuplicateRepairIds.add(token.repairId);
    await _queueSyncIfDriveConnected();
    return const DuplicateRepairUndoResult(DuplicateRepairUndoStatus.restored);
  }

  Future<QuickContentSaveResult> saveQuickContent(
    LearningItem candidate, {
    bool allowDuplicate = false,
  }) async {
    final normalized = _contentValidator.ensureValid(candidate);
    final existing = findContentIdentityMatch(normalized);
    if (existing == null || allowDuplicate) {
      final previousCustom = customItemById(normalized.id);
      final previousTombstone = state.customItemTombstones[normalized.id];
      await upsertCustomItem(normalized);
      final saved = customItemById(normalized.id) ?? normalized;
      return QuickContentSaveResult(
        item: saved,
        mergedWithExisting: false,
        addedMeaningCount: normalized.translations.length,
        undoToken: QuickContentUndoToken(
          id: 'quick-${saved.id}-${saved.updatedAt?.microsecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}',
          expectedItem: saved,
          previousCustomItem: previousCustom,
          previousTombstone: previousTombstone,
        ),
      );
    }

    final previousCustom = customItemById(existing.id);
    final previousTombstone = state.customItemTombstones[existing.id];

    final previousMeanings = existing.translations
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final mergedTranslations = <String>[
      ...existing.translations,
      for (final value in normalized.translations)
        if (!previousMeanings.contains(value.trim().toLowerCase())) value,
    ];
    final mergedAnswers = <String>{
      ...existing.acceptedAnswers,
      ...normalized.acceptedAnswers,
      ...mergedTranslations,
    }.toList(growable: false);
    final mergedReadings = <Reading>[];
    final readingKeys = <String>{};
    for (final reading in [...existing.readings, ...normalized.readings]) {
      final key =
          '${reading.scheme.name}|${reading.value.trim().toLowerCase()}';
      if (readingKeys.add(key)) mergedReadings.add(reading);
    }
    final distributionKey =
        importDistributionKeyOf(existing) ??
        importDistributionKeyOf(normalized);
    final mergedTagsWithoutDistributionKeys = tagsWithoutImportDistributionKeys(
      <String>{...existing.tags, ...normalized.tags},
    );
    final mergedTags = distributionKey == null
        ? mergedTagsWithoutDistributionKeys
        : tagsWithImportDistributionKey(
            mergedTagsWithoutDistributionKeys,
            distributionKey,
          );
    final merged = normalized.copyWith(
      id: existing.id,
      translations: mergedTranslations,
      acceptedAnswers: mergedAnswers,
      readings: mergedReadings,
      sentenceTokens: normalized.sentenceTokens.isEmpty
          ? existing.sentenceTokens
          : normalized.sentenceTokens,
      example: normalized.example ?? existing.example,
      exampleTranslation:
          normalized.exampleTranslation ?? existing.exampleTranslation,
      tags: mergedTags,
      priority: normalized.priority > existing.priority
          ? normalized.priority
          : existing.priority,
      source: existing.source,
    );
    await upsertCustomItem(merged);
    final saved = customItemById(existing.id) ?? merged;
    return QuickContentSaveResult(
      item: saved,
      mergedWithExisting: true,
      addedMeaningCount:
          mergedTranslations.length - existing.translations.length,
      undoToken: QuickContentUndoToken(
        id: 'quick-${saved.id}-${saved.updatedAt?.microsecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}',
        expectedItem: saved,
        previousCustomItem: previousCustom,
        previousTombstone: previousTombstone,
      ),
    );
  }

  Future<QuickContentUndoStatus> undoQuickContentSave(
    QuickContentUndoToken token,
  ) async {
    if (_undoneQuickContentSaveIds.contains(token.id)) {
      return QuickContentUndoStatus.alreadyUndone;
    }
    final current = customItemById(token.expectedItem.id);
    if (current == null ||
        jsonEncode(_itemCodec.toJson(current)) !=
            jsonEncode(_itemCodec.toJson(token.expectedItem))) {
      return QuickContentUndoStatus.conflict;
    }
    final nextItems = [
      for (final item in state.customItems)
        if (item.id != token.expectedItem.id) item,
      ?token.previousCustomItem,
    ];
    final nextTombstones = {...state.customItemTombstones}
      ..remove(token.expectedItem.id);
    if (token.previousTombstone case final deletedAt?) {
      nextTombstones[token.expectedItem.id] = deletedAt;
    }
    await _store.replaceCustomContent(
      items: nextItems,
      tombstones: nextTombstones,
    );
    if (!mounted) return QuickContentUndoStatus.conflict;
    state = state.copyWith(
      customItems: List.unmodifiable(nextItems),
      customItemTombstones: Map.unmodifiable(nextTombstones),
    );
    _undoneQuickContentSaveIds.add(token.id);
    await _queueSyncIfDriveConnected();
    return QuickContentUndoStatus.restored;
  }

  Future<void> deleteCustomItem(String itemId) async {
    await trashCustomItems({itemId});
  }

  List<TrashEntry> listTrash({String? subjectId}) {
    final values =
        state.preferences.trashEntries
            .where((entry) => subjectId == null || entry.subjectId == subjectId)
            .toList()
          ..sort((left, right) => right.deletedAt.compareTo(left.deletedAt));
    return List.unmodifiable(values);
  }

  Future<TrashBatch> trashCustomItems(Set<String> itemIds) async {
    final deletedAt = DateTime.now().toUtc();
    final selected = state.customItems
        .where((item) => itemIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      return TrashBatch(
        id: 'trash-${deletedAt.microsecondsSinceEpoch}',
        entries: const [],
        createdAt: deletedAt,
      );
    }
    final batchId = 'trash-${deletedAt.microsecondsSinceEpoch}';
    final entries = [
      for (final item in selected)
        TrashEntry(
          entryId: '$batchId:${item.id}',
          itemId: item.id,
          subjectId: item.effectiveSubjectId,
          item: _itemCodec.toJson(item),
          wasFavorite: state.preferences.favoriteItemIds.contains(item.id),
          wasExcluded: state.preferences.excludedItemIds.contains(item.id),
          deletedAt: deletedAt,
        ),
    ];
    for (final item in selected) {
      await _store.deleteCustomItem(item.id);
    }
    if (!mounted) {
      return TrashBatch(id: batchId, entries: entries, createdAt: deletedAt);
    }
    final selectedIds = selected.map((item) => item.id).toSet();
    final excluded = {...state.preferences.excludedItemIds}
      ..removeAll(selectedIds);
    final favorites = {...state.preferences.favoriteItemIds}
      ..removeAll(selectedIds);
    final tombstones = {
      ...state.customItemTombstones,
      for (final item in selected) item.id: deletedAt,
    };
    await _store.saveCustomItemTombstones(tombstones);
    final preferences = state.preferences.copyWith(
      settingsUpdatedAt: deletedAt,
      trashEntries: [
        ...state.preferences.trashEntries.where(
          (entry) => !selectedIds.contains(entry.itemId),
        ),
        ...entries,
      ],
      excludedItemIds: excluded,
      excludedItemChangedAtById: {
        ...state.preferences.excludedItemChangedAtById,
        for (final item in selected) item.id: deletedAt,
      },
      favoriteItemIds: favorites,
      favoriteItemChangedAtById: {
        ...state.preferences.favoriteItemChangedAtById,
        for (final item in selected) item.id: deletedAt,
      },
    );
    state = state.copyWith(
      customItems: state.customItems
          .where((item) => !selectedIds.contains(item.id))
          .toList(growable: false),
      customItemTombstones: tombstones,
      preferences: preferences,
    );
    await _store.savePreferences(state.preferences);
    await _queueSyncIfDriveConnected();
    return TrashBatch(id: batchId, entries: entries, createdAt: deletedAt);
  }

  Future<int> restoreTrashBatch(String batchId) async {
    final entries = state.preferences.trashEntries
        .where(
          (entry) =>
              entry.entryId == batchId || entry.entryId.startsWith('$batchId:'),
        )
        .toList(growable: false);
    if (entries.isEmpty) return 0;
    final restoredAt = DateTime.now().toUtc();
    final restoredItems = <LearningItem>[];
    for (final entry in entries) {
      if (customItemById(entry.itemId) != null) continue;
      try {
        final item = _nextContentRevision(
          _itemCodec.fromJson(entry.item).copyWith(updatedAt: restoredAt),
          null,
        );
        restoredItems.add(item);
      } on FormatException {
        // Keep a malformed trash entry available for diagnostics.
      }
    }
    if (restoredItems.isEmpty) return 0;
    await _store.saveCustomItems(restoredItems);
    final restoredIds = restoredItems.map((item) => item.id).toSet();
    final tombstones = {...state.customItemTombstones}
      ..removeWhere((itemId, _) => restoredIds.contains(itemId));
    await _store.saveCustomItemTombstones(tombstones);
    final byItemId = {for (final entry in entries) entry.itemId: entry};
    final favorites = {...state.preferences.favoriteItemIds};
    final excluded = {...state.preferences.excludedItemIds};
    for (final itemId in restoredIds) {
      final entry = byItemId[itemId];
      if (entry?.wasFavorite == true) favorites.add(itemId);
      if (entry?.wasExcluded == true) excluded.add(itemId);
    }
    final preferences = state.preferences.copyWith(
      settingsUpdatedAt: restoredAt,
      trashEntries: state.preferences.trashEntries
          .where((entry) => !restoredIds.contains(entry.itemId))
          .toList(growable: false),
      trashEntryTombstones: {
        ...state.preferences.trashEntryTombstones,
        for (final entry in entries)
          if (restoredIds.contains(entry.itemId)) entry.entryId: restoredAt,
      },
      favoriteItemIds: favorites,
      favoriteItemChangedAtById: {
        ...state.preferences.favoriteItemChangedAtById,
        for (final itemId in restoredIds) itemId: restoredAt,
      },
      excludedItemIds: excluded,
      excludedItemChangedAtById: {
        ...state.preferences.excludedItemChangedAtById,
        for (final itemId in restoredIds) itemId: restoredAt,
      },
    );
    state = state.copyWith(
      customItems: [...state.customItems, ...restoredItems],
      customItemTombstones: tombstones,
      preferences: preferences,
    );
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
    return restoredItems.length;
  }

  Future<int> restoreTrashEntry(String entryId) => restoreTrashBatch(entryId);

  Future<void> emptyTrash() async {
    if (state.preferences.trashEntries.isEmpty) return;
    final changedAt = DateTime.now().toUtc();
    final preferences = state.preferences.copyWith(
      settingsUpdatedAt: changedAt,
      trashEntries: const [],
      trashEntryTombstones: {
        ...state.preferences.trashEntryTombstones,
        for (final entry in state.preferences.trashEntries)
          entry.entryId: changedAt,
      },
    );
    state = state.copyWith(preferences: preferences);
    await _store.savePreferences(preferences);
    await _queueSyncIfDriveConnected();
  }

  LearningItem? customItemById(String itemId) {
    for (final item in state.customItems) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  LearningItem _mergeDuplicateContent({
    required LearningItem canonical,
    required List<LearningItem> source,
    required Set<DuplicateMergeField> fields,
  }) {
    final mergeMeanings = fields.contains(DuplicateMergeField.meanings);
    final translations = mergeMeanings
        ? _distinctContentValues(
            source.expand((item) => item.translations),
            first: canonical.translations,
          )
        : canonical.translations;
    final acceptedAnswers = mergeMeanings
        ? _distinctContentValues([
            ...source.expand((item) => item.acceptedAnswers),
            ...translations,
          ], first: canonical.acceptedAnswers)
        : canonical.acceptedAnswers;
    final readings = fields.contains(DuplicateMergeField.readings)
        ? _distinctReadings(source, canonical)
        : canonical.readings;
    var example = canonical.example;
    var exampleTranslation = canonical.exampleTranslation;
    if (fields.contains(DuplicateMergeField.examples)) {
      for (final item in source) {
        if (example == null && item.example != null) {
          example = item.example;
          exampleTranslation = item.exampleTranslation;
          continue;
        }
        if (example != null &&
            item.example != null &&
            _comparableContentValue(example) ==
                _comparableContentValue(item.example!) &&
            exampleTranslation == null) {
          exampleTranslation = item.exampleTranslation;
        }
      }
    }
    final tags = fields.contains(DuplicateMergeField.tags)
        ? _distinctContentValues(
            source.expand((item) => item.tags),
            first: canonical.tags,
          )
        : canonical.tags;
    return canonical.copyWith(
      translations: translations,
      acceptedAnswers: acceptedAnswers,
      readings: readings,
      example: example,
      exampleTranslation: exampleTranslation,
      tags: tags,
    );
  }

  List<String> _distinctContentValues(
    Iterable<String> values, {
    Iterable<String> first = const [],
  }) {
    final result = <String>[];
    final keys = <String>{};
    for (final value in [...first, ...values]) {
      final normalized = unicode
          .nfkc(value)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isNotEmpty &&
          keys.add(_comparableContentValue(normalized))) {
        result.add(normalized);
      }
    }
    return List.unmodifiable(result);
  }

  String _comparableContentValue(String value) =>
      unicode.nfkc(value).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<Reading> _distinctReadings(
    Iterable<LearningItem> source,
    LearningItem canonical,
  ) {
    final result = <Reading>[];
    final keys = <String>{};
    for (final reading in [
      ...canonical.readings,
      ...source.expand((item) => item.readings),
    ]) {
      final normalized = unicode
          .nfkc(reading.value)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      final key =
          '${reading.scheme.name}|${_comparableContentValue(normalized)}';
      if (normalized.isNotEmpty && keys.add(key)) {
        result.add(Reading(scheme: reading.scheme, value: normalized));
      }
    }
    return List.unmodifiable(result);
  }

  ProgressRecord? _mergeDuplicateProgress(
    String canonicalItemId,
    List<ProgressRecord> records,
  ) {
    if (records.isEmpty) return null;
    final ranked = [...records]
      ..sort(
        (left, right) => _progressStatusStrength(
          right.status,
        ).compareTo(_progressStatusStrength(left.status)),
      );
    DateTime? latestStudy;
    DateTime? latestReview;
    ProgressRecord? latestResultRecord;
    for (final record in records) {
      if (record.lastStudiedAt != null &&
          (latestStudy == null || record.lastStudiedAt!.isAfter(latestStudy))) {
        latestStudy = record.lastStudiedAt;
        latestResultRecord = record;
      }
      if (record.nextReviewAt != null &&
          (latestReview == null ||
              record.nextReviewAt!.isAfter(latestReview))) {
        latestReview = record.nextReviewAt;
      }
    }
    int combined(Iterable<int> values) =>
        values.fold<int>(0, (sum, value) => (sum + value).clamp(0, 0x7fffffff));
    return ProgressRecord(
      itemId: canonicalItemId,
      status: ranked.first.status,
      correctCount: combined(records.map((record) => record.correctCount)),
      wrongCount: combined(records.map((record) => record.wrongCount)),
      lapseCount: combined(records.map((record) => record.lapseCount)),
      currentIntervalDays: records
          .map((record) => record.currentIntervalDays)
          .fold<int>(0, (maximum, value) => value > maximum ? value : maximum),
      nextReviewAt: latestReview,
      lastStudiedAt: latestStudy,
      lastResult: latestResultRecord?.lastResult,
    );
  }

  int _progressStatusStrength(LearningStatus status) => switch (status) {
    LearningStatus.newItem => 0,
    LearningStatus.learning => 1,
    LearningStatus.suspended => 2,
    LearningStatus.review => 3,
    LearningStatus.mastered => 4,
  };

  StudyPreferences _remapDuplicatePreferences(
    StudyPreferences source,
    Map<String, String> aliases, {
    required Set<String> affectedIds,
    required DateTime changedAt,
  }) {
    final favoriteItemIds = {
      for (final itemId in source.favoriteItemIds) aliases[itemId] ?? itemId,
    };
    final excludedItemIds = {
      for (final itemId in source.excludedItemIds) aliases[itemId] ?? itemId,
    };
    final contentCorrections = remapContentCorrections(
      source.contentCorrections,
      aliases,
    );
    return source.copyWith(
      settingsUpdatedAt: changedAt,
      favoriteItemIds: favoriteItemIds,
      favoriteItemChangedAtById: _remapItemChangeDates(
        source.favoriteItemChangedAtById,
        aliases,
        affectedIds,
        changedAt,
      ),
      excludedItemIds: excludedItemIds,
      excludedItemChangedAtById: _remapItemChangeDates(
        source.excludedItemChangedAtById,
        aliases,
        affectedIds,
        changedAt,
      ),
      sessionPlan: remapPlanItemIds(source.sessionPlan, aliases),
      savedSessionPlans: [
        for (final plan in source.savedSessionPlans)
          remapPlanItemIds(plan, aliases),
      ],
      contentCorrections: contentCorrections,
      contentCorrectionTombstones: _remapCorrectionTombstones(
        source.contentCorrectionTombstones,
        aliases,
        changedAt,
        originalCorrections: source.contentCorrections,
        mergedCorrections: contentCorrections,
      ),
      contentItemAliases: _mergeContentItemAliases(
        source.contentItemAliases,
        const {},
        aliases,
      ),
    );
  }

  Map<String, DateTime> _remapItemChangeDates(
    Map<String, DateTime> source,
    Map<String, String> aliases,
    Set<String> affectedIds,
    DateTime changedAt,
  ) {
    final result = <String, DateTime>{...source};
    for (final itemId in affectedIds) {
      result[itemId] = changedAt;
    }
    for (final canonicalId in aliases.values) {
      result[canonicalId] = changedAt;
    }
    return Map.unmodifiable(result);
  }

  Map<String, DateTime> _remapCorrectionTombstones(
    Map<String, DateTime> source,
    Map<String, String> aliases,
    DateTime changedAt, {
    required Iterable<ContentCorrection> originalCorrections,
    required Iterable<ContentCorrection> mergedCorrections,
  }) {
    final result = <String, DateTime>{...source};
    for (final entry in source.entries) {
      final separator = entry.key.indexOf('\u001F');
      final itemId = separator < 0
          ? entry.key
          : entry.key.substring(0, separator);
      final suffix = separator < 0 ? '' : entry.key.substring(separator);
      final key = '${aliases[itemId] ?? itemId}$suffix';
      final current = result[key];
      if (current == null || entry.value.isAfter(current)) {
        result[key] = entry.value;
      }
    }
    for (final correction in originalCorrections) {
      if (aliases.containsKey(correction.itemId)) {
        result['${correction.itemId}\u001F${correction.field}'] = changedAt;
      }
    }
    for (final correction in mergedCorrections) {
      result.remove('${correction.itemId}\u001F${correction.field}');
    }
    return Map.unmodifiable(result);
  }

  bool _duplicateRepairUndoStateMatches(DuplicateRepairUndoToken token) {
    final currentItem = customItemById(token.canonicalItemId);
    if (currentItem == null ||
        jsonEncode(_itemCodec.toJson(currentItem)) !=
            jsonEncode(_itemCodec.toJson(token.expectedMergedItem)) ||
        token.affectedItemIds
            .difference({token.canonicalItemId})
            .any((itemId) => customItemById(itemId) != null) ||
        state.preferences.settingsUpdatedAt !=
            token.expectedPreferencesChangedAt) {
      return false;
    }
    for (final itemId in token.affectedItemIds) {
      final expected = itemId == token.canonicalItemId
          ? token.expectedProgress
          : null;
      if (!_sameProgress(state.progress[itemId], expected)) return false;
    }
    if (jsonEncode([
          for (final session in state.recentSessions) session.toJson(),
        ]) !=
        jsonEncode([
          for (final session in token.expectedRecentSessions) session.toJson(),
        ])) {
      return false;
    }
    return jsonEncode(state.activeStudySession?.toJson()) ==
        jsonEncode(token.expectedActiveSession?.toJson());
  }

  bool _sameProgress(ProgressRecord? left, ProgressRecord? right) {
    if (identical(left, right)) return true;
    return left?.itemId == right?.itemId &&
        left?.status == right?.status &&
        left?.correctCount == right?.correctCount &&
        left?.wrongCount == right?.wrongCount &&
        left?.lapseCount == right?.lapseCount &&
        left?.currentIntervalDays == right?.currentIntervalDays &&
        left?.nextReviewAt == right?.nextReviewAt &&
        left?.lastStudiedAt == right?.lastStudiedAt &&
        left?.lastResult == right?.lastResult;
  }

  LearningItem _nextContentRevision(LearningItem item, LearningItem? previous) {
    if (previous == null ||
        item.source.contentVersion > previous.source.contentVersion) {
      return item;
    }
    return item.copyWith(
      source: item.source.copyWith(
        contentVersion: previous.source.contentVersion + 1,
      ),
    );
  }

  Map<String, Object?> exportArchive() {
    final snapshot = exportSyncSnapshot();
    return {
      ...snapshot,
      // BackupArchive has its own format version. The embedded Drive snapshot
      // version is deliberately recorded separately.
      'schemaVersion': 1,
      'snapshotSchemaVersion': snapshot['schemaVersion'],
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sessions': [
        for (final session in state.recentSessions) session.toJson(),
      ],
    };
  }

  Map<String, Object?> exportSyncSnapshot() {
    return {
      'schemaVersion': 2,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': {
        'selectedLanguage': state.selectedLanguage.code,
        'totalXp': state.totalXp,
        if (state.xpByReplica.isNotEmpty)
          'xpByReplica': {
            for (final entry
                in (state.xpByReplica.entries.toList()
                  ..sort((left, right) => left.key.compareTo(right.key))))
              entry.key: entry.value,
          },
        'streakDays': state.streakDays,
        'dailyXp': state.dailyXp,
        'dailyXpByCourse': {
          for (final entry
              in (state.dailyXpByCourse.entries.toList()
                ..sort((left, right) => left.key.compareTo(right.key))))
            entry.key: entry.value,
        },
        if (state.dailyXpByCourseAndReplica.isNotEmpty)
          'dailyXpByCourseAndReplica': {
            for (final courseEntry
                in (state.dailyXpByCourseAndReplica.entries.toList()
                  ..sort((left, right) => left.key.compareTo(right.key))))
              courseEntry.key: {
                for (final replicaEntry
                    in (courseEntry.value.entries.toList()
                      ..sort((left, right) => left.key.compareTo(right.key))))
                  replicaEntry.key: replicaEntry.value,
              },
          },
        'badges': state.badges.toList()..sort(),
        'lastStudyDate': state.lastStudyDate?.toIso8601String(),
      },
      'settings': state.preferences.toJson(),
      'progress': [
        for (final record in state.progress.values) _progressToJson(record),
      ],
      'customItems': [
        for (final item in state.customItems) _itemCodec.toJson(item),
      ],
      'customItemTombstones': [
        for (final entry
            in (state.customItemTombstones.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          {'id': entry.key, 'deletedAt': entry.value.toUtc().toIso8601String()},
      ],
      'recentSessions': [
        for (final session in state.recentSessions.take(20)) session.toJson(),
      ],
      'activeStudy': state.activeSessionChangedAt == null
          ? null
          : {
              'changedAt': state.activeSessionChangedAt!
                  .toUtc()
                  .toIso8601String(),
              'session': state.activeStudySession?.toJson(),
            },
    };
  }

  Future<Map<String, Object?>> mergeRemoteSnapshot(
    Map<String, Object?>? remote, {
    bool markDriveConnected = true,
    bool recordSyncReport = true,
  }) async {
    final localBefore = exportSyncSnapshot();
    if (remote == null) {
      final merged = exportSyncSnapshot();
      if (recordSyncReport) {
        lastMergeReport = _syncMergeReporter.build(
          local: localBefore,
          remote: null,
          merged: merged,
          syncedAt: DateTime.now().toUtc(),
        );
      }
      return merged;
    }
    _snapshotValidator.validate(remote);
    final schemaVersion = (remote['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion > 2) {
      throw StateError('Drive 데이터가 더 최신 버전입니다. 앱을 업데이트한 뒤 다시 시도하세요.');
    }

    final remoteProgress = <String, ProgressRecord>{};
    for (final raw in (remote['progress'] as List<Object?>?) ?? const []) {
      if (raw is! Map) continue;
      try {
        final record = _progressFromJson(Map<String, Object?>.from(raw));
        remoteProgress[record.itemId] = record;
      } on FormatException {
        continue;
      }
    }
    var mergedProgress = <String, ProgressRecord>{...state.progress};
    for (final entry in remoteProgress.entries) {
      final local = mergedProgress[entry.key];
      if (local == null || _remoteProgressWins(entry.value, local)) {
        mergedProgress[entry.key] = entry.value;
      }
    }

    final remoteSnapshotAt =
        _optionalDate(remote['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final remoteItems = <String, LearningItem>{};
    for (final raw in (remote['customItems'] as List<Object?>?) ?? const []) {
      var item = _itemCodec.fromJson(Map<String, Object?>.from(raw! as Map));
      item = item.updatedAt == null
          ? item.copyWith(updatedAt: remoteSnapshotAt)
          : item;
      remoteItems[item.id] = item;
    }
    final remoteItemTombstones = _customItemTombstonesFromJson(
      remote['customItemTombstones'],
    );
    final mergedContent = _mergeCustomContent(
      localItems: state.customItems,
      remoteItems: remoteItems.values,
      localTombstones: state.customItemTombstones,
      remoteTombstones: remoteItemTombstones,
      itemCodec: _itemCodec,
    );
    mergedProgress = _remapProgressItemIds(
      mergedProgress,
      mergedContent.itemIdAliases,
    );
    final remoteSessions = <StudySessionSummary>[];
    for (final raw
        in (remote['recentSessions'] as List<Object?>?) ?? const []) {
      remoteSessions.add(
        StudySessionSummary.fromJson(Map<String, Object?>.from(raw! as Map)),
      );
    }
    var mergedRecentSessions = _mergeRecentSessions(
      state.recentSessions,
      remoteSessions,
    );
    final localActiveStudy = StoredActiveStudyState(
      session: state.activeStudySession,
      changedAt: state.activeSessionChangedAt,
    );
    final remoteActiveStudy = _activeStudyStateFromJson(remote['activeStudy']);
    var mergedActiveStudy = _mergeActiveStudyState(
      localActiveStudy,
      remoteActiveStudy,
    );

    final rawProfile = remote['profile'];
    final remoteProfile = rawProfile is Map
        ? Map<String, Object?>.from(rawProfile)
        : const <String, Object?>{};
    final rawRemoteTotalXp = (remoteProfile['totalXp'] as num?)?.toInt() ?? 0;
    final remoteTotalXp = rawRemoteTotalXp.clamp(0, 1000000000);
    final remoteXpByReplica = _normalizeXpLedger(
      totalXp: remoteTotalXp,
      xpByReplica: _xpLedgerFromJson(remoteProfile['xpByReplica']),
    );
    final mergedXpByReplica = _mergeXpLedgers(
      _normalizeXpLedger(
        totalXp: state.totalXp,
        xpByReplica: state.xpByReplica,
      ),
      remoteXpByReplica,
    );
    final remoteBadges =
        ((remoteProfile['badges'] as List<Object?>?) ?? const [])
            .whereType<String>();
    final remoteLastStudyDate = _optionalDate(remoteProfile['lastStudyDate']);
    final rawSettings = remote['settings'];
    final remotePreferences = rawSettings is Map
        ? StudyPreferences.fromJson(Map<String, Object?>.from(rawSettings))
        : state.preferences;
    final mergedContentItemAliases = _mergeContentItemAliases(
      state.preferences.contentItemAliases,
      remotePreferences.contentItemAliases,
      mergedContent.itemIdAliases,
    );
    mergedProgress = _remapProgressItemIds(
      mergedProgress,
      mergedContentItemAliases,
    );
    mergedRecentSessions = [
      for (final session in mergedRecentSessions)
        remapSummaryItemIds(session, mergedContentItemAliases),
    ];
    if (mergedActiveStudy.session case final activeSession?) {
      final remapped = remapActiveSessionItemIds(
        activeSession,
        mergedContentItemAliases,
      );
      mergedActiveStudy = StoredActiveStudyState(
        session: remapped,
        changedAt: mergedActiveStudy.changedAt,
      );
    }
    final remoteSettingsWins = _remoteStructuredPreferenceWins(
      localChangedAt: state.preferences.settingsUpdatedAt,
      remoteChangedAt: remotePreferences.settingsUpdatedAt,
      localJson: state.preferences.toJson(),
      remoteJson: remotePreferences.toJson(),
      remoteWhenUndated: true,
    );
    final basePreferences = remoteSettingsWins
        ? remotePreferences
        : state.preferences;
    final remoteExperienceWins = _remoteStructuredPreferenceWins(
      localChangedAt: state.preferences.experience.updatedAt,
      remoteChangedAt: remotePreferences.experience.updatedAt,
      localJson: state.preferences.experience.toJson(),
      remoteJson: remotePreferences.experience.toJson(),
      remoteWhenUndated: remoteSettingsWins,
    );
    final remoteInteractionWins = _remoteStructuredPreferenceWins(
      localChangedAt: state.preferences.interaction.updatedAt,
      remoteChangedAt: remotePreferences.interaction.updatedAt,
      localJson: state.preferences.interaction.toJson(),
      remoteJson: remotePreferences.interaction.toJson(),
      remoteWhenUndated: remoteSettingsWins,
    );
    final mergedDailyGoals = _mergeDailyGoals(
      local: state.preferences.dailyGoalsBySubject,
      remote: remotePreferences.dailyGoalsBySubject,
      localChangedAt: state.preferences.dailyGoalChangedAtBySubject,
      remoteChangedAt: remotePreferences.dailyGoalChangedAtBySubject,
    );
    final mergedActiveSubject = _mergeActiveSubjectSelection(
      localId: state.preferences.activeSubjectId,
      remoteId: remotePreferences.activeSubjectId,
      localChangedAt: state.preferences.activeSubjectChangedAt,
      remoteChangedAt: remotePreferences.activeSubjectChangedAt,
    );
    final mergedExcludedItems = _mergeTimestampedMembership(
      local: state.preferences.excludedItemIds,
      remote: remotePreferences.excludedItemIds,
      localChangedAt: state.preferences.excludedItemChangedAtById,
      remoteChangedAt: remotePreferences.excludedItemChangedAtById,
    );
    final mergedFavoriteItems = _mergeTimestampedMembership(
      local: state.preferences.favoriteItemIds,
      remote: remotePreferences.favoriteItemIds,
      localChangedAt: state.preferences.favoriteItemChangedAtById,
      remoteChangedAt: remotePreferences.favoriteItemChangedAtById,
    );
    final mergedSavedSessionPlans = _mergeSavedSessionPlans(
      remote: remotePreferences.savedSessionPlans,
      local: state.preferences.savedSessionPlans,
      remoteTombstones: remotePreferences.savedSessionPlanTombstones,
      localTombstones: state.preferences.savedSessionPlanTombstones,
    );
    final mergedLearningGroups = _mergeLearningGroupDefinitions(
      remote: remotePreferences.learningGroups,
      local: state.preferences.learningGroups,
      remoteTombstones: remotePreferences.learningGroupTombstones,
      localTombstones: state.preferences.learningGroupTombstones,
    );
    final mergedSmartCollections = _mergeVersionedPreferenceRecords(
      remote: remotePreferences.smartCollections,
      local: state.preferences.smartCollections,
      remoteTombstones: remotePreferences.smartCollectionTombstones,
      localTombstones: state.preferences.smartCollectionTombstones,
      idOf: (value) => value.id,
      updatedAtOf: (value) => value.updatedAt,
      toJson: (value) => value.toJson(),
      maximumRecords: 100,
      maximumTombstones: 200,
    );
    final mergedTrashEntries = _mergeVersionedPreferenceRecords(
      remote: remotePreferences.trashEntries,
      local: state.preferences.trashEntries,
      remoteTombstones: remotePreferences.trashEntryTombstones,
      localTombstones: state.preferences.trashEntryTombstones,
      idOf: (value) => value.entryId,
      updatedAtOf: (value) => value.deletedAt,
      toJson: (value) => value.toJson(),
      maximumRecords: 2000,
      maximumTombstones: 4000,
    );
    final mergedMappingPresets = _mergeVersionedPreferenceRecords(
      remote: remotePreferences.importMappingPresets,
      local: state.preferences.importMappingPresets,
      remoteTombstones: const {},
      localTombstones: const {},
      idOf: (value) => value.id,
      updatedAtOf: (value) => value.updatedAt,
      toJson: (value) => value.toJson(),
      maximumRecords: 50,
      maximumTombstones: 0,
    );
    final mergedImportReceipts = _mergeVersionedPreferenceRecords(
      remote: remotePreferences.importReceipts,
      local: state.preferences.importReceipts,
      remoteTombstones: const {},
      localTombstones: const {},
      idOf: (value) => value.importId,
      updatedAtOf: (value) => value.undoneAt ?? value.createdAt,
      toJson: (value) => value.toJson(),
      maximumRecords: 30,
      maximumTombstones: 0,
    );
    final mergedContentCorrections = _mergeVersionedPreferenceRecords(
      remote: remotePreferences.contentCorrections,
      local: state.preferences.contentCorrections,
      remoteTombstones: remotePreferences.contentCorrectionTombstones,
      localTombstones: state.preferences.contentCorrectionTombstones,
      idOf: (value) => '${value.itemId}:${value.field}',
      updatedAtOf: (value) => value.updatedAt,
      toJson: (value) => value.toJson(),
      maximumRecords: 2000,
      maximumTombstones: 4000,
    );
    final mergedHiddenSubjects = _mergeTimestampedMembership(
      local: state.preferences.hiddenSubjectIds,
      remote: remotePreferences.hiddenSubjectIds,
      localChangedAt: state.preferences.subjectVisibilityChangedAtById,
      remoteChangedAt: remotePreferences.subjectVisibilityChangedAtById,
    );
    final mergedSessionPlan = remapPlanItemIds(
      _newerSessionPlan(
        remotePreferences.sessionPlan,
        state.preferences.sessionPlan,
      ),
      mergedContentItemAliases,
    );
    final combinedPreferences = basePreferences.copyWith(
      experience: remoteExperienceWins
          ? remotePreferences.experience
          : state.preferences.experience,
      interaction: remoteInteractionWins
          ? remotePreferences.interaction
          : state.preferences.interaction,
      ttsRate: remoteInteractionWins
          ? remotePreferences.ttsRate
          : state.preferences.ttsRate,
      excludedItemIds: _remapItemIdSet(
        mergedExcludedItems.members,
        mergedContentItemAliases,
      ),
      excludedItemChangedAtById: _remapItemChangeDatesForAliases(
        mergedExcludedItems.changedAtById,
        mergedContentItemAliases,
      ),
      favoriteItemIds: _remapItemIdSet(
        mergedFavoriteItems.members,
        mergedContentItemAliases,
      ),
      favoriteItemChangedAtById: _remapItemChangeDatesForAliases(
        mergedFavoriteItems.changedAtById,
        mergedContentItemAliases,
      ),
      completedMissionIds: {
        ...remotePreferences.completedMissionIds,
        ...state.preferences.completedMissionIds,
      },
      sessionPlan: mergedSessionPlan,
      savedSessionPlans: [
        for (final plan in mergedSavedSessionPlans.plans)
          remapPlanItemIds(plan, mergedContentItemAliases),
      ],
      savedSessionPlanTombstones: mergedSavedSessionPlans.tombstones,
      customSubjects: _mergeStudySubjects(
        remotePreferences.customSubjects,
        state.preferences.customSubjects,
      ),
      hiddenSubjectIds: mergedHiddenSubjects.members,
      subjectVisibilityChangedAtById: mergedHiddenSubjects.changedAtById,
      importDistributionRules: _mergeImportDistributionRules(
        remotePreferences.importDistributionRules,
        state.preferences.importDistributionRules,
      ),
      learningGroups: mergedLearningGroups.groups,
      learningGroupTombstones: mergedLearningGroups.tombstones,
      smartCollections: mergedSmartCollections.records,
      smartCollectionTombstones: mergedSmartCollections.tombstones,
      trashEntries: mergedTrashEntries.records,
      trashEntryTombstones: mergedTrashEntries.tombstones,
      importMappingPresets: mergedMappingPresets.records,
      importReceipts: mergedImportReceipts.records,
      contentCorrections: remapContentCorrections(
        mergedContentCorrections.records,
        mergedContentItemAliases,
      ),
      contentCorrectionTombstones: mergedContentCorrections.tombstones,
      contentItemAliases: mergedContentItemAliases,
      dailyGoalsBySubject: mergedDailyGoals.goals,
      dailyGoalChangedAtBySubject: mergedDailyGoals.changedAtBySubject,
      activeSubjectId: mergedActiveSubject.id,
      activeSubjectChangedAt: mergedActiveSubject.changedAt,
    );
    final deletedItemIds = mergedContent.tombstones.keys.toSet();
    final excludedChangedAt = {
      ...combinedPreferences.excludedItemChangedAtById,
    };
    final favoriteChangedAt = {
      ...combinedPreferences.favoriteItemChangedAtById,
    };
    for (final entry in mergedContent.tombstones.entries) {
      final itemId = entry.key;
      final deletedAt = entry.value;
      final excludedAt = excludedChangedAt[itemId];
      if (excludedAt == null || deletedAt.isAfter(excludedAt)) {
        excludedChangedAt[itemId] = deletedAt;
      }
      final favoriteAt = favoriteChangedAt[itemId];
      if (favoriteAt == null || deletedAt.isAfter(favoriteAt)) {
        favoriteChangedAt[itemId] = deletedAt;
      }
    }
    var mergedPreferences = combinedPreferences.copyWith(
      excludedItemIds: {...combinedPreferences.excludedItemIds}
        ..removeAll(deletedItemIds),
      excludedItemChangedAtById: excludedChangedAt,
      favoriteItemIds: {...combinedPreferences.favoriteItemIds}
        ..removeAll(deletedItemIds),
      favoriteItemChangedAtById: favoriteChangedAt,
    );
    final mergedVisibleSubjects = _subjectsForPreferences(mergedPreferences)
        .where(
          (subject) => !mergedPreferences.hiddenSubjectIds.contains(subject.id),
        )
        .toList(growable: false);
    if (mergedVisibleSubjects.isEmpty) {
      mergedPreferences = mergedPreferences.copyWith(
        hiddenSubjectIds: const {},
        subjectVisibilityChangedAtById: const {},
      );
    } else if (!mergedVisibleSubjects.any(
      (subject) => subject.id == mergedPreferences.activeSubjectId,
    )) {
      mergedPreferences = mergedPreferences.copyWith(
        activeSubjectId: mergedVisibleSubjects.first.id,
        activeSubjectChangedAt: DateTime.now().toUtc(),
      );
    }
    final mergedSelectedSubject = _subjectsForPreferences(mergedPreferences)
        .firstWhere(
          (subject) => subject.id == mergedPreferences.activeSubjectId,
          orElse: () => StudySubject.language(state.selectedLanguage),
        );
    final mergedLastStudyDate =
        remoteLastStudyDate != null &&
            (state.lastStudyDate == null ||
                remoteLastStudyDate.isAfter(state.lastStudyDate!))
        ? remoteLastStudyDate
        : state.lastStudyDate;
    final rawRemoteDailyXp = (remoteProfile['dailyXp'] as num?)?.toInt() ?? 0;
    final remoteDailyXp = rawRemoteDailyXp.clamp(0, 1000000000);
    final remoteDailyXpByCourse = _dailyXpByCourseFromJson(
      remoteProfile['dailyXpByCourse'],
      legacyDailyXp: remoteDailyXp,
      legacyCourseId: courseIdForSubject(
        mergedActiveSubject.id.isEmpty
            ? languageSubjectId(
                LanguageTag.values.firstWhere(
                  (language) =>
                      language.code == remoteProfile['selectedLanguage'],
                  orElse: () => state.selectedLanguage,
                ),
              )
            : mergedActiveSubject.id,
      ),
    );
    final remoteDailyXpLedger = _normalizeDailyXpLedger(
      legacyByCourse: remoteDailyXpByCourse,
      ledger: _dailyXpLedgerFromJson(
        remoteProfile['dailyXpByCourseAndReplica'],
      ),
    );
    final localDailyXpLedger = _normalizeDailyXpLedger(
      legacyByCourse: state.dailyXpByCourse,
      ledger: state.dailyXpByCourseAndReplica,
    );
    final mergedDailyXpLedger = _mergeDailyXpLedgers(
      local: localDailyXpLedger,
      remote: remoteDailyXpLedger,
      localDate: state.lastStudyDate,
      remoteDate: remoteLastStudyDate,
    );
    final mergedDailyXpByCourse = _dailyXpByCourseFromLedger(
      mergedDailyXpLedger,
    );
    final mergedDriveConnected = markDriveConnected
        ? true
        : state.driveConnected;
    final nextState = state.copyWith(
      selectedLanguage: mergedSelectedSubject.isLanguage
          ? mergedSelectedSubject.contentLanguage
          : state.selectedLanguage,
      progress: mergedProgress,
      totalXp: _sumXpLedger(mergedXpByReplica),
      xpByReplica: mergedXpByReplica,
      streakDays: _maxInt(
        state.streakDays,
        (remoteProfile['streakDays'] as num?)?.toInt() ?? 0,
      ),
      dailyXp: _sumDailyXpByCourse(mergedDailyXpByCourse),
      dailyXpByCourse: mergedDailyXpByCourse,
      dailyXpByCourseAndReplica: mergedDailyXpLedger,
      badges: {...state.badges, ...remoteBadges},
      driveConnected: mergedDriveConnected,
      customItems: mergedContent.items,
      customItemTombstones: mergedContent.tombstones,
      recentSessions: mergedRecentSessions,
      preferences: mergedPreferences,
      activeStudySession: mergedActiveStudy.session,
      activeSessionChangedAt: mergedActiveStudy.changedAt,
      lastStudyDate: mergedLastStudyDate,
    );
    await _store.saveProfile(
      StoredProfile(
        selectedLanguage: nextState.selectedLanguage,
        totalXp: nextState.totalXp,
        replicaId: nextState.replicaId,
        xpByReplica: nextState.xpByReplica,
        streakDays: nextState.streakDays,
        dailyXp: nextState.dailyXp,
        dailyXpByCourse: nextState.dailyXpByCourse,
        dailyXpByCourseAndReplica: nextState.dailyXpByCourseAndReplica,
        badges: nextState.badges,
        driveConnected: nextState.driveConnected,
        progress: nextState.progress,
        lastStudyDate: nextState.lastStudyDate,
      ),
    );
    await _store.saveCustomItems(nextState.customItems);
    for (final itemId in nextState.customItemTombstones.keys) {
      await _store.deleteCustomItem(itemId);
    }
    await _store.saveCustomItemTombstones(nextState.customItemTombstones);
    await _store.savePreferences(nextState.preferences);
    for (final session in nextState.recentSessions) {
      await _store.saveStudySession(session);
    }
    if (mergedActiveStudy.changedAt case final changedAt?) {
      if (mergedActiveStudy.session case final session?) {
        await _store.saveActiveStudySession(session);
      } else {
        await _store.clearActiveStudySession(changedAt);
      }
    }
    if (mounted) {
      state = nextState;
      unawaited(_reconcileStudyNotifications(nextState.preferences));
    }
    final mergedSnapshot = exportSyncSnapshot();
    if (recordSyncReport) {
      lastMergeReport = _syncMergeReporter.build(
        local: localBefore,
        remote: remote,
        merged: mergedSnapshot,
        syncedAt: DateTime.now().toUtc(),
      );
    }
    return mergedSnapshot;
  }

  Future<Map<String, Object?>> replaceWithSyncSnapshot(
    Map<String, Object?> snapshot, {
    bool? driveConnected,
  }) async {
    _snapshotValidator.validate(snapshot);
    final schemaVersion = (snapshot['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion > 2) {
      throw StateError('Drive 데이터가 더 최신 버전입니다. 앱을 업데이트한 뒤 다시 시도하세요.');
    }
    final rawProfile = snapshot['profile'];
    final profile = rawProfile is Map
        ? Map<String, Object?>.from(rawProfile)
        : const <String, Object?>{};
    final selectedLanguage = LanguageTag.values.firstWhere(
      (value) => value.code == profile['selectedLanguage'],
      orElse: () => state.selectedLanguage,
    );
    final rawSettings = snapshot['settings'];
    final parsedPreferences = rawSettings is Map
        ? StudyPreferences.fromJson(Map<String, Object?>.from(rawSettings))
        : state.preferences;
    final preferences = parsedPreferences.copyWith(
      contentItemAliases: _mergeContentItemAliases(
        parsedPreferences.contentItemAliases,
        const {},
        const {},
      ),
    );
    final progress = <String, ProgressRecord>{};
    for (final raw
        in (snapshot['progress'] as List<Object?>?) ?? const <Object?>[]) {
      if (raw is! Map) continue;
      final record = _progressFromJson(Map<String, Object?>.from(raw));
      progress[record.itemId] = record;
    }
    final remappedProgress = _remapProgressItemIds(
      progress,
      preferences.contentItemAliases,
    );
    final snapshotAt =
        _optionalDate(snapshot['updatedAt']) ?? DateTime.now().toUtc();
    final customItems = <LearningItem>[];
    for (final raw
        in (snapshot['customItems'] as List<Object?>?) ?? const <Object?>[]) {
      if (raw is! Map) continue;
      var item = _itemCodec.fromJson(Map<String, Object?>.from(raw));
      if (item.updatedAt == null) {
        item = item.copyWith(updatedAt: snapshotAt);
      }
      customItems.add(item);
    }
    final tombstones = _customItemTombstonesFromJson(
      snapshot['customItemTombstones'],
    );
    customItems.removeWhere((item) {
      final deletedAt = tombstones[item.id];
      return deletedAt != null &&
          !deletedAt.isBefore(item.updatedAt ?? snapshotAt);
    });
    final recentSessions = <StudySessionSummary>[];
    for (final raw
        in (snapshot['recentSessions'] as List<Object?>?) ??
            const <Object?>[]) {
      if (raw is! Map) continue;
      recentSessions.add(
        remapSummaryItemIds(
          StudySessionSummary.fromJson(Map<String, Object?>.from(raw)),
          preferences.contentItemAliases,
        ),
      );
    }
    recentSessions.sort(
      (left, right) => right.startedAt.compareTo(left.startedAt),
    );
    final rawActiveStudy =
        _activeStudyStateFromJson(snapshot['activeStudy']) ??
        StoredActiveStudyState(changedAt: DateTime.now().toUtc());
    final activeSession = rawActiveStudy.session;
    final activeStudy = activeSession == null
        ? rawActiveStudy
        : StoredActiveStudyState(
            session: remapActiveSessionItemIds(
              activeSession,
              preferences.contentItemAliases,
            ),
            changedAt: rawActiveStudy.changedAt,
          );
    final rawTotalXp = (profile['totalXp'] as num?)?.toInt() ?? 0;
    final xpByReplica = _normalizeXpLedger(
      totalXp: rawTotalXp.clamp(0, 1000000000),
      xpByReplica: _xpLedgerFromJson(profile['xpByReplica']),
    );
    final activeSubjectId = preferences.activeSubjectId.isEmpty
        ? languageSubjectId(selectedLanguage)
        : preferences.activeSubjectId;
    final legacyDailyXp = ((profile['dailyXp'] as num?)?.toInt() ?? 0).clamp(
      0,
      1000000000,
    );
    final dailyXpByCourse = _dailyXpByCourseFromJson(
      profile['dailyXpByCourse'],
      legacyDailyXp: legacyDailyXp,
      legacyCourseId: courseIdForSubject(activeSubjectId),
    );
    final dailyXpLedger = _normalizeDailyXpLedger(
      legacyByCourse: dailyXpByCourse,
      ledger: _dailyXpLedgerFromJson(profile['dailyXpByCourseAndReplica']),
    );
    final derivedDailyXpByCourse = _dailyXpByCourseFromLedger(dailyXpLedger);
    final badges = ((profile['badges'] as List<Object?>?) ?? const <Object?>[])
        .whereType<String>()
        .toSet();
    final next = AppState(
      selectedLanguage: selectedLanguage,
      progress: Map.unmodifiable(remappedProgress),
      totalXp: _sumXpLedger(xpByReplica),
      replicaId: state.replicaId,
      xpByReplica: Map.unmodifiable(xpByReplica),
      streakDays: ((profile['streakDays'] as num?)?.toInt() ?? 0).clamp(
        0,
        1000000000,
      ),
      dailyXp: _sumDailyXpByCourse(derivedDailyXpByCourse),
      dailyXpByCourse: Map.unmodifiable(derivedDailyXpByCourse),
      dailyXpByCourseAndReplica: Map.unmodifiable(dailyXpLedger),
      badges: Set.unmodifiable(badges),
      driveConnected: driveConnected ?? state.driveConnected,
      isHydrated: true,
      customItems: List.unmodifiable(customItems),
      customItemTombstones: Map.unmodifiable(tombstones),
      preferences: preferences,
      recentSessions: List.unmodifiable(recentSessions.take(20)),
      activeStudySession: activeStudy.session,
      activeSessionChangedAt: activeStudy.changedAt,
      pendingSync: state.pendingSync,
      lastStudyDate: _optionalDate(profile['lastStudyDate']),
    );
    await _store.saveProfile(
      StoredProfile(
        selectedLanguage: next.selectedLanguage,
        totalXp: next.totalXp,
        streakDays: next.streakDays,
        dailyXp: next.dailyXp,
        badges: next.badges,
        driveConnected: next.driveConnected,
        progress: next.progress,
        dailyXpByCourse: next.dailyXpByCourse,
        dailyXpByCourseAndReplica: next.dailyXpByCourseAndReplica,
        replicaId: next.replicaId,
        xpByReplica: next.xpByReplica,
        lastStudyDate: next.lastStudyDate,
      ),
    );
    await _store.replaceProgress(next.progress);
    await _store.replaceCustomContent(
      items: next.customItems,
      tombstones: next.customItemTombstones,
    );
    await _store.savePreferences(next.preferences);
    await _store.replaceStudySessions(next.recentSessions);
    if (activeStudy.session case final session?) {
      await _store.saveActiveStudySession(session);
    } else {
      await _store.clearActiveStudySession(activeStudy.changedAt!);
    }
    if (mounted) {
      state = next;
      unawaited(_reconcileStudyNotifications(next.preferences));
    }
    return exportSyncSnapshot();
  }

  Future<BackupRestoreResult> restoreBackup(BackupArchive archive) async {
    await mergeRemoteSnapshot(
      archive.snapshot,
      markDriveConnected: false,
      recordSyncReport: false,
    );

    final sessionsById = <String, StudySessionSummary>{
      for (final session in state.recentSessions) session.sessionId: session,
    };
    var restoredSessionCount = 0;
    for (final incoming in archive.sessions) {
      final current = sessionsById[incoming.sessionId];
      final incomingWins =
          current == null ||
          incoming.endedAt.isAfter(current.endedAt) ||
          (incoming.endedAt == current.endedAt &&
              jsonEncode(
                    incoming.toJson(),
                  ).compareTo(jsonEncode(current.toJson())) >=
                  0);
      if (!incomingWins) continue;
      await _store.saveStudySession(incoming);
      sessionsById[incoming.sessionId] = incoming;
      restoredSessionCount += 1;
    }

    final recentSessions = await _store.loadRecentSessions();
    final nextState = state.copyWith(
      selectedLanguage: archive.selectedLanguage,
      recentSessions: recentSessions,
    );
    await _store.saveProfile(
      StoredProfile(
        selectedLanguage: nextState.selectedLanguage,
        totalXp: nextState.totalXp,
        replicaId: nextState.replicaId,
        xpByReplica: nextState.xpByReplica,
        streakDays: nextState.streakDays,
        dailyXp: nextState.dailyXp,
        dailyXpByCourse: nextState.dailyXpByCourse,
        dailyXpByCourseAndReplica: nextState.dailyXpByCourseAndReplica,
        badges: nextState.badges,
        driveConnected: nextState.driveConnected,
        progress: nextState.progress,
        lastStudyDate: nextState.lastStudyDate,
      ),
    );
    if (mounted) state = nextState;
    await _queueSyncIfDriveConnected();
    return BackupRestoreResult(
      customItemCount: nextState.customItems.length,
      progressCount: nextState.progress.length,
      restoredSessionCount: restoredSessionCount,
      recentSessionCount: recentSessions.length,
    );
  }
}

StoredActiveStudyState? _activeStudyStateFromJson(Object? raw) {
  if (raw is! Map) return null;
  final json = Map<String, Object?>.from(raw);
  final changedAt = _optionalDate(json['changedAt']);
  if (changedAt == null) return null;
  final rawSession = json['session'];
  if (rawSession == null) return StoredActiveStudyState(changedAt: changedAt);
  if (rawSession is! Map) return null;
  try {
    return StoredActiveStudyState(
      session: ActiveStudySession.fromJson(
        Map<String, Object?>.from(rawSession),
      ),
      changedAt: changedAt,
    );
  } on FormatException {
    return null;
  }
}

StoredActiveStudyState _mergeActiveStudyState(
  StoredActiveStudyState local,
  StoredActiveStudyState? remote,
) {
  if (remote == null || remote.changedAt == null) return local;
  if (local.changedAt == null) return remote;
  final comparison = remote.changedAt!.compareTo(local.changedAt!);
  if (comparison > 0) return remote;
  if (comparison < 0) return local;
  if (remote.session == null) return remote;
  if (local.session == null) return local;
  if (remote.session!.completedCount != local.session!.completedCount) {
    return remote.session!.completedCount > local.session!.completedCount
        ? remote
        : local;
  }
  return remote.session!.sessionId.compareTo(local.session!.sessionId) > 0
      ? remote
      : local;
}

bool _remoteProgressWins(ProgressRecord remote, ProgressRecord local) {
  final remoteTime = remote.lastStudiedAt;
  final localTime = local.lastStudiedAt;
  if (remoteTime != null && localTime == null) return true;
  if (remoteTime == null && localTime != null) return false;
  if (remoteTime != null && localTime != null) {
    final comparison = remoteTime.compareTo(localTime);
    if (comparison != 0) return comparison > 0;
  }
  if (remote.attempts != local.attempts) {
    return remote.attempts > local.attempts;
  }
  return remote.currentIntervalDays > local.currentIntervalDays;
}

Map<String, DateTime> _customItemTombstonesFromJson(Object? raw) {
  if (raw is! List<Object?>) return const {};
  final tombstones = <String, DateTime>{};
  for (final entry in raw) {
    if (entry is! Map || entry['id'] is! String) continue;
    final deletedAt = _optionalDate(entry['deletedAt']);
    if (deletedAt != null) {
      tombstones[entry['id']! as String] = deletedAt;
    }
  }
  return tombstones;
}

class _MergedCustomContent {
  const _MergedCustomContent({
    required this.items,
    required this.tombstones,
    required this.itemIdAliases,
  });

  final List<LearningItem> items;
  final Map<String, DateTime> tombstones;
  final Map<String, String> itemIdAliases;
}

_MergedCustomContent _mergeCustomContent({
  required Iterable<LearningItem> localItems,
  required Iterable<LearningItem> remoteItems,
  required Map<String, DateTime> localTombstones,
  required Map<String, DateTime> remoteTombstones,
  required LearningItemCodec itemCodec,
}) {
  final local = {for (final item in localItems) item.id: item};
  final remote = {for (final item in remoteItems) item.id: item};
  final ids = {
    ...local.keys,
    ...remote.keys,
    ...localTombstones.keys,
    ...remoteTombstones.keys,
  }.toList()..sort();
  final liveItemsById = <String, LearningItem>{};
  final deletedItemsById = <String, LearningItem>{};
  final tombstones = <String, DateTime>{};
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  for (final id in ids) {
    final localItem = local[id];
    final remoteItem = remote[id];
    LearningItem? selectedItem;
    if (localItem == null) {
      selectedItem = remoteItem;
    } else if (remoteItem == null) {
      selectedItem = localItem;
    } else {
      selectedItem =
          _compareCustomItemVersions(localItem, remoteItem, itemCodec) >= 0
          ? localItem
          : remoteItem;
    }

    final localDeletedAt = localTombstones[id];
    final remoteDeletedAt = remoteTombstones[id];
    final deletedAt = switch ((localDeletedAt, remoteDeletedAt)) {
      (final DateTime left, final DateTime right) =>
        left.isAfter(right) ? left : right,
      (final DateTime value, null) || (null, final DateTime value) => value,
      _ => null,
    };
    final itemChangedAt = selectedItem?.updatedAt ?? epoch;
    if (deletedAt != null &&
        (selectedItem == null || !deletedAt.isBefore(itemChangedAt))) {
      tombstones[id] = deletedAt;
      if (selectedItem != null) deletedItemsById[id] = selectedItem;
    } else if (selectedItem != null) {
      final contributors = <LearningItem>[];
      if (localItem != null) contributors.add(localItem);
      if (remoteItem != null) contributors.add(remoteItem);
      liveItemsById[id] = _mergeCustomItemEnhancements(
        preferred: selectedItem,
        contributors: contributors,
        itemCodec: itemCodec,
      );
    }
  }

  final semanticClusters = <String, List<LearningItem>>{};
  for (final item in liveItemsById.values) {
    semanticClusters
        .putIfAbsent(_customItemSemanticKey(item, itemCodec), () => [])
        .add(item);
  }

  final items = <LearningItem>[];
  final itemIdAliases = <String, String>{};
  final canonicalIdBySemanticKey = <String, String>{};
  final semanticKeys = semanticClusters.keys.toList()..sort();
  for (final semanticKey in semanticKeys) {
    final cluster = semanticClusters[semanticKey]!
      ..sort((left, right) => left.id.compareTo(right.id));
    var preferred = cluster.first;
    for (final candidate in cluster.skip(1)) {
      if (_compareCustomItemVersions(candidate, preferred, itemCodec) > 0) {
        preferred = candidate;
      }
    }
    final mergedItem = _mergeCustomItemEnhancements(
      preferred: preferred,
      contributors: cluster,
      itemCodec: itemCodec,
    );
    items.add(mergedItem);
    canonicalIdBySemanticKey[semanticKey] = mergedItem.id;

    for (final alias in cluster) {
      if (alias.id == mergedItem.id) continue;
      itemIdAliases[alias.id] = mergedItem.id;
      final deletedAt = alias.updatedAt ?? epoch;
      final existingDeletedAt = tombstones[alias.id];
      if (existingDeletedAt == null || deletedAt.isAfter(existingDeletedAt)) {
        tombstones[alias.id] = deletedAt;
      }
    }
  }

  // A device may receive a convergence tombstone after it has already recorded
  // progress against the retired ID. Its stale item still gives us enough
  // semantic information to carry that progress onto the surviving item.
  for (final entry in deletedItemsById.entries) {
    final canonicalId =
        canonicalIdBySemanticKey[_customItemSemanticKey(
          entry.value,
          itemCodec,
        )];
    if (canonicalId != null && canonicalId != entry.key) {
      itemIdAliases[entry.key] = canonicalId;
    }
  }

  return _MergedCustomContent(
    items: List.unmodifiable(items),
    tombstones: Map.unmodifiable(tombstones),
    itemIdAliases: Map.unmodifiable(itemIdAliases),
  );
}

int _compareCustomItemVersions(
  LearningItem left,
  LearningItem right,
  LearningItemCodec itemCodec,
) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final changedAtComparison = (left.updatedAt ?? epoch).compareTo(
    right.updatedAt ?? epoch,
  );
  if (changedAtComparison != 0) return changedAtComparison;
  final versionComparison = left.source.contentVersion.compareTo(
    right.source.contentVersion,
  );
  if (versionComparison != 0) return versionComparison;
  return jsonEncode(
    itemCodec.toJson(left),
  ).compareTo(jsonEncode(itemCodec.toJson(right)));
}

String _customItemSemanticKey(LearningItem item, LearningItemCodec itemCodec) {
  return itemCodec.validator.identityKey(item);
}

LearningItem _mergeCustomItemEnhancements({
  required LearningItem preferred,
  required Iterable<LearningItem> contributors,
  required LearningItemCodec itemCodec,
}) {
  final remaining =
      contributors.where((item) => !identical(item, preferred)).toList()..sort(
        (left, right) => _compareCustomItemVersions(right, left, itemCodec),
      );
  final ordered = <LearningItem>[preferred, ...remaining];
  final translations = _mergeCustomStringValues(
    ordered.map((item) => item.translations),
    limit: 20,
  );
  final acceptedAnswers = _mergeCustomStringValues([
    translations,
    ...ordered.map((item) => item.acceptedAnswers),
  ], limit: 50);
  final readings = _mergeCustomReadings(
    ordered.map((item) => item.readings),
    limit: 8,
  );
  final preferredDistributionKey = importDistributionKeyOf(preferred);
  final allTags = <String>[
    if (preferredDistributionKey != null)
      importDistributionTag(preferredDistributionKey),
    ..._mergeCustomStringValues(
      ordered.map(
        (item) => item.tags.where(
          (tag) => !tag.startsWith(importDistributionTagPrefix),
        ),
      ),
    ),
  ];
  final tags = allTags.length <= 24
      ? List<String>.unmodifiable(allTags)
      : <String>[
          ...allTags.where(_isStructuralCustomTag),
          ...allTags.where((tag) => !_isStructuralCustomTag(tag)),
        ].take(24).toList(growable: false);

  return itemCodec.validator.ensureValid(
    preferred.copyWith(
      translations: translations,
      acceptedAnswers: acceptedAnswers,
      readings: readings,
      tags: tags,
      capabilities: {for (final item in ordered) ...item.capabilities},
    ),
  );
}

List<String> _mergeCustomStringValues(
  Iterable<Iterable<String>> groups, {
  int? limit,
}) {
  final values = <String>[];
  final keys = <String>{};
  for (final group in groups) {
    for (final value in group) {
      if (keys.add(_customValueKey(value))) {
        values.add(value);
        if (limit != null && values.length == limit) {
          return List.unmodifiable(values);
        }
      }
    }
  }
  return List.unmodifiable(values);
}

List<Reading> _mergeCustomReadings(
  Iterable<Iterable<Reading>> groups, {
  required int limit,
}) {
  final values = <Reading>[];
  final keys = <String>{};
  for (final group in groups) {
    for (final reading in group) {
      final key = '${reading.scheme.name}|${_customValueKey(reading.value)}';
      if (keys.add(key)) {
        values.add(reading);
        if (values.length == limit) return List.unmodifiable(values);
      }
    }
  }
  return List.unmodifiable(values);
}

String _customValueKey(String value) =>
    unicode.nfkc(value).toLowerCase().replaceAll(RegExp(r'\s+'), '');

bool _isStructuralCustomTag(String tag) {
  final normalized = unicode.nfkc(tag).trim().toLowerCase();
  return normalized.startsWith(learningGroupTagPrefix) ||
      normalized.startsWith(importDistributionTagPrefix);
}

Map<String, ProgressRecord> _remapProgressItemIds(
  Map<String, ProgressRecord> progress,
  Map<String, String> itemIdAliases,
) {
  if (itemIdAliases.isEmpty) return progress;
  final remapped = <String, ProgressRecord>{};
  final itemIds = progress.keys.toList()..sort();
  for (final itemId in itemIds) {
    final record = progress[itemId]!;
    final canonicalId = _resolveCustomItemAlias(itemId, itemIdAliases);
    final candidate = canonicalId == record.itemId
        ? record
        : ProgressRecord(
            itemId: canonicalId,
            status: record.status,
            correctCount: record.correctCount,
            wrongCount: record.wrongCount,
            lapseCount: record.lapseCount,
            currentIntervalDays: record.currentIntervalDays,
            nextReviewAt: record.nextReviewAt,
            lastStudiedAt: record.lastStudiedAt,
            lastResult: record.lastResult,
          );
    final current = remapped[canonicalId];
    if (current == null || _progressCandidateWins(candidate, current)) {
      remapped[canonicalId] = candidate;
    }
  }
  return remapped;
}

String _resolveCustomItemAlias(
  String itemId,
  Map<String, String> itemIdAliases,
) {
  var current = itemId;
  final visited = <String>{};
  while (visited.add(current)) {
    final next = itemIdAliases[current];
    if (next == null) break;
    current = next;
  }
  return current;
}

Map<String, String> _mergeContentItemAliases(
  Map<String, String> local,
  Map<String, String> remote,
  Map<String, String> contentAliases,
) {
  final candidates = <String, Set<String>>{};
  for (final source in [local, remote]) {
    for (final entry in source.entries) {
      if (entry.key.isEmpty ||
          entry.value.isEmpty ||
          entry.key == entry.value) {
        continue;
      }
      candidates.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
    }
  }
  final raw = <String, String>{
    for (final entry in candidates.entries)
      entry.key: (entry.value.toList()..sort()).first,
    ...contentAliases,
  };
  String resolve(String itemId) {
    var current = itemId;
    final path = <String>[];
    final pathIndex = <String, int>{};
    while (true) {
      final cycleStart = pathIndex[current];
      if (cycleStart != null) {
        final cycle = path.sublist(cycleStart)..sort();
        return cycle.first;
      }
      pathIndex[current] = path.length;
      path.add(current);
      final next = raw[current];
      if (next == null || next == current) return current;
      current = next;
    }
  }

  final result = <String, String>{};
  final prioritized = contentAliases.keys.toList()..sort();
  final remaining =
      raw.keys.where((source) => !contentAliases.containsKey(source)).toList()
        ..sort();
  for (final source in [...prioritized, ...remaining].take(50000)) {
    final target = resolve(source);
    if (source != target) result[source] = target;
  }
  return Map.unmodifiable(result);
}

Set<String> _remapItemIdSet(
  Iterable<String> source,
  Map<String, String> aliases,
) => {for (final itemId in source) _resolveCustomItemAlias(itemId, aliases)};

Map<String, DateTime> _remapItemChangeDatesForAliases(
  Map<String, DateTime> source,
  Map<String, String> aliases,
) {
  final result = <String, DateTime>{...source};
  for (final entry in source.entries) {
    final target = _resolveCustomItemAlias(entry.key, aliases);
    final current = result[target];
    if (current == null || entry.value.isAfter(current)) {
      result[target] = entry.value;
    }
  }
  return Map.unmodifiable(result);
}

bool _progressCandidateWins(ProgressRecord candidate, ProgressRecord current) {
  if (_remoteProgressWins(candidate, current)) return true;
  if (_remoteProgressWins(current, candidate)) return false;
  return jsonEncode(
        _progressToJson(candidate),
      ).compareTo(jsonEncode(_progressToJson(current))) >
      0;
}

int _maxInt(int left, int right) => left >= right ? left : right;

const _maximumXp = 1000000000;
const _maximumXpReplicaCount = 500;
const _legacyXpReplicaId = 'legacy';

Map<String, int> _xpLedgerFromJson(Object? raw) {
  if (raw is! Map) return const {};
  final values = <String, int>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String ||
        !_isValidReplicaId(key) ||
        value is! num ||
        !value.isFinite ||
        value != value.round()) {
      continue;
    }
    values[key] = value.toInt().clamp(0, _maximumXp);
  }
  return Map.unmodifiable(values);
}

Map<String, int> _normalizeXpLedger({
  required int totalXp,
  required Map<String, int> xpByReplica,
}) {
  final normalized = <String, int>{};
  for (final entry in xpByReplica.entries) {
    if (!_isValidReplicaId(entry.key)) continue;
    normalized[entry.key] = entry.value.clamp(0, _maximumXp);
  }
  final legacyTotal = totalXp.clamp(0, _maximumXp);
  final ledgerTotal = _sumXpLedger(normalized);
  if (legacyTotal > ledgerTotal) {
    normalized[_legacyXpReplicaId] =
        (normalized[_legacyXpReplicaId] ?? 0) + legacyTotal - ledgerTotal;
  }
  final entries = normalized.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return Map.unmodifiable({
    for (final entry in entries) entry.key: entry.value,
  });
}

Map<String, int> _mergeXpLedgers(
  Map<String, int> local,
  Map<String, int> remote,
) {
  final replicaIds = {...local.keys, ...remote.keys}.toList()..sort();
  if (replicaIds.length > _maximumXpReplicaCount) {
    throw StateError(
      'XP replica ledger exceeds the safe limit of '
      '$_maximumXpReplicaCount devices.',
    );
  }
  return Map.unmodifiable({
    for (final replicaId in replicaIds)
      replicaId: _maxInt(local[replicaId] ?? 0, remote[replicaId] ?? 0),
  });
}

int _sumXpLedger(Map<String, int> ledger) {
  var total = 0;
  for (final value in ledger.values) {
    total += value.clamp(0, _maximumXp);
    if (total >= _maximumXp) return _maximumXp;
  }
  return total;
}

bool _isValidReplicaId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 80 || trimmed != value) return false;
  return trimmed.codeUnits.every(
    (code) =>
        (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 45 ||
        code == 95,
  );
}

class _MergedDailyGoals {
  const _MergedDailyGoals({
    required this.goals,
    required this.changedAtBySubject,
  });

  final Map<String, int> goals;
  final Map<String, DateTime> changedAtBySubject;
}

_MergedDailyGoals _mergeDailyGoals({
  required Map<String, int> local,
  required Map<String, int> remote,
  required Map<String, DateTime> localChangedAt,
  required Map<String, DateTime> remoteChangedAt,
}) {
  final ids = {...local.keys, ...remote.keys}.toList()..sort();
  final goals = <String, int>{};
  final changedAtBySubject = <String, DateTime>{};
  for (final id in ids) {
    final localGoal = local[id];
    final remoteGoal = remote[id];
    final localTime = localChangedAt[id]?.toUtc();
    final remoteTime = remoteChangedAt[id]?.toUtc();
    final remoteWins = switch ((localGoal, remoteGoal)) {
      (null, final int _) => true,
      (final int _, null) => false,
      (final int localValue, final int remoteValue) => _remoteTimestampWins(
        local: localTime,
        remote: remoteTime,
        localTieBreaker: localValue,
        remoteTieBreaker: remoteValue,
      ),
      _ => false,
    };
    final selectedGoal = remoteWins ? remoteGoal : localGoal;
    final selectedTime = remoteWins ? remoteTime : localTime;
    if (selectedGoal != null) goals[id] = selectedGoal;
    if (selectedTime != null) changedAtBySubject[id] = selectedTime;
  }
  return _MergedDailyGoals(
    goals: Map.unmodifiable(goals),
    changedAtBySubject: Map.unmodifiable(changedAtBySubject),
  );
}

class _ActiveSubjectSelection {
  const _ActiveSubjectSelection({required this.id, required this.changedAt});

  final String id;
  final DateTime? changedAt;
}

_ActiveSubjectSelection _mergeActiveSubjectSelection({
  required String localId,
  required String remoteId,
  required DateTime? localChangedAt,
  required DateTime? remoteChangedAt,
}) {
  if (localId.isEmpty) {
    return _ActiveSubjectSelection(
      id: remoteId,
      changedAt: remoteChangedAt?.toUtc(),
    );
  }
  if (remoteId.isEmpty) {
    return _ActiveSubjectSelection(
      id: localId,
      changedAt: localChangedAt?.toUtc(),
    );
  }
  final localTime = localChangedAt?.toUtc();
  final remoteTime = remoteChangedAt?.toUtc();
  final remoteWins = switch ((localTime, remoteTime)) {
    (null, final DateTime _) => true,
    (final DateTime _, null) => false,
    (final DateTime localValue, final DateTime remoteValue)
        when localValue != remoteValue =>
      remoteValue.isAfter(localValue),
    _ => remoteId.compareTo(localId) < 0,
  };
  return _ActiveSubjectSelection(
    id: remoteWins ? remoteId : localId,
    changedAt: remoteWins ? remoteTime : localTime,
  );
}

bool _remoteTimestampWins({
  required DateTime? local,
  required DateTime? remote,
  required int localTieBreaker,
  required int remoteTieBreaker,
}) {
  if (local == null) {
    if (remote != null) return true;
  } else if (remote == null) {
    return false;
  } else {
    final comparison = remote.compareTo(local);
    if (comparison != 0) return comparison > 0;
  }
  return remoteTieBreaker > localTieBreaker;
}

bool _remoteStructuredPreferenceWins({
  required DateTime? localChangedAt,
  required DateTime? remoteChangedAt,
  required Map<String, Object?> localJson,
  required Map<String, Object?> remoteJson,
  required bool remoteWhenUndated,
}) {
  final local = localChangedAt?.toUtc();
  final remote = remoteChangedAt?.toUtc();
  if (local == null && remote == null) return remoteWhenUndated;
  if (local == null) return true;
  if (remote == null) return false;
  final timestampOrder = remote.compareTo(local);
  if (timestampOrder != 0) return timestampOrder > 0;
  return jsonEncode(remoteJson).compareTo(jsonEncode(localJson)) > 0;
}

class _TimestampedMembership {
  const _TimestampedMembership({
    required this.members,
    required this.changedAtById,
  });

  final Set<String> members;
  final Map<String, DateTime> changedAtById;
}

_TimestampedMembership _mergeTimestampedMembership({
  required Set<String> local,
  required Set<String> remote,
  required Map<String, DateTime> localChangedAt,
  required Map<String, DateTime> remoteChangedAt,
}) {
  final ids = {
    ...local,
    ...remote,
    ...localChangedAt.keys,
    ...remoteChangedAt.keys,
  }.toList()..sort();
  final members = <String>{};
  final changedAtById = <String, DateTime>{};
  for (final id in ids) {
    final localContains = local.contains(id);
    final remoteContains = remote.contains(id);
    final localTime = localChangedAt[id]?.toUtc();
    final remoteTime = remoteChangedAt[id]?.toUtc();
    final selectedContains = switch ((localTime, remoteTime)) {
      (null, null) => localContains || remoteContains,
      (null, final DateTime _) => remoteContains,
      (final DateTime _, null) => localContains,
      (final DateTime left, final DateTime right) when left != right =>
        right.isAfter(left) ? remoteContains : localContains,
      _ => localContains && remoteContains,
    };
    if (selectedContains) members.add(id);
    final selectedTime = switch ((localTime, remoteTime)) {
      (null, final DateTime right) => right,
      (final DateTime left, null) => left,
      (final DateTime left, final DateTime right) =>
        right.isAfter(left) ? right : left,
      _ => null,
    };
    if (selectedTime != null) changedAtById[id] = selectedTime;
  }
  return _TimestampedMembership(
    members: Set.unmodifiable(members),
    changedAtById: Map.unmodifiable(changedAtById),
  );
}

Map<String, int> _dailyXpByCourseFromJson(
  Object? raw, {
  required int legacyDailyXp,
  required String legacyCourseId,
}) {
  final values = <String, int>{};
  if (raw is Map) {
    for (final entry in raw.entries.take(200)) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String ||
          key.trim().isEmpty ||
          key.runes.length > 160 ||
          value is! num ||
          !value.isFinite ||
          value != value.round()) {
        continue;
      }
      values[key] = value.toInt().clamp(0, 1000000000);
    }
  }
  if (values.isEmpty && legacyDailyXp > 0) {
    values[legacyCourseId] = legacyDailyXp.clamp(0, 1000000000);
  }
  return Map.unmodifiable(values);
}

Map<String, Map<String, int>> _dailyXpLedgerFromJson(Object? raw) {
  if (raw is! Map) return const {};
  final ledger = <String, Map<String, int>>{};
  for (final entry in raw.entries.take(200)) {
    final courseId = entry.key;
    if (courseId is! String ||
        courseId.trim().isEmpty ||
        courseId.runes.length > 160) {
      continue;
    }
    final replicaValues = _xpLedgerFromJson(entry.value);
    if (replicaValues.isNotEmpty) ledger[courseId] = replicaValues;
  }
  return _freezeDailyXpLedger(ledger);
}

Map<String, Map<String, int>> _normalizeDailyXpLedger({
  required Map<String, int> legacyByCourse,
  required Map<String, Map<String, int>> ledger,
}) {
  final normalized = <String, Map<String, int>>{
    for (final entry in ledger.entries)
      if (entry.key.trim().isNotEmpty && entry.key.runes.length <= 160)
        entry.key: _normalizeXpLedger(totalXp: 0, xpByReplica: entry.value),
  };
  for (final entry in legacyByCourse.entries) {
    final courseLedger = <String, int>{...?normalized[entry.key]};
    final legacyTotal = entry.value.clamp(0, _maximumXp);
    final ledgerTotal = _sumXpLedger(courseLedger);
    if (legacyTotal > ledgerTotal) {
      courseLedger[_legacyXpReplicaId] =
          (courseLedger[_legacyXpReplicaId] ?? 0) + legacyTotal - ledgerTotal;
    }
    if (courseLedger.isNotEmpty) normalized[entry.key] = courseLedger;
  }
  return _freezeDailyXpLedger(normalized);
}

Map<String, Map<String, int>> _mergeDailyXpLedgers({
  required Map<String, Map<String, int>> local,
  required Map<String, Map<String, int>> remote,
  required DateTime? localDate,
  required DateTime? remoteDate,
}) {
  if (localDate == null) return _freezeDailyXpLedger(remote);
  if (remoteDate == null) return _freezeDailyXpLedger(local);
  if (localDate.isAfter(remoteDate)) return _freezeDailyXpLedger(local);
  if (remoteDate.isAfter(localDate)) return _freezeDailyXpLedger(remote);

  final courseIds = {...local.keys, ...remote.keys}.toList()..sort();
  final merged = <String, Map<String, int>>{};
  for (final courseId in courseIds) {
    merged[courseId] = _mergeXpLedgers(
      local[courseId] ?? const {},
      remote[courseId] ?? const {},
    );
  }
  return _freezeDailyXpLedger(merged);
}

Map<String, Map<String, int>> _freezeDailyXpLedger(
  Map<String, Map<String, int>> ledger,
) {
  final courseEntries = ledger.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return Map<String, Map<String, int>>.unmodifiable({
    for (final courseEntry in courseEntries)
      courseEntry.key: Map<String, int>.unmodifiable({
        for (final replicaEntry
            in (courseEntry.value.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          replicaEntry.key: replicaEntry.value.clamp(0, _maximumXp),
      }),
  });
}

Map<String, int> _dailyXpByCourseFromLedger(
  Map<String, Map<String, int>> ledger,
) {
  return Map.unmodifiable({
    for (final entry in ledger.entries) entry.key: _sumXpLedger(entry.value),
  });
}

int _sumDailyXpByCourse(Map<String, int> values) {
  var total = 0;
  for (final value in values.values) {
    total += value.clamp(0, _maximumXp);
    if (total >= _maximumXp) return _maximumXp;
  }
  return total;
}

List<StudySessionSummary> _mergeRecentSessions(
  Iterable<StudySessionSummary> local,
  Iterable<StudySessionSummary> remote,
) {
  final merged = <String, StudySessionSummary>{};
  for (final session in [...local, ...remote]) {
    final current = merged[session.sessionId];
    if (current == null ||
        session.endedAt.isAfter(current.endedAt) ||
        (session.endedAt == current.endedAt &&
            jsonEncode(
                  session.toJson(),
                ).compareTo(jsonEncode(current.toJson())) >
                0)) {
      merged[session.sessionId] = session;
    }
  }
  final sessions = merged.values.toList()
    ..sort((left, right) {
      final endedOrder = right.endedAt.compareTo(left.endedAt);
      if (endedOrder != 0) return endedOrder;
      return left.sessionId.compareTo(right.sessionId);
    });
  return List.unmodifiable(sessions.take(20));
}

int _compareSavedSessionPlans(StudySessionPlan left, StudySessionPlan right) {
  final leftUpdatedAt =
      left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final rightUpdatedAt =
      right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final updatedOrder = rightUpdatedAt.compareTo(leftUpdatedAt);
  if (updatedOrder != 0) return updatedOrder;
  return left.planId.compareTo(right.planId);
}

class _MergedSavedSessionPlans {
  const _MergedSavedSessionPlans({
    required this.plans,
    required this.tombstones,
  });

  final List<StudySessionPlan> plans;
  final Map<String, DateTime> tombstones;
}

_MergedSavedSessionPlans _mergeSavedSessionPlans({
  required List<StudySessionPlan> remote,
  required List<StudySessionPlan> local,
  required Map<String, DateTime> remoteTombstones,
  required Map<String, DateTime> localTombstones,
}) {
  final merged = <String, StudySessionPlan>{
    for (final plan in remote)
      if (plan.planId.isNotEmpty) plan.planId: plan,
  };
  for (final plan in local) {
    if (plan.planId.isEmpty) continue;
    final current = merged[plan.planId];
    merged[plan.planId] = current == null
        ? plan
        : _newerSessionPlan(current, plan);
  }
  final tombstones = <String, DateTime>{...remoteTombstones};
  for (final entry in localTombstones.entries) {
    final current = tombstones[entry.key];
    if (current == null || entry.value.isAfter(current)) {
      tombstones[entry.key] = entry.value.toUtc();
    }
  }
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  merged.removeWhere((planId, plan) {
    final deletedAt = tombstones[planId];
    return deletedAt != null &&
        !deletedAt.isBefore((plan.updatedAt ?? epoch).toUtc());
  });
  final plans = merged.values.toList()..sort(_compareSavedSessionPlans);
  final tombstoneEntries = tombstones.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return _MergedSavedSessionPlans(
    plans: List.unmodifiable(plans.take(20)),
    tombstones: Map.unmodifiable({
      for (final entry in tombstoneEntries.take(100))
        entry.key: entry.value.toUtc(),
    }),
  );
}

List<StudySubject> _mergeStudySubjects(
  List<StudySubject> remote,
  List<StudySubject> local,
) {
  final merged = <String, StudySubject>{
    for (final subject in remote) subject.id: subject,
  };
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (final subject in local) {
    final current = merged[subject.id];
    if (current == null ||
        (subject.updatedAt ?? epoch).isAfter(current.updatedAt ?? epoch)) {
      merged[subject.id] = subject;
    }
  }
  final subjects = merged.values.toList()
    ..sort((left, right) => left.name.compareTo(right.name));
  return List.unmodifiable(subjects);
}

List<StudySubject> _subjectsForPreferences(StudyPreferences preferences) {
  final byId = <String, StudySubject>{
    for (final subject in builtInLanguageSubjects) subject.id: subject,
    for (final subject in preferences.customSubjects) subject.id: subject,
  };
  return byId.values.toList(growable: false);
}

List<ImportDistributionRule> _mergeImportDistributionRules(
  List<ImportDistributionRule> remote,
  List<ImportDistributionRule> local,
) {
  final merged = <String, ImportDistributionRule>{
    for (final rule in remote) rule.key: rule,
  };
  for (final rule in local) {
    final current = merged[rule.key];
    if (current == null ||
        rule.updatedAt.isAfter(current.updatedAt) ||
        rule.updatedAt == current.updatedAt &&
            jsonEncode(rule.toJson()).compareTo(jsonEncode(current.toJson())) >
                0) {
      merged[rule.key] = rule;
    }
  }
  final rules = merged.values.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return List.unmodifiable(rules.take(200));
}

List<LearningGroupDefinition> _definitionsIncludingLegacyTags(
  Iterable<LearningGroupDefinition> definitions,
  Iterable<LearningItem> items,
) {
  final byId = <String, LearningGroupDefinition>{
    for (final definition in definitions) definition.id: definition,
  };
  final nextOrderBySubject = <String, int>{};
  for (final definition in byId.values) {
    final next = definition.sortOrder + 1;
    final current = nextOrderBySubject[definition.subjectId] ?? 0;
    if (next > current) nextOrderBySubject[definition.subjectId] = next;
  }
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (final item in items) {
    for (final groupName in learningGroupsOf(item)) {
      final id = learningGroupDefinitionId(item.effectiveSubjectId, groupName);
      if (byId.containsKey(id)) continue;
      final order = nextOrderBySubject[item.effectiveSubjectId] ?? 0;
      byId[id] = LearningGroupDefinition(
        subjectId: item.effectiveSubjectId,
        name: groupName,
        sortOrder: order,
        createdAt: item.updatedAt ?? epoch,
        updatedAt: item.updatedAt ?? epoch,
      );
      nextOrderBySubject[item.effectiveSubjectId] = order + 1;
    }
  }
  return byId.values.toList(growable: true);
}

int _compareLearningGroupDefinitions(
  LearningGroupDefinition left,
  LearningGroupDefinition right,
) {
  final pinOrder = (right.pinned ? 1 : 0).compareTo(left.pinned ? 1 : 0);
  if (pinOrder != 0) return pinOrder;
  final manualOrder = left.sortOrder.compareTo(right.sortOrder);
  if (manualOrder != 0) return manualOrder;
  return left.name.compareTo(right.name);
}

class _MergedLearningGroupDefinitions {
  const _MergedLearningGroupDefinitions({
    required this.groups,
    required this.tombstones,
  });

  final List<LearningGroupDefinition> groups;
  final Map<String, DateTime> tombstones;
}

_MergedLearningGroupDefinitions _mergeLearningGroupDefinitions({
  required List<LearningGroupDefinition> remote,
  required List<LearningGroupDefinition> local,
  required Map<String, DateTime> remoteTombstones,
  required Map<String, DateTime> localTombstones,
}) {
  final merged = <String, LearningGroupDefinition>{};
  for (final group in [...remote, ...local]) {
    final current = merged[group.id];
    if (current == null ||
        group.updatedAt.isAfter(current.updatedAt) ||
        (group.updatedAt == current.updatedAt &&
            jsonEncode(group.toJson()).compareTo(jsonEncode(current.toJson())) >
                0)) {
      merged[group.id] = group;
    }
  }
  final tombstones = <String, DateTime>{...remoteTombstones};
  for (final entry in localTombstones.entries) {
    final current = tombstones[entry.key];
    if (current == null || entry.value.isAfter(current)) {
      tombstones[entry.key] = entry.value.toUtc();
    }
  }
  merged.removeWhere((id, group) {
    final deletedAt = tombstones[id];
    return deletedAt != null && !deletedAt.isBefore(group.updatedAt);
  });
  final groups = merged.values.toList()..sort(_compareLearningGroupDefinitions);
  final tombstoneEntries = tombstones.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return _MergedLearningGroupDefinitions(
    groups: List.unmodifiable(groups.take(500)),
    tombstones: Map.unmodifiable({
      for (final entry in tombstoneEntries.take(500))
        entry.key: entry.value.toUtc(),
    }),
  );
}

class _MergedVersionedPreferenceRecords<T> {
  const _MergedVersionedPreferenceRecords({
    required this.records,
    required this.tombstones,
  });

  final List<T> records;
  final Map<String, DateTime> tombstones;
}

_MergedVersionedPreferenceRecords<T> _mergeVersionedPreferenceRecords<T>({
  required List<T> remote,
  required List<T> local,
  required Map<String, DateTime> remoteTombstones,
  required Map<String, DateTime> localTombstones,
  required String Function(T value) idOf,
  required DateTime Function(T value) updatedAtOf,
  required Map<String, Object?> Function(T value) toJson,
  required int maximumRecords,
  required int maximumTombstones,
}) {
  final merged = <String, T>{};
  for (final value in [...remote, ...local]) {
    final id = idOf(value);
    final current = merged[id];
    if (current == null) {
      merged[id] = value;
      continue;
    }
    final updatedAt = updatedAtOf(value).toUtc();
    final currentUpdatedAt = updatedAtOf(current).toUtc();
    if (updatedAt.isAfter(currentUpdatedAt) ||
        (updatedAt == currentUpdatedAt &&
            jsonEncode(toJson(value)).compareTo(jsonEncode(toJson(current))) >
                0)) {
      merged[id] = value;
    }
  }
  final tombstones = <String, DateTime>{};
  for (final entry in [
    ...remoteTombstones.entries,
    ...localTombstones.entries,
  ]) {
    final current = tombstones[entry.key];
    final changedAt = entry.value.toUtc();
    if (current == null || changedAt.isAfter(current)) {
      tombstones[entry.key] = changedAt;
    }
  }
  merged.removeWhere((id, value) {
    final deletedAt = tombstones[id];
    return deletedAt != null && !deletedAt.isBefore(updatedAtOf(value).toUtc());
  });
  final records = merged.values.toList()
    ..sort((left, right) {
      final timestampOrder = updatedAtOf(right).compareTo(updatedAtOf(left));
      if (timestampOrder != 0) return timestampOrder;
      return idOf(left).compareTo(idOf(right));
    });
  final sortedTombstones = tombstones.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return _MergedVersionedPreferenceRecords<T>(
    records: List.unmodifiable(records.take(maximumRecords)),
    tombstones: Map.unmodifiable({
      for (final entry in sortedTombstones.take(maximumTombstones))
        entry.key: entry.value,
    }),
  );
}

StudySessionPlan _newerSessionPlan(
  StudySessionPlan remote,
  StudySessionPlan local,
) {
  final remoteUpdatedAt = remote.updatedAt;
  final localUpdatedAt = local.updatedAt;
  if (remoteUpdatedAt == null && localUpdatedAt == null) return remote;
  if (remoteUpdatedAt == null) return local;
  if (localUpdatedAt == null) return remote;
  final comparison = remoteUpdatedAt.compareTo(localUpdatedAt);
  if (comparison > 0) return remote;
  if (comparison < 0) return local;
  final remoteSignature = jsonEncode(remote.toJson());
  final localSignature = jsonEncode(local.toJson());
  return remoteSignature.compareTo(localSignature) >= 0 ? remote : local;
}

Map<String, Object?> _progressToJson(ProgressRecord record) => {
  'itemId': record.itemId,
  'status': record.status.name,
  'correctCount': record.correctCount,
  'wrongCount': record.wrongCount,
  'lapseCount': record.lapseCount,
  'currentIntervalDays': record.currentIntervalDays,
  'nextReviewAt': record.nextReviewAt?.toUtc().toIso8601String(),
  'lastStudiedAt': record.lastStudiedAt?.toUtc().toIso8601String(),
  'lastResult': record.lastResult?.name,
};

ProgressRecord _progressFromJson(Map<String, Object?> json) {
  final itemId = json['itemId'] as String?;
  if (itemId == null || itemId.isEmpty) {
    throw const FormatException('Progress itemId is required');
  }
  final statusName = json['status'] as String? ?? LearningStatus.newItem.name;
  final resultName = json['lastResult'] as String?;
  return ProgressRecord(
    itemId: itemId,
    status: LearningStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => LearningStatus.newItem,
    ),
    correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
    wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
    lapseCount: (json['lapseCount'] as num?)?.toInt() ?? 0,
    currentIntervalDays: (json['currentIntervalDays'] as num?)?.toInt() ?? 0,
    nextReviewAt: _optionalDate(json['nextReviewAt']),
    lastStudiedAt: _optionalDate(json['lastStudiedAt']),
    lastResult: resultName == null
        ? null
        : ReviewRating.values.firstWhere(
            (value) => value.name == resultName,
            orElse: () => ReviewRating.again,
          ),
  );
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

final studyStoreProvider = Provider<StudyStore>(
  (ref) => DriftStudyStore(ref.watch(appDatabaseProvider)),
);

final appControllerProvider = StateNotifierProvider<AppController, AppState>((
  ref,
) {
  return AppController(
    ref.watch(studyStoreProvider),
    notificationService: ref.watch(studyNotificationServiceProvider),
  );
});
