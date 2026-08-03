import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'game discovery filters, sorting, recommendation controls, and surprise rules persist',
    (tester) async {
      final container = await _pumpLearningHub(tester, openGames: false);

      final menu = find.byKey(
        const Key('practice-recommendation-menu-words-review'),
      );
      await _tapVisible(tester, menu);
      await tester.tap(find.text('이런 게임 더 보기'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appControllerProvider)
            .preferences
            .interaction
            .practiceCatalog
            .recommendationWeightByActivityId['words-review'],
        1,
      );

      await _tapVisible(tester, menu);
      await tester.tap(find.text('오늘 추천에서 숨기기'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appControllerProvider)
            .preferences
            .interaction
            .practiceCatalog
            .recommendationSnoozedUntilByActivityId,
        contains('words-review'),
      );

      await tester.tap(find.text('전체 게임'));
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(const Key('practice-discovery-controls')),
      );

      await _tapVisible(
        tester,
        find.byKey(const Key('practice-duration-filter-threeMinutes')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('practice-skill-filter-listening')),
      );
      if (find
          .byKey(const Key('practice-sort-launchCount'))
          .evaluate()
          .isEmpty) {
        await _tapVisible(
          tester,
          find.byKey(const Key('practice-discovery-controls')),
        );
      }
      await _tapVisible(
        tester,
        find.byKey(const Key('practice-sort-launchCount')),
      );

      var catalog = container
          .read(appControllerProvider)
          .preferences
          .interaction
          .practiceCatalog;
      expect(catalog.durationFilter, PracticeDurationFilter.threeMinutes);
      expect(catalog.skillFilter, PracticeSkillFilter.listening);
      expect(catalog.sortOrder, PracticeCatalogSort.launchCount);

      await _tapVisible(
        tester,
        find.byKey(const Key('practice-surprise-settings')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('surprise-duration-tenMinutes')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('surprise-skill-speaking')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('surprise-favorites-only')),
      );
      await _tapVisible(tester, find.byKey(const Key('surprise-avoid-recent')));
      await _tapVisible(
        tester,
        find.byKey(const Key('save-surprise-settings')),
      );

      catalog = container
          .read(appControllerProvider)
          .preferences
          .interaction
          .practiceCatalog;
      expect(catalog.surpriseDurationFilter, PracticeDurationFilter.tenMinutes);
      expect(catalog.surpriseSkillFilter, PracticeSkillFilter.speaking);
      expect(catalog.surpriseFavoritesOnly, isTrue);
      expect(catalog.surpriseAvoidRecent, isFalse);
    },
  );

  testWidgets(
    'recent game relaunches with its last rules and increments frequency',
    (tester) async {
      const interaction = StudyInteractionPreferences(
        practiceCatalog: PracticeCatalogPreferences(
          recentActivityIds: ['meaning-choice'],
          launchCountByActivityId: {'meaning-choice': 4},
          launchByActivityId: {
            'meaning-choice': PracticeLaunchPreferences(
              length: PracticeSessionLength.fiveItems,
              itemCount: 5,
              challengeScoringEnabled: true,
            ),
          },
        ),
      );
      final container = await _pumpLearningHub(
        tester,
        preferences: const StudyPreferences(
          onboardingCompleted: true,
          interaction: interaction,
        ),
      );

      await _tapVisible(
        tester,
        find.byKey(const Key('recent-practice-meaning-choice')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StudyScreen), findsOneWidget);
      expect(find.byKey(const Key('start-practice-session')), findsNothing);
      expect(
        container
            .read(appControllerProvider)
            .preferences
            .interaction
            .practiceCatalog
            .launchCountByActivityId['meaning-choice'],
        5,
      );
    },
  );

  testWidgets(
    'two study games can be saved and started as a sequential playlist',
    (tester) async {
      final container = await _pumpLearningHub(tester);

      for (final id in const ['meaning-choice', 'production-writing']) {
        await _tapVisible(tester, find.byKey(Key('practice-menu-$id')));
        await tester.tap(find.byKey(Key('practice-playlist-$id')));
        await tester.pumpAndSettle();
      }

      await _tapVisible(
        tester,
        find.byKey(const Key('save-practice-playlist')),
      );
      final playlist = container
          .read(appControllerProvider)
          .preferences
          .interaction
          .practiceCatalog
          .playlists
          .single;
      expect(playlist.activityIds, ['meaning-choice', 'production-writing']);

      await _tapVisible(
        tester,
        find.byKey(Key('start-practice-playlist-${playlist.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StudyScreen), findsOneWidget);
      final screen = tester.widget<StudyScreen>(find.byType(StudyScreen));
      expect(screen.playlistActivityIds, [
        'meaning-choice',
        'production-writing',
      ]);
      expect(screen.playlistIndex, 0);
    },
  );
}

Future<ProviderContainer> _pumpLearningHub(
  WidgetTester tester, {
  bool openGames = true,
  StudyPreferences preferences = const StudyPreferences(
    onboardingCompleted: true,
  ),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1100);
  addTearDown(() {
    tester.view.reset();
  });
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
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SpracheApp)),
  );
  container.read(appRouterProvider).go('/learn');
  await tester.pumpAndSettle();
  if (openGames) {
    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();
  }
  return container;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final hitTestableFinder = finder.hitTestable();
  expect(hitTestableFinder, findsOneWidget);
  await tester.tap(hitTestableFinder);
  await tester.pumpAndSettle();
}
