import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('iOS back gesture protects an import review draft', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: LearningItem(
            id: 'protected-import-row',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'protected',
            translations: ['보호됨'],
            acceptedAnswers: ['보호됨'],
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
        child: const MaterialApp(
          home: Scaffold(
            body: ImportScreen(
              initialPreview: preview,
              initialFileName: 'protected.csv',
              initialSha256: 'protected-sha',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-draft-exit-dialog')), findsOneWidget);
    expect(find.text('계속 검토'), findsOneWidget);
    expect(find.text('미리보기 닫기'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
