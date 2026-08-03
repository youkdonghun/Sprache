import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
  test(
    '45 offline days converge regardless of which device reconnects first',
    () async {
      final branches = await _buildOfflineBranches();

      final windowsFirst = await _runReconnectionScenario(
        branches,
        windowsFirst: true,
      );
      final androidFirst = await _runReconnectionScenario(
        branches,
        windowsFirst: false,
      );

      expect(
        _canonicalSnapshot(windowsFirst.cloud),
        _canonicalSnapshot(androidFirst.cloud),
      );
      _expectOfflineWorkPreserved(windowsFirst, branches);
      _expectOfflineWorkPreserved(androidFirst, branches);
    },
  );

  test(
    'interrupted first upload keeps the branch queued and converges on retry',
    () async {
      final branches = await _buildOfflineBranches();
      final cloud = _OfflineCloudService(
        snapshot: _cloneSnapshot(branches.base),
        failPushes: 1,
      );
      final windows = AppController(MemoryStudyStore());
      final android = AppController(MemoryStudyStore());
      await _hydrate(windows, android);
      await windows.mergeRemoteSnapshot(
        _cloneSnapshot(branches.windows),
        markDriveConnected: false,
      );
      await android.mergeRemoteSnapshot(
        _cloneSnapshot(branches.android),
        markDriveConnected: false,
      );
      final windowsConnection = ConnectionController(cloud, windows);
      final androidConnection = ConnectionController(cloud, android);
      addTearDown(() {
        windowsConnection.dispose();
        androidConnection.dispose();
        windows.dispose();
        android.dispose();
      });

      await windowsConnection.connect();

      expect(windowsConnection.state.phase, ConnectionPhase.failed);
      expect(windows.state.pendingSync, isNotNull);
      expect(
        _canonicalSnapshot(cloud.snapshot!),
        _canonicalSnapshot(branches.base),
      );

      await windowsConnection.syncNow();
      expect(windowsConnection.state.phase, ConnectionPhase.connected);
      expect(windows.state.pendingSync, isNull);
      await androidConnection.connect();
      for (var round = 0; round < 12; round++) {
        await windowsConnection.syncNow();
        await androidConnection.syncNow();
      }
      await windowsConnection.syncNow();

      final result = _ScenarioResult(
        cloud: cloud.snapshot!,
        windows: windows.exportSyncSnapshot(),
        android: android.exportSyncSnapshot(),
      );
      _expectOfflineWorkPreserved(result, branches);
      expect(
        _canonicalSnapshot(result.windows),
        _canonicalSnapshot(result.android),
      );
    },
  );
}

class _OfflineBranches {
  const _OfflineBranches({
    required this.base,
    required this.windows,
    required this.android,
    required this.windowsOnlyItemId,
    required this.androidOnlyItemId,
    required this.deletedSharedItemId,
    required this.windowsProgressItemId,
    required this.androidProgressItemId,
    required this.sharedProgressItemId,
    required this.expectedSharedProgressAt,
    required this.expectedEnglishDailyGoal,
    required this.expectedMergedXp,
    required this.expectedMergedDailyXp,
    required this.removedFavoriteItemId,
    required this.removedExcludedItemId,
  });

  final Map<String, Object?> base;
  final Map<String, Object?> windows;
  final Map<String, Object?> android;
  final String windowsOnlyItemId;
  final String androidOnlyItemId;
  final String deletedSharedItemId;
  final String windowsProgressItemId;
  final String androidProgressItemId;
  final String sharedProgressItemId;
  final DateTime expectedSharedProgressAt;
  final int expectedEnglishDailyGoal;
  final int expectedMergedXp;
  final int expectedMergedDailyXp;
  final String removedFavoriteItemId;
  final String removedExcludedItemId;
}

class _ScenarioResult {
  const _ScenarioResult({
    required this.cloud,
    required this.windows,
    required this.android,
  });

  final Map<String, Object?> cloud;
  final Map<String, Object?> windows;
  final Map<String, Object?> android;
}

Future<_OfflineBranches> _buildOfflineBranches() async {
  final baseController = AppController(MemoryStudyStore());
  await _hydrate(baseController);
  const deletedSharedItemId = 'offline-shared-item';
  await baseController.upsertCustomItem(
    const LearningItem(
      id: deletedSharedItemId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'shared',
      translations: ['공유'],
      acceptedAnswers: ['공유'],
    ),
  );
  final removedFavoriteItemId = baseController.selectedItems[5].id;
  final removedExcludedItemId = baseController.selectedItems[6].id;
  baseController.toggleFavorite(removedFavoriteItemId);
  baseController.toggleItemSelection(removedExcludedItemId);
  final base = _cloneSnapshot(baseController.exportSyncSnapshot());
  baseController.dispose();

  final windows = AppController(MemoryStudyStore());
  final android = AppController(MemoryStudyStore());
  await _hydrate(windows, android);
  await windows.mergeRemoteSnapshot(
    _cloneSnapshot(base),
    markDriveConnected: false,
  );
  await android.mergeRemoteSnapshot(
    _cloneSnapshot(base),
    markDriveConnected: false,
  );
  windows.toggleFavorite(removedFavoriteItemId);
  windows.toggleItemSelection(removedExcludedItemId);

  const windowsOnlyItemId = 'offline-windows-only';
  const androidOnlyItemId = 'offline-android-only';
  await windows.upsertCustomItem(
    const LearningItem(
      id: windowsOnlyItemId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'worksheet',
      translations: ['업무 자료'],
      acceptedAnswers: ['업무 자료'],
      tags: ['Windows'],
    ),
  );
  await android.upsertCustomItem(
    const LearningItem(
      id: androidOnlyItemId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'commute',
      translations: ['통근'],
      acceptedAnswers: ['통근'],
      tags: ['Android'],
    ),
  );

  await android.upsertCustomItem(
    const LearningItem(
      id: deletedSharedItemId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'shared',
      translations: ['공유', '함께 쓰는'],
      acceptedAnswers: ['공유', '함께 쓰는'],
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await windows.deleteCustomItem(deletedSharedItemId);

  final startedAt = DateTime.utc(2026, 5);
  final windowsItems = windows.selectedItems.take(48).toList(growable: false);
  final androidItems = android.selectedItems
      .skip(48)
      .take(48)
      .toList(growable: false);
  for (var day = 0; day < 45; day++) {
    windows.recordAnswer(
      item: windowsItems[day % windowsItems.length],
      correct: day % 7 != 0,
      studiedAt: startedAt.add(Duration(days: day, hours: 8)),
      exerciseType: day.isEven ? 'recognition' : 'production',
    );
    android.recordAnswer(
      item: androidItems[day % androidItems.length],
      correct: day % 5 != 0,
      studiedAt: startedAt.add(Duration(days: day, hours: 19)),
      exerciseType: day.isEven ? 'listening' : 'cloze',
    );
  }

  final sharedProgressItem = windows.selectedItems[100];
  windows.recordAnswer(
    item: sharedProgressItem,
    correct: true,
    studiedAt: startedAt.add(const Duration(days: 20, hours: 9)),
    exerciseType: 'recognition',
  );
  final expectedSharedProgressAt = startedAt.add(
    const Duration(days: 40, hours: 21),
  );
  android.recordAnswer(
    item: sharedProgressItem,
    correct: false,
    studiedAt: expectedSharedProgressAt,
    exerciseType: 'production',
  );

  windows.toggleFavorite(windowsItems.first.id);
  android.toggleFavorite(androidItems.first.id);
  windows.completeMission(0);
  android.completeMission(1);

  await windows.upsertStudySubject(
    StudySubject(
      id: 'general:offline-windows',
      kind: StudySubjectKind.general,
      name: 'Windows 오프라인 노트',
      description: '45일 동안 작성',
      symbol: 'W',
      contentLanguage: LanguageTag.korean,
      createdAt: startedAt,
      updatedAt: startedAt.add(const Duration(days: 44)),
    ),
  );
  await android.upsertStudySubject(
    StudySubject(
      id: 'general:offline-android',
      kind: StudySubjectKind.general,
      name: 'Android 오프라인 노트',
      description: '45일 동안 작성',
      symbol: 'A',
      contentLanguage: LanguageTag.korean,
      createdAt: startedAt,
      updatedAt: startedAt.add(const Duration(days: 44, hours: 1)),
    ),
  );

  windows.saveSessionPlan(
    const StudySessionPlan(
      planId: 'offline-windows-plan',
      title: 'Windows 퇴근 복습',
      deck: StudyDeckScope.favorites,
      itemLimit: 12,
    ),
  );
  android.saveSessionPlan(
    const StudySessionPlan(
      planId: 'offline-android-plan',
      title: 'Android 출근 복습',
      mode: StudyMode.listening,
      itemLimit: 8,
    ),
  );

  await windows.finishSession(
    StudySessionSummary(
      sessionId: 'offline-windows-session',
      courseId: 'ko-en',
      startedAt: startedAt.add(const Duration(days: 44, hours: 8)),
      endedAt: startedAt.add(const Duration(days: 44, hours: 8, minutes: 12)),
      correctCount: 10,
      wrongCount: 2,
      earnedXp: 100,
      itemIds: windowsItems.take(12).map((item) => item.id).toList(),
      wrongItemIds: {windowsItems[2].id, windowsItems[7].id},
    ),
  );
  await android.finishSession(
    StudySessionSummary(
      sessionId: 'offline-android-session',
      courseId: 'ko-en',
      startedAt: startedAt.add(const Duration(days: 44, hours: 19)),
      endedAt: startedAt.add(const Duration(days: 44, hours: 19, minutes: 8)),
      correctCount: 6,
      wrongCount: 2,
      earnedXp: 60,
      itemIds: androidItems.take(8).map((item) => item.id).toList(),
      wrongItemIds: {androidItems[1].id, androidItems[5].id},
    ),
  );

  windows.beginActiveStudySession(
    sessionId: 'offline-old-active-session',
    mode: StudyMode.mixed,
    unitIndex: null,
    itemIds: windowsItems.take(5).map((item) => item.id).toList(),
    startedAt: startedAt.add(const Duration(days: 35)),
  );
  android.clearActiveStudySession(
    clearedAt: startedAt.add(const Duration(days: 44, hours: 23)),
  );

  await Future<void>.delayed(const Duration(milliseconds: 30));
  final windowsSnapshot = _cloneSnapshot(windows.exportSyncSnapshot());
  final androidSnapshot = _cloneSnapshot(android.exportSyncSnapshot());
  _setOfflineDailyGoal(
    windowsSnapshot,
    goal: 140,
    changedAt: startedAt.add(const Duration(days: 20)),
  );
  _setOfflineDailyGoal(
    androidSnapshot,
    goal: 220,
    changedAt: startedAt.add(const Duration(days: 40)),
  );
  final expectedMergedXp = _mergedProfileXp(windowsSnapshot, androidSnapshot);
  final expectedMergedDailyXp = _mergedDailyProfileXp(
    windowsSnapshot,
    androidSnapshot,
  );
  windows.dispose();
  android.dispose();

  return _OfflineBranches(
    base: base,
    windows: windowsSnapshot,
    android: androidSnapshot,
    windowsOnlyItemId: windowsOnlyItemId,
    androidOnlyItemId: androidOnlyItemId,
    deletedSharedItemId: deletedSharedItemId,
    windowsProgressItemId: windowsItems.first.id,
    androidProgressItemId: androidItems.first.id,
    sharedProgressItemId: sharedProgressItem.id,
    expectedSharedProgressAt: expectedSharedProgressAt,
    expectedEnglishDailyGoal: 220,
    expectedMergedXp: expectedMergedXp,
    expectedMergedDailyXp: expectedMergedDailyXp,
    removedFavoriteItemId: removedFavoriteItemId,
    removedExcludedItemId: removedExcludedItemId,
  );
}

Future<_ScenarioResult> _runReconnectionScenario(
  _OfflineBranches branches, {
  required bool windowsFirst,
}) async {
  final service = _OfflineCloudService(snapshot: _cloneSnapshot(branches.base));
  final windows = AppController(MemoryStudyStore());
  final android = AppController(MemoryStudyStore());
  await _hydrate(windows, android);
  await windows.mergeRemoteSnapshot(
    _cloneSnapshot(branches.windows),
    markDriveConnected: false,
  );
  await android.mergeRemoteSnapshot(
    _cloneSnapshot(branches.android),
    markDriveConnected: false,
  );
  final windowsConnection = ConnectionController(service, windows);
  final androidConnection = ConnectionController(service, android);

  final first = windowsFirst ? windowsConnection : androidConnection;
  final second = windowsFirst ? androidConnection : windowsConnection;
  await first.connect();
  await second.connect();
  for (var round = 0; round < 12; round++) {
    await windowsConnection.syncNow();
    await androidConnection.syncNow();
  }
  await windowsConnection.syncNow();

  final result = _ScenarioResult(
    cloud: _cloneSnapshot(service.snapshot!),
    windows: _cloneSnapshot(windows.exportSyncSnapshot()),
    android: _cloneSnapshot(android.exportSyncSnapshot()),
  );
  windowsConnection.dispose();
  androidConnection.dispose();
  windows.dispose();
  android.dispose();
  return result;
}

void _expectOfflineWorkPreserved(
  _ScenarioResult result,
  _OfflineBranches branches,
) {
  const validator = SyncSnapshotValidator();
  validator.validate(result.cloud);
  final customItems = _records(result.cloud['customItems'], 'id');
  final tombstones = _records(result.cloud['customItemTombstones'], 'id');
  final progress = _records(result.cloud['progress'], 'itemId');
  final sessions = _records(result.cloud['recentSessions'], 'sessionId');
  final settings = Map<String, Object?>.from(result.cloud['settings']! as Map);
  final subjects = _records(settings['customSubjects'], 'id');
  final plans = _records(settings['savedSessionPlans'], 'planId');
  final favorites =
      (settings['favoriteItemIds'] as List<Object?>?)
          ?.whereType<String>()
          .toSet() ??
      const <String>{};
  final completedMissions =
      (settings['completedMissionIds'] as List<Object?>?)
          ?.whereType<String>()
          .toSet() ??
      const <String>{};
  final excluded =
      (settings['excludedItemIds'] as List<Object?>?)
          ?.whereType<String>()
          .toSet() ??
      const <String>{};

  expect(
    customItems.keys,
    containsAll([branches.windowsOnlyItemId, branches.androidOnlyItemId]),
  );
  expect(customItems, isNot(contains(branches.deletedSharedItemId)));
  expect(tombstones, contains(branches.deletedSharedItemId));
  expect(
    progress.keys,
    containsAll([
      branches.windowsProgressItemId,
      branches.androidProgressItemId,
      branches.sharedProgressItemId,
    ]),
  );
  expect(
    DateTime.parse(
      progress[branches.sharedProgressItemId]!['lastStudiedAt']! as String,
    ),
    branches.expectedSharedProgressAt,
  );
  expect(
    sessions.keys,
    containsAll(['offline-windows-session', 'offline-android-session']),
  );
  expect(
    subjects.keys,
    containsAll(['general:offline-windows', 'general:offline-android']),
  );
  expect(
    plans.keys,
    containsAll(['offline-windows-plan', 'offline-android-plan']),
  );
  expect(
    favorites,
    containsAll([
      branches.windowsProgressItemId,
      branches.androidProgressItemId,
    ]),
  );
  expect(completedMissions, containsAll(['ko-en:0', 'ko-en:1']));
  expect(favorites, isNot(contains(branches.removedFavoriteItemId)));
  expect(excluded, isNot(contains(branches.removedExcludedItemId)));
  expect(
    (settings['dailyGoalsBySubject']! as Map)['language:en'],
    branches.expectedEnglishDailyGoal,
  );
  expect((result.cloud['activeStudy']! as Map)['session'], isNull);
  expect(_profileXp(result.cloud), branches.expectedMergedXp);
  final cloudProfile = Map<String, Object?>.from(
    result.cloud['profile']! as Map,
  );
  final cloudXpByReplica = Map<String, Object?>.from(
    cloudProfile['xpByReplica']! as Map,
  );
  expect(
    cloudXpByReplica.values.where((value) => (value as num) > 0),
    hasLength(greaterThanOrEqualTo(2)),
  );
  expect(
    (cloudProfile['dailyXp']! as num).toInt(),
    branches.expectedMergedDailyXp,
  );
  expect(_canonicalSnapshot(result.cloud), _canonicalSnapshot(result.windows));
}

class _OfflineCloudService implements GoogleConnectionService {
  _OfflineCloudService({this.snapshot, this.failPushes = 0});

  Map<String, Object?>? snapshot;
  int failPushes;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    return const GoogleConnectionResult(
      folderId: 'offline-conflict-folder',
      folderName: 'Sprache Offline Conflict',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async {
    final current = snapshot;
    return current == null ? null : _cloneSnapshot(current);
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    if (failPushes > 0) {
      failPushes -= 1;
      throw StateError('simulated interrupted upload');
    }
    this.snapshot = _cloneSnapshot(snapshot);
  }
}

Future<void> _hydrate(AppController first, [AppController? second]) async {
  await Future<void>.delayed(Duration.zero);
  if (second != null) await Future<void>.delayed(Duration.zero);
}

Map<String, Object?> _cloneSnapshot(Map<String, Object?> snapshot) {
  return Map<String, Object?>.from(jsonDecode(jsonEncode(snapshot))! as Map);
}

Map<String, Map<String, Object?>> _records(Object? raw, String idKey) {
  final records = <String, Map<String, Object?>>{};
  for (final value in (raw as List<Object?>?) ?? const []) {
    if (value is! Map || value[idKey] is! String) continue;
    records[value[idKey]! as String] = Map<String, Object?>.from(value);
  }
  return records;
}

int _profileXp(Map<String, Object?> snapshot) {
  final profile = Map<String, Object?>.from(snapshot['profile']! as Map);
  return (profile['totalXp']! as num).toInt();
}

int _mergedProfileXp(Map<String, Object?> left, Map<String, Object?> right) {
  Map<String, int> ledger(Map<String, Object?> snapshot) {
    final profile = Map<String, Object?>.from(snapshot['profile']! as Map);
    final rawLedger = profile['xpByReplica'];
    if (rawLedger is! Map || rawLedger.isEmpty) {
      return {'legacy': _profileXp(snapshot)};
    }
    return {
      for (final entry in rawLedger.entries)
        entry.key as String: (entry.value as num).toInt(),
    };
  }

  final leftLedger = ledger(left);
  final rightLedger = ledger(right);
  final merged = <String, int>{...leftLedger};
  for (final entry in rightLedger.entries) {
    final current = merged[entry.key] ?? 0;
    if (entry.value > current) merged[entry.key] = entry.value;
  }
  return merged.values.fold(0, (total, value) => total + value);
}

int _mergedDailyProfileXp(
  Map<String, Object?> left,
  Map<String, Object?> right,
) {
  Map<String, Map<String, int>> ledger(Map<String, Object?> snapshot) {
    final profile = Map<String, Object?>.from(snapshot['profile']! as Map);
    final rawLedger = profile['dailyXpByCourseAndReplica'];
    if (rawLedger is! Map || rawLedger.isEmpty) {
      final dailyByCourse = Map<String, Object?>.from(
        (profile['dailyXpByCourse'] as Map?) ?? const {},
      );
      return {
        for (final entry in dailyByCourse.entries)
          entry.key: {'legacy': (entry.value as num).toInt()},
      };
    }
    return {
      for (final courseEntry in rawLedger.entries)
        courseEntry.key as String: {
          for (final replicaEntry in (courseEntry.value as Map).entries)
            replicaEntry.key as String: (replicaEntry.value as num).toInt(),
        },
    };
  }

  final merged = <String, Map<String, int>>{
    for (final entry in ledger(left).entries) entry.key: {...entry.value},
  };
  for (final courseEntry in ledger(right).entries) {
    final course = merged.putIfAbsent(courseEntry.key, () => {});
    for (final replicaEntry in courseEntry.value.entries) {
      final current = course[replicaEntry.key] ?? 0;
      if (replicaEntry.value > current) {
        course[replicaEntry.key] = replicaEntry.value;
      }
    }
  }
  return merged.values
      .expand((course) => course.values)
      .fold(0, (total, value) => total + value);
}

void _setOfflineDailyGoal(
  Map<String, Object?> snapshot, {
  required int goal,
  required DateTime changedAt,
}) {
  final settings = Map<String, Object?>.from(snapshot['settings']! as Map);
  final goals = Map<String, Object?>.from(
    (settings['dailyGoalsBySubject'] as Map?) ?? const {},
  );
  final changedAtBySubject = Map<String, Object?>.from(
    (settings['dailyGoalChangedAtBySubject'] as Map?) ?? const {},
  );
  goals['language:en'] = goal;
  changedAtBySubject['language:en'] = changedAt.toUtc().toIso8601String();
  settings['dailyGoalsBySubject'] = goals;
  settings['dailyGoalChangedAtBySubject'] = changedAtBySubject;
  snapshot['settings'] = settings;
}

Map<String, Object?> _canonicalSnapshot(Map<String, Object?> snapshot) {
  final root = _cloneSnapshot(snapshot)..remove('updatedAt');
  final profile = Map<String, Object?>.from(root['profile']! as Map);
  profile['badges'] =
      ((profile['badges'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toList()
        ..sort();
  root['profile'] = profile;

  final settings = Map<String, Object?>.from(root['settings']! as Map);
  for (final key in const [
    'excludedItemIds',
    'favoriteItemIds',
    'completedMissionIds',
  ]) {
    settings[key] =
        ((settings[key] as List<Object?>?) ?? const [])
            .whereType<String>()
            .toList()
          ..sort();
  }
  settings['customSubjects'] = _records(settings['customSubjects'], 'id');
  settings['savedSessionPlans'] = _records(
    settings['savedSessionPlans'],
    'planId',
  );
  root['settings'] = settings;
  root['progress'] = _records(root['progress'], 'itemId');
  root['customItems'] = _records(root['customItems'], 'id');
  root['customItemTombstones'] = _records(root['customItemTombstones'], 'id');
  root['recentSessions'] = _records(root['recentSessions'], 'sessionId');
  return root;
}
