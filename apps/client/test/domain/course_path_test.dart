import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/course_path.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';

void main() {
  const builder = CoursePathBuilder();

  List<LearningItem> englishItems() => sampleContent
      .where((item) => item.learningLanguage == LanguageTag.english)
      .toList(growable: false);

  test('builds six communication units without losing course items', () {
    final items = englishItems();
    final path = builder.build(items: items, progress: const {});

    expect(path.units, hasLength(6));
    expect(path.units.expand((unit) => unit.items).toSet(), items.toSet());
    expect(path.recommendedUnit.index, 0);
    expect(path.recommendedUnit.nextLesson, CourseLessonKind.cards);
  });

  test('places personal expressions in the final practical unit', () {
    final items = [
      ...englishItems(),
      const LearningItem(
        id: 'personal-expression',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        text: 'Could you send the report?',
        translations: ['보고서를 보내 주시겠어요?'],
        acceptedAnswers: ['보고서를 보내 주시겠어요?'],
      ),
    ];

    final path = builder.build(items: items, progress: const {});

    expect(
      path.units.last.items.map((item) => item.id),
      contains('personal-expression'),
    );
  });

  test('groups starter content by communication goal', () {
    final path = builder.build(items: englishItems(), progress: const {});

    expect(
      path.units[0].items.map((item) => item.text),
      containsAll(['hello', 'My name is Mina.', 'Nice to meet you.']),
    );
    expect(
      path.units[3].items.map((item) => item.text),
      containsAll(['coffee', 'restaurant', 'I would like coffee.']),
    );
    expect(
      path.units[4].items.map((item) => item.text),
      containsAll(['station', 'train', 'Where is the station?']),
    );
    expect(
      path.units[5].items.map((item) => item.text),
      containsAll(['help', 'Please speak slowly.', 'Can you help me?']),
    );
  });

  test('every language has words and sentences in all six units', () {
    for (final language in LanguageTag.values) {
      final path = builder.build(
        items: sampleContent
            .where((item) => item.learningLanguage == language)
            .toList(growable: false),
        progress: const {},
      );

      expect(
        path.units.every((unit) => unit.words.isNotEmpty),
        isTrue,
        reason: '${language.name} word coverage',
      );
      expect(
        path.units.every((unit) => unit.sentences.isNotEmpty),
        isTrue,
        reason: '${language.name} sentence coverage',
      );
    }
  });

  test('moves recommendation to the first incomplete unit', () {
    final items = englishItems();
    final emptyPath = builder.build(items: items, progress: const {});
    final firstUnitProgress = {
      for (final item in emptyPath.units.first.items)
        item.id: ProgressRecord(
          itemId: item.id,
          status: LearningStatus.mastered,
          correctCount: 5,
        ),
    };

    final path = builder.build(items: items, progress: firstUnitProgress);

    expect(path.units.first.completed, isTrue);
    expect(path.recommendedUnit.index, 1);
  });

  test('generates unit-scoped routes for every lesson type', () {
    expect(
      courseLessonRoute(CourseLessonKind.cards, 2),
      '/cards?kind=mixed&unit=2',
    );
    expect(
      courseLessonRoute(CourseLessonKind.speaking, 2),
      '/pronunciation?unit=2',
    );
  });
}
