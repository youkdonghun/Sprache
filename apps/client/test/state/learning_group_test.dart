import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'quick content merges new meanings without creating a duplicate',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const original = LearningItem(
        id: 'quick-merge-word',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'draft',
        translations: ['초안'],
        acceptedAnswers: ['초안'],
        tags: ['group:업무'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await controller.upsertCustomItem(original);

      final result = await controller.saveQuickContent(
        const LearningItem(
          id: 'quick-merge-duplicate',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'draft',
          translations: ['징집하다'],
          acceptedAnswers: ['징집하다'],
          tags: ['group:시험'],
          partOfSpeech: PartOfSpeech.noun,
        ),
      );

      expect(result.mergedWithExisting, isTrue);
      expect(result.addedMeaningCount, 1);
      expect(
        controller.courseItems.where((item) => item.text == 'draft'),
        hasLength(1),
      );
      final merged = controller.customItemById(original.id)!;
      expect(merged.translations, containsAll(['초안', '징집하다']));
      expect(learningGroupsOf(merged), containsAll(['업무', '시험']));
      controller.dispose();
    },
  );

  test('copies and moves custom items between learning groups', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    const item = LearningItem(
      id: 'group-word',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'station',
      translations: ['역'],
      acceptedAnswers: ['역'],
      tags: ['group:원본'],
      partOfSpeech: PartOfSpeech.noun,
    );
    await controller.upsertCustomItem(item);

    await controller.organizeItemsInLearningGroup({item.id}, '여행', copy: true);
    expect(learningGroupsOf(controller.customItemById(item.id)!), {'원본', '여행'});

    await controller.organizeItemsInLearningGroup(
      {item.id},
      '이번 주',
      copy: false,
    );
    expect(learningGroupsOf(controller.customItemById(item.id)!), {'이번 주'});
    controller.dispose();
  });

  test('a bundled item becomes a single local overlay when grouped', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final bundled = controller.courseItems.first;

    await controller.organizeItemsInLearningGroup(
      {bundled.id},
      '집중',
      copy: true,
    );

    expect(
      controller.courseItems.where((item) => item.id == bundled.id),
      hasLength(1),
    );
    expect(
      learningGroupsOf(
        controller.courseItems.firstWhere((item) => item.id == bundled.id),
      ),
      contains('집중'),
    );
    controller.dispose();
  });

  test('removes every group while preserving ordinary tags', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    const item = LearningItem(
      id: 'clear-groups-word',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'transfer',
      translations: ['옮기다'],
      acceptedAnswers: ['옮기다'],
      tags: ['group:여행', 'group:이번 주', 'verb'],
      partOfSpeech: PartOfSpeech.verb,
    );
    await controller.upsertCustomItem(item);

    await controller.removeItemsFromLearningGroups({item.id});

    final updated = controller.customItemById(item.id)!;
    expect(learningGroupsOf(updated), isEmpty);
    expect(updated.tags, contains('verb'));
    controller.dispose();
  });

  test('persists an empty group with metadata, pinning, and order', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);

    await controller.createLearningGroup(
      name: '출근길',
      description: '평일 아침에 외울 표현',
      colorKey: 'purple',
    );
    await controller.createLearningGroup(name: '이번 주');
    await controller.setLearningGroupPinned('이번 주', true);
    await controller.reorderLearningGroups(['이번 주', '출근길']);

    expect(controller.itemsForLearningGroup('출근길'), isEmpty);
    expect(controller.availableLearningGroups, ['이번 주', '출근길']);
    expect(
      controller.learningGroupDefinition('출근길')!.description,
      '평일 아침에 외울 표현',
    );
    expect(controller.learningGroupDefinition('출근길')!.colorKey, 'purple');
    expect(controller.learningGroupDefinition('이번 주')!.pinned, isTrue);
    expect(store.savedPreferences.learningGroups, hasLength(2));
    controller.dispose();
  });

  test(
    'restores items and independent group metadata from an undo snapshot',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      const item = LearningItem(
        id: 'undo-group-word',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'deadline',
        translations: ['마감일'],
        acceptedAnswers: ['마감일'],
        tags: ['group:업무'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await controller.upsertCustomItem(item);
      await controller.createLearningGroup(
        name: '업무',
        description: '평일에 복습',
        colorKey: 'blue',
      );
      final before = controller.captureLearningGroupWorkspace({item.id});

      await controller.organizeItemsInLearningGroup(
        {item.id},
        '여행',
        copy: false,
      );
      await controller.updateLearningGroupDefinition(
        controller
            .learningGroupDefinition('여행')!
            .copyWith(description: '임시 변경', colorKey: 'rose'),
      );
      expect(learningGroupsOf(controller.customItemById(item.id)!), {'여행'});

      await controller.restoreLearningGroupWorkspace(before);

      expect(learningGroupsOf(controller.customItemById(item.id)!), {'업무'});
      expect(controller.availableLearningGroups, ['업무']);
      expect(controller.learningGroupDefinition('업무')!.description, '평일에 복습');
      expect(controller.learningGroupDefinition('업무')!.colorKey, 'blue');
      expect(store.savedPreferences.learningGroups.single.name, '업무');
      controller.dispose();
    },
  );

  test(
    'renames and deletes a group without deleting its learning items',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const first = LearningItem(
        id: 'rename-word',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'platform',
        translations: ['승강장'],
        acceptedAnswers: ['승강장'],
        tags: ['group:여행', 'transport'],
        partOfSpeech: PartOfSpeech.noun,
      );
      const second = LearningItem(
        id: 'rename-sentence',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        text: 'Where is the platform?',
        translations: ['승강장은 어디인가요?'],
        acceptedAnswers: ['승강장은 어디인가요?'],
        tags: ['group:여행', 'group:질문'],
        sentenceTokens: ['Where', 'is', 'the', 'platform?'],
        capabilities: {
          ExerciseCapability.recognition,
          ExerciseCapability.production,
          ExerciseCapability.listening,
          ExerciseCapability.sentenceOrder,
        },
      );
      await controller.upsertCustomItem(first);
      await controller.upsertCustomItem(second);

      expect(await controller.renameLearningGroup('여행', '여행 준비'), 2);
      expect(controller.availableLearningGroups, contains('여행 준비'));
      expect(controller.availableLearningGroups, isNot(contains('여행')));
      expect(learningGroupsOf(controller.customItemById(second.id)!), {
        '여행 준비',
        '질문',
      });

      expect(await controller.deleteLearningGroup('여행 준비'), 2);
      expect(controller.availableLearningGroups, isNot(contains('여행 준비')));
      expect(controller.customItemById(first.id), isNotNull);
      expect(controller.customItemById(second.id), isNotNull);
      expect(controller.customItemById(first.id)!.tags, contains('transport'));
      expect(learningGroupsOf(controller.customItemById(second.id)!), {'질문'});
      controller.dispose();
    },
  );

  test('summarizes group item types, progress, and accuracy', () {
    const word = LearningItem(
      id: 'summary-word',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'ticket',
      translations: ['표'],
      acceptedAnswers: ['표'],
      tags: ['group:여행'],
    );
    const sentence = LearningItem(
      id: 'summary-sentence',
      kind: LearningItemKind.sentence,
      learningLanguage: LanguageTag.english,
      text: 'A ticket, please.',
      translations: ['표 한 장 주세요.'],
      acceptedAnswers: ['표 한 장 주세요.'],
      tags: ['group:여행'],
    );
    final summary = summarizeLearningGroup(
      '여행',
      [word, sentence],
      {
        word.id: const ProgressRecord(
          itemId: 'summary-word',
          status: LearningStatus.mastered,
          correctCount: 3,
          wrongCount: 1,
        ),
        sentence.id: const ProgressRecord(
          itemId: 'summary-sentence',
          correctCount: 1,
          wrongCount: 1,
        ),
      },
    );

    expect(summary.totalCount, 2);
    expect(summary.wordCount, 1);
    expect(summary.sentenceCount, 1);
    expect(summary.studiedCount, 2);
    expect(summary.masteredCount, 1);
    expect(summary.accuracy, closeTo(4 / 6, 0.001));
    expect(summary.studyRate, 1);
  });
}
