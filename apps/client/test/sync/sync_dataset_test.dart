import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/sync/sync_dataset.dart';

void main() {
  const codec = SyncDatasetCodec();

  final snapshot = <String, Object?>{
    'schemaVersion': 1,
    'updatedAt': '2026-07-29T00:00:00.000Z',
    'profile': {'totalXp': 120},
    'settings': {'dailyGoal': 100},
    'progress': [
      {'itemId': 'en-1', 'correctCount': 3},
    ],
    'customItems': [
      {'id': 'custom-1'},
    ],
    'customItemTombstones': [
      {'id': 'custom-2', 'deletedAt': '2026-07-29T00:00:00.000Z'},
    ],
    'recentSessions': [
      {'sessionId': 'session-1'},
    ],
    'activeStudy': null,
  };

  test('split dataset rejoins to the exact legacy snapshot contract', () {
    final sections = codec.split(snapshot);

    expect(sections.keys, SyncDatasetCodec.sectionPaths);
    expect(codec.join(sections), snapshot);
  });

  test(
    'segmented-v1 layout carries snapshot schema v2 without changing IDs',
    () {
      final v2 = Map<String, Object?>.from(snapshot)
        ..['schemaVersion'] = 2
        ..['settings'] = {
          'smartCollections': [
            {'id': 'smart-1'},
          ],
          'importReceipts': [
            {'importId': 'import-1', 'undoneAt': null},
          ],
        };

      final sections = codec.split(v2);

      expect(SyncDatasetCodec.layout, 'segmented-v1');
      expect(sections['state/meta.json']?['schemaVersion'], 2);
      expect(codec.join(sections), v2);
    },
  );

  test('validation paths resolve to the section that owns the data', () {
    expect(
      codec.sectionPathForValidationPath(r'$.profile.dailyXp'),
      'state/profile.json',
    );
    expect(
      codec.sectionPathForValidationPath(r'$.settings.dailyGoal'),
      'state/settings.json',
    );
    expect(
      codec.sectionPathForValidationPath(r'$.customItems[0].reading'),
      'content/custom-items.json',
    );
    expect(
      codec.sectionPathForValidationPath(r'$.activeStudy.session.itemIds'),
      'state/sessions.json',
    );
  });

  test('missing segmented files fail before partial data can be merged', () {
    final sections = codec.split(snapshot)..remove('state/progress.json');

    expect(
      () => codec.join(sections),
      throwsA(
        isA<SyncDatasetException>().having(
          (error) => error.code,
          'code',
          'sync_dataset_section_missing',
        ),
      ),
    );
  });
}
