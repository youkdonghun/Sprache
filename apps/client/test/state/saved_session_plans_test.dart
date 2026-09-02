import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('untitled settings get a clear subject and length name', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);

    final saved = controller.saveSessionPlan(
      const StudySessionPlan(mode: StudyMode.review, itemLimit: 24),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(saved.title, '영어 복습 예정만 24문제');
    expect(store.savedPreferences.savedSessionPlans.single.title, saved.title);
    controller.dispose();
  });

  test('multiple named schedules can be saved, updated, and deleted', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);

    final morning = controller.saveSessionPlan(
      StudySessionPlan(
        title: '아침 영어',
        scheduledAt: DateTime.utc(2026, 7, 29, 22),
        itemLimit: 10,
      ),
    );
    final lunch = controller.saveSessionPlan(
      StudySessionPlan(
        title: '점심 일본어',
        scheduledAt: DateTime.utc(2026, 7, 30, 3),
        itemLimit: 15,
      ),
    );
    final updatedMorning = controller.saveSessionPlan(
      morning.copyWith(itemLimit: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(morning.planId, isNotEmpty);
    expect(morning.subjectId, 'language:en');
    expect(lunch.planId, isNot(morning.planId));
    expect(updatedMorning.planId, morning.planId);
    expect(controller.state.preferences.savedSessionPlans, hasLength(2));
    expect(
      controller.state.preferences.savedSessionPlans
          .firstWhere((plan) => plan.planId == morning.planId)
          .itemLimit,
      20,
    );
    expect(store.savedPreferences.savedSessionPlans, hasLength(2));

    controller.deleteSavedSessionPlan(lunch.planId);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.preferences.savedSessionPlans, hasLength(1));
    expect(
      controller.state.preferences.savedSessionPlanTombstones,
      contains(lunch.planId),
    );
    expect(store.savedPreferences.savedSessionPlans, hasLength(1));
    expect(
      store.savedPreferences.savedSessionPlanTombstones,
      contains(lunch.planId),
    );
    controller.dispose();
  });

  test(
    'saved schedules stay inside their subject and a started slot is consumed',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);

      final english = controller.saveSessionPlan(
        StudySessionPlan(
          title: '영어 출근 복습',
          scheduledAt: DateTime.utc(2026, 7, 29, 22),
        ),
      );
      controller.selectSubject('language:ja');
      final japanese = controller.saveSessionPlan(
        StudySessionPlan(
          title: '일본어 점심 복습',
          scheduledAt: DateTime.utc(2026, 7, 30, 3),
        ),
      );

      expect(controller.activeSubjectSavedSessionPlans, [japanese]);
      expect(controller.useSavedSessionPlan(english), isNull);

      final started = controller.consumeScheduledSessionPlan(japanese.planId);
      expect(started, isNotNull);
      expect(started!.scheduledAt, isNull);
      expect(controller.activeSubjectScheduledSessionPlans, isEmpty);
      expect(
        controller.state.preferences.savedSessionPlans
            .firstWhere((plan) => plan.planId == english.planId)
            .scheduledAt,
        isNotNull,
      );

      controller.selectSubject('language:en');
      expect(controller.activeSubjectSavedSessionPlans, [english]);
      expect(controller.useSavedSessionPlan(english)?.planId, english.planId);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    },
  );

  test(
    'legacy in-memory schedules are migrated to the active subject',
    () async {
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(
          activeSubjectId: 'language:fr',
          sessionPlan: StudySessionPlan(planId: 'legacy-current'),
          savedSessionPlans: [
            StudySessionPlan(planId: 'legacy-saved', title: '이전 일정'),
          ],
        ),
      );
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);

      expect(controller.activeSessionPlan.subjectId, 'language:fr');
      expect(
        controller.activeSubjectSavedSessionPlans.single.subjectId,
        'language:fr',
      );
      expect(
        store.savedPreferences.savedSessionPlans.single.subjectId,
        'language:fr',
      );
      controller.dispose();
    },
  );

  test(
    'saved, consumed, and deleted schedules reconcile device alerts',
    () async {
      final store = MemoryStudyStore();
      final notifications = _RecordingStudyNotificationService();
      final controller = AppController(
        store,
        notificationService: notifications,
      );
      await Future<void>.delayed(Duration.zero);

      final saved = controller.saveSessionPlan(
        StudySessionPlan(
          title: '알림 복습',
          scheduledAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifications.reconciliations.last.single.planId, saved.planId);
      expect(notifications.reconciliations.last.single.scheduledAt, isNotNull);

      final permission = await controller.requestStudyNotificationPermission();
      expect(permission, StudyNotificationPermission.granted);
      expect(notifications.permissionRequests, 1);

      controller.consumeScheduledSessionPlan(saved.planId);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifications.reconciliations.last.single.scheduledAt, isNull);

      controller.deleteSavedSessionPlan(saved.planId);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifications.reconciliations.last, isEmpty);
      controller.dispose();
    },
  );

  test(
    'notification actions snooze atomically and start the matching subject',
    () async {
      final store = MemoryStudyStore();
      final notifications = _RecordingStudyNotificationService();
      final controller = AppController(
        store,
        notificationService: notifications,
      );
      await Future<void>.delayed(Duration.zero);

      controller.selectSubject('language:ja');
      final saved = controller.saveSessionPlan(
        StudySessionPlan(
          title: 'Japanese review',
          scheduledAt: DateTime.utc(2026, 8, 2, 12),
        ),
      );
      controller.selectSubject('language:en');
      const receivedAt = '2026-08-02T12:05:00Z';

      final snoozed = await controller.applyStudyNotificationAction(
        StudyNotificationAction(
          kind: StudyNotificationActionKind.snooze10,
          planId: saved.planId,
          receivedAt: DateTime.parse(receivedAt),
          notificationId: 41,
        ),
      );

      expect(snoozed, isTrue);
      expect(
        controller.state.preferences.savedSessionPlans
            .singleWhere((plan) => plan.planId == saved.planId)
            .scheduledAt,
        DateTime.utc(2026, 8, 2, 12, 15),
      );
      expect(
        store.savedPreferences.savedSessionPlans
            .singleWhere((plan) => plan.planId == saved.planId)
            .scheduledAt,
        DateTime.utc(2026, 8, 2, 12, 15),
      );

      final started = await controller.applyStudyNotificationAction(
        StudyNotificationAction(
          kind: StudyNotificationActionKind.start,
          planId: saved.planId,
          receivedAt: DateTime.utc(2026, 8, 2, 12, 6),
          notificationId: 41,
        ),
      );

      expect(started, isTrue);
      expect(controller.state.activeSubjectId, 'language:ja');
      expect(controller.activeSessionPlan.planId, saved.planId);
      expect(controller.activeSessionPlan.scheduledAt, isNull);
      expect(
        store.savedPreferences.savedSessionPlans
            .singleWhere((plan) => plan.planId == saved.planId)
            .scheduledAt,
        isNull,
      );
      expect(notifications.reconciliations.last.single.scheduledAt, isNull);

      final missing = await controller.applyStudyNotificationAction(
        StudyNotificationAction(
          kind: StudyNotificationActionKind.open,
          planId: 'deleted-plan',
          receivedAt: DateTime.utc(2026, 8, 2, 12, 7),
        ),
      );
      expect(missing, isFalse);
      controller.dispose();
    },
  );
}

class _RecordingStudyNotificationService implements StudyNotificationService {
  final reconciliations = <List<StudySessionPlan>>[];
  var permissionRequests = 0;

  @override
  Future<StudyNotificationPermission> requestPermission() async {
    permissionRequests += 1;
    return StudyNotificationPermission.granted;
  }

  @override
  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  }) async {
    final copied = plans.toList(growable: false);
    reconciliations.add(copied);
    return StudyNotificationReconcileResult(
      available: true,
      scheduledCount: buildStudyNotificationSpecs(
        copied,
        now: now ?? DateTime.now(),
      ).length,
    );
  }
}
