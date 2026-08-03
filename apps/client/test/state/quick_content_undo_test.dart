import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/state/app_state.dart';

LearningItem _item({required String id, required List<String> meanings}) =>
    LearningItem(
      id: id,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'ko-en',
      text: 'resilient',
      translations: meanings,
      acceptedAnswers: meanings,
      partOfSpeech: PartOfSpeech.adjective,
      capabilities: const {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
      },
      source: ContentSource.userCreated,
    );

void main() {
  test('undo removes a newly quick-saved item', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    final result = await controller.saveQuickContent(
      _item(id: 'user-new', meanings: const ['회복력 있는']),
    );
    expect(controller.customItemById(result.item.id), isNotNull);

    final status = await controller.undoQuickContentSave(result.undoToken);
    expect(status, QuickContentUndoStatus.restored);
    expect(controller.customItemById(result.item.id), isNull);
    expect(store.savedItems, isEmpty);
  });

  test('undo restores the exact item before a quick merge', () async {
    final store = MemoryStudyStore();
    final original = _item(id: 'user-existing', meanings: const ['탄력 있는']);
    await store.saveCustomItems([original]);
    final controller = AppController(store);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    final result = await controller.saveQuickContent(
      _item(id: 'user-candidate', meanings: const ['회복력 있는']),
    );
    expect(result.mergedWithExisting, isTrue);
    expect(result.item.translations, hasLength(2));

    final status = await controller.undoQuickContentSave(result.undoToken);
    expect(status, QuickContentUndoStatus.restored);
    expect(controller.customItemById(original.id)?.translations, const [
      '탄력 있는',
    ]);
  });

  test(
    'explicit separate choice permits a duplicate sentence identity',
    () async {
      final store = MemoryStudyStore();
      LearningItem sentence(String id) => LearningItem(
        id: id,
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        subjectId: 'ko-en',
        text: 'Same sentence.',
        translations: const ['같은 문장'],
        acceptedAnswers: const ['같은 문장'],
        capabilities: const {
          ExerciseCapability.recognition,
          ExerciseCapability.production,
        },
        source: ContentSource.userCreated,
      );
      await store.saveCustomItems([sentence('sentence-existing')]);
      final controller = AppController(store);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      final result = await controller.saveQuickContent(
        sentence('sentence-separate'),
        allowDuplicate: true,
      );

      expect(result.mergedWithExisting, isFalse);
      expect(store.savedItems, hasLength(2));
      expect(
        store.savedItems.where((item) => item.text == 'Same sentence.'),
        hasLength(2),
      );
    },
  );
}
