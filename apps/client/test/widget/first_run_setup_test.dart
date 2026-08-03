import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/onboarding_profile.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'first run setup stores language and goal before opening learning',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final store = MemoryStudyStore();

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('first-run-setup-card')), findsOneWidget);
        await tester.tap(find.byKey(const Key('open-first-run-setup')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('onboarding-step-panel')), findsOneWidget);
        expect(
          find.byKey(const Key('onboarding-purpose-hobby')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('onboarding-language-ja')));
        await tester.tap(find.byKey(const Key('onboarding-purpose-hobby')));
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding-level-advanced')));
        await tester.tap(find.byKey(const Key('onboarding-goal-150')));
        for (var step = 0; step < 4; step++) {
          await tester.tap(find.byKey(const Key('onboarding-next')));
          await tester.pumpAndSettle();
        }

        expect(find.byKey(const Key('onboarding-import-data')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('complete-first-run-setup')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('complete-first-run-setup')));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        final state = container.read(appControllerProvider);
        expect(state.selectedLanguage, LanguageTag.japanese);
        expect(state.preferences.onboardingCompleted, isTrue);
        expect(state.preferences.dailyGoal, 150);
        expect(state.preferences.preferredMode, StudyMode.words);
        expect(state.preferences.newItemLimit, 5);
        expect(state.preferences.sessionItemLimit, 15);
        expect(
          state.preferences.onboardingProfile.purpose,
          LearningPurpose.hobby,
        );
        expect(
          state.preferences.onboardingProfile.level,
          SelfAssessedLevel.advanced,
        );
        expect(state.preferences.onboardingProfile.dailyMinutes, 10);
        expect(
          state.preferences.onboardingProfile.entryChoice,
          OnboardingEntryChoice.sampleLesson,
        );
        expect(store.savedPreferences.onboardingCompleted, isTrue);
        expect(find.byKey(const Key('study-screen')), findsOneWidget);
        expect(find.byKey(const Key('first-run-setup-card')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets('first run setup is a desktop dialog on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-first-run-setup')));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('처음 학습 설정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
