import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/local_civil_schedule.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_routines.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('weekly local hour stays fixed when DST changes the UTC offset', () {
    final newYork = tz.getLocation('America/New_York');
    final schedule = LocalCivilSchedule(
      weekdays: const [DateTime.sunday],
      minuteOfDay: 9 * 60,
    );

    final beforeDst = schedule.nextUtc(
      after: DateTime.utc(2025, 3, 1, 15),
      location: newYork,
    )!;
    final afterDst = schedule.nextUtc(
      after: DateTime.utc(2025, 3, 9, 14),
      location: newYork,
    )!;

    expect(tz.TZDateTime.from(beforeDst, newYork).hour, 9);
    expect(tz.TZDateTime.from(afterDst, newYork).hour, 9);
    expect(beforeDst.hour, 14, reason: '09:00 EST');
    expect(afterDst.hour, 13, reason: '09:00 EDT');
  });

  test('travel recalculates the same civil rule in the current zone', () {
    final plan = const StudySessionPlan(
      routineName: 'Morning',
      routineWeekdays: {DateTime.monday},
      routineMinuteOfDay: 9 * 60,
    );
    final after = DateTime.utc(2026, 8, 2, 0);
    final seoul = tz.getLocation('Asia/Seoul');
    final losAngeles = tz.getLocation('America/Los_Angeles');

    final inSeoul = nextRoutineOccurrence(plan, after: after, location: seoul)!;
    final inLosAngeles = nextRoutineOccurrence(
      plan,
      after: after,
      location: losAngeles,
    )!;

    expect(tz.TZDateTime.from(inSeoul, seoul).hour, 9);
    expect(tz.TZDateTime.from(inLosAngeles, losAngeles).hour, 9);
    expect(inSeoul, isNot(inLosAngeles));
  });

  test('a repeated clock hour still returns an occurrence after now', () {
    final newYork = tz.getLocation('America/New_York');
    final schedule = LocalCivilSchedule(
      weekdays: const [DateTime.sunday],
      minuteOfDay: 90,
    );
    // 2025-11-02 01:45 EDT: the first 01:30 has passed, while the repeated
    // 01:30 EST is still in the future.
    final afterFirstOccurrence = DateTime.utc(2025, 11, 2, 5, 45);

    final next = schedule.nextUtc(
      after: afterFirstOccurrence,
      location: newYork,
    )!;

    expect(next, DateTime.utc(2025, 11, 2, 6, 30));
    final local = tz.TZDateTime.from(next, newYork);
    expect((local.hour, local.minute), (1, 30));
  });

  test('a skipped DST minute stays on the intended civil date', () {
    final newYork = tz.getLocation('America/New_York');
    final schedule = LocalCivilSchedule(
      weekdays: const [DateTime.sunday],
      minuteOfDay: 2 * 60 + 30,
    );

    final next = schedule.nextUtc(
      after: DateTime.utc(2025, 3, 8, 12),
      location: newYork,
    )!;
    final local = tz.TZDateTime.from(next, newYork);

    expect((local.year, local.month, local.day), (2025, 3, 9));
    expect((local.hour, local.minute), (3, 30));
  });

  test('historical study instants remain immutable across time zones', () {
    final original = StudySessionSummary(
      sessionId: 'history-1',
      courseId: 'language:en',
      startedAt: DateTime.parse('2026-08-02T00:00:00Z'),
      endedAt: DateTime.parse('2026-08-02T00:10:00Z'),
      correctCount: 4,
      wrongCount: 1,
      earnedXp: 9,
    );
    final restored = StudySessionSummary.fromJson(original.toJson());

    expect(restored.startedAt, original.startedAt.toUtc());
    expect(restored.endedAt, original.endedAt.toUtc());
    expect(
      tz.TZDateTime.from(
        restored.startedAt,
        tz.getLocation('Asia/Seoul'),
      ).toUtc(),
      tz.TZDateTime.from(
        restored.startedAt,
        tz.getLocation('America/New_York'),
      ).toUtc(),
    );
  });
}
