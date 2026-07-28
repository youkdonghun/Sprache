import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/answer_normalizer.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  const normalizer = AnswerNormalizer();

  test('normalizes width, spaces, case, and punctuation', () {
    final result = normalizer.normalize(
      '  ＨＥＬＬＯ,   World! ',
      language: LanguageTag.english,
    );
    expect(result, 'hello world');
  });

  test('accepts an explicitly listed Korean answer', () {
    expect(
      normalizer.matches(
        input: ' 학습 ',
        acceptedAnswers: const ['공부', '학습'],
        language: LanguageTag.japanese,
      ),
      isTrue,
    );
  });

  test('limits typo tolerance to sufficiently long answers', () {
    expect(
      normalizer.matches(
        input: 'langauge',
        acceptedAnswers: const ['language'],
        language: LanguageTag.english,
        policy: const AnswerPolicy(allowTypo: true),
      ),
      isTrue,
    );
    expect(
      normalizer.matches(
        input: 'wat',
        acceptedAnswers: const ['water'],
        language: LanguageTag.english,
        policy: const AnswerPolicy(allowTypo: true),
      ),
      isFalse,
    );
  });
}
