import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  const first = LearningItem(
    id: 'bulk-edit-first',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    subjectId: 'language:en',
    text: 'fixture',
    translations: ['설비'],
    acceptedAnswers: ['설비'],
    readings: [Reading(scheme: ReadingScheme.hangul, value: '픽스처')],
    partOfSpeech: PartOfSpeech.noun,
    tags: ['group:업무', '기존'],
  );
  const second = LearningItem(
    id: 'bulk-edit-second',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    subjectId: 'language:en',
    text: 'ledger',
    translations: ['원장'],
    acceptedAnswers: ['원장'],
    partOfSpeech: PartOfSpeech.noun,
  );

  Future<MemoryStudyStore> pumpLibrary(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    TargetPlatform platform = TargetPlatform.windows,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    });
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    await store.saveCustomItems(const [first, second]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: LibraryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('filtered custom items open in a spreadsheet and save together', (
    tester,
  ) async {
    final store = await pumpLibrary(tester);

    await tester.tap(find.byKey(const Key('library-bulk-edit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bulk-item-editor-dialog')), findsOneWidget);
    expect(find.byKey(const Key('bulk-item-desktop-table')), findsOneWidget);
    expect(find.text('전체 2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('bulk-meaning-bulk-edit-first')),
      '고정 장치',
    );
    await tester.enterText(
      find.byKey(const Key('bulk-pronunciation-bulk-edit-first')),
      '픽스처 새 발음',
    );
    await tester.enterText(
      find.byKey(const Key('bulk-tags-bulk-edit-first')),
      '기존, 핵심',
    );
    await tester.enterText(
      find.byKey(const Key('bulk-meaning-bulk-edit-second')),
      '회계 원장',
    );
    await tester.pump();

    expect(find.text('4개 변경 저장'), findsNothing);
    expect(find.text('2개 변경 저장'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('bulk-item-horizontal-scroll')),
      const Offset(-300, 0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('save-bulk-item-edits')));
    await tester.pumpAndSettle();

    final saved = await store.loadCustomItems();
    final savedFirst = saved.singleWhere((item) => item.id == first.id);
    final savedSecond = saved.singleWhere((item) => item.id == second.id);
    expect(savedFirst.primaryTranslation, '고정 장치');
    expect(savedFirst.koreanPronunciation, '픽스처 새 발음');
    expect(savedFirst.tags, containsAll(['기존', '핵심', learningGroupTag('업무')]));
    expect(savedSecond.primaryTranslation, '회계 원장');
    expect(find.byKey(const Key('bulk-item-editor-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an invalid row blocks the whole spreadsheet save', (
    tester,
  ) async {
    final store = await pumpLibrary(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );

    await tester.tap(find.byKey(const Key('library-bulk-edit-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bulk-item-mobile-list')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('bulk-meaning-bulk-edit-first')),
      '',
    );
    await tester.enterText(
      find.byKey(const Key('bulk-meaning-bulk-edit-second')),
      '저장되면 안 되는 값',
    );
    await tester.tap(find.byKey(const Key('save-bulk-item-edits')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bulk-item-editor-dialog')), findsOneWidget);
    expect(find.text('오류 1'), findsOneWidget);
    final saved = await store.loadCustomItems();
    expect(
      saved.singleWhere((item) => item.id == second.id).primaryTranslation,
      '원장',
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('tab-separated spreadsheet rows paste and save in one batch', (
    tester,
  ) async {
    final store = await pumpLibrary(tester);

    await tester.tap(find.byKey(const Key('library-bulk-edit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bulk-item-paste-grid')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('bulk-item-paste-grid-input')),
      '표현\t뜻\t태그\nfixture\t고정 장치\t기존, 핵심\nledger\t회계 원장\t회계',
    );
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('bulk-item-paste-grid-input')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      contains('\t'),
    );
    await tester.tap(find.byKey(const Key('confirm-bulk-item-paste-grid')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bulk-item-paste-grid-input')), findsNothing);
    expect(find.textContaining('2개 행의 4개 셀'), findsWidgets);
    await tester.tap(find.byKey(const Key('save-bulk-item-edits')));
    await tester.pumpAndSettle();

    final saved = await store.loadCustomItems();
    final savedFirst = saved.singleWhere((item) => item.id == first.id);
    final savedSecond = saved.singleWhere((item) => item.id == second.id);
    expect(savedFirst.primaryTranslation, '고정 장치');
    expect(savedFirst.tags, containsAll(['기존', '핵심', learningGroupTag('업무')]));
    expect(savedSecond.primaryTranslation, '회계 원장');
    expect(savedSecond.tags, contains('회계'));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
