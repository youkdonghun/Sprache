import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/content_validation.dart';
import '../domain/device_preferences.dart';
import '../domain/exam_library.dart';
import '../domain/item_editor_draft.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/active_study_session.dart';
import '../domain/local_storage.dart';
import '../domain/progress.dart';
import '../domain/quick_content_draft.dart';
import '../domain/quick_content_preferences.dart';
import '../domain/search_preferences.dart';
import '../domain/study_history.dart';
import '../domain/study_preferences.dart';
import '../import/import_review_draft.dart';
import '../sync/pending_sync.dart';
import '../sync/sync_policy.dart';
import 'database/app_database.dart';

String _itemEditorDraftScope(String? itemId) => itemId ?? '__new_item__';

String _itemEditorDraftStorageKey(String? itemId) {
  final encoded = base64Url
      .encode(utf8.encode(_itemEditorDraftScope(itemId)))
      .replaceAll('=', '');
  return 'item_editor_draft_v2:$encoded';
}

String _quickContentDraftStorageKey(String subjectId) {
  final encoded = base64Url.encode(utf8.encode(subjectId)).replaceAll('=', '');
  return 'quick_content_draft_v2:$encoded';
}

Map<String, QuickContentDraft> _initialQuickContentDrafts(
  QuickContentDraft? draft,
) => draft == null ? {} : {draft.subjectId: draft};

Map<String, ItemEditorDraft> _initialItemEditorDrafts(ItemEditorDraft? draft) =>
    draft == null ? {} : {_itemEditorDraftScope(draft.itemId): draft};

class StoredProfile {
  const StoredProfile({
    required this.selectedLanguage,
    required this.totalXp,
    required this.streakDays,
    required this.dailyXp,
    required this.badges,
    required this.driveConnected,
    required this.progress,
    this.dailyXpByCourse = const {},
    this.dailyXpByCourseAndReplica = const {},
    this.replicaId = '',
    this.xpByReplica = const {},
    this.lastStudyDate,
  });

  factory StoredProfile.empty({String? replicaId}) => StoredProfile(
    selectedLanguage: LanguageTag.english,
    totalXp: 0,
    streakDays: 0,
    dailyXp: 0,
    badges: const {},
    driveConnected: false,
    progress: const {},
    dailyXpByCourse: const {},
    dailyXpByCourseAndReplica: const {},
    replicaId: replicaId ?? _newReplicaId(),
    xpByReplica: const {},
    lastStudyDate: null,
  );

  final LanguageTag selectedLanguage;
  final int totalXp;
  final int streakDays;
  final int dailyXp;
  final Map<String, int> dailyXpByCourse;
  final Map<String, Map<String, int>> dailyXpByCourseAndReplica;
  final String replicaId;
  final Map<String, int> xpByReplica;
  final Set<String> badges;
  final bool driveConnected;
  final Map<String, ProgressRecord> progress;
  final DateTime? lastStudyDate;
}

class StoredActiveStudyState {
  const StoredActiveStudyState({this.session, this.changedAt});

  final ActiveStudySession? session;
  final DateTime? changedAt;

  bool get hasChange => changedAt != null;
}

class ImportCommitRecord {
  const ImportCommitRecord({
    required this.importId,
    required this.fileName,
    required this.sha256,
    required this.importedRows,
    required this.rejectedRows,
    required this.importedAt,
  });

  final String importId;
  final String fileName;
  final String sha256;
  final int importedRows;
  final int rejectedRows;
  final DateTime importedAt;
}

abstract interface class StudyStore {
  Future<StoredProfile> loadProfile();

  Future<void> saveProfile(StoredProfile profile);

  Future<StudyPreferences> loadPreferences();

  Future<void> savePreferences(StudyPreferences preferences);

  Future<LocalStorageSettings> loadLocalStorageSettings();

  Future<void> saveLocalStorageSettings(LocalStorageSettings settings);

  Future<SyncDeviceSettings> loadSyncDeviceSettings();

  Future<void> saveSyncDeviceSettings(SyncDeviceSettings settings);

  Future<QuickContentDraft?> loadQuickContentDraft({required String subjectId});

  Future<void> saveQuickContentDraft(QuickContentDraft draft);

  Future<void> clearQuickContentDraft({required String subjectId});

  Future<ItemEditorDraft?> loadItemEditorDraft({String? itemId});

  Future<void> saveItemEditorDraft(ItemEditorDraft draft);

  Future<void> clearItemEditorDraft({String? itemId});

  Future<QuickContentLocalPreferences> loadQuickContentLocalPreferences();

  Future<void> saveQuickContentLocalPreferences(
    QuickContentLocalPreferences preferences,
  );

  Future<SearchLocalPreferences> loadSearchLocalPreferences();

  Future<void> saveSearchLocalPreferences(SearchLocalPreferences preferences);

  Future<DevicePreferences> loadDevicePreferences();

  Future<void> saveDevicePreferences(DevicePreferences preferences);

  Future<ExamLibrary> loadExamLibrary();

  Future<void> saveExamLibrary(ExamLibrary library);

  Future<ImportReviewDraft?> loadImportReviewDraft();

  Future<void> saveImportReviewDraft(ImportReviewDraft draft);

  Future<void> clearImportReviewDraft();

  Future<List<LearningItem>> loadCustomItems();

  Future<void> saveCustomItems(Iterable<LearningItem> items);

  Future<void> replaceCustomContent({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
  });

  Future<void> replaceProgress(Map<String, ProgressRecord> progress);

  Future<void> commitCustomItemImport({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
    ImportCommitRecord? record,
  });

  Future<ImportCommitRecord?> findImportBySha256(String sha256);

  Future<Map<String, DateTime>> loadCustomItemTombstones();

  Future<void> saveCustomItemTombstones(Map<String, DateTime> tombstones);

  Future<void> deleteCustomItem(String itemId);

  Future<void> saveStudyEvent(StudyEventEntry event);

  Future<void> saveStudySession(StudySessionSummary session);

  Future<void> replaceStudySessions(Iterable<StudySessionSummary> sessions);

  Future<List<StudySessionSummary>> loadRecentSessions({int limit = 20});

  Future<StoredActiveStudyState> loadActiveStudyState();

  Future<void> saveActiveStudySession(ActiveStudySession session);

  Future<void> clearActiveStudySession(DateTime clearedAt);

  Future<void> replaceActiveStudyState(StoredActiveStudyState activeStudy);

  Future<PendingSyncOperation?> loadPendingSnapshotSync();

  Future<void> replacePendingSnapshotSync(PendingSyncOperation operation);

  Future<void> updatePendingSync(PendingSyncOperation operation);

  Future<void> deletePendingSync(String operationId);
}

class MemoryStudyStore implements StudyStore {
  MemoryStudyStore({
    StoredProfile? profile,
    StudyPreferences? preferences,
    ActiveStudySession? activeStudySession,
    DateTime? activeStudySessionClearedAt,
    PendingSyncOperation? pendingSnapshotSync,
    LocalStorageSettings? localStorageSettings,
    SyncDeviceSettings? syncDeviceSettings,
    QuickContentDraft? quickContentDraft,
    ItemEditorDraft? itemEditorDraft,
    QuickContentLocalPreferences? quickContentLocalPreferences,
    SearchLocalPreferences? searchLocalPreferences,
    DevicePreferences? devicePreferences,
    ExamLibrary? examLibrary,
    ImportReviewDraft? importReviewDraft,
    String? replicaId,
  }) : _profile = _profileWithReplicaId(profile, replicaId),
       _preferences = preferences ?? const StudyPreferences(),
       // The public constructor name is intentionally clearer for tests/callers.
       // ignore: prefer_initializing_formals
       _activeStudyState = StoredActiveStudyState(
         session: activeStudySession,
         changedAt:
             activeStudySession?.updatedAt ?? activeStudySessionClearedAt,
       ),
       // The public constructor name is intentionally clearer for tests/callers.
       // ignore: prefer_initializing_formals
       _pendingSnapshotSync = pendingSnapshotSync,
       _localStorageSettings =
           localStorageSettings ?? const LocalStorageSettings(),
       _syncDeviceSettings = syncDeviceSettings ?? const SyncDeviceSettings(),
       // The public constructor name is intentionally clearer for tests/callers.
       // ignore: prefer_initializing_formals
       _quickContentDrafts = _initialQuickContentDrafts(quickContentDraft),
       // The public constructor name is intentionally clearer for tests/callers.
       // ignore: prefer_initializing_formals
       _itemEditorDrafts = _initialItemEditorDrafts(itemEditorDraft),
       _quickContentLocalPreferences =
           quickContentLocalPreferences ?? const QuickContentLocalPreferences(),
       _searchLocalPreferences =
           searchLocalPreferences ?? const SearchLocalPreferences(),
       _devicePreferences = devicePreferences ?? const DevicePreferences(),
       _examLibrary = examLibrary ?? const ExamLibrary(),
       // The public constructor name is intentionally clearer for tests/callers.
       // ignore: prefer_initializing_formals
       _importReviewDraft = importReviewDraft;

  StoredProfile _profile;
  StudyPreferences _preferences;
  StoredActiveStudyState _activeStudyState;
  final _items = <String, LearningItem>{};
  final _itemTombstones = <String, DateTime>{};
  final _events = <String, StudyEventEntry>{};
  final _sessions = <String, StudySessionSummary>{};
  final _imports = <String, ImportCommitRecord>{};
  PendingSyncOperation? _pendingSnapshotSync;
  LocalStorageSettings _localStorageSettings;
  SyncDeviceSettings _syncDeviceSettings;
  final Map<String, QuickContentDraft> _quickContentDrafts;
  final Map<String, ItemEditorDraft> _itemEditorDrafts;
  Future<void> _quickContentDraftWriteTail = Future<void>.value();
  Future<void> _itemEditorDraftWriteTail = Future<void>.value();
  QuickContentLocalPreferences _quickContentLocalPreferences;
  SearchLocalPreferences _searchLocalPreferences;
  DevicePreferences _devicePreferences;
  ExamLibrary _examLibrary;
  ImportReviewDraft? _importReviewDraft;

  List<StudyEventEntry> get savedEvents => List.unmodifiable(_events.values);

  List<StudySessionSummary> get savedSessions =>
      List.unmodifiable(_sessions.values);

  List<LearningItem> get savedItems => List.unmodifiable(_items.values);

  Map<String, DateTime> get savedItemTombstones =>
      Map.unmodifiable(_itemTombstones);

  StudyPreferences get savedPreferences => _preferences;

  ActiveStudySession? get savedActiveStudySession => _activeStudyState.session;

  DateTime? get activeStudySessionChangedAt => _activeStudyState.changedAt;

  PendingSyncOperation? get pendingSnapshotSync => _pendingSnapshotSync;

  List<ImportCommitRecord> get savedImports =>
      List.unmodifiable(_imports.values);

  @override
  Future<StoredProfile> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(StoredProfile profile) async {
    _profile = profile;
  }

  @override
  Future<StudyPreferences> loadPreferences() async => _preferences;

  @override
  Future<void> savePreferences(StudyPreferences preferences) async {
    _preferences = preferences;
  }

  @override
  Future<LocalStorageSettings> loadLocalStorageSettings() async =>
      _localStorageSettings;

  @override
  Future<void> saveLocalStorageSettings(LocalStorageSettings settings) async {
    _localStorageSettings = settings;
  }

  @override
  Future<SyncDeviceSettings> loadSyncDeviceSettings() async =>
      _syncDeviceSettings;

  @override
  Future<void> saveSyncDeviceSettings(SyncDeviceSettings settings) async {
    _syncDeviceSettings = settings;
  }

  @override
  Future<QuickContentDraft?> loadQuickContentDraft({
    required String subjectId,
  }) async {
    try {
      await _quickContentDraftWriteTail;
    } on Object {
      // A later read must still be possible after a best-effort write fails.
    }
    return _quickContentDrafts[subjectId];
  }

  @override
  Future<void> saveQuickContentDraft(QuickContentDraft draft) =>
      _enqueueQuickContentDraftWrite(
        () async => _quickContentDrafts[draft.subjectId] = draft,
      );

  @override
  Future<void> clearQuickContentDraft({required String subjectId}) =>
      _enqueueQuickContentDraftWrite(
        () async => _quickContentDrafts.remove(subjectId),
      );

  @override
  Future<ItemEditorDraft?> loadItemEditorDraft({String? itemId}) async {
    try {
      await _itemEditorDraftWriteTail;
    } on Object {
      // A later read must still be possible after a best-effort write fails.
    }
    return _itemEditorDrafts[_itemEditorDraftScope(itemId)];
  }

  @override
  Future<void> saveItemEditorDraft(ItemEditorDraft draft) =>
      _enqueueItemEditorDraftWrite(
        () async =>
            _itemEditorDrafts[_itemEditorDraftScope(draft.itemId)] = draft,
      );

  @override
  Future<void> clearItemEditorDraft({String? itemId}) =>
      _enqueueItemEditorDraftWrite(
        () async => _itemEditorDrafts.remove(_itemEditorDraftScope(itemId)),
      );

  Future<void> _enqueueQuickContentDraftWrite(
    Future<void> Function() operation,
  ) {
    final previous = _quickContentDraftWriteTail;
    final next = () async {
      try {
        await previous;
      } on Object {
        // Keep the queue usable after a failed best-effort write.
      }
      await operation();
    }();
    _quickContentDraftWriteTail = next;
    return next;
  }

  Future<void> _enqueueItemEditorDraftWrite(Future<void> Function() operation) {
    final previous = _itemEditorDraftWriteTail;
    final next = () async {
      try {
        await previous;
      } on Object {
        // Keep the queue usable after a failed best-effort write.
      }
      await operation();
    }();
    _itemEditorDraftWriteTail = next;
    return next;
  }

  @override
  Future<QuickContentLocalPreferences>
  loadQuickContentLocalPreferences() async => _quickContentLocalPreferences;

  @override
  Future<void> saveQuickContentLocalPreferences(
    QuickContentLocalPreferences preferences,
  ) async {
    _quickContentLocalPreferences = preferences;
  }

  @override
  Future<SearchLocalPreferences> loadSearchLocalPreferences() async =>
      _searchLocalPreferences;

  @override
  Future<void> saveSearchLocalPreferences(
    SearchLocalPreferences preferences,
  ) async {
    _searchLocalPreferences = preferences;
  }

  @override
  Future<DevicePreferences> loadDevicePreferences() async => _devicePreferences;

  @override
  Future<void> saveDevicePreferences(DevicePreferences preferences) async {
    _devicePreferences = preferences;
  }

  @override
  Future<ExamLibrary> loadExamLibrary() async => _examLibrary;

  @override
  Future<void> saveExamLibrary(ExamLibrary library) async {
    _examLibrary = library;
  }

  @override
  Future<ImportReviewDraft?> loadImportReviewDraft() async =>
      _importReviewDraft;

  @override
  Future<void> saveImportReviewDraft(ImportReviewDraft draft) async {
    _importReviewDraft = draft;
  }

  @override
  Future<void> clearImportReviewDraft() async {
    _importReviewDraft = null;
  }

  @override
  Future<List<LearningItem>> loadCustomItems() async => _items.values.toList();

  @override
  Future<void> saveCustomItems(Iterable<LearningItem> items) async {
    for (final item in items) {
      _items[item.id] = item;
      _itemTombstones.remove(item.id);
    }
  }

  @override
  Future<void> replaceCustomContent({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
  }) async {
    _items
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item)));
    _itemTombstones
      ..clear()
      ..addAll(tombstones);
  }

  @override
  Future<void> replaceProgress(Map<String, ProgressRecord> progress) async {
    _profile = StoredProfile(
      selectedLanguage: _profile.selectedLanguage,
      totalXp: _profile.totalXp,
      streakDays: _profile.streakDays,
      dailyXp: _profile.dailyXp,
      badges: _profile.badges,
      driveConnected: _profile.driveConnected,
      progress: Map.unmodifiable(progress),
      dailyXpByCourse: _profile.dailyXpByCourse,
      dailyXpByCourseAndReplica: _profile.dailyXpByCourseAndReplica,
      replicaId: _profile.replicaId,
      xpByReplica: _profile.xpByReplica,
      lastStudyDate: _profile.lastStudyDate,
    );
  }

  @override
  Future<void> commitCustomItemImport({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
    ImportCommitRecord? record,
  }) async {
    final validatedItems = [
      for (final item in items)
        const LearningContentValidator().ensureValid(item),
    ];
    final nextItems = {..._items};
    final nextTombstones = {...tombstones};
    final nextImports = {..._imports};
    for (final item in validatedItems) {
      nextItems[item.id] = item;
      nextTombstones.remove(item.id);
    }
    if (record != null) nextImports[record.importId] = record;

    _items
      ..clear()
      ..addAll(nextItems);
    _itemTombstones
      ..clear()
      ..addAll(nextTombstones);
    _imports
      ..clear()
      ..addAll(nextImports);
  }

  @override
  Future<ImportCommitRecord?> findImportBySha256(String sha256) async {
    final matches =
        _imports.values.where((record) => record.sha256 == sha256).toList()
          ..sort((left, right) => right.importedAt.compareTo(left.importedAt));
    return matches.firstOrNull;
  }

  @override
  Future<Map<String, DateTime>> loadCustomItemTombstones() async =>
      Map.unmodifiable(_itemTombstones);

  @override
  Future<void> saveCustomItemTombstones(
    Map<String, DateTime> tombstones,
  ) async {
    _itemTombstones
      ..clear()
      ..addAll(tombstones);
  }

  @override
  Future<void> deleteCustomItem(String itemId) async {
    _items.remove(itemId);
    _itemTombstones[itemId] = DateTime.now().toUtc();
  }

  @override
  Future<void> saveStudyEvent(StudyEventEntry event) async {
    _events[event.eventId] = event;
  }

  @override
  Future<void> saveStudySession(StudySessionSummary session) async {
    _sessions[session.sessionId] = session;
  }

  @override
  Future<void> replaceStudySessions(
    Iterable<StudySessionSummary> sessions,
  ) async {
    _sessions
      ..clear()
      ..addEntries(
        sessions.map((session) => MapEntry(session.sessionId, session)),
      );
  }

  @override
  Future<List<StudySessionSummary>> loadRecentSessions({int limit = 20}) async {
    final values = _sessions.values.toList()
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return values.take(limit).toList(growable: false);
  }

  @override
  Future<StoredActiveStudyState> loadActiveStudyState() async =>
      _activeStudyState;

  @override
  Future<void> saveActiveStudySession(ActiveStudySession session) async {
    _activeStudyState = StoredActiveStudyState(
      session: session,
      changedAt: session.updatedAt,
    );
  }

  @override
  Future<void> clearActiveStudySession(DateTime clearedAt) async {
    _activeStudyState = StoredActiveStudyState(changedAt: clearedAt);
  }

  @override
  Future<void> replaceActiveStudyState(
    StoredActiveStudyState activeStudy,
  ) async {
    _activeStudyState = activeStudy;
  }

  @override
  Future<PendingSyncOperation?> loadPendingSnapshotSync() async =>
      _pendingSnapshotSync;

  @override
  Future<void> replacePendingSnapshotSync(
    PendingSyncOperation operation,
  ) async {
    _pendingSnapshotSync = operation;
  }

  @override
  Future<void> updatePendingSync(PendingSyncOperation operation) async {
    if (_pendingSnapshotSync?.operationId == operation.operationId) {
      _pendingSnapshotSync = operation;
    }
  }

  @override
  Future<void> deletePendingSync(String operationId) async {
    if (_pendingSnapshotSync?.operationId == operationId) {
      _pendingSnapshotSync = null;
    }
  }
}

StoredProfile _profileWithReplicaId(
  StoredProfile? profile,
  String? requestedReplicaId,
) {
  if (profile == null) {
    return StoredProfile.empty(replicaId: requestedReplicaId);
  }
  if (_safeReplicaId(profile.replicaId) != null) return profile;
  return StoredProfile(
    selectedLanguage: profile.selectedLanguage,
    totalXp: profile.totalXp,
    streakDays: profile.streakDays,
    dailyXp: profile.dailyXp,
    badges: profile.badges,
    driveConnected: profile.driveConnected,
    progress: profile.progress,
    dailyXpByCourse: profile.dailyXpByCourse,
    dailyXpByCourseAndReplica: profile.dailyXpByCourseAndReplica,
    replicaId: _safeReplicaId(requestedReplicaId) ?? _newReplicaId(),
    xpByReplica: profile.xpByReplica,
    lastStudyDate: profile.lastStudyDate,
  );
}

class DriftStudyStore implements StudyStore {
  DriftStudyStore(this.database);

  final AppDatabase database;
  Future<void> _quickContentDraftWriteTail = Future<void>.value();
  Future<void> _itemEditorDraftWriteTail = Future<void>.value();

  @override
  Future<StoredProfile> loadProfile() async {
    final setting = await (database.select(
      database.appSettings,
    )..where((table) => table.key.equals('profile'))).getSingleOrNull();
    final progressRows = await database.select(database.progressRows).get();
    final profileJson = setting == null
        ? const <String, Object?>{}
        : jsonDecode(setting.valueJson) as Map<String, Object?>;
    final selectedCode = profileJson['selectedLanguage'] as String? ?? 'en';
    final selectedLanguage = LanguageTag.values.firstWhere(
      (language) => language.code == selectedCode,
      orElse: () => LanguageTag.english,
    );

    return StoredProfile(
      selectedLanguage: selectedLanguage,
      totalXp: profileJson['totalXp'] as int? ?? 0,
      streakDays: profileJson['streakDays'] as int? ?? 0,
      dailyXp: profileJson['dailyXp'] as int? ?? 0,
      dailyXpByCourse: _safeXpMap(profileJson['dailyXpByCourse']),
      dailyXpByCourseAndReplica: _safeDailyXpLedger(
        profileJson['dailyXpByCourseAndReplica'],
      ),
      replicaId: _safeReplicaId(profileJson['replicaId']) ?? _newReplicaId(),
      xpByReplica: _safeXpLedger(profileJson['xpByReplica']),
      badges: ((profileJson['badges'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toSet(),
      driveConnected: profileJson['driveConnected'] as bool? ?? false,
      lastStudyDate: switch (profileJson['lastStudyDate']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
      progress: {
        for (final row in progressRows)
          row.itemId: ProgressRecord(
            itemId: row.itemId,
            status: LearningStatus.values.byName(row.status),
            correctCount: row.correctCount,
            wrongCount: row.wrongCount,
            lapseCount: row.lapseCount,
            currentIntervalDays: row.currentIntervalDays,
            nextReviewAt: row.nextReviewAt,
            lastStudiedAt: row.lastStudiedAt,
            lastResult: row.lastResult == null
                ? null
                : ReviewRating.values.byName(row.lastResult!),
          ),
      },
    );
  }

  @override
  Future<void> saveProfile(StoredProfile profile) async {
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: 'profile',
              valueJson: jsonEncode({
                'selectedLanguage': profile.selectedLanguage.code,
                'totalXp': profile.totalXp,
                'streakDays': profile.streakDays,
                'dailyXp': profile.dailyXp,
                'dailyXpByCourse': {
                  for (final entry
                      in (profile.dailyXpByCourse.entries.toList()
                        ..sort((left, right) => left.key.compareTo(right.key))))
                    entry.key: entry.value,
                },
                'dailyXpByCourseAndReplica': {
                  for (final courseEntry
                      in (profile.dailyXpByCourseAndReplica.entries.toList()
                        ..sort((left, right) => left.key.compareTo(right.key))))
                    courseEntry.key: {
                      for (final replicaEntry
                          in (courseEntry.value.entries.toList()..sort(
                            (left, right) => left.key.compareTo(right.key),
                          )))
                        replicaEntry.key: replicaEntry.value,
                    },
                },
                'replicaId': profile.replicaId,
                'xpByReplica': {
                  for (final entry
                      in (profile.xpByReplica.entries.toList()
                        ..sort((left, right) => left.key.compareTo(right.key))))
                    entry.key: entry.value,
                },
                'badges': profile.badges.toList()..sort(),
                'driveConnected': profile.driveConnected,
                'lastStudyDate': profile.lastStudyDate?.toIso8601String(),
              }),
              updatedAt: now,
            ),
          );

      for (final record in profile.progress.values) {
        await database
            .into(database.progressRows)
            .insertOnConflictUpdate(
              ProgressRowsCompanion.insert(
                courseId: profile.selectedLanguage.courseId,
                itemId: record.itemId,
                status: record.status.name,
                correctCount: Value(record.correctCount),
                wrongCount: Value(record.wrongCount),
                lapseCount: Value(record.lapseCount),
                currentIntervalDays: Value(record.currentIntervalDays),
                nextReviewAt: Value(record.nextReviewAt),
                lastStudiedAt: Value(record.lastStudiedAt),
                lastResult: Value(record.lastResult?.name),
                deviceId: 'local-device',
                updatedAt: now,
              ),
            );
      }
    });
  }

  @override
  Future<void> replaceProgress(Map<String, ProgressRecord> progress) async {
    final profile = await loadProfile();
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      await database.delete(database.progressRows).go();
      for (final record in progress.values) {
        await database
            .into(database.progressRows)
            .insert(
              ProgressRowsCompanion.insert(
                courseId: profile.selectedLanguage.courseId,
                itemId: record.itemId,
                status: record.status.name,
                correctCount: Value(record.correctCount),
                wrongCount: Value(record.wrongCount),
                lapseCount: Value(record.lapseCount),
                currentIntervalDays: Value(record.currentIntervalDays),
                nextReviewAt: Value(record.nextReviewAt),
                lastStudiedAt: Value(record.lastStudiedAt),
                lastResult: Value(record.lastResult?.name),
                deviceId: 'local-device',
                updatedAt: now,
              ),
            );
      }
    });
  }

  @override
  Future<StudyPreferences> loadPreferences() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('study_preferences')))
            .getSingleOrNull();
    if (setting == null) return const StudyPreferences();
    try {
      return StudyPreferences.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } on FormatException {
      return const StudyPreferences();
    }
  }

  @override
  Future<void> savePreferences(StudyPreferences preferences) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'study_preferences',
            valueJson: jsonEncode(preferences.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<LocalStorageSettings> loadLocalStorageSettings() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('local_storage_settings')))
            .getSingleOrNull();
    if (setting == null) return const LocalStorageSettings();
    try {
      return LocalStorageSettings.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return const LocalStorageSettings();
    }
  }

  @override
  Future<void> saveLocalStorageSettings(LocalStorageSettings settings) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'local_storage_settings',
            valueJson: jsonEncode(settings.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<SyncDeviceSettings> loadSyncDeviceSettings() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('sync_device_settings')))
            .getSingleOrNull();
    if (setting == null) return const SyncDeviceSettings();
    try {
      return SyncDeviceSettings.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return const SyncDeviceSettings();
    }
  }

  @override
  Future<void> saveSyncDeviceSettings(SyncDeviceSettings settings) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'sync_device_settings',
            valueJson: jsonEncode(settings.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<QuickContentDraft?> loadQuickContentDraft({
    required String subjectId,
  }) async {
    try {
      await _quickContentDraftWriteTail;
    } on Object {
      // Recovery writes are best-effort; a failed write cannot poison reads.
    }
    final key = _quickContentDraftStorageKey(subjectId);
    var setting = await (database.select(
      database.appSettings,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    setting ??=
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('quick_content_draft')))
            .getSingleOrNull();
    if (setting == null) return null;
    try {
      final draft = QuickContentDraft.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
      if (draft.subjectId != subjectId) return null;
      if (setting.key == 'quick_content_draft') {
        await saveQuickContentDraft(draft);
        await (database.delete(
          database.appSettings,
        )..where((table) => table.key.equals('quick_content_draft'))).go();
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveQuickContentDraft(QuickContentDraft draft) =>
      _enqueueQuickContentDraftWrite(() async {
        await database
            .into(database.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                key: _quickContentDraftStorageKey(draft.subjectId),
                valueJson: jsonEncode(draft.toJson()),
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      });

  @override
  Future<void> clearQuickContentDraft({required String subjectId}) =>
      _enqueueQuickContentDraftWrite(() async {
        await (database.delete(database.appSettings)..where(
              (table) =>
                  table.key.equals(_quickContentDraftStorageKey(subjectId)),
            ))
            .go();
      });

  @override
  Future<ItemEditorDraft?> loadItemEditorDraft({String? itemId}) async {
    try {
      await _itemEditorDraftWriteTail;
    } on Object {
      // Recovery writes are best-effort; a failed write cannot poison reads.
    }
    final key = _itemEditorDraftStorageKey(itemId);
    var setting = await (database.select(
      database.appSettings,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    setting ??=
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('item_editor_draft')))
            .getSingleOrNull();
    if (setting == null) return null;
    try {
      final draft = ItemEditorDraft.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
      if (draft.itemId != itemId) return null;
      if (setting.key == 'item_editor_draft') {
        await saveItemEditorDraft(draft);
        await (database.delete(
          database.appSettings,
        )..where((table) => table.key.equals('item_editor_draft'))).go();
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveItemEditorDraft(ItemEditorDraft draft) =>
      _enqueueItemEditorDraftWrite(() async {
        await database
            .into(database.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                key: _itemEditorDraftStorageKey(draft.itemId),
                valueJson: jsonEncode(draft.toJson()),
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      });

  @override
  Future<void> clearItemEditorDraft({String? itemId}) =>
      _enqueueItemEditorDraftWrite(() async {
        await (database.delete(database.appSettings)..where(
              (table) => table.key.equals(_itemEditorDraftStorageKey(itemId)),
            ))
            .go();
      });

  Future<void> _enqueueQuickContentDraftWrite(
    Future<void> Function() operation,
  ) {
    final previous = _quickContentDraftWriteTail;
    final next = () async {
      try {
        await previous;
      } on Object {
        // Keep the queue usable after a failed best-effort write.
      }
      await operation();
    }();
    _quickContentDraftWriteTail = next;
    return next;
  }

  Future<void> _enqueueItemEditorDraftWrite(Future<void> Function() operation) {
    final previous = _itemEditorDraftWriteTail;
    final next = () async {
      try {
        await previous;
      } on Object {
        // Keep the queue usable after a failed best-effort write.
      }
      await operation();
    }();
    _itemEditorDraftWriteTail = next;
    return next;
  }

  @override
  Future<QuickContentLocalPreferences>
  loadQuickContentLocalPreferences() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('quick_content_preferences')))
            .getSingleOrNull();
    if (setting == null) return const QuickContentLocalPreferences();
    try {
      return QuickContentLocalPreferences.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return const QuickContentLocalPreferences();
    }
  }

  @override
  Future<void> saveQuickContentLocalPreferences(
    QuickContentLocalPreferences preferences,
  ) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'quick_content_preferences',
            valueJson: jsonEncode(preferences.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<SearchLocalPreferences> loadSearchLocalPreferences() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('search_local_preferences')))
            .getSingleOrNull();
    if (setting == null) return const SearchLocalPreferences();
    try {
      return SearchLocalPreferences.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return const SearchLocalPreferences();
    }
  }

  @override
  Future<void> saveSearchLocalPreferences(
    SearchLocalPreferences preferences,
  ) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'search_local_preferences',
            valueJson: jsonEncode(preferences.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<DevicePreferences> loadDevicePreferences() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('device_preferences')))
            .getSingleOrNull();
    if (setting == null) return const DevicePreferences();
    try {
      return DevicePreferences.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return const DevicePreferences();
    }
  }

  @override
  Future<void> saveDevicePreferences(DevicePreferences preferences) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'device_preferences',
            valueJson: jsonEncode(preferences.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<ExamLibrary> loadExamLibrary() async {
    final setting = await (database.select(
      database.appSettings,
    )..where((table) => table.key.equals('exam_library_v1'))).getSingleOrNull();
    if (setting == null) return const ExamLibrary();
    try {
      return ExamLibrary.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return const ExamLibrary();
    }
  }

  @override
  Future<void> saveExamLibrary(ExamLibrary library) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'exam_library_v1',
            valueJson: jsonEncode(library.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<ImportReviewDraft?> loadImportReviewDraft() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('import_review_draft')))
            .getSingleOrNull();
    if (setting == null) return null;
    try {
      return ImportReviewDraft.fromJson(
        Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveImportReviewDraft(ImportReviewDraft draft) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'import_review_draft',
            valueJson: jsonEncode(draft.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<void> clearImportReviewDraft() async {
    await (database.delete(
      database.appSettings,
    )..where((table) => table.key.equals('import_review_draft'))).go();
  }

  @override
  Future<List<LearningItem>> loadCustomItems() async {
    final rows = await (database.select(
      database.contentItems,
    )..where((table) => table.deletedAt.isNull())).get();
    const validator = LearningContentValidator();
    final items = <LearningItem>[];
    for (final row in rows) {
      try {
        final language = LanguageTag.values.firstWhere(
          (value) => value.code == row.learningLanguageTag,
        );
        final readingsJson =
            jsonDecode(row.readingsJson) as List<Object?>? ?? const [];
        final sourceJson = Map<String, Object?>.from(
          jsonDecode(row.sourceJson) as Map<Object?, Object?>,
        );
        final capabilityNames =
            ((sourceJson['capabilities'] as List<Object?>?) ?? const [])
                .whereType<String>()
                .toSet();
        final rawPartOfSpeech = sourceJson['partOfSpeech'];
        items.add(
          validator.ensureValid(
            LearningItem(
              id: row.id,
              kind: LearningItemKind.values.byName(row.kind),
              learningLanguage: language,
              text: row.textValue,
              translations: (jsonDecode(row.translationsJson) as List<Object?>)
                  .cast<String>(),
              acceptedAnswers:
                  (jsonDecode(row.acceptedAnswersJson) as List<Object?>)
                      .cast<String>(),
              subjectId: sourceJson['subjectId'] as String?,
              readings: readingsJson
                  .cast<Map<String, Object?>>()
                  .map(
                    (reading) => Reading(
                      scheme: ReadingScheme.values.byName(
                        reading['scheme']! as String,
                      ),
                      value: reading['value']! as String,
                    ),
                  )
                  .toList(),
              sentenceTokens:
                  (jsonDecode(row.sentenceTokensJson) as List<Object?>)
                      .cast<String>(),
              example: sourceJson['example'] as String?,
              exampleTranslation: sourceJson['exampleTranslation'] as String?,
              partOfSpeech: rawPartOfSpeech is String
                  ? parsePartOfSpeech(rawPartOfSpeech)
                  : null,
              tags: (jsonDecode(row.tagsJson) as List<Object?>).cast<String>(),
              level: row.level,
              capabilities: capabilityNames.isEmpty
                  ? const {
                      ExerciseCapability.recognition,
                      ExerciseCapability.production,
                    }
                  : ExerciseCapability.values
                        .where((value) => capabilityNames.contains(value.name))
                        .toSet(),
              priority: row.priority,
              source: ContentSource.fromJson(sourceJson),
              updatedAt: row.updatedAt,
            ),
          ),
        );
      } catch (_) {
        // Keep one malformed local row from preventing the whole app startup.
      }
    }
    return items;
  }

  @override
  Future<Map<String, DateTime>> loadCustomItemTombstones() async {
    final tombstones = <String, DateTime>{};
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('custom_item_tombstones')))
            .getSingleOrNull();
    if (setting != null) {
      try {
        final decoded = Map<String, Object?>.from(
          jsonDecode(setting.valueJson) as Map<Object?, Object?>,
        );
        for (final entry in decoded.entries) {
          final parsed = DateTime.tryParse(entry.value as String? ?? '');
          if (parsed != null) tombstones[entry.key] = parsed.toUtc();
        }
      } catch (_) {
        // A malformed tombstone cache must not prevent local study startup.
      }
    }
    final deletedRows = await (database.select(
      database.contentItems,
    )..where((table) => table.deletedAt.isNotNull())).get();
    for (final row in deletedRows) {
      final deletedAt = row.deletedAt;
      if (deletedAt == null) continue;
      final current = tombstones[row.id];
      if (current == null || deletedAt.isAfter(current)) {
        tombstones[row.id] = deletedAt.toUtc();
      }
    }
    return tombstones;
  }

  @override
  Future<void> saveCustomItemTombstones(
    Map<String, DateTime> tombstones,
  ) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'custom_item_tombstones',
            valueJson: jsonEncode({
              for (final entry in tombstones.entries)
                entry.key: entry.value.toUtc().toIso8601String(),
            }),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<void> saveCustomItems(Iterable<LearningItem> items) async {
    final validatedItems = [
      for (final item in items)
        const LearningContentValidator().ensureValid(item),
    ];
    final now = DateTime.now().toUtc();
    await database.batch((batch) {
      for (final item in validatedItems) {
        batch.insert(
          database.contentItems,
          ContentItemsCompanion.insert(
            id: item.id,
            kind: item.kind.name,
            learningLanguageTag: item.learningLanguage.code,
            textValue: item.text,
            translationsJson: jsonEncode(item.translations),
            acceptedAnswersJson: jsonEncode(item.acceptedAnswers),
            readingsJson: Value(
              jsonEncode([
                for (final reading in item.readings)
                  {'scheme': reading.scheme.name, 'value': reading.value},
              ]),
            ),
            sentenceTokensJson: Value(jsonEncode(item.sentenceTokens)),
            tagsJson: Value(jsonEncode(item.tags)),
            level: Value(item.level),
            priority: Value(item.priority),
            sourceJson: jsonEncode({
              ...item.source.toJson(),
              'partOfSpeech': item.partOfSpeech?.name,
              'example': item.example,
              'exampleTranslation': item.exampleTranslation,
              'subjectId': item.effectiveSubjectId,
              'capabilities': item.capabilities
                  .map((value) => value.name)
                  .toList(),
            }),
            updatedAt: item.updatedAt ?? now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> replaceCustomContent({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
  }) async {
    await database.transaction(() async {
      await database.delete(database.contentItems).go();
      await saveCustomItems(items);
      await saveCustomItemTombstones(tombstones);
    });
  }

  @override
  Future<void> commitCustomItemImport({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
    ImportCommitRecord? record,
  }) async {
    final validatedItems = [
      for (final item in items)
        const LearningContentValidator().ensureValid(item),
    ];
    await database.transaction(() async {
      await saveCustomItems(validatedItems);
      await saveCustomItemTombstones(tombstones);
      if (record != null) {
        await database
            .into(database.importedFiles)
            .insertOnConflictUpdate(
              ImportedFilesCompanion.insert(
                importId: record.importId,
                fileName: record.fileName,
                sha256: record.sha256,
                importedRows: record.importedRows,
                rejectedRows: record.rejectedRows,
                importedAt: record.importedAt.toUtc(),
              ),
            );
      }
    });
  }

  @override
  Future<ImportCommitRecord?> findImportBySha256(String sha256) async {
    final row =
        await (database.select(database.importedFiles)
              ..where((table) => table.sha256.equals(sha256))
              ..orderBy([(table) => OrderingTerm.desc(table.importedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return ImportCommitRecord(
      importId: row.importId,
      fileName: row.fileName,
      sha256: row.sha256,
      importedRows: row.importedRows,
      rejectedRows: row.rejectedRows,
      importedAt: row.importedAt.toUtc(),
    );
  }

  @override
  Future<void> deleteCustomItem(String itemId) async {
    await (database.update(
      database.contentItems,
    )..where((table) => table.id.equals(itemId))).write(
      ContentItemsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> saveStudyEvent(StudyEventEntry event) async {
    await database
        .into(database.studyEvents)
        .insertOnConflictUpdate(
          StudyEventsCompanion.insert(
            eventId: event.eventId,
            courseId: event.courseId,
            itemId: event.itemId,
            exerciseType: event.exerciseType,
            result: event.result,
            studiedAt: event.studiedAt.toUtc(),
            deviceId: 'local-device',
          ),
        );
  }

  @override
  Future<void> saveStudySession(StudySessionSummary session) async {
    await database
        .into(database.studySessions)
        .insertOnConflictUpdate(
          StudySessionsCompanion.insert(
            sessionId: session.sessionId,
            courseId: session.courseId,
            startedAt: session.startedAt.toUtc(),
            endedAt: Value(session.endedAt.toUtc()),
            correctCount: Value(session.correctCount),
            wrongCount: Value(session.wrongCount),
            earnedXp: Value(session.earnedXp),
            metadataJson: Value(jsonEncode(session.toJson())),
          ),
        );
  }

  @override
  Future<void> replaceStudySessions(
    Iterable<StudySessionSummary> sessions,
  ) async {
    await database.transaction(() async {
      await database.delete(database.studySessions).go();
      for (final session in sessions) {
        await saveStudySession(session);
      }
    });
  }

  @override
  Future<List<StudySessionSummary>> loadRecentSessions({int limit = 20}) async {
    final query = database.select(database.studySessions)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.startedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    final rows = await query.get();
    final sessions = <StudySessionSummary>[];
    for (final row in rows) {
      if (row.endedAt == null) continue;
      try {
        final metadata = Map<String, Object?>.from(
          jsonDecode(row.metadataJson) as Map<Object?, Object?>,
        );
        sessions.add(
          StudySessionSummary.fromJson({
            ...metadata,
            'sessionId': row.sessionId,
            'courseId': row.courseId,
            'startedAt': row.startedAt.toUtc().toIso8601String(),
            'endedAt': row.endedAt!.toUtc().toIso8601String(),
            'correctCount': row.correctCount,
            'wrongCount': row.wrongCount,
            'earnedXp': row.earnedXp,
          }),
        );
      } catch (_) {
        sessions.add(
          StudySessionSummary(
            sessionId: row.sessionId,
            courseId: row.courseId,
            startedAt: row.startedAt,
            endedAt: row.endedAt!,
            correctCount: row.correctCount,
            wrongCount: row.wrongCount,
            earnedXp: row.earnedXp,
          ),
        );
      }
    }
    return sessions;
  }

  @override
  Future<StoredActiveStudyState> loadActiveStudyState() async {
    final setting =
        await (database.select(database.appSettings)
              ..where((table) => table.key.equals('active_study_session')))
            .getSingleOrNull();
    if (setting == null) return const StoredActiveStudyState();
    try {
      final json = Map<String, Object?>.from(
        jsonDecode(setting.valueJson) as Map<Object?, Object?>,
      );
      if (json.containsKey('session')) {
        final changedAt = DateTime.tryParse(json['changedAt'] as String? ?? '');
        if (changedAt == null) return const StoredActiveStudyState();
        final rawSession = json['session'];
        return StoredActiveStudyState(
          session: rawSession is Map
              ? ActiveStudySession.fromJson(
                  Map<String, Object?>.from(rawSession),
                )
              : null,
          changedAt: changedAt,
        );
      }
      final legacySession = ActiveStudySession.fromJson(json);
      return StoredActiveStudyState(
        session: legacySession,
        changedAt: legacySession.updatedAt,
      );
    } catch (_) {
      return const StoredActiveStudyState();
    }
  }

  @override
  Future<void> saveActiveStudySession(ActiveStudySession session) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'active_study_session',
            valueJson: jsonEncode({
              'changedAt': session.updatedAt.toUtc().toIso8601String(),
              'session': session.toJson(),
            }),
            updatedAt: session.updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> clearActiveStudySession(DateTime clearedAt) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'active_study_session',
            valueJson: jsonEncode({
              'changedAt': clearedAt.toUtc().toIso8601String(),
              'session': null,
            }),
            updatedAt: clearedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> replaceActiveStudyState(
    StoredActiveStudyState activeStudy,
  ) async {
    final changedAt = activeStudy.changedAt;
    if (changedAt == null) {
      await (database.delete(
        database.appSettings,
      )..where((table) => table.key.equals('active_study_session'))).go();
      return;
    }
    final session = activeStudy.session;
    if (session == null) {
      await clearActiveStudySession(changedAt);
      return;
    }
    await saveActiveStudySession(session);
  }

  @override
  Future<PendingSyncOperation?> loadPendingSnapshotSync() async {
    final row =
        await (database.select(database.pendingSyncs)
              ..where(
                (table) => table.entityType.equals(
                  PendingSyncEntityType.snapshot.name,
                ),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return PendingSyncOperation(
        operationId: row.operationId,
        entityType: PendingSyncEntityType.values.byName(row.entityType),
        entityId: row.entityId,
        payload: Map<String, Object?>.from(
          jsonDecode(row.payloadJson) as Map<Object?, Object?>,
        ),
        attempts: row.attempts,
        nextAttemptAt: row.nextAttemptAt.toUtc(),
        createdAt: row.createdAt.toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> replacePendingSnapshotSync(
    PendingSyncOperation operation,
  ) async {
    await database.transaction(() async {
      await (database.delete(database.pendingSyncs)..where(
            (table) =>
                table.entityType.equals(PendingSyncEntityType.snapshot.name),
          ))
          .go();
      await database
          .into(database.pendingSyncs)
          .insert(_pendingSyncCompanion(operation));
    });
  }

  @override
  Future<void> updatePendingSync(PendingSyncOperation operation) async {
    await (database.update(database.pendingSyncs)
          ..where((table) => table.operationId.equals(operation.operationId)))
        .write(_pendingSyncCompanion(operation));
  }

  @override
  Future<void> deletePendingSync(String operationId) async {
    await (database.delete(
      database.pendingSyncs,
    )..where((table) => table.operationId.equals(operationId))).go();
  }
}

PendingSyncsCompanion _pendingSyncCompanion(PendingSyncOperation operation) {
  return PendingSyncsCompanion.insert(
    operationId: operation.operationId,
    entityType: operation.entityType.name,
    entityId: operation.entityId,
    payloadJson: jsonEncode(operation.payload),
    attempts: Value(operation.attempts),
    nextAttemptAt: operation.nextAttemptAt.toUtc(),
    createdAt: operation.createdAt.toUtc(),
  );
}

Map<String, int> _safeXpMap(Object? raw, {int maximumEntries = 200}) {
  if (raw is! Map) return const {};
  final values = <String, int>{};
  for (final entry in raw.entries.take(maximumEntries)) {
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
  return Map.unmodifiable(values);
}

Map<String, int> _safeXpLedger(Object? raw) {
  if (raw is! Map) return const {};
  final values = <String, int>{};
  for (final entry in raw.entries.take(500)) {
    final key = _safeReplicaId(entry.key);
    final value = entry.value;
    if (key == null ||
        value is! num ||
        !value.isFinite ||
        value != value.round()) {
      continue;
    }
    values[key] = value.toInt().clamp(0, 1000000000);
  }
  return Map.unmodifiable(values);
}

Map<String, Map<String, int>> _safeDailyXpLedger(Object? raw) {
  if (raw is! Map) return const {};
  final values = <String, Map<String, int>>{};
  for (final entry in raw.entries.take(200)) {
    final courseId = entry.key;
    if (courseId is! String ||
        courseId.trim().isEmpty ||
        courseId.runes.length > 160) {
      continue;
    }
    final ledger = _safeXpLedger(entry.value);
    if (ledger.isNotEmpty) values[courseId] = ledger;
  }
  return Map.unmodifiable(values);
}

String? _safeReplicaId(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  if (value.isEmpty || value.length > 80) return null;
  final valid = value.codeUnits.every(
    (code) =>
        (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 45 ||
        code == 95,
  );
  return valid ? value : null;
}

String _newReplicaId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final encoded = base64UrlEncode(bytes).replaceAll('=', '');
  return 'replica-$encoded';
}
