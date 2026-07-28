import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  test('ships the promised starter catalog for all six languages', () {
    final counts = {
      for (final language in LanguageTag.values)
        language: sampleContent
            .where((item) => item.learningLanguage == language)
            .length,
    };

    expect(counts[LanguageTag.english], 100);
    expect(counts[LanguageTag.japanese], 100);
    expect(counts[LanguageTag.german], 100);
    expect(counts[LanguageTag.french], 100);
    expect(counts[LanguageTag.spanish], 100);
    expect(counts[LanguageTag.simplifiedChinese], 100);
    expect(LanguageTag.values.every((language) => language.available), isTrue);
  });

  test('every built-in sentence supports cloze and sentence order', () {
    final sentences = sampleContent.where(
      (item) => item.kind == LearningItemKind.sentence,
    );

    for (final sentence in sentences) {
      expect(sentence.sentenceTokens.length, greaterThanOrEqualTo(2));
      expect(
        sentence.capabilities,
        contains(ExerciseCapability.cloze),
        reason: sentence.id,
      );
      expect(
        sentence.capabilities,
        contains(ExerciseCapability.sentenceOrder),
        reason: sentence.id,
      );
    }
  });

  test('Japanese and Chinese starter words include reading aids', () {
    final japaneseWords = sampleContent.where(
      (item) =>
          item.learningLanguage == LanguageTag.japanese &&
          item.kind == LearningItemKind.word,
    );
    final chineseWords = sampleContent.where(
      (item) =>
          item.learningLanguage == LanguageTag.simplifiedChinese &&
          item.kind == LearningItemKind.word,
    );

    for (final word in japaneseWords) {
      expect(word.reading(ReadingScheme.kana), isNotEmpty, reason: word.id);
      expect(word.reading(ReadingScheme.romaji), isNotEmpty, reason: word.id);
    }
    for (final word in chineseWords) {
      expect(word.reading(ReadingScheme.pinyin), isNotEmpty, reason: word.id);
    }
  });
}
