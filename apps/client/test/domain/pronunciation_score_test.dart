import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/pronunciation_score.dart';

void main() {
  const scorer = PronunciationScorer();

  test('exact recognized sentence receives a perfect score', () {
    final result = scorer.assess(
      expected: 'Nice to meet you.',
      recognized: 'nice to meet you',
      language: LanguageTag.english,
    );

    expect(result.score, 100);
    expect(result.passed, isTrue);
  });

  test('partially recognized sentence stays below pass threshold', () {
    final result = scorer.assess(
      expected: 'Please speak slowly.',
      recognized: 'speak',
      language: LanguageTag.english,
    );

    expect(result.score, lessThan(75));
    expect(result.passed, isFalse);
  });

  test('unicode languages are scored by normalized characters', () {
    final result = scorer.assess(
      expected: '你好。',
      recognized: '你好',
      language: LanguageTag.simplifiedChinese,
    );

    expect(result.score, 100);
  });
}
