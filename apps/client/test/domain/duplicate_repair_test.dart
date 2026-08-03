import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/duplicate_repair.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';

void main() {
  LearningItem item(
    String id,
    String text, {
    String subjectId = 'language:en',
    LanguageTag language = LanguageTag.english,
  }) => LearningItem(
    id: id,
    kind: LearningItemKind.word,
    learningLanguage: language,
    subjectId: subjectId,
    text: text,
    translations: const ['meaning'],
    acceptedAnswers: const ['meaning'],
  );

  test(
    'exact groups use normalized expression, language, and subject only',
    () {
      const analyzer = DuplicateRepairAnalyzer();
      final catalog = analyzer.analyze([
        item('first', '  Draft  '),
        item('second', 'draft'),
        item('other-subject', 'draft', subjectId: 'custom:office'),
        item(
          'other-language',
          'draft',
          language: LanguageTag.german,
          subjectId: 'language:de',
        ),
      ]);

      expect(catalog.exactGroups, hasLength(1));
      expect(
        catalog.exactGroups.single.items.map((value) => value.id).toSet(),
        {'first', 'second'},
      );
    },
  );

  test('near matches are suggestions and never exact groups', () {
    const analyzer = DuplicateRepairAnalyzer();
    final catalog = analyzer.analyze([
      item('correct', 'accommodate'),
      item('typo', 'acommodate'),
      item('unrelated', 'passport'),
    ]);

    expect(catalog.exactGroups, isEmpty);
    expect(catalog.similarSuggestions, hasLength(1));
    expect(catalog.similarSuggestions.single.kind, DuplicateMatchKind.similar);
    expect(
      catalog.similarSuggestions.single.items.map((value) => value.id).toSet(),
      {'correct', 'typo'},
    );
    expect(catalog.similarSuggestions.single.similarity, greaterThan(0.8));
  });

  test('recommended canonical favors established progress', () {
    const analyzer = DuplicateRepairAnalyzer();
    final first = item('first', 'draft');
    final second = item('second', 'draft');

    expect(
      analyzer
          .recommendCanonical(
            [first, second],
            {
              first.id: const ProgressRecord(
                itemId: 'first',
                status: LearningStatus.learning,
                correctCount: 2,
              ),
              second.id: const ProgressRecord(
                itemId: 'second',
                status: LearningStatus.mastered,
                correctCount: 8,
              ),
            },
          )
          .id,
      'second',
    );
  });
}
