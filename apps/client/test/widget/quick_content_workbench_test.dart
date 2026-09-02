import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quick_content_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/quick_content_sheet.dart';

const _subjectId = 'language:en';

class _QuickContentLauncher extends ConsumerWidget {
  const _QuickContentLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(appControllerProvider).isHydrated;
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-quick-content'),
          onPressed: !hydrated
              ? null
              : () => showQuickContentSheet(
                  context: context,
                  initialKind: LearningItemKind.word,
                ),
          child: const Text('빠른 등록 열기'),
        ),
      ),
    );
  }
}

QuickContentTemplate _template() => QuickContentTemplate(
  id: 'travel-template',
  name: '여행 설정',
  kind: LearningItemKind.word,
  partOfSpeech: PartOfSpeech.noun,
  group: null,
  tags: const ['여행', '회화'],
  favorite: true,
  priority: 4,
  pinned: true,
  createdAt: DateTime.utc(2026, 8, 3, 9),
  updatedAt: DateTime.utc(2026, 8, 3, 9),
);

LearningItem _existingWord() => const LearningItem(
  id: 'existing-duplicate-word-workbench',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  subjectId: _subjectId,
  text: 'duplicate',
  translations: ['중복'],
  acceptedAnswers: ['중복'],
  readings: [Reading(scheme: ReadingScheme.hangul, value: '듀플리킷')],
  example: 'Existing example.',
  exampleTranslation: '기존 예문',
  partOfSpeech: PartOfSpeech.noun,
  tags: ['기존 태그'],
  capabilities: {ExerciseCapability.recognition, ExerciseCapability.production},
  source: ContentSource.userCreated,
);

Future<void> _openQuickWord(WidgetTester tester, MemoryStudyStore store) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1100);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: _QuickContentLauncher()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-quick-content')));
  await tester.pumpAndSettle();
}

Future<void> _expandWorkbench(WidgetTester tester) async {
  final finder = find.byKey(const Key('quick-content-workbench'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterRequired(
  WidgetTester tester,
  String text,
  String meaning,
) async {
  await tester.ensureVisible(find.byKey(const Key('quick-content-text')));
  await tester.enterText(find.byKey(const Key('quick-content-text')), text);
  await tester.enterText(
    find.byKey(const Key('quick-content-meaning')),
    meaning,
  );
  // Let duplicate detection and the local draft debounce finish before callers
  // assert against the derived preview. A single frame can observe the preview
  // between controller updates when the wider widget suite is under load.
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'required fields lead while groups and workbench stay collapsed',
    (tester) async {
      await _openQuickWord(tester, MemoryStudyStore());

      expect(find.byKey(const Key('quick-content-text')), findsOneWidget);
      expect(find.byKey(const Key('quick-content-meaning')), findsOneWidget);
      expect(
        find.byKey(const Key('quick-content-group-options')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('quick-content-workbench')), findsOneWidget);
      expect(find.byKey(const Key('quick-content-new-group')), findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('quick-content-group-options')),
      );
      await tester.tap(find.byKey(const Key('quick-content-group-options')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('quick-content-show-new-group')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('quick-content-new-group')), findsNothing);
      await tester.tap(find.byKey(const Key('quick-content-show-new-group')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick-content-new-group')), findsOneWidget);
    },
  );

  testWidgets(
    'template applies metadata, preserves source fields, and can be created',
    (tester) async {
      final store = MemoryStudyStore(
        quickContentLocalPreferences: QuickContentLocalPreferences(
          templatesBySubject: {
            _subjectId: [_template()],
          },
        ),
      );
      await _openQuickWord(tester, store);
      await _enterRequired(tester, 'untouched source', '유지할 뜻');
      await _expandWorkbench(tester);

      await _tapVisible(
        tester,
        find.byKey(const Key('quick-content-template-travel-template')),
      );

      expect(find.text('untouched source'), findsOneWidget);
      expect(find.text('유지할 뜻'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('quick-content-more')));
      await tester.tap(find.byKey(const Key('quick-content-more')));
      await tester.pumpAndSettle();
      final favorite = tester.widget<SwitchListTile>(
        find.byKey(const Key('quick-content-favorite')),
      );
      final priority = tester.widget<Slider>(
        find.byKey(const Key('quick-content-priority')),
      );
      expect(favorite.value, isTrue);
      expect(priority.value, 4);

      await tester.ensureVisible(
        find.byKey(const Key('quick-content-template-create')),
      );
      await tester.tap(find.byKey(const Key('quick-content-template-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('quick-content-template-name')),
        '나의 현재 설정',
      );
      await tester.tap(
        find.byKey(const Key('quick-content-template-name-confirm')),
      );
      await tester.pumpAndSettle();

      final preferences = await store.loadQuickContentLocalPreferences();
      expect(
        preferences.templatesBySubject[_subjectId]!.map(
          (template) => template.name,
        ),
        contains('나의 현재 설정'),
      );
    },
  );

  testWidgets('template menu renames duplicates pins and deletes locally', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      quickContentLocalPreferences: QuickContentLocalPreferences(
        templatesBySubject: {
          _subjectId: [_template()],
        },
      ),
    );
    await _openQuickWord(tester, store);
    await _expandWorkbench(tester);

    await _tapVisible(
      tester,
      find.byKey(const Key('quick-content-template-menu-travel-template')),
    );
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-content-template-name')),
      '출장 설정',
    );
    await tester.tap(
      find.byKey(const Key('quick-content-template-name-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.text('출장 설정'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const Key('quick-content-template-menu-travel-template')),
    );
    await tester.tap(find.text('고정 해제'));
    await tester.pumpAndSettle();
    var preferences = await store.loadQuickContentLocalPreferences();
    expect(preferences.templatesBySubject[_subjectId]!.single.pinned, isFalse);

    await _tapVisible(
      tester,
      find.byKey(const Key('quick-content-template-menu-travel-template')),
    );
    await tester.tap(find.text('복제'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-content-template-name')),
      '출장 설정 복제',
    );
    await tester.tap(
      find.byKey(const Key('quick-content-template-name-confirm')),
    );
    await tester.pumpAndSettle();
    preferences = await store.loadQuickContentLocalPreferences();
    expect(preferences.templatesBySubject[_subjectId], hasLength(2));

    final copied = preferences.templatesBySubject[_subjectId]!.firstWhere(
      (template) => template.id != 'travel-template',
    );
    await _tapVisible(
      tester,
      find.byKey(Key('quick-content-template-menu-${copied.id}')),
    );
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('quick-content-template-delete-confirm')),
    );
    await tester.pumpAndSettle();
    preferences = await store.loadQuickContentLocalPreferences();
    expect(preferences.templatesBySubject[_subjectId], hasLength(1));
  });

  testWidgets(
    'basket shows status, bulk saves metadata, and keeps five-step undo',
    (tester) async {
      final batchTemplate = _template().copyWith(group: '바구니 그룹');
      final store = MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          activeSubjectId: _subjectId,
          learningGroups: [
            LearningGroupDefinition(subjectId: _subjectId, name: '바구니 그룹'),
          ],
        ),
        quickContentLocalPreferences: QuickContentLocalPreferences(
          templatesBySubject: {
            _subjectId: [batchTemplate],
          },
        ),
      );
      await _openQuickWord(tester, store);
      await _expandWorkbench(tester);

      for (final pair in const [
        ('alpha', '알파'),
        ('beta', '베타'),
        ('gamma', '감마'),
        ('delta', '델타'),
        ('epsilon', '엡실론'),
        ('zeta', '제타'),
      ]) {
        await _enterRequired(tester, pair.$1, pair.$2);
        await tester.ensureVisible(
          find.byKey(const Key('quick-content-add-to-basket')),
        );
        await tester.tap(find.byKey(const Key('quick-content-add-to-basket')));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('저장 목록 6'), findsOneWidget);
      final basketList = find.byKey(const Key('quick-content-basket-list'));
      expect(
        find.descendant(of: basketList, matching: find.text('필수 완료')),
        findsWidgets,
      );
      expect(
        find.descendant(of: basketList, matching: find.text('읽기 없음')),
        findsWidgets,
      );
      expect(
        find.descendant(of: basketList, matching: find.text('단어')),
        findsWidgets,
      );
      expect(
        find.descendant(of: basketList, matching: find.text('신규')),
        findsWidgets,
      );
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-template-travel-template')),
      );
      await tester.tap(
        find.byKey(const Key('quick-content-template-travel-template')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-basket-apply-options')),
      );
      await tester.tap(
        find.byKey(const Key('quick-content-basket-apply-options')),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-basket-save-all')),
      );
      await tester.tap(find.byKey(const Key('quick-content-basket-save-all')));
      await tester.pumpAndSettle();

      expect(store.savedItems, hasLength(6));
      for (final item in store.savedItems) {
        expect(item.priority, 4);
        expect(item.tags, containsAll(['여행', '회화', 'group:바구니 그룹']));
      }
      final savedPreferences = await store.loadPreferences();
      expect(savedPreferences.favoriteItemIds, hasLength(6));
      expect(
        find.byKey(const Key('quick-content-session-undo')),
        findsOneWidget,
      );
      final undoChips = find.descendant(
        of: find.byKey(const Key('quick-content-session-undo')),
        matching: find.byType(ActionChip),
      );
      expect(undoChips, findsNWidgets(5));
      await tester.ensureVisible(undoChips.first);
      await tester.tap(undoChips.first);
      await tester.pumpAndSettle();
      expect(store.savedItems, hasLength(5));
    },
  );

  testWidgets('duplicate preview compares existing and incoming meanings', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await store.saveCustomItems([_existingWord()]);
    await _openQuickWord(tester, store);
    await _enterRequired(tester, 'duplicate', '새 뜻');
    await tester.ensureVisible(find.byKey(const Key('quick-content-more')));
    await tester.tap(find.byKey(const Key('quick-content-more')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-content-reading')),
      '듀플러컷',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-example')),
      'Incoming example.',
    );
    await tester.enterText(find.byKey(const Key('quick-content-tags')), '새 태그');
    await tester.pump();
    expect(
      find.byKey(const Key('quick-content-duplicate-details')),
      findsNothing,
    );
    final detailsToggle = find.byKey(
      const Key('quick-content-duplicate-details-toggle'),
    );
    await tester.ensureVisible(detailsToggle);
    await tester.tap(detailsToggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick-content-duplicate-side-기존 자료')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-duplicate-side-새로 입력')),
      findsOneWidget,
    );
    expect(find.textContaining('뜻 · 중복'), findsOneWidget);
    expect(find.textContaining('뜻 · 새 뜻'), findsOneWidget);
    expect(find.textContaining('읽기 · 듀플리킷'), findsOneWidget);
    expect(find.textContaining('읽기 · 듀플러컷'), findsOneWidget);
    expect(find.textContaining('예문 · Existing example.'), findsOneWidget);
    expect(find.textContaining('태그 · 새 태그'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quick-content-merge-summary-add')),
        matching: find.textContaining('뜻 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quick-content-merge-summary-conflict')),
        matching: find.textContaining('예문'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Enter advances and Shift Enter moves focus backward', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await _openQuickWord(tester, store);
    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'keyboard',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'quick content meaning',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'quick content text',
    );
  });

  testWidgets('Enter on the last detail field saves the valid entry', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await _openQuickWord(tester, store);
    await _enterRequired(tester, 'keyboard save', '키보드 저장');
    await tester.ensureVisible(find.byKey(const Key('quick-content-more')));
    await tester.tap(find.byKey(const Key('quick-content-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('quick-content-tags')));
    await tester.enterText(
      find.byKey(const Key('quick-content-tags')),
      'shortcut',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.savedItems, hasLength(1));
    expect(store.savedItems.single.text, 'keyboard save');
    expect(find.byKey(const Key('quick-content-sheet')), findsNothing);
  });

  testWidgets('typing suggests similar items, examples, and tags', (
    tester,
  ) async {
    final similar = LearningItem(
      id: 'suggestion-accomplish',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'accomplish',
      translations: ['성취하다'],
      acceptedAnswers: ['성취하다'],
      partOfSpeech: PartOfSpeech.verb,
      tags: ['achievement', learningGroupTag('성취')],
      capabilities: {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
      },
      source: ContentSource.userCreated,
    );
    const example = LearningItem(
      id: 'suggestion-example',
      kind: LearningItemKind.sentence,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'I accomplish one goal every day.',
      translations: ['나는 매일 목표 하나를 이룬다.'],
      acceptedAnswers: ['나는 매일 목표 하나를 이룬다.'],
      sentenceTokens: ['I', 'accomplish', 'one', 'goal', 'every', 'day.'],
      tags: ['daily'],
      capabilities: {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
      },
      source: ContentSource.userCreated,
    );
    final store = MemoryStudyStore();
    await store.saveCustomItems([similar, example]);
    await _openQuickWord(tester, store);
    await _enterRequired(tester, 'accomplis', '성취하다');

    expect(find.byKey(const Key('quick-content-suggestions')), findsOneWidget);
    expect(
      find.byKey(const Key('quick-content-similar-suggestion-accomplish')),
      findsOneWidget,
    );
    expect(find.textContaining('accomplish · 성취하다 ·'), findsOneWidget);
    final groupSuggestion = find.byKey(
      const Key('quick-content-group-suggestion-성취'),
    );
    expect(groupSuggestion, findsOneWidget);
    await tester.ensureVisible(groupSuggestion);
    await tester.tap(groupSuggestion);
    await tester.pump();
    expect(find.textContaining('성취에 바로 저장'), findsOneWidget);
    final exampleChip = find.byKey(
      const Key('quick-content-example-suggestion-suggestion-example'),
    );
    await tester.ensureVisible(exampleChip);
    await tester.tap(exampleChip);
    await tester.pumpAndSettle();
    final exampleField = tester.widget<TextFormField>(
      find.byKey(const Key('quick-content-example')),
    );
    expect(exampleField.controller?.text, 'I accomplish one goal every day.');

    final tagChip = find.byKey(
      const Key('quick-content-tag-suggestion-achievement'),
    );
    await tester.ensureVisible(tagChip);
    await tester.tap(tagChip);
    await tester.pump();
    final tagsField = tester.widget<TextFormField>(
      find.byKey(const Key('quick-content-tags')),
    );
    expect(tagsField.controller?.text, contains('achievement'));
  });

  testWidgets('registration basket survives closing and widget restart', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await _openQuickWord(tester, store);
    await _enterRequired(tester, 'persisted basket', '복구되는 바구니');
    await tester.ensureVisible(
      find.byKey(const Key('quick-content-add-to-basket')),
    );
    await tester.tap(find.byKey(const Key('quick-content-add-to-basket')));
    await tester.pumpAndSettle();

    final storedDraft = await store.loadQuickContentDraft(
      subjectId: _subjectId,
    );
    expect(storedDraft?.basket, hasLength(1));
    expect(storedDraft?.basket.single.item.text, 'persisted basket');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _openQuickWord(tester, store);
    expect(
      find.byKey(const Key('quick-content-draft-recovery')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quick-content-draft-restore')));
    await tester.pumpAndSettle();
    await _expandWorkbench(tester);

    expect(find.byKey(const Key('quick-content-basket-list')), findsOneWidget);
    expect(find.text('persisted basket'), findsOneWidget);
  });

  testWidgets(
    'selection-only draft flushes pending debounce before recreation',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          activeSubjectId: _subjectId,
          learningGroups: [
            LearningGroupDefinition(subjectId: _subjectId, name: '선택 전용'),
          ],
        ),
      );
      await _openQuickWord(tester, store);

      final groupOptions = find.byKey(const Key('quick-content-group-options'));
      await tester.ensureVisible(groupOptions);
      await tester.tap(groupOptions);
      await tester.pumpAndSettle();
      final selection = find.byKey(const Key('quick-content-group-선택 전용'));
      await tester.ensureVisible(selection);
      await tester.tap(selection);
      await tester.pump();

      // Recreate immediately, before the normal draft debounce can fire.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _openQuickWord(tester, store);

      expect(
        find.byKey(const Key('quick-content-draft-recovery')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('quick-content-draft-restore')));
      await tester.pump();
      expect(
        find.byKey(const Key('quick-content-clear-group')),
        findsOneWidget,
      );
      expect(find.textContaining('선택 전용에 바로 저장'), findsOneWidget);
    },
  );

  testWidgets('saving one entry keeps the remaining basket recoverable', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await _openQuickWord(tester, store);
    await _enterRequired(tester, 'basket first', '바구니 첫 항목');
    await tester.ensureVisible(
      find.byKey(const Key('quick-content-add-to-basket')),
    );
    await tester.tap(find.byKey(const Key('quick-content-add-to-basket')));
    await tester.pumpAndSettle();

    await _enterRequired(tester, 'save now', '지금 저장');
    await tester.ensureVisible(find.byKey(const Key('quick-content-save')));
    await tester.tap(find.byKey(const Key('quick-content-save')));
    await tester.pumpAndSettle();

    expect(store.savedItems.map((item) => item.text), contains('save now'));
    final draft = await store.loadQuickContentDraft(subjectId: _subjectId);
    expect(draft?.basket, hasLength(1));
    expect(draft?.basket.single.item.text, 'basket first');
    expect(draft?.text, isEmpty);
  });

  testWidgets('mobile keyboard focus mode keeps only essential entry actions', (
    tester,
  ) async {
    await _openQuickWord(tester, MemoryStudyStore());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick-content-keyboard-focus-mode')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quick-content-text')), findsOneWidget);
    expect(find.byKey(const Key('quick-content-meaning')), findsOneWidget);
    expect(
      find.byKey(const Key('quick-content-add-to-basket')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quick-content-save')), findsOneWidget);

    expect(find.byKey(const Key('quick-content-kind')), findsNothing);
    expect(find.byKey(const Key('quick-content-group-options')), findsNothing);
    expect(find.byKey(const Key('quick-content-workbench')), findsNothing);
    expect(find.byKey(const Key('quick-content-save-and-study')), findsNothing);
    expect(find.byKey(const Key('quick-content-save-and-add')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact action bar stays usable at 320px and 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
        child: const MaterialApp(home: _QuickContentLauncher()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-quick-content')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-content-save')), findsOneWidget);
    expect(
      find.byKey(const Key('quick-content-add-to-basket')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('quick-content-workbench')),
    );
    await tester.tap(find.byKey(const Key('quick-content-workbench')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-content-template-create')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
