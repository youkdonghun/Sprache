import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/sample_content.dart';
import '../data/study_store.dart';
import '../domain/active_study_session.dart';
import '../domain/content_validation.dart';
import '../domain/course_path.dart';
import '../domain/daily_queue.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/learning_item_codec.dart';
import '../domain/progress.dart';
import '../domain/review_forecast.dart';
import '../domain/scheduler.dart';
import '../domain/study_history.dart';
import '../domain/study_preferences.dart';
import '../domain/study_session_builder.dart';
import '../import/content_import_parser.dart';
import '../import/import_reconciler.dart';
import '../sync/pending_sync.dart';
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

class AppState {
  const AppState({
    required this.selectedLanguage,
    required this.progress,
    required this.totalXp,
    required this.streakDays,
    required this.dailyXp,
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
    streakDays: 0,
    dailyXp: 0,
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
  final int streakDays;
  final int dailyXp;
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
  int get dailyGoal => preferences.dailyGoal;

  AppState copyWith({
    LanguageTag? selectedLanguage,
    Map<String, ProgressRecord>? progress,
    int? totalXp,
    int? streakDays,
    int? dailyXp,
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
      streakDays: streakDays ?? this.streakDays,
      dailyXp: dailyXp ?? this.dailyXp,
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

class AppController extends StateNotifier<AppState> {
  AppController(this._store) : super(AppState.initial()) {
    unawaited(_hydrate());
  }

  final StudyStore _store;
  final _scheduler = const ReviewScheduler();
  final _queueBuilder = const DailyQueueBuilder();
  final _sessionBuilder = const StudySessionBuilder();
  final _pathBuilder = const CoursePathBuilder();
  final _forecastBuilder = const ReviewForecastBuilder();
  final _contentValidator = const LearningContentValidator();
  final _importReconciler = const ImportReconciler();
  final _itemCodec = const LearningItemCodec();
  final _snapshotValidator = const SyncSnapshotValidator();
  int _syncSequence = 0;

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
    final preferences = results[3] as StudyPreferences;
    final recentSessions = results[4] as List<StudySessionSummary>;
    final activeStudyState = results[5] as StoredActiveStudyState;
    final pendingSync = results[6] as PendingSyncOperation?;
    if (!mounted) return;
    state = state.copyWith(
      selectedLanguage: profile.selectedLanguage,
      progress: profile.progress,
      totalXp: profile.totalXp,
      streakDays: profile.streakDays,
      dailyXp: profile.dailyXp,
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
  }

  void _persist({bool queueSync = true}) {
    unawaited(() async {
      await _store.saveProfile(
        StoredProfile(
          selectedLanguage: state.selectedLanguage,
          totalXp: state.totalXp,
          streakDays: state.streakDays,
          dailyXp: state.dailyXp,
          badges: state.badges,
          driveConnected: state.driveConnected,
          progress: state.progress,
          lastStudyDate: state.lastStudyDate,
        ),
      );
      if (queueSync) await queueSyncSnapshot();
    }());
  }

  Future<PendingSyncOperation> queueSyncSnapshot({DateTime? now}) async {
    final createdAt = (now ?? DateTime.now()).toUtc();
    final operation = PendingSyncOperation(
      operationId:
          'snapshot-${createdAt.microsecondsSinceEpoch}-${_syncSequence++}',
      entityType: PendingSyncEntityType.snapshot,
      entityId: 'state/snapshot.json',
      payload: exportSyncSnapshot(),
      attempts: 0,
      nextAttemptAt: createdAt,
      createdAt: createdAt,
    );
    await _store.replacePendingSnapshotSync(operation);
    if (mounted) state = state.copyWith(pendingSync: operation);
    return operation;
  }

  Future<PendingSyncOperation?> markPendingSyncFailed(
    String operationId, {
    DateTime? now,
  }) async {
    final current = state.pendingSync;
    if (current == null || current.operationId != operationId) return current;
    final failedAt = (now ?? DateTime.now()).toUtc();
    final attempts = current.attempts + 1;
    final next = current.copyWith(
      attempts: attempts,
      nextAttemptAt: failedAt.add(pendingSyncBackoff(attempts)),
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

  List<LearningItem> get courseItems => [...state.customItems, ...sampleContent]
      .where((item) => item.learningLanguage == state.selectedLanguage)
      .toList(growable: false);

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
            .where((tag) => !tag.startsWith('unit-'))
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

  StudySessionBuildResult previewSessionPlan(
    StudySessionPlan plan,
    DateTime now,
  ) {
    return _sessionBuilder.build(
      courseId: state.selectedLanguage.courseId,
      localDate: now,
      items: selectedItems,
      progress: state.progress,
      plan: plan,
      favoriteItemIds: state.preferences.favoriteItemIds,
      personalItemIds: state.customItems.map((item) => item.id).toSet(),
    );
  }

  List<LearningItem> queue(
    DateTime now, {
    StudyMode? mode,
    int? unitIndex,
    StudySessionPlan? sessionPlan,
  }) {
    if (sessionPlan != null) {
      return previewSessionPlan(sessionPlan, now).items;
    }
    final selectedMode = mode ?? state.preferences.preferredMode;
    final sourceItems = unitIndex == null
        ? selectedItems
        : itemsForUnit(unitIndex);
    final filtered = sourceItems
        .where((item) {
          final progress = state.progress[item.id];
          return switch (selectedMode) {
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
      return filtered
          .take(state.preferences.sessionItemLimit)
          .toList(growable: false);
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
      return filtered
          .take(
            state.preferences.reviewLimit < state.preferences.sessionItemLimit
                ? state.preferences.reviewLimit
                : state.preferences.sessionItemLimit,
          )
          .toList(growable: false);
    }

    return _queueBuilder
        .build(
          courseId: state.selectedLanguage.courseId,
          localDate: now,
          items: filtered,
          progress: state.progress,
          newItemLimit: selectedMode == StudyMode.review
              ? 0
              : state.preferences.newItemLimit,
          reviewLimit: selectedMode == StudyMode.newItems
              ? 0
              : state.preferences.reviewLimit,
          sentenceRatio: selectedMode == StudyMode.words
              ? 0
              : selectedMode == StudyMode.sentences ||
                    selectedMode == StudyMode.cloze ||
                    selectedMode == StudyMode.sentenceOrder
              ? 1
              : state.preferences.sentenceRatio,
        )
        .take(state.preferences.sessionItemLimit)
        .toList(growable: false);
  }

  ReviewForecast reviewForecast(DateTime now) => _forecastBuilder.build(
    progress: state.progress.values,
    itemIds: selectedItems.map((item) => item.id).toSet(),
    now: now,
  );

  void selectLanguage(LanguageTag language) {
    if (!language.available) return;
    state = state.copyWith(selectedLanguage: language);
    _persist();
  }

  void updatePreferences(StudyPreferences preferences) {
    state = state.copyWith(preferences: preferences);
    unawaited(() async {
      await _store.savePreferences(preferences);
      await queueSyncSnapshot();
    }());
  }

  void updateSessionPlan(StudySessionPlan plan) {
    updatePreferences(
      state.preferences.copyWith(
        sessionPlan: plan.copyWith(updatedAt: DateTime.now().toUtc()),
      ),
    );
  }

  void toggleItemSelection(String itemId) {
    final excluded = {...state.preferences.excludedItemIds};
    if (!excluded.add(itemId)) excluded.remove(itemId);
    updatePreferences(state.preferences.copyWith(excludedItemIds: excluded));
  }

  void toggleFavorite(String itemId) {
    final favorites = {...state.preferences.favoriteItemIds};
    if (!favorites.add(itemId)) favorites.remove(itemId);
    updatePreferences(state.preferences.copyWith(favoriteItemIds: favorites));
  }

  bool hasCompletedMission(int unitIndex) => state.preferences
      .hasCompletedMission(state.selectedLanguage.courseId, unitIndex);

  int get completedMissionCount => List.generate(
    coursePath.units.length,
    (index) => index,
  ).where(hasCompletedMission).length;

  void completeMission(int unitIndex) {
    if (unitIndex < 0 || unitIndex >= coursePath.units.length) return;
    final completed = {...state.preferences.completedMissionIds}
      ..add('${state.selectedLanguage.courseId}:$unitIndex');
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
  }) {
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
    final studiedDay = DateTime(studiedAt.year, studiedAt.month, studiedAt.day);
    final previousDay = state.lastStudyDate == null
        ? null
        : DateTime(
            state.lastStudyDate!.year,
            state.lastStudyDate!.month,
            state.lastStudyDate!.day,
          );
    final isSameDay = previousDay == studiedDay;
    final isConsecutive =
        previousDay != null && studiedDay.difference(previousDay).inDays == 1;
    final nextStreak = isSameDay
        ? state.streakDays
        : isConsecutive
        ? state.streakDays + 1
        : 1;
    final nextBadges = {...state.badges};
    if (state.progress.isEmpty) {
      nextBadges.add('첫걸음');
    }
    if (state.totalXp + xp >= 100) {
      nextBadges.add('100 XP');
    }
    if (next.correctCount >= 3) {
      nextBadges.add('꾸준한 복습');
    }

    state = state.copyWith(
      progress: {...state.progress, item.id: next},
      totalXp: state.totalXp + xp,
      dailyXp: isSameDay ? state.dailyXp + xp : xp,
      streakDays: nextStreak,
      badges: nextBadges,
      lastStudyDate: studiedDay,
    );
    unawaited(
      _store.saveStudyEvent(
        StudyEventEntry(
          eventId:
              '${studiedAt.toUtc().microsecondsSinceEpoch}-${item.id}-${next.attempts}',
          courseId: item.learningLanguage.courseId,
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
  }) {
    final session = ActiveStudySession.started(
      sessionId: sessionId,
      courseId: state.selectedLanguage.courseId,
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
  }) {
    final current = state.activeStudySession;
    if (current == null) return null;
    final next = current.copyWith(
      itemIds: List.unmodifiable(itemIds),
      wrongItemIds: Set.unmodifiable(wrongItemIds),
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
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    int? earnedXp,
  }) {
    final current = state.activeStudySession;
    if (current == null) return null;
    final updated = current.copyWith(
      itemIds: itemIds,
      wrongItemIds: wrongItemIds,
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

  ActiveStudySession? resumeActiveStudySession(DateTime occurredAt) {
    final current = state.activeStudySession;
    if (current == null) return null;
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
      await queueSyncSnapshot();
    }());
  }

  void clearActiveStudySession({DateTime? clearedAt}) {
    final changedAt = clearedAt ?? DateTime.now();
    state = state.copyWith(
      activeStudySession: null,
      activeSessionChangedAt: changedAt,
    );
    unawaited(() async {
      await _store.clearActiveStudySession(changedAt);
      await queueSyncSnapshot();
    }());
  }

  Future<void> finishSession(StudySessionSummary session) async {
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
    final existingByContentKey = {
      for (final item in state.customItems)
        _contentValidator.duplicateKey(item): item,
    };
    final toSave = <LearningItem>[];
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
        continue;
      }

      final expectedId = resolution.expectedExistingId;
      final current = expectedId == null ? null : existing[expectedId];
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
      existingByContentKey[_contentValidator.duplicateKey(versioned)] =
          versioned;
      toSave.add(versioned);
    }
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
    state = state.copyWith(
      customItems: existing.values.toList(growable: false),
      customItemTombstones: tombstones,
    );
    if (toSave.isNotEmpty) await queueSyncSnapshot();
    return result;
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
    await queueSyncSnapshot();
  }

  Future<void> deleteCustomItem(String itemId) async {
    final deletedAt = DateTime.now().toUtc();
    await _store.deleteCustomItem(itemId);
    if (!mounted) return;
    final excluded = {...state.preferences.excludedItemIds}..remove(itemId);
    final favorites = {...state.preferences.favoriteItemIds}..remove(itemId);
    final tombstones = {...state.customItemTombstones, itemId: deletedAt};
    await _store.saveCustomItemTombstones(tombstones);
    state = state.copyWith(
      customItems: state.customItems
          .where((item) => item.id != itemId)
          .toList(growable: false),
      customItemTombstones: tombstones,
      preferences: state.preferences.copyWith(
        excludedItemIds: excluded,
        favoriteItemIds: favorites,
      ),
    );
    await _store.savePreferences(state.preferences);
    await queueSyncSnapshot();
  }

  LearningItem? customItemById(String itemId) {
    for (final item in state.customItems) {
      if (item.id == itemId) return item;
    }
    return null;
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

  Map<String, Object?> exportArchive() => {
    ...exportSyncSnapshot(),
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'sessions': [for (final session in state.recentSessions) session.toJson()],
  };

  Map<String, Object?> exportSyncSnapshot() {
    return {
      'schemaVersion': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': {
        'selectedLanguage': state.selectedLanguage.code,
        'totalXp': state.totalXp,
        'streakDays': state.streakDays,
        'dailyXp': state.dailyXp,
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
    Map<String, Object?>? remote,
  ) async {
    if (remote == null) return exportSyncSnapshot();
    _snapshotValidator.validate(remote);
    final schemaVersion = (remote['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion > 1) {
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
    final mergedProgress = <String, ProgressRecord>{...state.progress};
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
    final localActiveStudy = StoredActiveStudyState(
      session: state.activeStudySession,
      changedAt: state.activeSessionChangedAt,
    );
    final remoteActiveStudy = _activeStudyStateFromJson(remote['activeStudy']);
    final mergedActiveStudy = _mergeActiveStudyState(
      localActiveStudy,
      remoteActiveStudy,
    );

    final rawProfile = remote['profile'];
    final remoteProfile = rawProfile is Map
        ? Map<String, Object?>.from(rawProfile)
        : const <String, Object?>{};
    final remoteBadges =
        ((remoteProfile['badges'] as List<Object?>?) ?? const [])
            .whereType<String>();
    final remoteLastStudyDate = _optionalDate(remoteProfile['lastStudyDate']);
    final rawSettings = remote['settings'];
    final remotePreferences = rawSettings is Map
        ? StudyPreferences.fromJson(Map<String, Object?>.from(rawSettings))
        : state.preferences;
    final combinedPreferences = remotePreferences.copyWith(
      excludedItemIds: {
        ...remotePreferences.excludedItemIds,
        ...state.preferences.excludedItemIds,
      },
      favoriteItemIds: {
        ...remotePreferences.favoriteItemIds,
        ...state.preferences.favoriteItemIds,
      },
      completedMissionIds: {
        ...remotePreferences.completedMissionIds,
        ...state.preferences.completedMissionIds,
      },
      sessionPlan: _newerSessionPlan(
        remotePreferences.sessionPlan,
        state.preferences.sessionPlan,
      ),
    );
    final deletedItemIds = mergedContent.tombstones.keys.toSet();
    final mergedPreferences = combinedPreferences.copyWith(
      excludedItemIds: {...combinedPreferences.excludedItemIds}
        ..removeAll(deletedItemIds),
      favoriteItemIds: {...combinedPreferences.favoriteItemIds}
        ..removeAll(deletedItemIds),
    );
    final mergedLastStudyDate =
        remoteLastStudyDate != null &&
            (state.lastStudyDate == null ||
                remoteLastStudyDate.isAfter(state.lastStudyDate!))
        ? remoteLastStudyDate
        : state.lastStudyDate;
    final nextState = state.copyWith(
      progress: mergedProgress,
      totalXp: _maxInt(
        state.totalXp,
        (remoteProfile['totalXp'] as num?)?.toInt() ?? 0,
      ),
      streakDays: _maxInt(
        state.streakDays,
        (remoteProfile['streakDays'] as num?)?.toInt() ?? 0,
      ),
      dailyXp: _maxInt(
        state.dailyXp,
        (remoteProfile['dailyXp'] as num?)?.toInt() ?? 0,
      ),
      badges: {...state.badges, ...remoteBadges},
      driveConnected: true,
      customItems: mergedContent.items,
      customItemTombstones: mergedContent.tombstones,
      preferences: mergedPreferences,
      activeStudySession: mergedActiveStudy.session,
      activeSessionChangedAt: mergedActiveStudy.changedAt,
      lastStudyDate: mergedLastStudyDate,
    );
    await _store.saveProfile(
      StoredProfile(
        selectedLanguage: nextState.selectedLanguage,
        totalXp: nextState.totalXp,
        streakDays: nextState.streakDays,
        dailyXp: nextState.dailyXp,
        badges: nextState.badges,
        driveConnected: true,
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
    if (mergedActiveStudy.changedAt case final changedAt?) {
      if (mergedActiveStudy.session case final session?) {
        await _store.saveActiveStudySession(session);
      } else {
        await _store.clearActiveStudySession(changedAt);
      }
    }
    if (mounted) state = nextState;
    return exportSyncSnapshot();
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
  const _MergedCustomContent({required this.items, required this.tombstones});

  final List<LearningItem> items;
  final Map<String, DateTime> tombstones;
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
  final items = <LearningItem>[];
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
      final localChangedAt = localItem.updatedAt ?? epoch;
      final remoteChangedAt = remoteItem.updatedAt ?? epoch;
      final comparison = localChangedAt.compareTo(remoteChangedAt);
      if (comparison > 0) {
        selectedItem = localItem;
      } else if (comparison < 0) {
        selectedItem = remoteItem;
      } else {
        final versionComparison = localItem.source.contentVersion.compareTo(
          remoteItem.source.contentVersion,
        );
        if (versionComparison != 0) {
          selectedItem = versionComparison > 0 ? localItem : remoteItem;
        } else {
          final localSignature = jsonEncode(itemCodec.toJson(localItem));
          final remoteSignature = jsonEncode(itemCodec.toJson(remoteItem));
          selectedItem = localSignature.compareTo(remoteSignature) >= 0
              ? localItem
              : remoteItem;
        }
      }
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
    } else if (selectedItem != null) {
      items.add(selectedItem);
    }
  }

  return _MergedCustomContent(
    items: List.unmodifiable(items),
    tombstones: Map.unmodifiable(tombstones),
  );
}

int _maxInt(int left, int right) => left >= right ? left : right;

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
  return AppController(ref.watch(studyStoreProvider));
});
