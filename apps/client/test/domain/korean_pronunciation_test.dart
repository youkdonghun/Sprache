import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/korean_pronunciation.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  group('deriveKoreanPronunciation', () {
    test('uses curated starter-word readings for Latin languages', () {
      expect(
        deriveKoreanPronunciation(language: LanguageTag.english, text: 'beef'),
        '비프',
      );
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.english,
          text: 'friend',
        ),
        '프렌드',
      );
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.german,
          text: 'Sprache',
        ),
        '슈프라헤',
      );
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.french,
          text: 'aujourd’hui',
        ),
        '오주르뒤',
      );
      expect(
        deriveKoreanPronunciation(
          language: LanguageTag.spanish,
          text: 'habitación',
        ),
        '아비타시온',
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

    test('keeps sentence spacing and punctuation without Latin leftovers', () {
      final result = deriveKoreanPronunciation(
        language: LanguageTag.spanish,
        text: '¿Dónde está la estación?',
      );

      expect(result, contains(' '));
      expect(result, endsWith('?'));
      expect(result, isNot(matches(RegExp(r'[A-Za-z]'))));
      expect(result, matches(RegExp(r'[가-힣]')));
    });

    test('accepts common Latin ligatures without leaking source letters', () {
      final result = tryDeriveKoreanPronunciation(
        language: LanguageTag.french,
        text: 'cœur',
      );

      expect(result, isNotNull);
      expect(result, isNot(matches(RegExp(r'[A-Za-zœ]'))));
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

    test(
      'does not silently drop a terminal consonant without a Hangul coda',
      () {
        expect(
          deriveKoreanPronunciation(
            language: LanguageTag.english,
            text: 'reef',
          ),
          endsWith('프'),
        );
      },
    );
  });
}
