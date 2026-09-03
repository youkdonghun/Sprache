import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/korean_pronunciation.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  group('deriveKoreanPronunciation', () {
    test('does not guess pronunciation from Latin spelling', () {
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.english,
          text: 'beef',
        ),
        isNull,
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.english,
          text: 'friend',
        ),
        isNull,
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.german,
          text: 'Sprache',
        ),
        isNull,
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.french,
          text: 'aujourd’hui',
        ),
        isNull,
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.spanish,
          text: 'habitación',
        ),
        isNull,
      );
    });

    test('transcribes Japanese romaji and Chinese pinyin offline', () {
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.japanese,
          text: '学校',
          reading: 'がっこう',
          romanization: 'gakkou',
        ),
        '가코우',
      );
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.simplifiedChinese,
          text: '你好',
          reading: 'nǐ hǎo',
        ),
        '니 하오',
      );
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.simplifiedChinese,
          text: '学习',
          reading: 'xué xí',
        ),
        '쉐 시',
      );
    });

    test('uses kana safely without guessing kanji or raw hanzi', () {
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.japanese,
          text: '学校',
          reading: 'がっこう',
        ),
        '가코우',
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.japanese,
          text: 'カフェ',
        ),
        '카페',
      );
      expect(
        tryDeriveKoreanPronunciation(language: LanguageTag.japanese, text: '駅'),
        isNull,
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.simplifiedChinese,
          text: '你好',
        ),
        isNull,
      );
    });

    test('Latin sentences and ligatures also require reviewed readings', () {
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.spanish,
          text: '¿Dónde está la estación?',
        ),
        isNull,
      );
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.french,
          text: 'cœur',
        ),
        isNull,
      );
    });

    test('automatic Latin readings skip terms containing digits', () {
      expect(
        tryDeriveKoreanPronunciation(
          language: LanguageTag.english,
          text: 'term-2026',
        ),
        isNull,
      );
    });

    test('throwing API rejects Latin spelling without a phonetic source', () {
      expect(
        () => deriveKoreanPronunciation(
          language: LanguageTag.english,
          text: 'reef',
        ),
        throwsArgumentError,
      );
    });
  });
}
