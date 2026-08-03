import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'recent recorded sessions drive the timed-session speed estimate',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);

      await controller.finishSession(
        StudySessionSummary(
          sessionId: 'speed',
          courseId: controller.state.activeCourseId,
          startedAt: DateTime.utc(2026, 7, 31, 10),
          endedAt: DateTime.utc(2026, 7, 31, 10, 5),
          correctCount: 8,
          wrongCount: 2,
          earnedXp: 100,
        ),
      );

      expect(controller.averageSecondsPerStudyItem, 30);
      final preview = controller.previewSessionPlan(
        const StudySessionPlan(
          lengthMode: StudySessionLengthMode.timeBudget,
          timeBudgetMinutes: 3,
        ),
        DateTime.utc(2026, 7, 31, 11),
      );
      expect(preview.items.length, lessThanOrEqualTo(6));
      controller.dispose();
    },
  );

  test(
    'unrecorded practice leaves progress, XP, streak, and history unchanged',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final item = controller.selectedItems.first;
      final before = controller.state;

      controller.recordAnswer(
        item: item,
        correct: true,
        studiedAt: DateTime.utc(2026, 7, 31, 10),
        exerciseType: 'practice',
        recordProgress: false,
      );
      await controller.finishSession(
        StudySessionSummary(
          sessionId: 'practice',
          courseId: controller.state.activeCourseId,
          startedAt: DateTime.utc(2026, 7, 31, 10),
          endedAt: DateTime.utc(2026, 7, 31, 10, 1),
          correctCount: 1,
          wrongCount: 0,
          earnedXp: 0,
          recordProgress: false,
        ),
      );

      expect(controller.state.progress, before.progress);
      expect(controller.state.totalXp, before.totalXp);
      expect(controller.state.streakDays, before.streakDays);
      expect(controller.state.recentSessions, before.recentSessions);
      expect(store.savedEvents, isEmpty);
      expect(store.savedSessions, isEmpty);
      controller.dispose();
    },
  );

  test(
    'recovery previews share one cumulative allowance per local day',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final now = DateTime(2026, 7, 31, 20);
      final itemIds = controller.selectedItems
          .take(2)
          .map((item) => item.id)
          .toList(growable: false);
      await controller.finishSession(
        StudySessionSummary(
          sessionId: 'recovery-today',
          courseId: controller.state.activeCourseId,
          startedAt: now.subtract(const Duration(minutes: 2)),
          endedAt: now,
          correctCount: 2,
          wrongCount: 0,
          earnedXp: 20,
          itemIds: itemIds,
          finalCorrectItemIds: itemIds.toSet(),
          backlogRecovery: true,
        ),
      );

      final preview = controller.previewSessionPlan(
        const StudySessionPlan(
          itemLimit: 100,
          backlogRecovery: BacklogRecoverySettings(
            enabled: true,
            dailyLimit: 3,
          ),
        ),
        now.add(const Duration(minutes: 5)),
      );
      expect(preview.items, hasLength(1));
      controller.dispose();
    },
  );

  test('exam plan actions complete, snooze, defer, and change time', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final now = DateTime.utc(2026, 7, 31, 1);
    final saved = controller.saveSessionPlan(
      StudySessionPlan(
        title: '시험 준비',
        examSchedule: ExamSchedule(
          targetDate: DateTime.utc(2026, 8, 10),
          preferredMinuteOfDay: 19 * 60,
        ),
        scheduledAt: now,
      ),
    );

    final snoozed = controller.snoozeSessionPlan(saved.planId, now: now);
    expect(snoozed?.scheduledAt, now.add(const Duration(minutes: 10)));
    expect(snoozed?.examSchedule?.snoozedUntil, snoozed?.scheduledAt);

    final tomorrow = controller.deferSessionPlanUntilTomorrow(
      saved.planId,
      now: now,
    );
    final tomorrowLocal = tomorrow!.scheduledAt!.toLocal();
    final expectedTomorrow = DateTime(
      now.toLocal().year,
      now.toLocal().month,
      now.toLocal().day + 1,
    );
    expect(
      DateTime(tomorrowLocal.year, tomorrowLocal.month, tomorrowLocal.day),
      expectedTomorrow,
    );

    final retimed = controller.changeSessionPlanTime(
      saved.planId,
      minuteOfDay: 8 * 60 + 45,
      now: now,
    );
    expect(retimed?.examSchedule?.preferredMinuteOfDay, 8 * 60 + 45);

    final completed = controller.completeExamPlanForToday(
      saved.planId,
      completedAt: now,
    );
    expect(completed?.examSchedule?.lastCompletedAt, now);
    expect(completed?.scheduledAt, isNotNull);
    controller.dispose();
  });
}
