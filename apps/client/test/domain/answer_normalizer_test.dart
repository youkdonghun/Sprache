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

  test('handles English and French apostrophe spacing', () {
    expect(
      normalizer.matches(
        input: "don't",
        acceptedAnswers: const ['dont'],
        language: LanguageTag.english,
      ),
      isTrue,
    );
    expect(
      normalizer.matches(
        input: "l' ami",
        acceptedAnswers: const ["l’ami"],
        language: LanguageTag.french,
      ),
      isTrue,
    );
  });

  test('treats German sharp s as its common ss spelling', () {
    expect(
      normalizer.matches(
        input: 'STRASSE',
        acceptedAnswers: const ['Straße'],
        language: LanguageTag.german,
      ),
      isTrue,
    );
  });

  test('normalizes Spanish inverted punctuation without dropping accents', () {
    expect(
      normalizer.matches(
        input: '¿Cómo estás?',
        acceptedAnswers: const ['cómo estás'],
        language: LanguageTag.spanish,
      ),
      isTrue,
    );
    expect(
      normalizer.matches(
        input: 'como estas',
        acceptedAnswers: const ['cómo estás'],
        language: LanguageTag.spanish,
      ),
      isFalse,
    );
  });

  test('removes optional spacing for Japanese and simplified Chinese', () {
    expect(
      normalizer.matches(
        input: '日 本 語。',
        acceptedAnswers: const ['日本語'],
        language: LanguageTag.japanese,
      ),
      isTrue,
    );
    expect(
      normalizer.matches(
        input: '你 好！',
        acceptedAnswers: const ['你好'],
        language: LanguageTag.simplifiedChinese,
      ),
      isTrue,
    );
  });
}
