import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/session_enhancements.dart';

void main() {
  test('exam schedule recalculates a capped daily recommendation', () {
    final schedule = ExamSchedule(
      targetDate: DateTime.utc(2026, 8, 4),
      dailyCap: 20,
    );

    expect(
      schedule.recommendedDailyItems(
        remainingItems: 100,
        now: DateTime.utc(2026, 7, 31),
      ),
      20,
    );
    expect(
      schedule.recommendedDailyItems(
        remainingItems: 9,
        now: DateTime.utc(2026, 7, 31),
      ),
      2,
    );
  });

  test('exam completion and snooze state round-trip safely', () {
    final completedAt = DateTime.utc(2026, 7, 31, 10);
    final snoozedUntil = completedAt.add(const Duration(minutes: 10));
    final schedule = ExamSchedule(
      targetDate: DateTime.utc(2026, 9),
      dailyCap: 35,
      preferredMinuteOfDay: 8 * 60 + 30,
      lastCompletedAt: completedAt,
      snoozedUntil: snoozedUntil,
      updatedAt: completedAt,
    );

    final restored = ExamSchedule.fromJson(schedule.toJson());

    expect(restored.dailyCap, 35);
    expect(restored.preferredMinuteOfDay, 8 * 60 + 30);
    expect(restored.lastCompletedAt, completedAt);
    expect(restored.snoozedUntil, snoozedUntil);
    expect(restored.isCompletedOn(completedAt), isTrue);
  });

  test('next study time respects the selected local minute of day', () {
    final schedule = ExamSchedule(
      targetDate: DateTime.now().add(const Duration(days: 30)),
      preferredMinuteOfDay: 7 * 60 + 15,
    );
    final next = schedule
        .nextStudyAt(DateTime(2026, 7, 31, 20), tomorrow: true)
        .toLocal();

    expect(next, DateTime(2026, 8, 1, 7, 15));
  });
}
