import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/daily_queue.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';

void main() {
  const builder = DailyQueueBuilder();
  final date = DateTime(2026, 7, 27, 10);
  final englishItems = sampleContent
      .where((item) => item.learningLanguage == LanguageTag.english)
      .toList();

  test('uses a deterministic new-item order for the same course and date', () {
    final first = builder.build(
      courseId: 'ko-en',
      localDate: date,
      items: englishItems,
      progress: const {},
    );
    final second = builder.build(
      courseId: 'ko-en',
      localDate: date,
      items: englishItems,
      progress: const {},
    );

    expect(first.map((item) => item.id), second.map((item) => item.id));
  });

  test('places overdue reviews before new items', () {
    final dueItem = englishItems.last;
    final queue = builder.build(
      courseId: 'ko-en',
      localDate: date,
      items: englishItems,
      progress: {
        dueItem.id: ProgressRecord(
          itemId: dueItem.id,
          status: LearningStatus.review,
          nextReviewAt: date.subtract(const Duration(days: 1)),
        ),
      },
    );

    expect(queue.first.id, dueItem.id);
  });

  test('honors the configured sentence ratio when enough items exist', () {
    final items = [
      for (var index = 0; index < 15; index++)
        LearningItem(
          id: 'word-$index',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'word $index',
          translations: ['단어 $index'],
          acceptedAnswers: ['단어 $index'],
        ),
      for (var index = 0; index < 5; index++)
        LearningItem(
          id: 'sentence-$index',
          kind: LearningItemKind.sentence,
          learningLanguage: LanguageTag.english,
          text: 'Sentence $index.',
          translations: ['문장 $index'],
          acceptedAnswers: ['문장 $index'],
        ),
    ];

    final queue = builder.build(
      courseId: 'ko-en',
      localDate: date,
      items: items,
      progress: const {},
      newItemLimit: 20,
      sentenceRatio: 0.25,
    );

    expect(queue, hasLength(20));
    expect(
      queue.where((item) => item.kind == LearningItemKind.sentence),
      hasLength(5),
    );
  });
}
