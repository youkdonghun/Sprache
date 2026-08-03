import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('routine order, recurrence, and explicit time apply persist', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final after = DateTime(2026, 8, 3, 9);

    final first = controller.saveSessionPlan(
      StudySessionPlan(
        title: '단어',
        routineName: '출근 루틴',
        routineWeekdays: const {1, 3, 5},
        routineMinuteOfDay: 8 * 60,
        scheduledAt: after.add(const Duration(days: 2)),
      ),
    );
    final second = controller.saveSessionPlan(
      StudySessionPlan(
        title: '문장',
        routineName: '출근 루틴',
        routineWeekdays: const {1, 3, 5},
        routineMinuteOfDay: 8 * 60,
        scheduledAt: after.add(const Duration(days: 2)),
      ),
    );
    expect(first.routineOrder, 0);
    expect(second.routineOrder, 1);

    controller.reorderRoutineSessionPlans('출근 루틴', [
      second.planId,
      first.planId,
    ]);
    expect(
      controller.state.preferences.savedSessionPlans
          .firstWhere((plan) => plan.planId == second.planId)
          .routineOrder,
      0,
    );

    final consumed = controller.consumeScheduledSessionPlan(first.planId)!;
    expect(consumed.scheduledAt, isNotNull);
    expect(consumed.scheduledAt!.isAfter(DateTime.now().toUtc()), isTrue);

    final changed = controller.applyRecommendedRoutineTime(
      7 * 60 + 30,
      now: after,
    );
    expect(changed, 2);
    expect(
      controller.state.preferences.savedSessionPlans
          .where((plan) => plan.routineName == '출근 루틴')
          .every((plan) => plan.routineMinuteOfDay == 7 * 60 + 30),
      isTrue,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      store.savedPreferences.savedSessionPlans
          .where((plan) => plan.routineName == '출근 루틴')
          .every((plan) => plan.routineMinuteOfDay == 7 * 60 + 30),
      isTrue,
    );
    controller.dispose();
  });
}
