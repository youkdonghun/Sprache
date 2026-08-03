import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  test('Drift preserves content attribution and part of speech', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftStudyStore(database);
    const item = LearningItem(
      id: 'bank-noun',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'bank',
      translations: ['은행'],
      acceptedAnswers: ['은행'],
      partOfSpeech: PartOfSpeech.noun,
      source: ContentSource(
        name: 'My vocabulary book',
        license: 'private',
        sourceVersion: '2026-07',
        contentVersion: 4,
        sourceId: 'chapter-2-entry-7',
        sourceUrl: 'https://example.com/chapter-2/entry-7',
        author: 'Study Team',
        attribution: 'Study Team · My vocabulary book',
      ),
    );

    try {
      await store.saveCustomItems([item]);
      final restored = (await store.loadCustomItems()).single;

      expect(restored.partOfSpeech, PartOfSpeech.noun);
      expect(restored.source.name, 'My vocabulary book');
      expect(restored.source.license, 'private');
      expect(restored.source.sourceVersion, '2026-07');
      expect(restored.source.contentVersion, 4);
      expect(restored.source.sourceId, 'chapter-2-entry-7');
      expect(
        restored.source.sourceUrl,
        'https://example.com/chapter-2/entry-7',
      );
      expect(restored.source.author, 'Study Team');
      expect(restored.source.attribution, 'Study Team · My vocabulary book');
    } finally {
      await database.close();
    }
  });

  test(
    'Drift commits imported items, tombstones, and history atomically',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = DriftStudyStore(database);
      const item = LearningItem(
        id: 'imported-tea',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'tea',
        translations: ['차'],
        acceptedAnswers: ['차'],
        partOfSpeech: PartOfSpeech.noun,
      );
      final importedAt = DateTime.utc(2026, 7, 28, 10, 30);
      final record = ImportCommitRecord(
        importId: 'import-1',
        fileName: 'tea.csv',
        sha256: 'tea-hash',
        importedRows: 1,
        rejectedRows: 2,
        importedAt: importedAt,
      );

      try {
        await store.commitCustomItemImport(
          items: const [item],
          tombstones: {'removed-item': importedAt},
          record: record,
        );

        expect((await store.loadCustomItems()).single.id, item.id);
        expect(await store.loadCustomItemTombstones(), {
          'removed-item': importedAt,
        });
        final restored = await store.findImportBySha256('tea-hash');
        expect(restored?.fileName, 'tea.csv');
        expect(restored?.importedRows, 1);
        expect(restored?.rejectedRows, 2);
      } finally {
        await database.close();
      }
    },
  );
}
