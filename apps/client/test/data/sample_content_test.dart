import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  test('ships the promised starter catalog for all six languages', () {
    final availableLanguages = LanguageTag.values.where(
      (language) => language.available,
    );
    final counts = {
      for (final language in availableLanguages)
        language: sampleContent
            .where((item) => item.learningLanguage == language)
            .length,
    };

    expect(counts[LanguageTag.english], 120);
    expect(counts[LanguageTag.japanese], 120);
    expect(counts[LanguageTag.german], 120);
    expect(counts[LanguageTag.french], 120);
    expect(counts[LanguageTag.spanish], 120);
    expect(counts[LanguageTag.simplifiedChinese], 120);
    expect(availableLanguages, hasLength(6));
    expect(LanguageTag.korean.available, isFalse);
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

  test('Japanese and Chinese starter content includes reading aids', () {
    final japaneseItems = sampleContent.where(
      (item) => item.learningLanguage == LanguageTag.japanese,
    );
    final chineseItems = sampleContent.where(
      (item) => item.learningLanguage == LanguageTag.simplifiedChinese,
    );

    for (final item in japaneseItems) {
      expect(item.reading(ReadingScheme.kana), isNotEmpty, reason: item.id);
      expect(item.reading(ReadingScheme.romaji), isNotEmpty, reason: item.id);
    }
    for (final item in chineseItems) {
      expect(item.reading(ReadingScheme.pinyin), isNotEmpty, reason: item.id);
    }
  });

  test('all 720 starter items include a Korean pronunciation aid', () {
    for (final language in LanguageTag.values.where(
      (value) => value.available,
    )) {
      final items = sampleContent.where(
        (item) => item.learningLanguage == language,
      );
      expect(items, hasLength(120), reason: language.code);
      for (final item in items) {
        final pronunciation = item.reading(ReadingScheme.hangul);
        expect(pronunciation, isNotNull, reason: item.id);
        expect(pronunciation, isNotEmpty, reason: item.id);
        expect(
          pronunciation,
          isNot(matches(RegExp(r'[A-Za-z]'))),
          reason: item.id,
        );
        expect(pronunciation, matches(RegExp(r'[가-힣]')), reason: item.id);
        expect(pronunciation, isNot(contains(r'$')), reason: item.id);
      }
    }
  });

  test('curated sentence readings remain readable across six languages', () {
    const expected = <String, String>{
      'Where is the station?': '웨어 이즈 더 스테이션?',
      '駅はどこですか。': '에키 와 도코 데스 카',
      'Wo ist der Bahnhof?': '보 이스트 데어 반호프?',
      'Où est la gare ?': '우 에 라 가르?',
      '¿Dónde está la estación?': '돈데 에스타 라 에스타시온?',
      '车站在哪里？': '처 잔 자이 나 리',
    };

    for (final entry in expected.entries) {
      final item = sampleContent.singleWhere(
        (candidate) => candidate.text == entry.key,
      );
      expect(item.reading(ReadingScheme.hangul), entry.value, reason: item.id);
    }
    expect(
      sampleContent
          .singleWhere((item) => item.id == 'en-starter-word-1')
          .reading(ReadingScheme.hangul),
      '헬로우',
    );
  });

  test('built-in catalog IDs and localized texts stay unique', () {
    expect(sampleContent.map((item) => item.id).toSet(), hasLength(720));
    for (final language in LanguageTag.values.where(
      (language) => language.available,
    )) {
      final localizedTexts = sampleContent
          .where((item) => item.learningLanguage == language)
          .map((item) => '${item.kind.name}:${item.text}')
          .toSet();
      expect(localizedTexts, hasLength(120), reason: language.code);
    }
  });
}
