import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';

void main() {
  test('notification specs keep only future named schedules', () {
    final now = DateTime.utc(2026, 7, 29, 0);
    final specs = buildStudyNotificationSpecs([
      StudySessionPlan(
        planId: 'later',
        title: '저녁 발음',
        mode: StudyMode.pronunciation,
        itemLimit: 15,
        scheduledAt: now.add(const Duration(hours: 8)),
      ),
      StudySessionPlan(
        planId: 'first',
        title: '아침 복습',
        scheduledAt: now.add(const Duration(hours: 2)),
      ),
      StudySessionPlan(
        planId: 'past',
        scheduledAt: now.subtract(const Duration(minutes: 1)),
      ),
      StudySessionPlan(
        title: '저장되지 않은 일정',
        scheduledAt: now.add(const Duration(hours: 1)),
      ),
    ], now: now);

    expect(specs.map((spec) => spec.planId), ['first', 'later']);
    expect(specs.last.title, '저녁 발음');
    expect(specs.last.body, '발음 따라하기 · 15개 표현을 시작해요.');
    expect(specs.last.payload, 'session-plan/later');
    expect(specs.map((spec) => spec.id).toSet(), hasLength(2));
  });

  test('newer duplicate wins and IDs stay stable across input order', () {
    final now = DateTime.utc(2026, 7, 29, 0);
    final older = StudySessionPlan(
      planId: 'same-plan',
      title: '이전 이름',
      scheduledAt: now.add(const Duration(hours: 2)),
      updatedAt: now,
    );
    final newer = older.copyWith(
      title: '새 이름',
      scheduledAt: now.add(const Duration(hours: 3)),
      updatedAt: now.add(const Duration(minutes: 1)),
    );
    final other = StudySessionPlan(
      planId: 'other-plan',
      scheduledAt: now.add(const Duration(hours: 1)),
    );

    final forward = buildStudyNotificationSpecs([
      older,
      other,
      newer,
    ], now: now);
    final reversed = buildStudyNotificationSpecs([
      newer,
      other,
      older,
    ], now: now);

    expect(
      forward.map((spec) => (spec.planId, spec.id)),
      reversed.map((spec) => (spec.planId, spec.id)),
    );
    expect(
      forward.singleWhere((spec) => spec.planId == 'same-plan').title,
      '새 이름',
    );
  });

  test('at most twenty upcoming notifications are scheduled', () {
    final now = DateTime.utc(2026, 7, 29, 0);
    final specs = buildStudyNotificationSpecs([
      for (var index = 0; index < 24; index++)
        StudySessionPlan(
          planId: 'plan-$index',
          scheduledAt: now.add(Duration(minutes: index + 1)),
        ),
    ], now: now);

    expect(specs, hasLength(20));
    expect(specs.first.planId, 'plan-0');
    expect(specs.last.planId, 'plan-19');
  });
}
