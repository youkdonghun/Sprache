import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
  const validator = SyncSnapshotValidator();

  test('accepts a minimal backward-compatible snapshot', () {
    expect(() => validator.validate({'schemaVersion': 1}), returnsNormally);
  });

  test('reports exact paths for corrupt progress and content', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'progress': [
          {'itemId': 'item-1', 'correctCount': -1},
        ],
        'customItems': [
          {
            'id': 'bad-item',
            'kind': 'word',
            'language': 'en',
            'text': 'word',
            'translations': <String>[],
          },
        ],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([r'$.progress[0].correctCount', r'$.customItems[0]']),
        ),
      ),
    );
  });

  test('rejects duplicate remote content IDs', () {
    final item = {
      'id': 'same-id',
      'kind': 'word',
      'language': 'en',
      'text': 'hello',
      'translations': ['안녕하세요'],
      'acceptedAnswers': ['안녕하세요'],
    };

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'customItems': [item, item],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) =>
              error.issues.any((issue) => issue.path == r'$.customItems[1].id'),
          'duplicate ID issue',
          isTrue,
        ),
      ),
    );
  });

  test('rejects malformed custom item tombstones', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'customItemTombstones': [
          {'id': 'deleted-item', 'deletedAt': 'not-a-date'},
        ],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.first.path,
          'path',
          r'$.customItemTombstones[0].deletedAt',
        ),
      ),
    );
  });

  test('rejects malformed session builder settings with exact paths', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'sessionPlan': {
            'mode': 'unsupported',
            'deck': 'everywhere',
            'unitIndex': 20,
            'sentenceRatio': 4,
            'itemLimit': 100,
            'updatedAt': 'not-a-date',
          },
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([
            r'$.settings.sessionPlan.mode',
            r'$.settings.sessionPlan.deck',
            r'$.settings.sessionPlan.unitIndex',
            r'$.settings.sessionPlan.sentenceRatio',
            r'$.settings.sessionPlan.itemLimit',
            r'$.settings.sessionPlan.updatedAt',
          ]),
        ),
      ),
    );
  });

  test(
    'validates active session lineage while allowing repeat queue entries',
    () {
      final startedAt = DateTime.utc(2026, 7, 28, 9);
      final session = ActiveStudySession.started(
        sessionId: 'active-session',
        courseId: 'ko-en',
        mode: StudyMode.mixed,
        unitIndex: null,
        itemIds: const ['a', 'b'],
        startedAt: startedAt,
      ).copyWith(itemIds: const ['a', 'b', 'a'], wrongItemIds: const {'a'});
      final valid = {
        'schemaVersion': 1,
        'activeStudy': {
          'changedAt': session.updatedAt.toIso8601String(),
          'session': session.toJson(),
        },
      };

      expect(() => validator.validate(valid), returnsNormally);
      expect(
        () => validator.validate({
          ...valid,
          'activeStudy': {
            'changedAt': session.updatedAt.toIso8601String(),
            'session': {
              ...session.toJson(),
              'wrongItemIds': ['missing'],
            },
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'paths',
            contains(r'$.activeStudy.session.wrongItemIds'),
          ),
        ),
      );
    },
  );
}
