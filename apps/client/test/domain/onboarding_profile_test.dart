import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/onboarding_profile.dart';

void main() {
  test('draft round-trips every resumable onboarding choice', () {
    final profile = OnboardingProfile(
      languageCode: 'ja',
      purpose: LearningPurpose.travel,
      level: SelfAssessedLevel.intermediate,
      dailyMinutes: 10,
      dailyGoal: 150,
      entryChoice: OnboardingEntryChoice.importMyData,
      draftStep: 4,
      studyWeekdays: const {2, 4, 6},
      scheduleConfigured: true,
      accessibilityProfile: OnboardingAccessibilityProfile.easyAccess,
      themeMode: OnboardingThemeMode.dark,
      accent: OnboardingAccent.ocean,
      quickActions: const [
        HomeQuickAction.practice,
        HomeQuickAction.study,
        HomeQuickAction.stats,
      ],
      deferred: true,
    );

    final restored = OnboardingProfile.fromJson(profile.toJson());

    expect(restored.languageCode, 'ja');
    expect(restored.purpose, LearningPurpose.travel);
    expect(restored.level, SelfAssessedLevel.intermediate);
    expect(restored.dailyMinutes, 10);
    expect(restored.dailyGoal, 150);
    expect(restored.entryChoice, OnboardingEntryChoice.importMyData);
    expect(restored.draftStep, 4);
    expect(restored.normalizedStudyWeekdays, {2, 4, 6});
    expect(restored.scheduleConfigured, isTrue);
    expect(restored.easyAccess, isTrue);
    expect(restored.themeMode, OnboardingThemeMode.dark);
    expect(restored.accent, OnboardingAccent.ocean);
    expect(restored.quickActions, [
      HomeQuickAction.practice,
      HomeQuickAction.study,
      HomeQuickAction.stats,
    ]);
    expect(restored.deferred, isTrue);
  });

  test('malformed draft is bounded and keeps three unique quick actions', () {
    final restored = OnboardingProfile.fromJson({
      'languageCode': '../secret',
      'draftStep': 999,
      'dailyMinutes': -1,
      'dailyGoal': 5000,
      'studyWeekdays': [0, 9],
      'quickActions': ['stats', 'stats', 'unknown'],
    });

    expect(restored.languageCode, isEmpty);
    expect(restored.draftStep, OnboardingProfile.stepCount - 1);
    expect(restored.dailyMinutes, 3);
    expect(restored.dailyGoal, 500);
    expect(restored.normalizedStudyWeekdays, {1, 2, 3, 4, 5});
    expect(restored.quickActions, hasLength(3));
    expect(restored.quickActions.toSet(), hasLength(3));
    expect(restored.quickActions.first, HomeQuickAction.stats);
  });

  test('rest days move today plan and reminder to the next study day', () {
    const profile = OnboardingProfile(
      studyWeekdays: {1, 3, 5},
      scheduleConfigured: true,
    );
    final sunday = DateTime(2026, 8, 2, 20, 30);

    expect(profile.isStudyDay(sunday), isFalse);
    expect(profile.nextStudyDate(sunday), DateTime(2026, 8, 3));
    expect(profile.nextStudyDateTime(sunday), DateTime(2026, 8, 3, 20, 30));
  });

  test('legacy profiles keep all days active until a schedule is chosen', () {
    const legacy = OnboardingProfile();
    expect(legacy.scheduleConfigured, isFalse);
    expect(legacy.isStudyDay(DateTime(2026, 8, 2)), isTrue);
  });

  test('purpose produces a concrete starter group and game recommendation', () {
    const travel = OnboardingProfile(purpose: LearningPurpose.travel);
    const exam = OnboardingProfile(purpose: LearningPurpose.exam);

    expect(travel.recommendedStarterGroupLabel, '여행 필수 표현');
    expect(travel.recommendedActivityId, 'pronunciation');
    expect(exam.recommendedStarterGroupLabel, '시험 집중 복습');
    expect(exam.recommendedActivityId, 'meaning-choice');
  });
}
