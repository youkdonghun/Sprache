import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/daily_practice_quests.dart';

void main() {
  test('creates three distinct deterministic quests for a day and subject', () {
    final first = buildDailyPracticeQuests(
      day: DateTime(2026, 8, 3, 8),
      subjectId: 'language:en',
      activityIds: const ['cards', 'quiz', 'listen', 'write', 'quiz'],
    );
    final second = buildDailyPracticeQuests(
      day: DateTime(2026, 8, 3, 22),
      subjectId: 'language:en',
      activityIds: const ['write', 'listen', 'quiz', 'cards'],
    );

    expect(first, hasLength(3));
    expect(first.map((quest) => quest.activityId).toSet(), hasLength(3));
    expect(
      second.map((quest) => quest.activityId),
      first.map((quest) => quest.activityId),
    );
    expect(first.map((quest) => quest.slot), [0, 1, 2]);
  });

  test('caps quests to available activities and ignores blank duplicates', () {
    final quests = buildDailyPracticeQuests(
      day: DateTime(2026, 8, 3),
      subjectId: 'general:baseball',
      activityIds: const ['quiz', ' quiz ', '', 'quiz'],
    );

    expect(quests, hasLength(1));
    expect(quests.single.activityId, 'quiz');
  });
}
