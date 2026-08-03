import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/state/app_state.dart';

const _existing = LearningItem(
  id: 'existing',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: 'existing',
  translations: ['기존'],
  acceptedAnswers: ['기존'],
  partOfSpeech: PartOfSpeech.noun,
);

const _validIncoming = LearningItem(
  id: 'valid',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: 'valid',
  translations: ['유효'],
  acceptedAnswers: ['유효'],
  partOfSpeech: PartOfSpeech.noun,
);

const _invalidIncoming = LearningItem(
  id: 'invalid',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: '',
  translations: ['무효'],
  acceptedAnswers: ['무효'],
  partOfSpeech: PartOfSpeech.noun,
);

ImportCommitRecord get _record => ImportCommitRecord(
  importId: 'import-test',
  fileName: 'large.csv',
  sha256: 'atomicity-sha256',
  importedRows: 2,
  rejectedRows: 0,
  importedAt: DateTime.utc(2026, 7, 29),
);

void main() {
  test(
    'memory import validates the full batch before changing any state',
    () async {
      final store = MemoryStudyStore();
      await store.saveCustomItems(const [_existing]);
      final tombstoneTime = DateTime.utc(2026, 7, 28);
      await store.saveCustomItemTombstones({'deleted': tombstoneTime});

      await expectLater(
        store.commitCustomItemImport(
          items: const [_validIncoming, _invalidIncoming],
          tombstones: const {},
          record: _record,
        ),
        throwsA(isA<Exception>()),
      );

      expect(store.savedItems, [_existing]);
      expect(store.savedItemTombstones, {'deleted': tombstoneTime});
      expect(store.savedImports, isEmpty);
    },
  );

  test(
    'SQLite import validates the full batch before its transaction',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = DriftStudyStore(database);
      addTearDown(database.close);
      await store.saveCustomItems(const [_existing]);

      await expectLater(
        store.commitCustomItemImport(
          items: const [_validIncoming, _invalidIncoming],
          tombstones: const {},
          record: _record,
        ),
        throwsA(isA<Exception>()),
      );

      final storedItems = await store.loadCustomItems();
      expect(storedItems, hasLength(1));
      expect(storedItems.single.id, _existing.id);
      expect(storedItems.single.text, _existing.text);
      expect(storedItems.single.translations, _existing.translations);
      expect(await store.findImportBySha256(_record.sha256), isNull);
    },
  );

  test(
    'failed import is unchanged and the same review can be retried',
    () async {
      final store = _FailOnceImportStore();
      final controller = AppController(store);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      const preview = ImportPreview(
        entries: [ParsedImportEntry(row: 2, item: _validIncoming)],
        issues: [],
        duplicates: [],
      );
      final review = controller.reviewImport(preview);
      final resolutions = [
        for (final entry in review.entries) entry.resolve(entry.defaultAction),
      ];

      await expectLater(
        controller.importResolvedItems(
          resolutions,
          fileName: 'retry.csv',
          sha256: 'retry-sha256',
          rejectedRows: 0,
        ),
        throwsStateError,
      );
      expect(controller.state.customItems, isEmpty);
      expect(store.savedItems, isEmpty);
      expect(store.savedImports, isEmpty);

      final result = await controller.importResolvedItems(
        resolutions,
        fileName: 'retry.csv',
        sha256: 'retry-sha256',
        rejectedRows: 0,
      );

      expect(result.added, 1);
      expect(controller.state.customItems.single.id, _validIncoming.id);
      expect(controller.state.customItems.single.text, _validIncoming.text);
      expect(controller.state.customItems.single.updatedAt, isNotNull);
      expect(store.savedItems, hasLength(1));
      expect(store.savedImports, hasLength(1));
    },
  );
}

class _FailOnceImportStore extends MemoryStudyStore {
  var _failNextImport = true;

  @override
  Future<void> commitCustomItemImport({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
    ImportCommitRecord? record,
  }) {
    if (_failNextImport) {
      _failNextImport = false;
      throw StateError('simulated interrupted import');
    }
    return super.commitCustomItemImport(
      items: items,
      tombstones: tombstones,
      record: record,
    );
  }
}
