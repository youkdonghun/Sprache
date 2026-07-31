import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/study_history.dart';

void main() {
  test('completed session preserves reusable item and wrong-answer IDs', () {
    final session = StudySessionSummary(
      sessionId: 'session-reuse',
      courseId: 'ko-en',
      startedAt: DateTime.utc(2026, 7, 28, 8),
      endedAt: DateTime.utc(2026, 7, 28, 8, 5),
      correctCount: 2,
      wrongCount: 1,
      earnedXp: 25,
      itemIds: const ['item-a', 'item-b', 'item-c'],
      wrongItemIds: const {'item-b'},
      finalCorrectItemIds: const {'item-a', 'item-c'},
    );

    final restored = StudySessionSummary.fromJson(session.toJson());

    expect(restored.itemIds, ['item-a', 'item-b', 'item-c']);
    expect(restored.wrongItemIds, {'item-b'});
    expect(restored.finalCorrectItemIds, {'item-a', 'item-c'});
    expect(restored.unresolvedWrongItemIds, {'item-b'});
    expect(restored.notCorrectItemIds, {'item-b'});
  });

  test('legacy summaries conservatively keep ever-wrong items unresolved', () {
    final restored = StudySessionSummary.fromJson({
      'sessionId': 'legacy-session',
      'courseId': 'ko-en',
      'startedAt': DateTime.utc(2026, 7, 28).toIso8601String(),
      'endedAt': DateTime.utc(2026, 7, 28, 0, 5).toIso8601String(),
      'correctCount': 2,
      'wrongCount': 1,
      'earnedXp': 20,
      'itemIds': ['item-a', 'item-b', 'item-c'],
      'wrongItemIds': ['item-b'],
    });

    expect(restored.finalCorrectItemIds, {'item-a', 'item-c'});
    expect(restored.unresolvedWrongItemIds, {'item-b'});
  });

  test('a corrected retry is no longer an unresolved wrong answer', () {
    final restored = StudySessionSummary.fromJson({
      'sessionId': 'corrected-session',
      'courseId': 'ko-en',
      'startedAt': DateTime.utc(2026, 7, 28).toIso8601String(),
      'endedAt': DateTime.utc(2026, 7, 28, 0, 5).toIso8601String(),
      'correctCount': 2,
      'wrongCount': 1,
      'earnedXp': 20,
      'itemIds': ['item-a', 'item-b'],
      'wrongItemIds': ['item-b'],
      'finalCorrectItemIds': ['item-a', 'item-b'],
    });

    expect(restored.unresolvedWrongItemIds, isEmpty);
    expect(restored.notCorrectItemIds, isEmpty);
  });

  test('wrong-answer IDs must belong to the completed item set', () {
    expect(
      () => StudySessionSummary.fromJson({
        'sessionId': 'bad-session',
        'courseId': 'ko-en',
        'startedAt': DateTime.utc(2026, 7, 28).toIso8601String(),
        'endedAt': DateTime.utc(2026, 7, 28, 0, 5).toIso8601String(),
        'correctCount': 0,
        'wrongCount': 1,
        'earnedXp': 0,
        'itemIds': ['item-a'],
        'wrongItemIds': ['missing'],
      }),
      throwsFormatException,
    );
  });

  test('recovery session metadata round-trips and rejects corrupt flags', () {
    final session = StudySessionSummary(
      sessionId: 'recovery-session',
      courseId: 'ko-en',
      startedAt: DateTime.utc(2026, 7, 31, 8),
      endedAt: DateTime.utc(2026, 7, 31, 8, 5),
      correctCount: 1,
      wrongCount: 0,
      earnedXp: 10,
      itemIds: const ['item-a'],
      finalCorrectItemIds: const {'item-a'},
      backlogRecovery: true,
    );

    expect(
      StudySessionSummary.fromJson(session.toJson()).backlogRecovery,
      isTrue,
    );
    expect(
      () => StudySessionSummary.fromJson({
        ...session.toJson(),
        'backlogRecovery': 'yes',
      }),
      throwsFormatException,
    );
    expect(
      () => StudySessionSummary.fromJson({
        ...session.toJson(),
        'recordProgress': 1,
      }),
      throwsFormatException,
    );
  });
}
