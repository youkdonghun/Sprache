import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/onboarding_profile.dart';
import 'package:sprache/src/widgets/onboarding_setup_dialog.dart';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    OnboardingProfile profile = const OnboardingProfile(),
    ValueChanged<OnboardingProfile>? onDraft,
    ValueChanged<OnboardingSetupResult>? onComplete,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingSetupPanel(
            initialLanguage: LanguageTag.english,
            initialProfile: profile,
            onDraft: onDraft ?? (_) {},
            onComplete: onComplete ?? (_) {},
            onLater: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('short step flow exposes progress, previous, and later actions', (
    tester,
  ) async {
    final drafts = <OnboardingProfile>[];
    await pumpPanel(tester, onDraft: drafts.add);

    expect(find.textContaining('1/2단계'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-previous')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-later')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-purpose-travel')));
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2/2단계'), findsOneWidget);
    expect(drafts.last.purpose, LearningPurpose.travel);
    expect(drafts.last.draftStep, 1);
  });

  testWidgets('legacy saved draft resumes at the compact final step', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      profile: const OnboardingProfile(
        draftStep: 3,
        themeMode: OnboardingThemeMode.dark,
        accent: OnboardingAccent.ocean,
      ),
    );

    expect(find.textContaining('2/2단계'), findsOneWidget);
    expect(find.text('준비됐어요'), findsOneWidget);
    expect(find.byKey(const Key('complete-first-run-setup')), findsOneWidget);
  });

  testWidgets('review shows one sample and an account-free quick start', (
    tester,
  ) async {
    OnboardingSetupResult? completed;
    await pumpPanel(
      tester,
      profile: const OnboardingProfile(
        languageCode: 'ja',
        purpose: LearningPurpose.travel,
        draftStep: 5,
      ),
      onComplete: (result) => completed = result,
    );

    expect(find.byKey(const Key('onboarding-sample-1')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-sample-2')), findsNothing);
    expect(find.textContaining('로그인 없이 체험'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-first-run-setup')));
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.language, LanguageTag.japanese);
    expect(completed!.profile.entryChoice, OnboardingEntryChoice.sampleLesson);
  });
}
