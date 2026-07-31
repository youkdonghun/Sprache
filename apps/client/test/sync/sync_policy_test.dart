import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/sync/sync_history.dart';
import 'package:sprache/src/sync/sync_policy.dart';

void main() {
  test('device sync policy, history, and recovery point round-trip', () {
    final now = DateTime.utc(2026, 7, 31, 10);
    final settings = SyncDeviceSettings(
      policy: const SyncPolicy(mode: SyncMode.wifiOnly),
      history: [
        SyncHistoryEntry(
          id: 'sync-1',
          status: SyncHistoryStatus.success,
          startedAt: now,
          endedAt: now.add(const Duration(seconds: 2)),
          summary: '완료',
          changeCount: 1,
          comparisons: const [
            SyncItemComparison(
              section: 'progress',
              recordId: 'word-1',
              localExists: true,
              driveExists: true,
              localPreview: '{"correctCount":1}',
              drivePreview: '{"correctCount":2}',
              selection: SyncVersionSelection.drive,
            ),
          ],
        ),
      ],
      recoveryPoint: SyncRecoveryPoint(
        id: 'sync-1',
        createdAt: now,
        localSnapshot: const {'schemaVersion': 2, 'progress': []},
        driveSnapshot: const {'schemaVersion': 1, 'progress': []},
        mergedSnapshot: const {'schemaVersion': 2, 'progress': []},
      ),
    );

    final restored = SyncDeviceSettings.fromJson(settings.toJson());

    expect(restored.policy.mode, SyncMode.wifiOnly);
    expect(restored.history.single.changeCount, 1);
    expect(
      restored.history.single.comparisons.single.selection,
      SyncVersionSelection.drive,
    );
    expect(restored.recoveryPoint?.localSnapshot['schemaVersion'], 2);
    expect(restored.recoveryPoint?.driveSnapshot?['schemaVersion'], 1);
  });

  test('comparison and selected version resolver work per record', () {
    final local = <String, Object?>{
      'schemaVersion': 2,
      'settings': {'dailyGoal': 20},
      'profile': {'totalXp': 1},
      'progress': [
        {'itemId': 'same', 'correctCount': 1},
        {'itemId': 'local', 'correctCount': 3},
      ],
      'customItems': <Object?>[],
      'customItemTombstones': <Object?>[],
      'recentSessions': <Object?>[],
      'activeStudy': null,
    };
    final drive = <String, Object?>{
      'schemaVersion': 1,
      'settings': {'dailyGoal': 40},
      'profile': {'totalXp': 1},
      'progress': [
        {'itemId': 'same', 'correctCount': 2},
        {'itemId': 'drive', 'correctCount': 4},
      ],
      'customItems': <Object?>[],
      'customItemTombstones': <Object?>[],
      'recentSessions': <Object?>[],
      'activeStudy': null,
    };
    final comparisons = const SyncSnapshotDiffer().compare(
      local: local,
      drive: drive,
    );
    expect(
      comparisons.map((value) => value.key),
      containsAll([
        'progress::same',
        'progress::local',
        'progress::drive',
        'settings::settings',
      ]),
    );

    final resolved = const SyncSnapshotResolver().resolve(
      local: local,
      drive: drive,
      merged: local,
      selections: const {
        'progress::same': SyncVersionSelection.drive,
        'progress::local': SyncVersionSelection.local,
        'progress::drive': SyncVersionSelection.drive,
        'settings::settings': SyncVersionSelection.drive,
      },
    );
    final progress = (resolved['progress']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(resolved['schemaVersion'], 2);
    expect(resolved['settings'], {'dailyGoal': 40});
    expect(
      progress.singleWhere((row) => row['itemId'] == 'same')['correctCount'],
      2,
    );
    expect(
      progress.map((row) => row['itemId']),
      containsAll(['local', 'drive']),
    );
  });
}
