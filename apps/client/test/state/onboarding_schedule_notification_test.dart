import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/onboarding_profile.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('incomplete onboarding draft resumes from the local store', () async {
    final store = MemoryStudyStore();
    final first = AppController(store);
    await Future<void>.delayed(Duration.zero);
    first.saveOnboardingDraft(
      const OnboardingProfile(
        languageCode: 'ja',
        purpose: LearningPurpose.travel,
        draftStep: 4,
        themeMode: OnboardingThemeMode.dark,
        quickActions: [
          HomeQuickAction.practice,
          HomeQuickAction.stats,
          HomeQuickAction.study,
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    first.dispose();

    final resumed = AppController(store);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final profile = resumed.state.preferences.onboardingProfile;
    expect(resumed.state.preferences.onboardingCompleted, isFalse);
    expect(profile.languageCode, 'ja');
    expect(profile.purpose, LearningPurpose.travel);
    expect(profile.draftStep, 4);
    expect(profile.themeMode, OnboardingThemeMode.dark);
    expect(profile.quickActions.first, HomeQuickAction.practice);
    resumed.dispose();
  });

  test(
    'a reminder on a rest day is reconciled on the next study day',
    () async {
      const profile = OnboardingProfile(
        studyWeekdays: {1, 3, 5},
        scheduleConfigured: true,
      );
      final sundayLocal = DateTime(2026, 8, 2, 20, 30);
      final plan = StudySessionPlan(
        planId: 'rest-day-plan',
        subjectId: 'language:en',
        title: '저녁 학습',
        scheduledAt: sundayLocal.toUtc(),
      );
      final notifications = _RecordingNotifications();
      final controller = AppController(
        MemoryStudyStore(
          preferences: StudyPreferences(
            onboardingCompleted: true,
            onboardingProfile: profile,
            activeSubjectId: 'language:en',
            savedSessionPlans: [plan],
          ),
        ),
        notificationService: notifications,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final scheduled = notifications.reconciliations.last.single.scheduledAt!;
      expect(scheduled, profile.nextStudyDateTime(sundayLocal).toUtc());
      expect(scheduled.toLocal().weekday, DateTime.monday);
      expect(scheduled.toLocal().hour, 20);
      expect(scheduled.toLocal().minute, 30);
      controller.dispose();
    },
  );
}

class _RecordingNotifications implements StudyNotificationService {
  final reconciliations = <List<StudySessionPlan>>[];

  @override
  Future<StudyNotificationPermission> requestPermission() async =>
      StudyNotificationPermission.granted;

  @override
  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  }) async {
    final values = plans.toList(growable: false);
    reconciliations.add(values);
    return StudyNotificationReconcileResult(
      available: true,
      scheduledCount: values.length,
    );
  }
}
