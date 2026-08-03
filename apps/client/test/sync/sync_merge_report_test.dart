import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/sync/sync_merge_report.dart';

void main() {
  test('sync report explains uploads, downloads, and conflict decisions', () {
    final report = const SyncMergeReporter().build(
      local: {
        'progress': [
          {'itemId': 'local-only', 'correctCount': 1},
          {'itemId': 'conflict', 'correctCount': 4},
        ],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'settings': {
          'favoriteItemIds': ['local'],
        },
        'profile': {'totalXp': 10},
        'activeStudy': null,
      },
      remote: {
        'progress': [
          {'itemId': 'remote-only', 'correctCount': 2},
          {'itemId': 'conflict', 'correctCount': 2},
        ],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'settings': {
          'favoriteItemIds': ['remote'],
        },
        'profile': {'totalXp': 20},
        'activeStudy': null,
      },
      merged: {
        'progress': [
          {'itemId': 'local-only', 'correctCount': 1},
          {'itemId': 'remote-only', 'correctCount': 2},
          {'itemId': 'conflict', 'correctCount': 4},
        ],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'settings': {
          'favoriteItemIds': ['local', 'remote'],
        },
        'profile': {'totalXp': 20},
        'activeStudy': null,
      },
      syncedAt: DateTime.utc(2026, 7, 28, 13),
    );

    expect(report.uploadCount, 1);
    expect(report.downloadCount, 1);
    expect(report.conflictCount, 3);
    expect(
      report.changes
          .firstWhere((change) => change.recordId == 'conflict')
          .decision,
      SyncMergeDecision.keepLocal,
    );
    expect(
      report.changes
          .firstWhere((change) => change.recordId == 'settings')
          .decision,
      SyncMergeDecision.merge,
    );
    expect(
      report.changes
          .firstWhere((change) => change.recordId == 'profile')
          .decision,
      SyncMergeDecision.useRemote,
    );
  });
}
