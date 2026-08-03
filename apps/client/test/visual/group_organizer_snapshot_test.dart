import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/state/app_state.dart';

const _snapshotItems = [
  LearningItem(
    id: 'snapshot-passport',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'passport',
    translations: ['여권'],
    acceptedAnswers: ['여권'],
    tags: ['group:여행 준비'],
    partOfSpeech: PartOfSpeech.noun,
  ),
  LearningItem(
    id: 'snapshot-reservation',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'reservation',
    translations: ['예약'],
    acceptedAnswers: ['예약'],
    tags: ['group:여행 준비', 'group:이번 주'],
    partOfSpeech: PartOfSpeech.noun,
  ),
  LearningItem(
    id: 'snapshot-itinerary',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'itinerary',
    translations: ['여행 일정'],
    acceptedAnswers: ['여행 일정'],
    partOfSpeech: PartOfSpeech.noun,
  ),
];

void main() {
  testWidgets('desktop group organizer stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    final store = MemoryStudyStore();
    await store.saveCustomItems(_snapshotItems);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/library/groups');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-group-organizer.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('narrow Windows group board stays side by side', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 760);
    final store = MemoryStudyStore();
    await store.saveCustomItems(_snapshotItems);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/library/groups');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/windows-narrow-group-organizer.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('mobile ${brightness.name} group organizer stays stable', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          brightness;
      final store = MemoryStudyStore();
      await store.saveCustomItems(_snapshotItems);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        container.read(appRouterProvider).go('/library/groups');
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/mobile-group-organizer'
            '${brightness == Brightness.dark ? '-dark' : ''}.png',
          ),
        );

        final mobileSelection = find.byKey(
          const Key('group-organizer-item-snapshot-itinerary'),
        );
        await tester.ensureVisible(mobileSelection);
        await tester.tap(mobileSelection);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/mobile-group-organizer-selected'
            '${brightness == Brightness.dark ? '-dark' : ''}.png',
          ),
        );

        await tester.tap(find.byKey(const Key('open-mobile-group-targets')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/mobile-group-manager'
            '${brightness == Brightness.dark ? '-dark' : ''}.png',
          ),
        );
      } finally {
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }
}
