import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'compact hub prioritizes recommendations recent and favorites before catalog',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        openGames: false,
        preferences: const StudyPreferences(
          onboardingCompleted: true,
          interaction: StudyInteractionPreferences(
            practiceCatalog: PracticeCatalogPreferences(
              recentActivityIds: ['meaning-choice'],
              favoriteActivityIds: {'production-writing'},
              launchCountByActivityId: {'meaning-choice': 3},
              sortOrder: PracticeCatalogSort.name,
            ),
          ),
        ),
      );

      final recommendations = find.byKey(
        const Key('personalized-practice-hub'),
      );
      final recent = find.byKey(const Key('recent-practice-games'));
      final favorites = find.byKey(const Key('favorite-practice-games'));
      final quizCatalog = find.byKey(const Key('practice-category-퀴즈'));

      expect(recommendations, findsOneWidget);
      expect(recent, findsOneWidget);
      expect(favorites, findsOneWidget);
      expect(quizCatalog, findsNothing);
      expect(find.text('짧게 풀고 바로 피드백을 받아요.'), findsNothing);

      await tester.tap(find.text('전체 게임'));
      await tester.pumpAndSettle();
      expect(recommendations, findsNothing);
      expect(recent, findsOneWidget);
      expect(favorites, findsOneWidget);
      expect(quizCatalog, findsOneWidget);
      expect(
        find.byKey(const Key('practice-search-result-summary')),
        findsOneWidget,
      );

      await _tapVisible(
        tester,
        find.byKey(const Key('reset-practice-filters')),
      );
      final catalog = harness
          .read(appControllerProvider)
          .preferences
          .interaction
          .practiceCatalog;
      expect(catalog.durationFilter, PracticeDurationFilter.any);
      expect(catalog.skillFilter, PracticeSkillFilter.all);
      expect(catalog.sortOrder, PracticeCatalogSort.recommended);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'launch sheet keeps quick start and short presets above the fold',
    (tester) async {
      final harness = await _pumpApp(tester);

      await _tapVisible(
        tester,
        find.byKey(const Key('practice-activity-혼합 퀴즈')).first,
      );

      final inventory = find.byKey(
        const Key('practice-launch-inventory-strip'),
      );
      expect(inventory, findsOneWidget);
      expect(tester.getSize(inventory).height, 44);
      expect(find.text('5분 · 추천'), findsOneWidget);
      expect(
        find.byKey(const Key('practice-launch-use-current-rules')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const Key('practice-launch-use-current-rules')),
            )
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('practice-count-options'))).dy,
        ),
      );

      await tester.tap(
        find.byKey(const Key('practice-launch-use-current-rules')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StudyScreen), findsOneWidget);
      expect(
        harness
            .read(appControllerProvider.notifier)
            .activeSessionPlan
            .itemLimit,
        10,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('launch and builder advanced rules reset without touching core', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      preferences: StudyPreferences(
        onboardingCompleted: true,
        sessionPlan: StudySessionPlan(
          difficulty: StudyDifficulty.weak,
          examSchedule: ExamSchedule(targetDate: DateTime.utc(2026, 9, 1)),
        ),
        interaction: const StudyInteractionPreferences(
          practiceCatalog: PracticeCatalogPreferences(
            launchByActivityId: {
              'mixed-quiz': PracticeLaunchPreferences(
                difficulty: PracticeDifficultyPreset.challenge,
                historyScope: PracticeHistoryScope.excludeCorrect,
                queueOrder: PracticeQueueOrder.newFirst,
                hintsEnabled: false,
                autoAdvance: true,
              ),
            },
          ),
        ),
      ),
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('practice-activity-혼합 퀴즈')).first,
    );
    expect(find.byKey(const Key('reset-practice-rules')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-practice-rules')));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-advanced-settings')),
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('practice-difficulty-balanced')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('practice-history-all')))
          .selected,
      isTrue,
    );
    Navigator.of(
      tester.element(find.byKey(const Key('practice-advanced-settings'))),
    ).pop();
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const Key('open-session-builder')));
    final summary = find.byKey(const Key('mobile-session-summary'));
    final quick = find.byKey(const Key('quick-session-presets'));
    final core = find.byKey(const Key('mobile-session-core-settings'));
    expect(tester.getSize(summary).height, lessThan(80));
    expect(find.byKey(const Key('saved-session-plans')), findsNothing);
    expect(tester.getTopLeft(quick).dy, lessThan(tester.getTopLeft(core).dy));

    await _tapVisible(
      tester,
      find.byKey(const Key('session-advanced-settings')),
    );
    await _chooseOption(
      tester,
      fieldKey: 'session-difficulty-select',
      optionKey: 'session-difficulty-weak',
    );
    expect(
      find.byKey(const Key('reset-session-advanced-settings')),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('reset-session-advanced-settings')),
    );
    expect(
      tester
          .widget<DropdownButtonFormField<StudyDifficulty>>(
            find.byKey(const Key('session-difficulty-select')),
          )
          .initialValue,
      StudyDifficulty.all,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<StudyHistoryFilter>>(
            find.byKey(const Key('session-history-select')),
          )
          .initialValue,
      StudyHistoryFilter.all,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<StudyQueuePriority>>(
            find.byKey(const Key('session-priority-select')),
          )
          .initialValue,
      StudyQueuePriority.dueFirst,
    );
    expect(find.text('세부 설정'), findsOneWidget);
    expect(find.textContaining('개 적용'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in const [
    (
      label: 'word-only',
      includeWords: true,
      includeSentences: false,
      initialRatio: 0.0,
      initialAdvancedCount: 1,
      expectedRatio: 0.0,
    ),
    (
      label: 'sentence-only',
      includeWords: false,
      includeSentences: true,
      initialRatio: 1.0,
      initialAdvancedCount: 1,
      expectedRatio: 1.0,
    ),
    (
      label: 'mixed',
      includeWords: true,
      includeSentences: true,
      initialRatio: 0.7,
      initialAdvancedCount: 2,
      expectedRatio: 0.3,
    ),
  ]) {
    testWidgets(
      'advanced reset preserves ${scenario.label} core content ratio',
      (tester) async {
        await _pumpApp(
          tester,
          preferences: StudyPreferences(
            onboardingCompleted: true,
            sessionPlan: StudySessionPlan(
              includeWords: scenario.includeWords,
              includeSentences: scenario.includeSentences,
              sentenceRatio: scenario.initialRatio,
              difficulty: StudyDifficulty.weak,
            ),
          ),
        );

        await _tapVisible(
          tester,
          find.byKey(const Key('open-session-builder')),
        );
        expect(
          find.text('세부 설정 · ${scenario.initialAdvancedCount}개 적용'),
          findsOneWidget,
        );
        await _tapVisible(
          tester,
          find.byKey(const Key('session-advanced-settings')),
        );
        await _tapVisible(
          tester,
          find.byKey(const Key('reset-session-advanced-settings')),
        );

        expect(
          tester
              .widget<Slider>(find.byKey(const Key('session-sentence-ratio')))
              .value,
          closeTo(scenario.expectedRatio, 0.001),
        );
        expect(find.text('세부 설정'), findsOneWidget);
        expect(find.textContaining('개 적용'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  bool openGames = true,
  StudyPreferences preferences = const StudyPreferences(
    onboardingCompleted: true,
  ),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(
          MemoryStudyStore(preferences: preferences),
        ),
      ],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav-learn')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('toggle-advanced-practice')));
  await tester.pumpAndSettle();
  if (openGames) {
    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();
  }
  return ProviderScope.containerOf(tester.element(find.byType(SpracheApp)));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseOption(
  WidgetTester tester, {
  required String fieldKey,
  required String optionKey,
}) async {
  final field = find.byKey(Key(fieldKey));
  await _tapVisible(tester, field);
  final option = find.byKey(Key(optionKey));
  expect(option, findsWidgets);
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}
