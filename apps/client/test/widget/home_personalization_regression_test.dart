import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    required AppExperiencePreferences experience,
    Iterable<LearningItem> items = const [],
    Size size = const Size(900, 1100),
    double textScale = 1,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
    });

    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:en',
        experience: experience,
      ),
    );
    await store.saveCustomItems(items);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('home renders header, XP, today plan, and default data section', (
    tester,
  ) async {
    await pumpHome(tester, experience: const AppExperiencePreferences());

    expect(find.byKey(const Key('home-header')), findsOneWidget);
    expect(find.byKey(const Key('home-xp-summary')), findsOneWidget);
    expect(find.byKey(const Key('home-today-plan')), findsOneWidget);
    expect(
      find.byKey(const Key('home-today-plan-summary-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-target-summary-row')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-today-plan'))).height,
      lessThan(100),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('home-weekly-target-summary-row')))
          .height,
      lessThanOrEqualTo(60),
    );
    expect(find.byKey(const Key('learning-data-flow-card')), findsOneWidget);
  });

  testWidgets('home hides optional chrome and respects personalized ordering', (
    tester,
  ) async {
    const recentItem = LearningItem(
      id: 'personalized-recent-item',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'clarity',
      translations: ['명확함'],
      acceptedAnswers: ['명확함'],
    );
    await pumpHome(
      tester,
      experience: const AppExperiencePreferences(
        showHomeHeader: false,
        showXp: false,
        showTodayPlan: false,
        showPinnedCollections: false,
        showRecentAdditions: true,
        showDataFlow: true,
        showSchedules: false,
        homeSectionOrder: [
          AppHomeSection.recentAdditions,
          AppHomeSection.dataFlow,
          AppHomeSection.pinnedCollections,
          AppHomeSection.schedules,
        ],
      ),
      items: const [recentItem],
    );

    expect(find.byKey(const Key('home-header')), findsNothing);
    expect(find.byKey(const Key('home-xp-summary')), findsNothing);
    expect(find.byKey(const Key('home-today-plan')), findsNothing);
    expect(find.byKey(const Key('home-pinned-collections')), findsNothing);
    expect(find.byKey(const Key('home-scheduled-plans')), findsNothing);

    final recent = find.byKey(const Key('recent-additions-tray'));
    final dataFlow = find.byKey(const Key('learning-data-flow-card'));
    expect(recent, findsOneWidget);
    expect(dataFlow, findsOneWidget);
    expect(
      tester.getTopLeft(recent).dy,
      lessThan(tester.getTopLeft(dataFlow).dy),
    );
  });

  testWidgets('wide home layout visibly switches focus and insight priority', (
    tester,
  ) async {
    const size = Size(1280, 900);

    await pumpHome(
      tester,
      size: size,
      experience: const AppExperiencePreferences(
        homeLayout: AppHomeLayout.balanced,
      ),
    );
    var primary = find.byKey(const Key('home-next-study-card'));
    var insights = find.byKey(const Key('home-today-plan'));
    expect(
      tester.getTopLeft(primary).dx,
      lessThan(tester.getTopLeft(insights).dx),
    );

    await pumpHome(
      tester,
      size: size,
      experience: const AppExperiencePreferences(
        homeLayout: AppHomeLayout.insights,
      ),
    );
    primary = find.byKey(const Key('home-next-study-card'));
    insights = find.byKey(const Key('home-today-plan'));
    expect(
      tester.getTopLeft(insights).dx,
      lessThan(tester.getTopLeft(primary).dx),
    );

    await pumpHome(
      tester,
      size: size,
      experience: const AppExperiencePreferences(
        homeLayout: AppHomeLayout.focus,
      ),
    );
    primary = find.byKey(const Key('home-next-study-card'));
    insights = find.byKey(const Key('home-today-plan'));
    expect(
      tester.getTopLeft(primary).dy,
      lessThan(tester.getTopLeft(insights).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact density reduces home chrome while preserving actions', (
    tester,
  ) async {
    await pumpHome(
      tester,
      experience: const AppExperiencePreferences(density: AppDensity.compact),
    );

    final pagePadding = tester.widget<SliverPadding>(
      find.byKey(const Key('home-page-padding')),
    );
    expect(pagePadding.padding.resolve(TextDirection.ltr).left, 12);
    expect(find.text('오늘 체크리스트'), findsOneWidget);
    expect(find.text('오늘의 영어'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('home-custom-quick-actions'))).height,
      lessThanOrEqualTo(56),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('home-weekly-target-summary-row')))
          .height,
      lessThanOrEqualTo(50),
    );
    expect(
      tester.getSize(find.byKey(const Key('home-today-plan'))).height,
      lessThanOrEqualTo(60),
    );
    expect(
      tester.getSize(find.byKey(const Key('home-primary-study-button'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px large text keeps home quick-action labels readable', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(320, 640),
      textScale: 1.3,
      experience: const AppExperiencePreferences(),
    );

    final actions = [
      find.byKey(const Key('home-quick-action-0-study')),
      find.byKey(const Key('home-quick-action-1-quickAdd')),
      find.byKey(const Key('home-quick-action-2-practice')),
    ];
    for (final action in actions) {
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
      final label = find.descendant(of: action, matching: find.byType(Text));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(
      tester.getTopLeft(actions[0]).dy,
      equals(tester.getTopLeft(actions[1]).dy),
    );
    expect(
      tester.getTopLeft(actions[2]).dy,
      greaterThan(tester.getTopLeft(actions[0]).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent additions limits the dashboard preview to three items', (
    tester,
  ) async {
    final items = List.generate(
      4,
      (index) => LearningItem(
        id: 'compact-recent-$index',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        subjectId: 'language:en',
        text: 'recent $index',
        translations: ['최근 $index'],
        acceptedAnswers: ['최근 $index'],
        updatedAt: DateTime(2026, 8, index + 1),
      ),
    );
    await pumpHome(
      tester,
      experience: const AppExperiencePreferences(
        density: AppDensity.compact,
        showDataFlow: false,
      ),
      items: items,
    );

    final tray = find.byKey(const Key('recent-additions-tray'));
    expect(tray, findsOneWidget);
    expect(
      find.descendant(of: tray, matching: find.byType(ListTile)),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const Key('home-view-all-recent-additions')),
      findsOneWidget,
    );
    expect(find.text('recent 0'), findsNothing);
    expect(find.text('recent 3'), findsOneWidget);
  });
}
