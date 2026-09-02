import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('Windows moves selected material with a left-to-right drag', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    const source = LearningItem(
      id: 'group-board-source',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'boarding pass',
      translations: ['탑승권'],
      acceptedAnswers: ['탑승권'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const grouped = LearningItem(
      id: 'group-board-target-seed',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'passport',
      translations: ['여권'],
      acceptedAnswers: ['여권'],
      tags: ['group:여행'],
      partOfSpeech: PartOfSpeech.noun,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([source, grouped]);

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

      expect(
        find.byKey(const Key('group-organizer-source-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('group-organizer-target-panel')),
        findsOneWidget,
      );
      expect(find.textContaining('왼쪽에서 자료를 고르거나'), findsOneWidget);

      final sourceFinder = find.byKey(
        const Key('group-organizer-item-group-board-source'),
      );
      final targetFinder = find.byKey(const Key('group-organizer-target-여행'));
      final sourceCenter = tester.getCenter(sourceFinder);
      final targetCenter = tester.getCenter(targetFinder);
      await tester.dragFrom(sourceCenter, targetCenter - sourceCenter);
      await tester.pumpAndSettle();

      final saved = store.savedItems.firstWhere((item) => item.id == source.id);
      expect(learningGroupsOf(saved), {'여행'});
      expect(find.textContaining('“여행” 그룹에 추가'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile uses select then choose-group flow', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    const source = LearningItem(
      id: 'mobile-group-source',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'itinerary',
      translations: ['여행 일정'],
      acceptedAnswers: ['여행 일정'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const grouped = LearningItem(
      id: 'mobile-group-target-seed',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'luggage',
      translations: ['짐'],
      acceptedAnswers: ['짐'],
      tags: ['group:여행'],
      partOfSpeech: PartOfSpeech.noun,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([source, grouped]);

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

      expect(find.textContaining('자료를 고른 뒤 넣을 그룹'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('group-organizer-item-mobile-group-source')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-mobile-group-targets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-group-target-여행')));
      await tester.pumpAndSettle();

      final saved = store.savedItems.firstWhere((item) => item.id == source.id);
      expect(learningGroupsOf(saved), {'여행'});
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets(
    'narrow Windows keeps the split board and supports keyboard range selection',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 760);
      final store = MemoryStudyStore();
      await store.saveCustomItems(const [
        LearningItem(
          id: 'range-first',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'range item first',
          translations: ['첫째'],
          acceptedAnswers: ['첫째'],
        ),
        LearningItem(
          id: 'range-second',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'range item second',
          translations: ['둘째'],
          acceptedAnswers: ['둘째'],
        ),
        LearningItem(
          id: 'range-third',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'range item third',
          translations: ['셋째'],
          acceptedAnswers: ['셋째'],
          tags: ['group:범위'],
        ),
      ]);

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

        expect(
          find.byKey(const Key('group-organizer-source-panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('group-organizer-target-panel')),
          findsOneWidget,
        );

        final search = find.byKey(const Key('group-organizer-search'));
        await tester.enterText(search, 'range item');
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text('3개 선택'), findsOneWidget);

        await tester.enterText(search, 'range item first');
        await tester.pumpAndSettle();
        expect(find.text('3개 선택 · 숨김 2'), findsOneWidget);

        await tester.tap(find.byKey(const Key('clear-group-selection')));
        await tester.pumpAndSettle();
        expect(find.textContaining('개 선택'), findsNothing);

        await tester.enterText(search, 'range item');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('group-organizer-item-range-first')),
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(
          find.byKey(const Key('group-organizer-item-range-third')),
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(find.text('3개 선택'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.textContaining('개 선택'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets(
    'group move previews impact, protects unlink, and can be undone',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1120, 780);
      const source = LearningItem(
        id: 'impact-source',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'impact preview term',
        translations: ['영향 미리보기'],
        acceptedAnswers: ['영향 미리보기'],
        tags: ['group:기존 그룹'],
      );
      const seed = LearningItem(
        id: 'impact-target',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'target group seed',
        translations: ['대상 그룹'],
        acceptedAnswers: ['대상 그룹'],
        tags: ['group:새 그룹'],
      );
      final store = MemoryStudyStore();
      await store.saveCustomItems([source, seed]);

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

        await tester.enterText(
          find.byKey(const Key('group-organizer-search')),
          'impact preview term',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('group-organizer-item-impact-source')),
        );
        await tester.tap(find.text('이동'));
        await tester.pumpAndSettle();
        final target = find.byKey(const Key('group-organizer-target-새 그룹'));
        await tester.ensureVisible(target);
        final moveButton = find.descendant(
          of: target,
          matching: find.text('여기에 넣기'),
        );
        await tester.ensureVisible(moveButton);
        await tester.pumpAndSettle();
        await tester.tap(moveButton);
        await tester.pumpAndSettle();

        expect(find.text('선택 자료의 그룹을 이동할까요?'), findsOneWidget);
        expect(find.text('현재 그룹 연결'), findsOneWidget);
        expect(find.text('1개 · 1개 그룹'), findsOneWidget);
        expect(find.text('새 그룹'), findsWidgets);
        await tester.tap(find.byKey(const Key('confirm-group-impact')));
        await tester.pumpAndSettle();
        expect(
          learningGroupsOf(
            store.savedItems.firstWhere((item) => item.id == source.id),
          ),
          {'새 그룹'},
        );

        await tester.tap(find.text('실행 취소'));
        await tester.pumpAndSettle();
        expect(
          learningGroupsOf(
            store.savedItems.firstWhere((item) => item.id == source.id),
          ),
          {'기존 그룹'},
        );

        final unlinkTarget = find.byKey(
          const Key('group-organizer-ungrouped-target'),
        );
        await tester.ensureVisible(unlinkTarget);
        await tester.tap(
          find.descendant(of: unlinkTarget, matching: find.text('그룹에서 빼기')),
        );
        await tester.pumpAndSettle();
        expect(find.text('선택한 자료를 모든 그룹에서 뺄까요?'), findsOneWidget);
        expect(find.textContaining('자료와 학습 기록은 그대로 남아요.'), findsOneWidget);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(
          learningGroupsOf(
            store.savedItems.firstWhere((item) => item.id == source.id),
          ),
          {'기존 그룹'},
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets(
    'moving to another subject keeps the current subject until opened',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 760);
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(
          customSubjects: [
            StudySubject(
              id: 'general:work',
              kind: StudySubjectKind.general,
              name: '업무',
              description: '회사 표현',
              symbol: '💼',
              contentLanguage: LanguageTag.korean,
            ),
          ],
        ),
      );
      await store.saveCustomItems(const [
        LearningItem(
          id: 'subject-move-source',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'subject move term',
          translations: ['주제 이동'],
          acceptedAnswers: ['주제 이동'],
        ),
      ]);

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
        await tester.enterText(
          find.byKey(const Key('group-organizer-search')),
          'subject move term',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('group-organizer-item-subject-move-source')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('organizer-move-items-to-subject')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('organizer-move-to-subject-general:work')),
        );
        await tester.pumpAndSettle();

        expect(
          container.read(appControllerProvider.notifier).activeSubject.id,
          'language:en',
        );
        expect(find.byKey(const Key('open-moved-subject')), findsOneWidget);
        await tester.tap(find.byKey(const Key('open-moved-subject')));
        await tester.pumpAndSettle();
        expect(
          container.read(appControllerProvider.notifier).activeSubject.id,
          'general:work',
        );
        expect(find.textContaining('업무 자료실'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets(
      'group organizer fits ${size.width.toInt()}px in light and dark',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;

        try {
          for (final brightness in [Brightness.light, Brightness.dark]) {
            tester.binding.platformDispatcher.platformBrightnessTestValue =
                brightness;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  studyStoreProvider.overrideWithValue(MemoryStudyStore()),
                ],
                child: const SpracheApp(),
              ),
            );
            await tester.pumpAndSettle();
            final container = ProviderScope.containerOf(
              tester.element(find.byType(SpracheApp)),
            );
            container.read(appRouterProvider).go('/library/groups');
            await tester.pumpAndSettle();

            expect(
              find.byKey(const Key('group-organizer-source-panel')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        } finally {
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
        }
      },
    );
  }

  testWidgets(
    'library explains app cache, Drive, and hidden binding ownership',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        container.read(appRouterProvider).go('/library');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('learning-data-flow-card')), findsNothing);
        expect(find.byKey(const Key('library-search-field')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets('group add keeps the batch selected and group move clears it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    const source = LearningItem(
      id: 'batch-source',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'transfer',
      translations: ['옮기다'],
      acceptedAnswers: ['옮기다'],
      partOfSpeech: PartOfSpeech.verb,
    );
    const groupA = LearningItem(
      id: 'batch-group-a',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'alpha',
      translations: ['알파'],
      acceptedAnswers: ['알파'],
      tags: ['group:A'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const groupB = LearningItem(
      id: 'batch-group-b',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'beta',
      translations: ['베타'],
      acceptedAnswers: ['베타'],
      tags: ['group:B'],
      partOfSpeech: PartOfSpeech.noun,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([source, groupA, groupB]);

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

      await tester.tap(
        find.byKey(const Key('group-organizer-item-batch-source')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('organizer-selection-action-bar')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('open-mobile-group-targets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-group-target-A')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('organizer-selection-action-bar')),
        findsOneWidget,
      );
      expect(
        learningGroupsOf(
          store.savedItems.firstWhere((item) => item.id == source.id),
        ),
        {'A'},
      );

      await tester.tap(find.byKey(const Key('open-mobile-group-targets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-group-target-B')));
      await tester.pumpAndSettle();
      expect(
        learningGroupsOf(
          store.savedItems.firstWhere((item) => item.id == source.id),
        ),
        {'A', 'B'},
      );

      await tester.tap(find.byKey(const Key('organizer-selection-group-move')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-group-target-B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-group-impact')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('organizer-selection-action-bar')),
        findsNothing,
      );
      expect(
        learningGroupsOf(
          store.savedItems.firstWhere((item) => item.id == source.id),
        ),
        {'B'},
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
