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

    expect(find.text('1/6단계 · 고른 내용은 이 기기에 바로 저장돼요.'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-previous')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-later')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-purpose-travel')));
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2/6단계'), findsOneWidget);
    expect(drafts.last.purpose, LearningPurpose.travel);
    expect(drafts.last.draftStep, 1);
  });

  testWidgets('saved draft resumes at appearance and previews actual theme', (
    tester,
  ) async {
    final drafts = <OnboardingProfile>[];
    await pumpPanel(
      tester,
      profile: const OnboardingProfile(
        draftStep: 3,
        themeMode: OnboardingThemeMode.dark,
        accent: OnboardingAccent.ocean,
      ),
      onDraft: drafts.add,
    );

    expect(find.textContaining('4/6단계'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-theme-preview')), findsOneWidget);
    await tester.tap(find.text('편한 조작'));
    await tester.pumpAndSettle();

    expect(drafts.last.easyAccess, isTrue);
    expect(find.textContaining('큰 버튼 · 큰 글자 · 고대비'), findsOneWidget);
  });

  testWidgets('quick actions remain exactly three and can be reordered', (
    tester,
  ) async {
    final drafts = <OnboardingProfile>[];
    await pumpPanel(
      tester,
      profile: const OnboardingProfile(draftStep: 4),
      onDraft: drafts.add,
    );

    expect(find.byKey(const Key('onboarding-quick-action-0')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-quick-action-1')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-quick-action-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-quick-action-down-0')));
    await tester.pumpAndSettle();

    expect(drafts.last.quickActions, [
      HomeQuickAction.quickAdd,
      HomeQuickAction.study,
      HomeQuickAction.practice,
    ]);
  });

  testWidgets('review shows three samples, estimate, and account-free result', (
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
    expect(find.byKey(const Key('onboarding-sample-2')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-sample-3')), findsOneWidget);
    expect(find.textContaining('천천히 풀어도 괜찮아요'), findsOneWidget);
    expect(find.textContaining('샘플 학습에는 계정이 필요 없어요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-first-run-setup')));
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.language, LanguageTag.japanese);
    expect(completed!.profile.entryChoice, OnboardingEntryChoice.sampleLesson);
  });
}
