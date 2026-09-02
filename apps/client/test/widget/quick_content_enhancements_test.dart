import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/quick_content_draft.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/quick_content_sheet.dart';

class _FailSecondQuickSaveStore extends MemoryStudyStore {
  var _saveCalls = 0;

  @override
  Future<void> saveCustomItems(Iterable<LearningItem> items) async {
    _saveCalls++;
    if (_saveCalls == 2) throw StateError('simulated second save failure');
    await super.saveCustomItems(items);
  }
}

LearningItem _existingWord() => const LearningItem(
  id: 'existing-duplicate-word',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  subjectId: 'language:en',
  text: 'duplicate',
  translations: ['중복'],
  acceptedAnswers: ['중복'],
  partOfSpeech: PartOfSpeech.noun,
  capabilities: {ExerciseCapability.recognition, ExerciseCapability.production},
  source: ContentSource.userCreated,
);

Future<void> _openQuickWord(WidgetTester tester, MemoryStudyStore store) async {
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
  await tester.ensureVisible(find.byKey(const Key('add-quick-word')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add-quick-word')));
  await tester.pumpAndSettle();
}

void _setClipboardText(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData'
        ? <String, Object?>{'text': text}
        : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets(
    'public quick sheet prefill parameters populate feedback fields',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showQuickContentSheet(
                    context: context,
                    initialText: 'feedback term',
                    initialMeaning: '피드백 뜻',
                    initialExample: 'A feedback example.',
                    initialExampleMeaning: '피드백 예문',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('feedback term'), findsOneWidget);
      expect(find.text('피드백 뜻'), findsOneWidget);
    },
  );

  testWidgets(
    'clipboard pair fills fields and swap clears dependent metadata',
    (tester) async {
      final store = MemoryStudyStore();
      await _openQuickWord(tester, store);
      await tester.ensureVisible(find.byKey(const Key('quick-content-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-content-more')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-example')),
      );
      await tester.enterText(
        find.byKey(const Key('quick-content-example')),
        'stale example',
      );
      await tester.enterText(
        find.byKey(const Key('quick-content-example-meaning')),
        '예전 예문',
      );
      _setClipboardText(tester, 'serene\t평온한');

      await tester.ensureVisible(
        find.byKey(const Key('quick-content-clipboard')),
      );
      await tester.tap(find.byKey(const Key('quick-content-clipboard')));
      await tester.pumpAndSettle();
      expect(find.text('serene'), findsOneWidget);
      expect(find.text('평온한'), findsWidgets);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('quick-content-example')),
            )
            .controller
            ?.text,
        isEmpty,
      );

      await tester.enterText(
        find.byKey(const Key('quick-content-example')),
        'A calm lake.',
      );
      await tester.enterText(
        find.byKey(const Key('quick-content-example-meaning')),
        '평온한 호수.',
      );

      await tester.ensureVisible(find.byKey(const Key('quick-content-swap')));
      await tester.tap(find.byKey(const Key('quick-content-swap')));
      await tester.pump();
      expect(find.text('평온한'), findsWidgets);
      expect(find.text('serene'), findsWidgets);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('quick-content-example')),
            )
            .controller
            ?.text,
        '평온한 호수.',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('quick-content-example-meaning')),
            )
            .controller
            ?.text,
        'A calm lake.',
      );
    },
  );

  testWidgets('device-local quick draft can be restored after widget restart', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await _openQuickWord(tester, store);
    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'recoverable',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '복구할 수 있는',
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      await store.loadQuickContentDraft(subjectId: 'language:en'),
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _openQuickWord(tester, store);
    expect(
      find.byKey(const Key('quick-content-draft-recovery')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quick-content-draft-restore')));
    await tester.pump();
    expect(find.text('recoverable'), findsOneWidget);
    expect(find.text('복구할 수 있는'), findsWidgets);
  });

  testWidgets('multi-paste rolls back earlier rows if a later save fails', (
    tester,
  ) async {
    final store = _FailSecondQuickSaveStore();
    await _openQuickWord(tester, store);
    _setClipboardText(tester, 'alpha\t알파\nbeta\t베타');

    await tester.tap(find.byKey(const Key('quick-content-clipboard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-content-clipboard-confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(store.savedItems, isEmpty);
    expect(find.textContaining('자동으로 되돌렸습니다'), findsOneWidget);
  });

  testWidgets('duplicate requires a three-way choice and merge is explicit', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await store.saveCustomItems([_existingWord()]);
    await _openQuickWord(tester, store);
    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'duplicate',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '복제본',
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const Key('quick-content-merge-existing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-view-existing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-save-separate')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('quick-content-save')));
    await tester.pump();
    expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
    expect(store.savedItems, hasLength(1));

    await tester.ensureVisible(
      find.byKey(const Key('quick-content-merge-existing')),
    );
    await tester.tap(find.byKey(const Key('quick-content-merge-existing')));
    await tester.tap(find.byKey(const Key('quick-content-save')));
    await tester.pumpAndSettle();

    expect(store.savedItems, hasLength(1));
    expect(store.savedItems.single.translations, contains('복제본'));
  });

  testWidgets('duplicate existing action opens the actual item editor', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await store.saveCustomItems([_existingWord()]);
    await _openQuickWord(tester, store);
    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'duplicate',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '중복',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(
      find.byKey(const Key('quick-content-view-existing')),
    );
    await tester.tap(find.byKey(const Key('quick-content-view-existing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('item-editor-scroll')), findsOneWidget);
    expect(find.text('duplicate'), findsWidgets);
  });

  testWidgets(
    'opening a bundled duplicate editor does not create an override',
    (tester) async {
      final bundled = sampleContent.firstWhere(
        (item) =>
            item.learningLanguage == LanguageTag.english &&
            item.kind == LearningItemKind.word &&
            item.partOfSpeech == PartOfSpeech.noun,
      );
      final store = MemoryStudyStore();
      await _openQuickWord(tester, store);
      await tester.enterText(
        find.byKey(const Key('quick-content-text')),
        bundled.text,
      );
      await tester.enterText(
        find.byKey(const Key('quick-content-meaning')),
        bundled.translations.first,
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-view-existing')),
      );
      await tester.tap(find.byKey(const Key('quick-content-view-existing')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('item-editor-scroll')), findsOneWidget);
      expect(store.savedItems, isEmpty);
    },
  );

  testWidgets('draft recovery stays overflow-free at 320px and 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final store = MemoryStudyStore(
      quickContentDraft: QuickContentDraft(
        subjectId: 'language:en',
        kind: LearningItemKind.word,
        text: 'narrow draft',
        meanings: const ['좁은 화면 초안'],
        acceptedAnswers: const [],
        readings: const {},
        sentenceTokens: const [],
        example: '',
        exampleMeaning: '',
        partOfSpeech: PartOfSpeech.noun,
        group: null,
        tags: const [],
        favorite: false,
        priority: 0,
        updatedAt: DateTime.utc(2026, 8, 2),
      ),
    );

    await _openQuickWord(tester, store);

    expect(
      find.byKey(const Key('quick-content-draft-recovery')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
