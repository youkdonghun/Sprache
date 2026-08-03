import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  test('file database enables WAL and full flush durability', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'sprache-database-durability-',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });
    final database = AppDatabase(
      NativeDatabase(File(path.join(sandbox.path, 'sprache.sqlite'))),
    );
    addTearDown(database.close);

    expect(await _pragma(database, 'journal_mode'), 'wal');
    expect(await _pragma(database, 'synchronous'), 2);
    expect(await _pragma(database, 'fullfsync'), 1);
    expect(await _pragma(database, 'checkpoint_fullfsync'), 1);
  });

  test('a partial replacement rolls back to the existing database', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftStudyStore(database);
    addTearDown(database.close);
    await store.saveCustomItems([_item('existing')]);
    final oldDeletedAt = DateTime.utc(2026, 8, 1);
    await store.saveCustomItemTombstones({'old-deleted': oldDeletedAt});
    await database.customStatement('''
      CREATE TRIGGER fail_second_replacement
      BEFORE INSERT ON content_items
      WHEN NEW.id = 'replacement-2'
      BEGIN
        SELECT RAISE(ABORT, 'simulated partial write');
      END
    ''');

    await expectLater(
      store.replaceCustomContent(
        items: [_item('replacement-1'), _item('replacement-2')],
        tombstones: {'new-deleted': DateTime.utc(2026, 8, 2)},
      ),
      throwsA(anything),
    );

    expect((await store.loadCustomItems()).map((item) => item.id), [
      'existing',
    ]);
    expect(await store.loadCustomItemTombstones(), {
      'old-deleted': oldDeletedAt,
    });
  });

  test('SQLITE_FULL leaves the previously committed content intact', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftStudyStore(database);
    addTearDown(database.close);
    await store.saveCustomItems([_item('existing')]);
    final pageCount = await _pragma(database, 'page_count') as int;
    await database.customStatement('PRAGMA max_page_count = $pageCount');
    final oversizedReplacement = [
      for (var index = 0; index < 1000; index++)
        _item(
          'replacement-$index',
          text:
              '${index.toString().padLeft(4, '0')}-'
              '${List<String>.filled(580, 'x').join()}',
        ),
    ];

    await expectLater(
      store.replaceCustomContent(
        items: oversizedReplacement,
        tombstones: const {},
      ),
      throwsA(anything),
    );

    final retained = await store.loadCustomItems();
    expect(retained, hasLength(1));
    expect(retained.single.id, 'existing');
    expect(retained.single.text, 'existing');
  });
}

Future<Object?> _pragma(AppDatabase database, String name) async {
  final row = await database.customSelect('PRAGMA $name').getSingle();
  return row.data.values.single;
}

LearningItem _item(String id, {String? text}) => LearningItem(
  id: id,
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: text ?? id,
  translations: const ['meaning'],
  acceptedAnswers: const ['meaning'],
  partOfSpeech: PartOfSpeech.noun,
);
