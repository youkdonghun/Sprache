import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'a user can inspect, rename, and delete a group without losing items',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      const word = LearningItem(
        id: 'group-ui-word',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'reservation',
        translations: ['예약'],
        acceptedAnswers: ['예약'],
        tags: ['group:여행'],
        partOfSpeech: PartOfSpeech.noun,
      );
      const sentence = LearningItem(
        id: 'group-ui-sentence',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        text: 'I have a reservation.',
        translations: ['예약했습니다.'],
        acceptedAnswers: ['예약했습니다.'],
        tags: ['group:여행'],
        sentenceTokens: ['I', 'have', 'a', 'reservation.'],
      );
      final store = MemoryStudyStore(
        profile: const StoredProfile(
          selectedLanguage: LanguageTag.english,
          totalXp: 0,
          streakDays: 0,
          dailyXp: 0,
          badges: {},
          driveConnected: false,
          progress: {
            'group-ui-word': ProgressRecord(
              itemId: 'group-ui-word',
              correctCount: 3,
              wrongCount: 1,
            ),
          },
        ),
      );
      await store.saveCustomItems([word, sentence]);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('자료실').last);
        await tester.pumpAndSettle();
        final groupChip = find.byKey(
          const ValueKey('mobile-learning-group-여행'),
        );
        await tester.ensureVisible(groupChip);
        await tester.tap(groupChip);
        await tester.pumpAndSettle();

        expect(find.textContaining('전체 2개 · 단어 1 · 문장 1'), findsOneWidget);
        expect(find.textContaining('정확도 75%'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('rename-learning-group')),
        );
        await tester.tap(find.byKey(const Key('rename-learning-group')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('rename-learning-group-input')),
          '여행 준비',
        );
        await tester.tap(
          find.byKey(const Key('confirm-rename-learning-group')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('mobile-learning-group-여행 준비')),
          findsOneWidget,
        );
        expect(
          store.savedItems.every(
            (item) => learningGroupsOf(item).contains('여행 준비'),
          ),
          isTrue,
        );

        await tester.ensureVisible(
          find.byKey(const Key('delete-learning-group')),
        );
        await tester.tap(find.byKey(const Key('delete-learning-group')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('confirm-delete-learning-group')),
        );
        await tester.pumpAndSettle();

        expect(find.text('여행 준비'), findsNothing);
        expect(store.savedItems, hasLength(2));
        expect(
          store.savedItems.every((item) => learningGroupsOf(item).isEmpty),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets('a group quiz preset starts the selected group immediately', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    const item = LearningItem(
      id: 'group-quiz-word',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'itinerary',
      translations: ['여행 일정'],
      acceptedAnswers: ['여행 일정'],
      tags: ['group:여행 준비'],
      partOfSpeech: PartOfSpeech.noun,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([item]);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();

      final groupChip = find.byKey(
        const ValueKey('mobile-learning-group-여행 준비'),
      );
      await tester.ensureVisible(groupChip);
      await tester.tap(groupChip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('퀴즈'));
      await tester.tap(find.text('퀴즈'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('group-quiz-quick-5')), findsOneWidget);
      await tester.tap(find.byKey(const Key('group-quiz-quick-5')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('study-screen')), findsOneWidget);
      expect(store.savedPreferences.sessionPlan.deck, StudyDeckScope.selected);
      expect(store.savedPreferences.sessionPlan.mode, StudyMode.mixed);
      expect(store.savedPreferences.sessionPlan.selectedItemIds, {item.id});
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('library selection bar starts a quiz from exact materials', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    const item = LearningItem(
      id: 'library-selected-quiz',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'compact',
      translations: ['간결한'],
      acceptedAnswers: ['간결한'],
      partOfSpeech: PartOfSpeech.adjective,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([item]);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();

      final select = find.byKey(const Key('library-select-materials'));
      await tester.ensureVisible(select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('library-item-library-selected-quiz')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('library-selection-action-bar')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('library-selection-action-bar')),
          matching: find.text('선택 1개'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library-selection-group-add')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library-selection-group-move')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('library-selection-quiz')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile-session-summary')), findsOneWidget);
      expect(store.savedPreferences.sessionPlan.deck, StudyDeckScope.selected);
      expect(store.savedPreferences.sessionPlan.selectedItemIds, {item.id});
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('library search is debounced and remains case insensitive', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    const item = LearningItem(
      id: 'library-debounce-search',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'DebounceNeedle',
      translations: ['검색 지연 표식'],
      acceptedAnswers: ['검색 지연 표식'],
      partOfSpeech: PartOfSpeech.noun,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([item]);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-library')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('library-search-field')),
        'DEBOUNCENEEDLE',
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const Key('active-library-filters')),
        findsNothing,
        reason: 'the item list should not rebuild for every search keystroke',
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('library-item-library-debounce-search')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets(
    'changing subjects clears search, group filter, and bulk selection together',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      const english = LearningItem(
        id: 'subject-state-english',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'reservation',
        translations: ['예약'],
        acceptedAnswers: ['예약'],
        tags: ['group:여행'],
        partOfSpeech: PartOfSpeech.noun,
      );
      const japanese = LearningItem(
        id: 'subject-state-japanese',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.japanese,
        text: '予約',
        translations: ['예약'],
        acceptedAnswers: ['예약'],
        tags: ['group:일본'],
        partOfSpeech: PartOfSpeech.noun,
      );
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(
          onboardingCompleted: true,
          activeSubjectId: 'language:en',
        ),
      );
      await store.saveCustomItems([english, japanese]);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav-library')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('library-search-field')),
          'reservation',
        );
        await tester.pump(const Duration(milliseconds: 210));
        final englishGroup = find.byKey(
          const ValueKey('mobile-learning-group-여행'),
        );
        await tester.ensureVisible(englishGroup);
        await tester.tap(englishGroup);
        await tester.pumpAndSettle();

        final select = find.byKey(const Key('library-select-materials'));
        tester.widget<OutlinedButton>(select).onPressed?.call();
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('library-item-subject-state-english')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('library-selection-action-bar')),
          findsOneWidget,
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        container
            .read(appControllerProvider.notifier)
            .selectSubject('language:ja');
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const Key('mobile-library-scroll')),
          const Offset(0, 1200),
        );
        await tester.pumpAndSettle();

        final searchField = tester.widget<TextField>(
          find.byKey(const Key('library-search-field')),
        );
        expect(searchField.controller?.text, isEmpty);
        expect(find.byKey(const Key('active-library-filters')), findsNothing);
        expect(
          find.byKey(const Key('library-selection-action-bar')),
          findsNothing,
        );
        expect(find.byKey(const Key('library-selection-hint')), findsNothing);
        expect(
          find.byKey(const ValueKey('mobile-learning-group-여행')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('mobile-learning-group-일본')),
          findsOneWidget,
        );
        expect(
          container
              .read(appControllerProvider)
              .customItems
              .any((item) => item.id == 'subject-state-japanese'),
          isTrue,
        );
        expect(find.text('학습 주제가 바뀌어 검색과 선택을 지웠어요.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}
