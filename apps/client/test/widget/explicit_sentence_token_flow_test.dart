import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/state/app_state.dart';

Future<void> _openQuickSentence(
  WidgetTester tester,
  MemoryStudyStore store,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav-library')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('library-add-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add-quick-sentence')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quick sentence save never creates tokens automatically', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = MemoryStudyStore();
    await _openQuickSentence(tester, store);

    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'A uniquely unsegmented sentence.',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '자동으로 나누지 않는 문장',
    );
    await tester.tap(find.byKey(const Key('quick-content-save')));
    await tester.pumpAndSettle();

    final saved = store.savedItems.single;
    expect(saved.sentenceTokens, isEmpty);
    expect(
      saved.capabilities,
      isNot(contains(ExerciseCapability.sentenceOrder)),
    );
    expect(saved.capabilities, isNot(contains(ExerciseCapability.cloze)));
  });

  testWidgets('quick sentence stores a suggestion only after explicit action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = MemoryStudyStore();
    await _openQuickSentence(tester, store);

    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'We learn together.',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '우리는 함께 배워요.',
    );
    final suggest = find.byKey(const Key('sentence-token-suggest-from-text'));
    await tester.ensureVisible(suggest);
    await tester.tap(suggest);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sentence-token-chip-2')), findsOneWidget);

    final save = find.byKey(const Key('quick-content-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = store.savedItems.single;
    expect(saved.sentenceTokens, ['We', 'learn', 'together.']);
    expect(saved.capabilities, contains(ExerciseCapability.sentenceOrder));
    expect(saved.capabilities, contains(ExerciseCapability.cloze));
  });

  testWidgets('full editor preserves existing explicit tokens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    const existing = LearningItem(
      id: 'user-explicit-token-sentence',
      kind: LearningItemKind.sentence,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'Tokens stay explicit.',
      translations: ['토큰은 명시적으로 유지됩니다.'],
      acceptedAnswers: ['토큰은 명시적으로 유지됩니다.'],
      sentenceTokens: ['Tokens', 'stay', 'explicit.'],
      capabilities: {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
        ExerciseCapability.cloze,
        ExerciseCapability.sentenceOrder,
        ExerciseCapability.listening,
      },
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems(const [existing]);
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
    container
        .read(appRouterProvider)
        .go('/library/edit/user-explicit-token-sentence');
    await tester.pumpAndSettle();

    expect(find.text('1. Tokens'), findsOneWidget);
    expect(find.text('2. stay'), findsOneWidget);
    expect(find.text('3. explicit.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('item-translation-field')),
      '토큰이 계속 명시적으로 유지됩니다.',
    );
    await tester.tap(find.text('변경 내용 저장'));
    await tester.pumpAndSettle();

    expect(store.savedItems.single.sentenceTokens, existing.sentenceTokens);
  });
}
