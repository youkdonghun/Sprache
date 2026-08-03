import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/import/import_review_draft.dart';

void main() {
  final draft = ImportReviewDraft(
    fileSha256: 'a' * 64,
    updatedAt: DateTime.utc(2026, 8, 2, 12),
    extension: 'csv',
    columnMapping: const {'term': 'front', 'meaning': 'back'},
    decisions: const {
      '2:item-a': ImportDraftDecision.add,
      '3:item-b': ImportDraftDecision.skip,
    },
    encodingName: 'utf8',
    delimiterName: 'comma',
    destinationSubjectId: 'language:en',
    distributionGroup: '업무',
  );

  test('round-trips review metadata without source rows or file text', () {
    final source = jsonEncode(draft.toJson());
    final raw = Map<String, Object?>.from(jsonDecode(source) as Map);
    final restored = ImportReviewDraft.fromJson(raw);

    expect(source, isNot(contains('fileName')));
    expect(source, isNot(contains('sourceText')));
    expect(source, isNot(contains('previewRows')));
    expect(raw.keys.toSet(), {
      'version',
      'fileSha256',
      'updatedAt',
      'extension',
      'columnMapping',
      'decisions',
      'encodingName',
      'delimiterName',
      'destinationSubjectId',
      'distributionGroup',
    });
    expect(restored.fileSha256, 'a' * 64);
    expect(restored.columnMapping['term'], 'front');
    expect(restored.decisions['3:item-b'], ImportDraftDecision.skip);
  });

  test('rejects malformed identity metadata', () {
    expect(
      () => ImportReviewDraft.fromJson({
        ...draft.toJson(),
        'fileSha256': '../source.csv',
      }),
      throwsFormatException,
    );
  });

  test(
    'memory and Drift stores isolate and clear the local review draft',
    () async {
      final memory = MemoryStudyStore();
      await memory.saveImportReviewDraft(draft);
      expect((await memory.loadImportReviewDraft())?.fileSha256, 'a' * 64);
      await memory.clearImportReviewDraft();
      expect(await memory.loadImportReviewDraft(), isNull);

      final database = AppDatabase(NativeDatabase.memory());
      final drift = DriftStudyStore(database);
      try {
        await drift.saveImportReviewDraft(draft);
        expect(
          (await drift.loadImportReviewDraft())?.decisions,
          draft.decisions,
        );
        final rows = await database.select(database.appSettings).get();
        expect(rows.map((row) => row.key), contains('import_review_draft'));
        await drift.clearImportReviewDraft();
        expect(await drift.loadImportReviewDraft(), isNull);
      } finally {
        await database.close();
      }
    },
  );
}
