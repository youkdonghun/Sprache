import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/item_editor_draft.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  ItemEditorDraft createDraft({String? itemId, int priority = 3}) =>
      ItemEditorDraft(
        itemId: itemId,
        baseFingerprint: 'empty-editor-v1',
        subjectId: 'language:ja',
        kind: LearningItemKind.word,
        partOfSpeech: PartOfSpeech.noun,
        priority: priority,
        group: '여행',
        sentenceTokens: const [],
        text: '水',
        translation: '물',
        acceptedAnswers: '물, 식수',
        reading: 'みず',
        secondaryReading: 'mizu',
        koreanPronunciation: '미즈',
        example: '水を飲む。',
        exampleTranslation: '물을 마신다.',
        tags: '기초, 여행',
        level: '입문',
        sourceName: '사용자 생성',
        license: 'private',
        sourceVersion: '1',
        sourceId: '',
        sourceUrl: '',
        author: '',
        attribution: '',
        updatedAt: DateTime.utc(2026, 8, 3, 10),
      );

  test('memory store saves and clears a full editor draft', () async {
    final store = MemoryStudyStore();
    final draft = createDraft();

    await store.saveItemEditorDraft(draft);
    final restored = await store.loadItemEditorDraft();

    expect(restored?.text, '水');
    expect(restored?.subjectId, 'language:ja');
    expect(restored?.group, '여행');

    await store.clearItemEditorDraft();
    expect(await store.loadItemEditorDraft(), isNull);
  });

  test('full editor draft JSON preserves all recovery fields', () {
    final original = createDraft();
    final restored = ItemEditorDraft.fromJson(original.toJson());

    expect(restored.baseFingerprint, original.baseFingerprint);
    expect(restored.reading, 'みず');
    expect(restored.secondaryReading, 'mizu');
    expect(restored.example, '水を飲む。');
    expect(restored.priority, 3);
  });

  test(
    'draft scopes cannot clear another item and priority keeps 0 to 10',
    () async {
      final store = MemoryStudyStore();
      final first = createDraft(itemId: 'item-a', priority: 10);
      final second = createDraft(itemId: 'item-b', priority: 7);
      await store.saveItemEditorDraft(first);
      await store.saveItemEditorDraft(second);

      await store.clearItemEditorDraft(itemId: 'item-b');

      expect((await store.loadItemEditorDraft(itemId: 'item-a'))?.priority, 10);
      expect(await store.loadItemEditorDraft(itemId: 'item-b'), isNull);
      expect(ItemEditorDraft.fromJson(first.toJson()).priority, 10);
    },
  );

  test(
    'Memory and Drift isolate new and existing editor draft scopes',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      try {
        for (final store in <StudyStore>[
          MemoryStudyStore(),
          DriftStudyStore(database),
        ]) {
          final newItem = createDraft(priority: 1);
          final first = createDraft(itemId: 'item-a', priority: 5);
          final second = createDraft(itemId: 'item-b', priority: 9);
          await store.saveItemEditorDraft(newItem);
          await store.saveItemEditorDraft(first);
          await store.saveItemEditorDraft(second);

          // Saving item B clears only B's recovery scope. New-item and item A
          // drafts remain independently recoverable.
          await store.clearItemEditorDraft(itemId: 'item-b');
          expect((await store.loadItemEditorDraft())?.priority, 1);
          expect(
            (await store.loadItemEditorDraft(itemId: 'item-a'))?.priority,
            5,
          );
          expect(await store.loadItemEditorDraft(itemId: 'item-b'), isNull);

          await store.clearItemEditorDraft(itemId: 'item-a');
          expect((await store.loadItemEditorDraft())?.priority, 1);
        }
      } finally {
        await database.close();
      }
    },
  );
}
