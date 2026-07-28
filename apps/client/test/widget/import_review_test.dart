import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  testWidgets('import review shows field diffs and per-item decisions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final store = MemoryStudyStore();
    await store.saveCustomItems(const [
      LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
        partOfSpeech: PartOfSpeech.noun,
      ),
    ]);
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: LearningItem(
            id: 'existing-water',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'water',
            translations: ['생수'],
            acceptedAnswers: ['생수'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
        ParsedImportEntry(
          row: 3,
          item: LearningItem(
            id: 'new-axolotl',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'axolotl',
            translations: ['우파루파'],
            acceptedAnswers: ['우파루파'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            theme: AppTheme.mobile,
            home: const Scaffold(
              body: ImportScreen(
                initialPreview: preview,
                initialFileName: 'review.csv',
                initialSha256: 'review-sha256',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('import-review-summary')), findsOneWidget);
      expect(find.text('기존'), findsWidgets);
      expect(find.text('가져올 값'), findsWidgets);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('import-action-3-new-axolotl-add')),
            )
            .selected,
        isTrue,
      );

      final outerList = find.byType(ListView).first;
      final replaceAction = find.byKey(
        const Key('import-action-2-existing-water-replace'),
      );
      await tester.drag(outerList, const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(replaceAction);
      await tester.pump();

      await tester.drag(outerList, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('2개를 단어장에 반영합니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.reset();
    }
  });
}
