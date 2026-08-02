import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/onboarding_profile.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('home honors custom quick-action order and planned rest day', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1100);
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 8, 2, 10); // Sunday.
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:en',
        onboardingProfile: OnboardingProfile(
          languageCode: 'en',
          studyWeekdays: {1, 3, 5},
          scheduleConfigured: true,
          quickActions: [
            HomeQuickAction.stats,
            HomeQuickAction.library,
            HomeQuickAction.study,
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(store),
          appClockProvider.overrideWithValue(() => now),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-custom-quick-actions')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-action-0-stats')), findsOneWidget);
    expect(
      find.byKey(const Key('home-quick-action-1-library')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-rest-day-banner')), findsOneWidget);
    expect(find.textContaining('다음 학습 8/3'), findsOneWidget);
    expect(find.byKey(const Key('home-first-recommendation')), findsOneWidget);
  });

  testWidgets(
    'completed setup applies queue, game, theme, and access choices',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1100);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final app = tester.element(find.byType(SpracheApp));
      final container = ProviderScope.containerOf(app);

      await tester.tap(find.byKey(const Key('open-first-run-setup')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-purpose-travel')));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-level-intermediate')));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('편한 조작'));
      await tester.tap(find.byKey(const Key('onboarding-theme-dark')));
      await tester.tap(find.byKey(const Key('onboarding-accent-ocean')));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('complete-first-run-setup')),
      );
      await tester.tap(find.byKey(const Key('complete-first-run-setup')));
      await tester.pumpAndSettle();

      final preferences = container.read(appControllerProvider).preferences;
      expect(preferences.onboardingCompleted, isTrue);
      expect(preferences.onboardingProfile.purpose, LearningPurpose.travel);
      expect(preferences.newItemLimit, 6);
      expect(preferences.sessionItemLimit, 10);
      expect(preferences.sessionPlan.title, '여행 필수 표현');
      expect(preferences.sessionPlan.mode, StudyMode.sentences);
      expect(preferences.experience.highContrast, isTrue);
      expect(preferences.experience.accentPalette.name, 'ocean');
      expect(
        preferences.interaction.practiceCatalog.quickLaunchActivityIds,
        contains('pronunciation'),
      );
      expect(
        preferences.interaction.practiceCatalog
            .launchFor('pronunciation')
            .largeControls,
        isTrue,
      );
    },
  );
}
