import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_reconciler.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'resolved replacement preserves ID, increments version, and records file',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      const existing = LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await controller.upsertCustomItem(existing);
      const preview = ImportPreview(
        entries: [
          ParsedImportEntry(
            row: 2,
            item: LearningItem(
              id: 'foreign-water',
              kind: LearningItemKind.word,
              learningLanguage: LanguageTag.english,
              text: 'water',
              translations: ['물'],
              acceptedAnswers: ['물', '생수'],
              partOfSpeech: PartOfSpeech.noun,
            ),
          ),
        ],
        issues: [],
        duplicates: [],
      );
      final entry = controller.reviewImport(preview).entries.single;

      final result = await controller.importResolvedItems(
        [entry.resolve(ImportReviewAction.replace)],
        fileName: 'words.csv',
        sha256: '1234567890abcdef',
        rejectedRows: 0,
      );

      expect(result.replaced, 1);
      expect(result.stale, 0);
      expect(controller.state.customItems.single.id, existing.id);
      expect(
        controller.state.customItems.single.acceptedAnswers,
        contains('생수'),
      );
      expect(controller.state.customItems.single.source.contentVersion, 2);
      expect(store.savedImports.single.fileName, 'words.csv');
      expect(store.savedImports.single.importedRows, 1);
      controller.dispose();
    },
  );

  test(
    'rejects a reviewed replacement when the stored item changed meanwhile',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      const existing = LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await controller.upsertCustomItem(existing);
      const incoming = LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['생수'],
        acceptedAnswers: ['생수'],
        partOfSpeech: PartOfSpeech.noun,
      );
      const preview = ImportPreview(
        entries: [ParsedImportEntry(row: 2, item: incoming)],
        issues: [],
        duplicates: [],
      );
      final reviewed = controller.reviewImport(preview).entries.single;
      await controller.upsertCustomItem(
        existing.copyWith(tags: const ['방금 수정']),
      );

      final result = await controller.importResolvedItems(
        [reviewed.resolve(ImportReviewAction.replace)],
        fileName: 'words.csv',
        sha256: 'abcdef1234567890',
        rejectedRows: 0,
      );

      expect(result.replaced, 0);
      expect(result.stale, 1);
      expect(controller.state.customItems.single.translations, ['물']);
      expect(controller.state.customItems.single.tags, ['방금 수정']);
      controller.dispose();
    },
  );
}
