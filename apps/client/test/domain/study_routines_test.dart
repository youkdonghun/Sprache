import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_routines.dart';

void main() {
  test('routine plans round-trip and group in explicit order', () {
    final second = StudySessionPlan(
      planId: 'second',
      routineName: '출근 루틴',
      routineWeekdays: const {1, 3, 5},
      routineMinuteOfDay: 8 * 60,
      routineOrder: 1,
    );
    final first = StudySessionPlan.fromJson({
      ...second.copyWith(planId: 'first', routineOrder: 0).toJson(),
    });

    final group = groupStudyRoutines([second, first]).single;
    expect(group.name, '출근 루틴');
    expect(group.plans.map((plan) => plan.planId), ['first', 'second']);
    expect(group.weekdays, {1, 3, 5});
    expect(group.minuteOfDay, 8 * 60);
    expect(first.routineWeekdays, {1, 3, 5});
  });

  test(
    'next routine occurrence uses local weekdays and stays in the future',
    () {
      final after = DateTime(2026, 8, 3, 9); // Monday local.
      final plan = const StudySessionPlan(
        routineName: '아침',
        routineWeekdays: {DateTime.monday, DateTime.wednesday},
        routineMinuteOfDay: 8 * 60,
      );

      final next = nextRoutineOccurrence(plan, after: after)!.toLocal();
      expect(next.weekday, DateTime.wednesday);
      expect(next.hour, 8);
      expect(next.isAfter(after), isTrue);
    },
  );

  test('two-minute plan prioritizes due, deduplicates, and limits to five', () {
    final plan = buildTwoMinuteStudyPlan(
      subjectId: 'language:en',
      dueItemIds: const ['due-1', 'same', 'due-2'],
      weakItemIds: const ['same', 'weak-1', 'weak-2', 'weak-3'],
    )!;

    expect(plan.selectedItemIds.toList(), [
      'due-1',
      'same',
      'due-2',
      'weak-1',
      'weak-2',
    ]);
    expect(plan.itemLimit, 5);
    expect(plan.lengthMode, StudySessionLengthMode.timeBudget);
    expect(plan.timeBudgetMinutes, 2);
    expect(
      buildTwoMinuteStudyPlan(
        subjectId: 'language:en',
        dueItemIds: const ['one'],
        weakItemIds: const ['two'],
      ),
      isNull,
    );
  });

  test('missed work is evenly redistributed without crossing daily cap', () {
    final result = redistributeMissedStudy(
      missedItems: 17,
      remainingStudyDays: 4,
      dailyCap: 4,
    );

    expect(result.dailyItems, [4, 4, 4, 4]);
    expect(result.scheduledItems, 16);
    expect(result.remainingBacklog, 1);
  });

  test('local study time recommendation handles sessions around midnight', () {
    StudySessionSummary session(String id, int day, int hour, int minute) =>
        StudySessionSummary(
          sessionId: id,
          courseId: 'en',
          startedAt: DateTime(2026, 8, day, hour, minute),
          endedAt: DateTime(2026, 8, day, hour, minute),
          correctCount: 1,
          wrongCount: 0,
          earnedXp: 1,
        );

    final recommendation = recommendLocalStudyTime([
      session('a', 1, 23, 45),
      session('b', 2, 0, 0),
      session('c', 3, 0, 15),
    ])!;
    expect(
      recommendation.minuteOfDay == 0 ||
          recommendation.minuteOfDay >= 23 * 60 + 45,
      isTrue,
    );
    expect(recommendation.sampleCount, 3);
    expect(recommendation.confidence, greaterThan(0.95));
  });
}
