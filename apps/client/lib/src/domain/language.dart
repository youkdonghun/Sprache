enum LanguageTag {
  english(
    code: 'en',
    koreanName: '영어',
    nativeName: 'English',
    ttsLocale: 'en-US',
    symbol: 'EN',
    available: true,
  ),
  japanese(
    code: 'ja',
    koreanName: '일본어',
    nativeName: '日本語',
    ttsLocale: 'ja-JP',
    symbol: '日',
    available: true,
  ),
  german(
    code: 'de',
    koreanName: '독일어',
    nativeName: 'Deutsch',
    ttsLocale: 'de-DE',
    symbol: 'DE',
    available: true,
  ),
  french(
    code: 'fr',
    koreanName: '프랑스어',
    nativeName: 'Français',
    ttsLocale: 'fr-FR',
    symbol: 'FR',
    available: true,
  ),
  spanish(
    code: 'es',
    koreanName: '스페인어',
    nativeName: 'Español',
    ttsLocale: 'es-ES',
    symbol: 'ES',
    available: true,
  ),
  simplifiedChinese(
    code: 'zh-Hans',
    koreanName: '중국어',
    nativeName: '简体中文',
    ttsLocale: 'zh-CN',
    symbol: '中',
    available: true,
  );

  const LanguageTag({
    required this.code,
    required this.koreanName,
    required this.nativeName,
    required this.ttsLocale,
    required this.symbol,
    this.available = false,
  });

  final String code;
  final String koreanName;
  final String nativeName;
  final String ttsLocale;
  final String symbol;
  final bool available;

  String get courseId => 'ko-$code';
}

enum ReadingScheme { kana, romaji, pinyin }

class Reading {
  const Reading({required this.scheme, required this.value});

  final ReadingScheme scheme;
  final String value;
}

class LanguageProfile {
  const LanguageProfile({
    required this.tag,
    required this.readingSchemes,
    required this.usesSpaces,
  });

  final LanguageTag tag;
  final Set<ReadingScheme> readingSchemes;
  final bool usesSpaces;

  static LanguageProfile of(LanguageTag tag) => switch (tag) {
    LanguageTag.japanese => const LanguageProfile(
      tag: LanguageTag.japanese,
      readingSchemes: {ReadingScheme.kana, ReadingScheme.romaji},
      usesSpaces: false,
    ),
    LanguageTag.simplifiedChinese => const LanguageProfile(
      tag: LanguageTag.simplifiedChinese,
      readingSchemes: {ReadingScheme.pinyin},
      usesSpaces: false,
    ),
    _ => LanguageProfile(tag: tag, readingSchemes: const {}, usesSpaces: true),
  };
}
