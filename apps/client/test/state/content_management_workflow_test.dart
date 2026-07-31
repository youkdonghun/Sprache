import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/content_management.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/smart_collection.dart';
import 'package:sprache/src/import/import_reconciler.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  LearningItem item(String id, String text) => LearningItem(
    id: id,
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: text,
    translations: const ['뜻'],
    acceptedAnswers: const ['뜻'],
    subjectId: 'language:en',
    tags: const ['여행'],
    updatedAt: DateTime.utc(2026, 7, 31),
  );

  test(
    'smart collection, trash and correction survive controller state',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final custom = item('custom-1', 'passport');
      await controller.upsertCustomItem(custom);

      final collection = SmartCollectionDefinition(
        id: 'smart-1',
        subjectId: controller.activeSubject.id,
        name: '여행',
        tags: const {'여행'},
        updatedAt: DateTime.utc(2026, 7, 31),
      );
      await controller.upsertSmartCollection(collection);
      expect(controller.smartCollections.single.name, '여행');
      expect(
        controller.itemsForSmartCollection(collection).map((value) => value.id),
        contains(custom.id),
      );

      final batch = await controller.trashCustomItems({custom.id});
      expect(batch.entries, hasLength(1));
      expect(controller.customItemById(custom.id), isNull);
      expect(controller.listTrash(), hasLength(1));
      expect(await controller.restoreTrashBatch(batch.id), 1);
      expect(controller.customItemById(custom.id), isNotNull);

      await controller.upsertContentCorrection(
        ContentCorrection(
          itemId: 'starter-item',
          field: 'translation',
          note: '뜻 확인 필요',
          proposedValue: '새 뜻',
          updatedAt: DateTime.utc(2026, 7, 31),
        ),
      );
      expect(
        controller.contentCorrectionFor('starter-item')?.proposedValue,
        '새 뜻',
      );
      controller.dispose();
    },
  );

  test(
    'mapping presets persist and an unchanged import can be undone',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final imported = item('imported-1', 'terminal');

      await controller.upsertImportMappingPreset(
        ImportMappingPreset(
          id: 'mapping-1',
          name: '회사 양식',
          columns: const {'term': '앞면', 'meaning': '뒷면'},
          updatedAt: DateTime.utc(2026, 7, 31),
        ),
      );
      expect(controller.importMappingPresets.single.name, '회사 양식');

      final result = await controller.importResolvedItems(
        [ImportResolution(incoming: imported, action: ImportReviewAction.add)],
        fileName: 'office.xlsx',
        sha256: List.filled(64, 'a').join(),
        rejectedRows: 0,
      );
      expect(result.added, 1);
      final receipt = controller.importReceipts.single;
      expect(receipt.addedCount, 1);
      expect(receipt.canUndo, isTrue);
      expect(receipt.destinations.single.subjectId, 'language:en');

      final undone = await controller.undoImport(receipt.importId);
      expect(undone.removed, 1);
      expect(undone.skippedConflicts, 0);
      expect(controller.customItemById(imported.id), isNull);
      expect(controller.importReceipts.single.canUndo, isFalse);
      controller.dispose();
    },
  );

  test('import receipt preserves every routed subject and key', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final english = item(
      'import-en',
      'terminal',
    ).copyWith(tags: tagsWithImportDistributionKey(const [], 'office-en'));
    final japanese = item('import-ja', '改札').copyWith(
      learningLanguage: LanguageTag.japanese,
      subjectId: 'language:ja',
      tags: tagsWithImportDistributionKey(const [], 'travel-ja'),
    );

    await controller.importResolvedItems(
      [
        ImportResolution(incoming: english, action: ImportReviewAction.add),
        ImportResolution(incoming: japanese, action: ImportReviewAction.add),
      ],
      fileName: 'multi.xlsx',
      sha256: List.filled(64, 'b').join(),
      rejectedRows: 0,
    );

    final destinations = controller.importReceipts.single.destinations;
    expect(destinations, hasLength(2));
    expect(
      destinations.map(
        (value) => '${value.subjectId}:${value.distributionKey}',
      ),
      containsAll(['language:en:office-en', 'language:ja:travel-ja']),
    );
    controller.dispose();
  });

  test(
    'undo preview requires comparison for an item edited after import',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final imported = item('import-conflict', 'platform');
      await controller.importResolvedItems(
        [ImportResolution(incoming: imported, action: ImportReviewAction.add)],
        fileName: 'conflict.xlsx',
        sha256: List.filled(64, 'c').join(),
        rejectedRows: 0,
      );
      final receipt = controller.importReceipts.single;
      final current = controller.customItemById(imported.id)!;
      await controller.upsertCustomItem(
        current.copyWith(
          translations: const ['직접 수정'],
          acceptedAnswers: const ['직접 수정'],
        ),
      );

      final preview = controller.previewImportUndo(receipt.importId);
      expect(preview.safeChangeCount, 0);
      expect(preview.conflicts.single.itemId, imported.id);
      final undone = await controller.undoImport(receipt.importId);
      expect(undone.skippedConflicts, 1);
      expect(
        controller.customItemById(imported.id)!.primaryTranslation,
        '직접 수정',
      );
      controller.dispose();
    },
  );
}
