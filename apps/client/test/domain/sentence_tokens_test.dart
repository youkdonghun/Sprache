import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/sentence_tokens.dart';

void main() {
  const parser = SentenceTokenParser();
  const validator = SentenceTokenValidator();

  test('suggests whitespace tokens only after the parser is called', () {
    expect(
      parser.suggest(
        'I  accomplished\nmy goal.',
        language: LanguageTag.english,
      ),
      ['I', 'accomplished', 'my', 'goal.'],
    );
  });

  test('uses explicit whitespace boundaries for Japanese pasted text', () {
    expect(parser.suggest('私 は 学生 です。', language: LanguageTag.japanese), [
      '私',
      'は',
      '学生',
      'です。',
    ]);
    expect(parser.suggest('私は学生です。', language: LanguageTag.japanese), [
      '私',
      'は',
      '学',
      '生',
      'で',
      'す',
      '。',
    ]);
  });

  test('empty tokens disable token exercises without blocking save', () {
    final result = validator.inspect(
      sentence: 'How are you?',
      tokens: const [],
    );

    expect(result.canSave, isTrue);
    expect(result.enablesSentenceExercises, isFalse);
    expect(result.message, isNull);
  });

  test('valid explicit tokens reconstruct the sentence', () {
    final result = validator.inspect(
      sentence: 'How are you?',
      tokens: const ['How', 'are', 'you?'],
    );

    expect(result.canSave, isTrue);
    expect(result.enablesSentenceExercises, isTrue);
    expect(result.tokens, ['How', 'are', 'you?']);
  });

  test('one token and mismatched tokens explain why save is blocked', () {
    final tooFew = validator.inspect(
      sentence: 'How are you?',
      tokens: const ['How are you?'],
    );
    final mismatch = validator.inspect(
      sentence: 'How are you?',
      tokens: const ['How', 'is', 'you?'],
    );

    expect(tooFew.issue, SentenceTokenIssue.tooFew);
    expect(tooFew.message, contains('2개'));
    expect(mismatch.issue, SentenceTokenIssue.mismatch);
    expect(mismatch.message, contains('다릅니다'));
  });
}
