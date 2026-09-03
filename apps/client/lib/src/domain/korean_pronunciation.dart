import 'language.dart';

/// Builds an offline Korean reading aid from an actual phonetic reading.
///
/// Latin spelling is intentionally not transcribed: it is not a phonetic source
/// and previously produced confident but wrong aids. Audio remains the source
/// of truth for pronunciation practice.
String? tryDeriveKoreanPronunciation({
  required LanguageTag language,
  required String text,
  String? reading,
  String? romanization,
}) {
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) return null;

  switch (language) {
    case LanguageTag.japanese:
      final romaji = romanization?.trim() ?? '';
      if (romaji.isNotEmpty && _isSafeLatinSource(romaji)) {
        return _nonEmptyOrNull(_transcribeJapanese(romaji));
      }
      for (final candidate in [reading?.trim() ?? '', trimmedText]) {
        if (candidate.isEmpty) continue;
        final kanaRomaji = _romanizeKana(candidate);
        if (kanaRomaji != null) {
          return _nonEmptyOrNull(_transcribeJapanese(kanaRomaji));
        }
      }
      return null;
    case LanguageTag.simplifiedChinese:
      final pinyin = reading?.trim() ?? '';
      if (pinyin.isEmpty || !_isSafePinyinSource(pinyin)) return null;
      return _nonEmptyOrNull(_transcribePinyin(pinyin));
    case LanguageTag.english:
    case LanguageTag.german:
    case LanguageTag.french:
    case LanguageTag.spanish:
      return null;
    case LanguageTag.korean:
      return trimmedText;
  }
}

String deriveKoreanPronunciation({
  required LanguageTag language,
  required String text,
  String? reading,
  String? romanization,
}) {
  final result = tryDeriveKoreanPronunciation(
    language: language,
    text: text,
    reading: reading,
    romanization: romanization,
  );
  if (result == null) {
    throw ArgumentError.value(
      romanization ?? reading ?? text,
      'source',
      '${language.code} 한국어 발음 보조표기를 안전하게 만들 수 없습니다.',
    );
  }
  return result;
}

String? _nonEmptyOrNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool _isSafeLatinSource(String source) {
  final folded = _foldLatin(source);
  var hasLetter = false;
  for (final rune in folded.runes) {
    final isLetter =
        (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
    if (isLetter) {
      hasLetter = true;
      continue;
    }
    if (_safeTranscriptionSeparators.contains(rune)) {
      continue;
    }
    return false;
  }
  return hasLetter;
}

bool _isSafePinyinSource(String source) {
  final folded = _foldLatin(source);
  var hasLetter = false;
  for (final rune in folded.runes) {
    final isLetter =
        (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
    if (isLetter) {
      hasLetter = true;
      continue;
    }
    if ((rune >= 0x31 && rune <= 0x35) ||
        rune == 0x3A ||
        _safeTranscriptionSeparators.contains(rune)) {
      continue;
    }
    return false;
  }
  return hasLetter;
}

const _safeTranscriptionSeparators = <int>{
  0x20,
  0x09,
  0x0A,
  0x0D,
  0x27,
  0x28,
  0x29,
  0x2C,
  0x2D,
  0x2E,
  0x2F,
  0x21,
  0x3F,
  0x3B,
  0x00B7,
  0x00BF,
  0x00A1,
  0x2013,
  0x2014,
  0x2019,
};

String? _romanizeKana(String source) {
  final characters = [
    for (final rune in source.runes) _toHiragana(String.fromCharCode(rune)),
  ];
  final output = StringBuffer();
  var hasMora = false;
  var geminate = false;
  String? lastVowel;

  for (var index = 0; index < characters.length;) {
    final character = characters[index];
    if (character == 'っ') {
      geminate = true;
      index++;
      continue;
    }
    if (character == 'ー') {
      if (lastVowel == null) return null;
      output.write(lastVowel);
      index++;
      continue;
    }
    final separator = _kanaSeparators[character];
    if (separator != null) {
      if (geminate) return null;
      output.write(separator);
      index++;
      continue;
    }

    String? mora;
    if (index + 1 < characters.length) {
      mora = _kanaMora['${characters[index]}${characters[index + 1]}'];
      if (mora != null) index += 2;
    }
    if (mora == null) {
      mora = _kanaMora[character];
      if (mora == null) return null;
      index++;
    }
    if (geminate) {
      final first = mora[0];
      if ('aeiouvn'.contains(first)) return null;
      output.write(first);
      geminate = false;
    }
    output.write(mora);
    hasMora = true;
    for (final unit in mora.split('').reversed) {
      if ('aeiouv'.contains(unit)) {
        lastVowel = unit == 'v' ? 'u' : unit;
        break;
      }
    }
  }
  if (geminate || !hasMora) return null;
  return output.toString();
}

String _toHiragana(String value) {
  final rune = value.runes.single;
  if (rune >= 0x30A1 && rune <= 0x30F6) {
    return String.fromCharCode(rune - 0x60);
  }
  return value;
}

String _transcribeJapanese(String source) {
  final normalized = _foldLatin(source).toLowerCase();
  final output = StringBuffer();
  var index = 0;
  while (index < normalized.length) {
    final character = normalized[index];
    if (!_isAsciiLetter(character)) {
      _writeSeparator(output, character);
      index += 1;
      continue;
    }
    if (character == 'n' &&
        (index + 1 == normalized.length ||
            !_isVowel(normalized[index + 1]) && normalized[index + 1] != 'y')) {
      final attached = _attachCoda(output.toString(), 4);
      output
        ..clear()
        ..write(attached);
      index += 1;
      continue;
    }
    if (index + 1 < normalized.length &&
        character == normalized[index + 1] &&
        !_isVowel(character) &&
        character != 'n') {
      index += 1;
      continue;
    }
    String? matched;
    for (final length in const [3, 2, 1]) {
      if (index + length > normalized.length) continue;
      final candidate = normalized.substring(index, index + length);
      if (_japaneseMora.containsKey(candidate)) {
        matched = candidate;
        break;
      }
    }
    if (matched != null) {
      output.write(_japaneseMora[matched]);
      index += matched.length;
      continue;
    }
    output.write(_latinLetterNames[character] ?? '');
    index += 1;
  }
  return _normalizeResult(output.toString());
}

String _transcribePinyin(String source) {
  final words = source
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.map(_pinyinSyllable).join(' ');
}

String _pinyinSyllable(String source) {
  var syllable = _foldLatin(
    source,
  ).toLowerCase().replaceAll('u:', 'v').replaceAll(RegExp('[^a-zv]'), '');
  if (syllable.isEmpty) return '';
  final exact = _pinyinExact[syllable];
  if (exact != null) return exact;

  var initial = '';
  for (final candidate in const [
    'zh',
    'ch',
    'sh',
    'b',
    'p',
    'm',
    'f',
    'd',
    't',
    'n',
    'l',
    'g',
    'k',
    'h',
    'j',
    'q',
    'x',
    'r',
    'z',
    'c',
    's',
    'y',
    'w',
  ]) {
    if (syllable.startsWith(candidate)) {
      initial = candidate;
      syllable = syllable.substring(candidate.length);
      break;
    }
  }
  if (initial == 'y') {
    syllable = switch (syllable) {
      'a' => 'ia',
      'ao' => 'iao',
      'e' => 'ie',
      'ou' => 'iu',
      'an' => 'ian',
      'ang' => 'iang',
      'ong' => 'iong',
      'u' => 'v',
      final value when value.startsWith('u') => 'v${value.substring(1)}',
      '' => 'i',
      _ => syllable,
    };
    initial = '';
  } else if (initial == 'w') {
    syllable = switch (syllable) {
      '' => 'u',
      final value when value.startsWith('u') => value,
      _ => 'u$syllable',
    };
    initial = '';
  } else if ({'j', 'q', 'x'}.contains(initial) && syllable.startsWith('u')) {
    syllable = 'v${syllable.substring(1)}';
  }

  final rime = _pinyinRimes[syllable];
  if (rime == null) {
    return _latinSyllables(syllable, language: LanguageTag.simplifiedChinese);
  }
  final onset = _pinyinOnsets[initial];
  return onset == null ? rime : _replaceFirstOnset(rime, onset);
}

// Kept only as an editor-side preview implementation for possible future
// phonetic-source support. Production content never calls this spelling-based
// helper because Latin orthography alone is not a reliable pronunciation aid.
// ignore: unused_element
String _transcribeLatin(LanguageTag language, String source) {
  final normalized = _foldLatin(source).toLowerCase();
  final entireOverride = _latinOverrides[language]?[normalized.trim()];
  if (entireOverride != null) return entireOverride;

  final output = StringBuffer();
  for (final match in RegExp(r'[a-z]+|[^a-z]+').allMatches(normalized)) {
    final token = match.group(0)!;
    if (RegExp(r'^[a-z]+$').hasMatch(token)) {
      output.write(
        _sentenceWordOverrides[language]?[token] ??
            _latinOverrides[language]?[token] ??
            _latinSyllables(token, language: language),
      );
    } else {
      for (final character in token.split('')) {
        _writeSeparator(output, character);
      }
    }
  }
  return _normalizeResult(output.toString());
}

String _latinSyllables(String source, {required LanguageTag language}) {
  var word = source;
  word = switch (language) {
    LanguageTag.english => _prepareEnglish(word),
    LanguageTag.german => _prepareGerman(word),
    LanguageTag.french => _prepareFrench(word),
    LanguageTag.spanish => _prepareSpanish(word),
    _ => word,
  };
  if (word.isEmpty) return '';

  word = word
      .replaceAll('sch', 'S')
      .replaceAll('sh', 'S')
      .replaceAll('ch', 'C')
      .replaceAll('zh', 'Z')
      .replaceAll('th', 'T')
      .replaceAll('ph', 'F')
      .replaceAll('ng', 'N')
      .replaceAll('ny', 'Y')
      .replaceAll('ts', 'X');

  final units = word.split('');
  final output = StringBuffer();
  var index = 0;
  while (index < units.length) {
    final onsetUnits = <String>[];
    while (index < units.length && !_isVowelUnit(units[index])) {
      onsetUnits.add(units[index]);
      index += 1;
    }
    if (index == units.length) {
      for (var i = 0; i < onsetUnits.length; i += 1) {
        final consonant = onsetUnits[i];
        if (i == 0 && output.isNotEmpty) {
          final attached = _attachCoda(
            output.toString(),
            _codaIndexes[consonant] ?? 0,
          );
          output
            ..clear()
            ..write(attached);
        } else {
          output.write(_compose(_onsetIndexes[consonant] ?? 11, 18));
        }
      }
      break;
    }

    final vowel = units[index];
    index += 1;
    final onset = onsetUnits.isEmpty
        ? 11
        : _onsetIndexes[onsetUnits.removeLast()] ?? 11;
    for (final consonant in onsetUnits) {
      output.write(_compose(_onsetIndexes[consonant] ?? 11, 18));
    }
    output.write(_compose(onset, _vowelIndexes[vowel] ?? 18));

    final trailing = <String>[];
    var cursor = index;
    while (cursor < units.length && !_isVowelUnit(units[cursor])) {
      trailing.add(units[cursor]);
      cursor += 1;
    }
    final reachesEnd = cursor == units.length;
    if (reachesEnd && trailing.isNotEmpty) {
      final first = trailing.first;
      final coda = _codaIndexes[first];
      if (coda != null) {
        final attached = _attachCoda(output.toString(), coda);
        output
          ..clear()
          ..write(attached);
        index += 1;
      }
      for (final consonant in coda == null ? trailing : trailing.skip(1)) {
        output.write(_compose(_onsetIndexes[consonant] ?? 11, 18));
        index += 1;
      }
    }
  }
  return output.toString();
}

String _prepareEnglish(String word) {
  var value = word;
  value = value
      .replaceAll('tion', 'shon')
      .replaceAll('sion', 'zhon')
      .replaceAll('ture', 'cher')
      .replaceAll('igh', 'ai')
      .replaceAll('eigh', 'ei')
      .replaceAll('ee', 'i')
      .replaceAll('oo', 'u')
      .replaceAll('ck', 'k')
      .replaceAll('qu', 'kw')
      .replaceAll('wr', 'r')
      .replaceAll('kn', 'n')
      .replaceAll('ph', 'f');
  if (value.length > 3 && value.endsWith('e')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

String _prepareGerman(String word) => word
    .replaceAll('tsch', 'ch')
    .replaceAll('sch', 'sh')
    .replaceAll('ch', 'h')
    .replaceAll('ei', 'ai')
    .replaceAll('ie', 'i')
    .replaceAll('eu', 'oi')
    .replaceAll('oe', 'o')
    .replaceAll('ue', 'u')
    .replaceAll('z', 'ts')
    .replaceAll('v', 'f')
    .replaceAll('w', 'v')
    .replaceAll('j', 'y');

String _prepareFrench(String word) {
  var value = word
      .replaceAll('eaux', 'o')
      .replaceAll('eau', 'o')
      .replaceAll('ain', 'eng')
      .replaceAll('ein', 'eng')
      .replaceAll('an', 'ang')
      .replaceAll('en', 'ang')
      .replaceAll('on', 'ong')
      .replaceAll('oi', 'wa')
      .replaceAll('ou', 'u')
      .replaceAll('au', 'o')
      .replaceAll('gn', 'ny')
      .replaceAll('ill', 'y')
      .replaceAll('ch', 'sh')
      .replaceAll('qu', 'k')
      .replaceAll('ph', 'f');
  if (value.length > 3) {
    value = value.replaceFirst(RegExp(r'(ent|es|e|s|x|t|d|p|g)$'), '');
  }
  return value;
}

String _prepareSpanish(String word) => word
    .replaceAll('ll', 'y')
    .replaceAll('qu', 'k')
    .replaceAll(RegExp(r'c(?=[ei])'), 's')
    .replaceAll(RegExp(r'g(?=[ei])'), 'H')
    .replaceAll('j', 'H')
    .replaceAll('v', 'b')
    .replaceAll('z', 's')
    .replaceAll('x', 'ks')
    .replaceAll('h', '')
    .replaceAll('H', 'h');

String _foldLatin(String value) {
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'ae',
    'ã': 'a',
    'å': 'a',
    'ā': 'a',
    'ǎ': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ě': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ǐ': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'oe',
    'õ': 'o',
    'ō': 'o',
    'ǒ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'v',
    'ū': 'u',
    'ǔ': 'u',
    'ǖ': 'v',
    'ǘ': 'v',
    'ǚ': 'v',
    'ǜ': 'v',
    'ñ': 'ny',
    'ç': 'c',
    'ß': 'ss',
    'œ': 'oe',
    'æ': 'ae',
    'ø': 'o',
    'ł': 'l',
    'ð': 'd',
    'þ': 'th',
    '‘': "'",
    '’': "'",
  };
  final output = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    output.write(replacements[character.toLowerCase()] ?? character);
  }
  return output.toString();
}

bool _isAsciiLetter(String value) =>
    value.codeUnitAt(0) >= 97 && value.codeUnitAt(0) <= 122;

bool _isVowel(String value) => 'aeiouv'.contains(value);

bool _isVowelUnit(String value) => _vowelIndexes.containsKey(value);

void _writeSeparator(StringBuffer output, String character) {
  if (RegExp(r'\s').hasMatch(character)) {
    if (output.isNotEmpty && !output.toString().endsWith(' ')) {
      output.write(' ');
    }
    return;
  }
  if (RegExp(r'[0-9.,!?:;()\-]').hasMatch(character)) {
    output.write(character);
  }
}

String _normalizeResult(String value) => value
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAllMapped(RegExp(r'\s+([.,!?])'), (match) => match.group(1)!)
    .trim();

String _compose(int onset, int vowel, [int coda = 0]) =>
    String.fromCharCode(0xAC00 + ((onset * 21) + vowel) * 28 + coda);

String _replaceFirstOnset(String value, int onset) {
  if (value.isEmpty) return value;
  final first = value.codeUnitAt(0);
  if (first < 0xAC00 || first > 0xD7A3) return value;
  final offset = first - 0xAC00;
  final vowel = (offset % 588) ~/ 28;
  final coda = offset % 28;
  return '${_compose(onset, vowel, coda)}${value.substring(1)}';
}

String _attachCoda(String value, int coda) {
  if (value.isEmpty || coda == 0) return value;
  final runes = value.runes.toList();
  final last = runes.last;
  if (last < 0xAC00 || last > 0xD7A3 || (last - 0xAC00) % 28 != 0) {
    return value;
  }
  runes[runes.length - 1] = last + coda;
  return String.fromCharCodes(runes);
}

const _kanaSeparators = <String, String>{
  ' ': ' ',
  '\t': ' ',
  '\n': ' ',
  '\r': ' ',
  '、': ',',
  '。': '.',
  '・': ' ',
  '！': '!',
  '？': '?',
  '〜': '-',
  '～': '-',
  ',': ',',
  '.': '.',
  '!': '!',
  '?': '?',
  '-': '-',
  "'": "'",
  '’': "'",
};

const _kanaMora = <String, String>{
  'きゃ': 'kya',
  'きゅ': 'kyu',
  'きょ': 'kyo',
  'しゃ': 'sha',
  'しゅ': 'shu',
  'しょ': 'sho',
  'ちゃ': 'cha',
  'ちゅ': 'chu',
  'ちょ': 'cho',
  'にゃ': 'nya',
  'にゅ': 'nyu',
  'にょ': 'nyo',
  'ひゃ': 'hya',
  'ひゅ': 'hyu',
  'ひょ': 'hyo',
  'みゃ': 'mya',
  'みゅ': 'myu',
  'みょ': 'myo',
  'りゃ': 'rya',
  'りゅ': 'ryu',
  'りょ': 'ryo',
  'ぎゃ': 'gya',
  'ぎゅ': 'gyu',
  'ぎょ': 'gyo',
  'じゃ': 'ja',
  'じゅ': 'ju',
  'じょ': 'jo',
  'びゃ': 'bya',
  'びゅ': 'byu',
  'びょ': 'byo',
  'ぴゃ': 'pya',
  'ぴゅ': 'pyu',
  'ぴょ': 'pyo',
  'しぇ': 'she',
  'じぇ': 'je',
  'ちぇ': 'che',
  'てぃ': 'ti',
  'でぃ': 'di',
  'とぅ': 'tu',
  'どぅ': 'du',
  'ふぁ': 'fa',
  'ふぃ': 'fi',
  'ふぇ': 'fe',
  'ふぉ': 'fo',
  'うぃ': 'wi',
  'うぇ': 'we',
  'うぉ': 'wo',
  'つぁ': 'tsa',
  'つぃ': 'tsi',
  'つぇ': 'tse',
  'つぉ': 'tso',
  'ゔぁ': 'va',
  'ゔぃ': 'vi',
  'ゔぇ': 've',
  'ゔぉ': 'vo',
  'あ': 'a',
  'い': 'i',
  'う': 'u',
  'え': 'e',
  'お': 'o',
  'か': 'ka',
  'き': 'ki',
  'く': 'ku',
  'け': 'ke',
  'こ': 'ko',
  'が': 'ga',
  'ぎ': 'gi',
  'ぐ': 'gu',
  'げ': 'ge',
  'ご': 'go',
  'さ': 'sa',
  'し': 'shi',
  'す': 'su',
  'せ': 'se',
  'そ': 'so',
  'ざ': 'za',
  'じ': 'ji',
  'ず': 'zu',
  'ぜ': 'ze',
  'ぞ': 'zo',
  'た': 'ta',
  'ち': 'chi',
  'つ': 'tsu',
  'て': 'te',
  'と': 'to',
  'だ': 'da',
  'ぢ': 'ji',
  'づ': 'zu',
  'で': 'de',
  'ど': 'do',
  'な': 'na',
  'に': 'ni',
  'ぬ': 'nu',
  'ね': 'ne',
  'の': 'no',
  'は': 'ha',
  'ひ': 'hi',
  'ふ': 'fu',
  'へ': 'he',
  'ほ': 'ho',
  'ば': 'ba',
  'び': 'bi',
  'ぶ': 'bu',
  'べ': 'be',
  'ぼ': 'bo',
  'ぱ': 'pa',
  'ぴ': 'pi',
  'ぷ': 'pu',
  'ぺ': 'pe',
  'ぽ': 'po',
  'ま': 'ma',
  'み': 'mi',
  'む': 'mu',
  'め': 'me',
  'も': 'mo',
  'や': 'ya',
  'ゆ': 'yu',
  'よ': 'yo',
  'ら': 'ra',
  'り': 'ri',
  'る': 'ru',
  'れ': 're',
  'ろ': 'ro',
  'わ': 'wa',
  'を': 'o',
  'ん': "n'",
  'ゔ': 'vu',
};

const _japaneseMora = <String, String>{
  'she': '셰',
  'che': '체',
  'kya': '캬',
  'kyu': '큐',
  'kyo': '쿄',
  'sha': '샤',
  'shu': '슈',
  'sho': '쇼',
  'cha': '차',
  'chu': '추',
  'cho': '초',
  'nya': '냐',
  'nyu': '뉴',
  'nyo': '뇨',
  'hya': '햐',
  'hyu': '휴',
  'hyo': '효',
  'mya': '먀',
  'myu': '뮤',
  'myo': '묘',
  'rya': '랴',
  'ryu': '류',
  'ryo': '료',
  'gya': '갸',
  'gyu': '규',
  'gyo': '교',
  'bya': '뱌',
  'byu': '뷰',
  'byo': '뵤',
  'pya': '퍄',
  'pyu': '퓨',
  'pyo': '표',
  'fa': '파',
  'fi': '피',
  'fe': '페',
  'fo': '포',
  'ti': '티',
  'di': '디',
  'tu': '투',
  'du': '두',
  'wi': '위',
  'we': '웨',
  'tsa': '차',
  'tsi': '치',
  'tse': '체',
  'tso': '초',
  'ja': '자',
  'ju': '주',
  'jo': '조',
  'ka': '카',
  'ki': '키',
  'ku': '쿠',
  'ke': '케',
  'ko': '코',
  'ga': '가',
  'gi': '기',
  'gu': '구',
  'ge': '게',
  'go': '고',
  'sa': '사',
  'shi': '시',
  'su': '스',
  'se': '세',
  'so': '소',
  'za': '자',
  'ji': '지',
  'zu': '즈',
  'ze': '제',
  'zo': '조',
  'ta': '타',
  'chi': '치',
  'tsu': '쓰',
  'te': '테',
  'to': '토',
  'da': '다',
  'de': '데',
  'do': '도',
  'na': '나',
  'ni': '니',
  'nu': '누',
  'ne': '네',
  'no': '노',
  'ha': '하',
  'hi': '히',
  'fu': '후',
  'he': '헤',
  'ho': '호',
  'ba': '바',
  'bi': '비',
  'bu': '부',
  'be': '베',
  'bo': '보',
  'pa': '파',
  'pi': '피',
  'pu': '푸',
  'pe': '페',
  'po': '포',
  'ma': '마',
  'mi': '미',
  'mu': '무',
  'me': '메',
  'mo': '모',
  'ya': '야',
  'yu': '유',
  'yo': '요',
  'ra': '라',
  'ri': '리',
  'ru': '루',
  're': '레',
  'ro': '로',
  'wa': '와',
  'wo': '오',
  'a': '아',
  'i': '이',
  'u': '우',
  'e': '에',
  'o': '오',
};

const _pinyinExact = <String, String>{
  'zhi': '즈',
  'chi': '츠',
  'shi': '스',
  'ri': '르',
  'zi': '쯔',
  'ci': '츠',
  'si': '쓰',
  'er': '얼',
};

const _pinyinOnsets = <String, int>{
  'b': 7,
  'p': 17,
  'm': 6,
  'f': 17,
  'd': 3,
  't': 16,
  'n': 2,
  'l': 5,
  'g': 0,
  'k': 15,
  'h': 18,
  'j': 12,
  'q': 14,
  'x': 9,
  'zh': 12,
  'ch': 14,
  'sh': 9,
  'r': 5,
  'z': 12,
  'c': 14,
  's': 9,
};

const _pinyinRimes = <String, String>{
  'a': '아',
  'ai': '아이',
  'an': '안',
  'ang': '앙',
  'ao': '아오',
  'e': '어',
  'ei': '에이',
  'en': '언',
  'eng': '엉',
  'o': '오',
  'ong': '옹',
  'ou': '오우',
  'i': '이',
  'ia': '이아',
  'ie': '이에',
  'iao': '야오',
  'iu': '이오',
  'ian': '이앤',
  'in': '인',
  'iang': '이앙',
  'ing': '잉',
  'iong': '이옹',
  'u': '우',
  'ua': '우아',
  'uo': '워',
  'uai': '와이',
  'ui': '웨이',
  'uan': '완',
  'un': '운',
  'uang': '우앙',
  'v': '위',
  've': '웨',
  'van': '위앤',
  'vn': '윈',
};

const _onsetIndexes = <String, int>{
  'b': 7,
  'p': 17,
  'm': 6,
  'f': 17,
  'd': 3,
  't': 16,
  'n': 2,
  'l': 5,
  'r': 5,
  'g': 0,
  'k': 15,
  'c': 15,
  'q': 15,
  'h': 18,
  'j': 12,
  'z': 12,
  's': 9,
  'v': 7,
  'w': 11,
  'y': 11,
  'S': 9,
  'C': 14,
  'Z': 12,
  'T': 3,
  'F': 17,
  'N': 11,
  'Y': 2,
  'X': 14,
};

const _codaIndexes = <String, int>{
  'g': 1,
  'k': 1,
  'c': 1,
  'n': 4,
  'd': 7,
  't': 7,
  'l': 8,
  'r': 8,
  'm': 16,
  'b': 17,
  'p': 17,
  's': 19,
  'z': 19,
  'h': 27,
  'N': 21,
};

const _vowelIndexes = <String, int>{
  'a': 0,
  'e': 5,
  'i': 20,
  'o': 8,
  'u': 13,
  'v': 16,
};

const _latinLetterNames = <String, String>{
  'a': '아',
  'b': '브',
  'c': '크',
  'd': '드',
  'e': '에',
  'f': '프',
  'g': '그',
  'h': '흐',
  'i': '이',
  'j': '지',
  'k': '크',
  'l': '르',
  'm': '므',
  'n': '느',
  'o': '오',
  'p': '프',
  'q': '크',
  'r': '르',
  's': '스',
  't': '트',
  'u': '우',
  'v': '브',
  'w': '우',
  'x': '스',
  'y': '이',
  'z': '즈',
};

const _latinOverrides = <LanguageTag, Map<String, String>>{
  LanguageTag.english: {
    'beef': '비프',
    'hello': '헬로',
    'goodbye': '굿바이',
    'please': '플리즈',
    'thank you': '땡큐',
    'yes': '예스',
    'no': '노',
    'person': '퍼슨',
    'name': '네임',
    'friend': '프렌드',
    'family': '패밀리',
    'mother': '마더',
    'father': '파더',
    'child': '차일드',
    'house': '하우스',
    'room': '룸',
    'door': '도어',
    'window': '윈도우',
    'school': '스쿨',
    'office': '오피스',
    'work': '워크',
    'study': '스터디',
    'book': '북',
    'word': '워드',
    'language': '랭귀지',
    'time': '타임',
    'day': '데이',
    'week': '위크',
    'today': '투데이',
    'tomorrow': '투모로우',
    'morning': '모닝',
    'evening': '이브닝',
    'food': '푸드',
    'water': '워터',
    'coffee': '커피',
    'tea': '티',
    'bread': '브레드',
    'rice': '라이스',
    'apple': '애플',
    'city': '시티',
    'country': '컨트리',
    'street': '스트리트',
    'station': '스테이션',
    'airport': '에어포트',
    'bus': '버스',
    'train': '트레인',
    'car': '카',
    'phone': '폰',
    'computer': '컴퓨터',
    'money': '머니',
    'shop': '숍',
    'restaurant': '레스토랑',
    'hospital': '호스피털',
    'weather': '웨더',
    'rain': '레인',
    'sun': '선',
    'hot': '핫',
    'cold': '콜드',
    'big': '빅',
    'small': '스몰',
    'good': '굿',
    'bad': '배드',
    'new': '뉴',
    'old': '올드',
    'fast': '패스트',
    'slow': '슬로우',
    'go': '고',
    'come': '컴',
    'eat': '이트',
    'drink': '드링크',
    'read': '리드',
    'write': '라이트',
    'speak': '스피크',
    'listen': '리슨',
    'see': '시',
    'know': '노',
    'want': '원트',
    'need': '니드',
    'like': '라이크',
    'love': '러브',
    'help': '헬프',
  },
  LanguageTag.german: {
    'person': '페르존',
    'name': '나메',
    'freund': '프로인트',
    'familie': '파밀리에',
    'mutter': '무터',
    'vater': '파터',
    'kind': '킨트',
    'haus': '하우스',
    'zimmer': '치머',
    'tvr': '튀어',
    'fenster': '펜스터',
    'schule': '슐레',
    'bvro': '뷔로',
    'arbeit': '아르바이트',
    'lernen': '레르넨',
    'buch': '부흐',
    'wort': '보르트',
    'sprache': '슈프라헤',
    'zeit': '차이트',
    'tag': '타크',
    'woche': '보헤',
    'heute': '호이테',
    'morgen': '모르겐',
    'abend': '아벤트',
    'essen': '에센',
    'wasser': '바서',
    'kaffee': '카페',
    'tee': '테',
    'brot': '브로트',
    'reis': '라이스',
    'apfel': '압펠',
    'stadt': '슈타트',
    'land': '란트',
    'strasse': '슈트라세',
    'bahnhof': '반호프',
    'flughafen': '플루크하펜',
    'bus': '부스',
    'zug': '추크',
    'auto': '아우토',
    'telefon': '텔레폰',
    'computer': '콤퓨터',
    'geld': '겔트',
    'geschaeft': '게셰프트',
    'restaurant': '레스토랑',
    'krankenhaus': '크랑켄하우스',
    'wetter': '베터',
    'regen': '레겐',
    'sonne': '조네',
    'heiss': '하이스',
    'kalt': '칼트',
    'gross': '그로스',
    'klein': '클라인',
    'gut': '구트',
    'schlecht': '슐레히트',
    'neu': '노이',
    'alt': '알트',
    'schnell': '슈넬',
    'langsam': '랑잠',
    'gehen': '게엔',
    'kommen': '코멘',
    'trinken': '트링켄',
    'lesen': '레젠',
    'schreiben': '슈라이벤',
    'sprechen': '슈프레헨',
    'zuhoeren': '추회렌',
    'sehen': '제엔',
    'wissen': '비센',
    'wollen': '볼렌',
    'brauchen': '브라우헨',
    'moegen': '뫼겐',
    'lieben': '리벤',
    'helfen': '헬펜',
  },
  LanguageTag.french: {
    'personne': '페르손',
    'nom': '농',
    'ami': '아미',
    'famille': '파미유',
    'mere': '메르',
    'pere': '페르',
    'enfant': '앙팡',
    'maison': '메종',
    'chambre': '샹브르',
    'porte': '포르트',
    'fenetre': '프네트르',
    'ecole': '에콜',
    'bureau': '뷔로',
    'travail': '트라바유',
    'etude': '에튀드',
    'livre': '리브르',
    'mot': '모',
    'langue': '랑그',
    'temps': '탕',
    'jour': '주르',
    'semaine': '스멘',
    "aujourd'hui": '오주르뒤',
    'demain': '드맹',
    'matin': '마탱',
    'soir': '수아르',
    'nourriture': '누리튀르',
    'eau': '오',
    'cafe': '카페',
    'the': '테',
    'pain': '팽',
    'riz': '리',
    'pomme': '폼',
    'ville': '빌',
    'pays': '페이',
    'rue': '뤼',
    'gare': '가르',
    'aeroport': '아에로포르',
    'bus': '뷔스',
    'train': '트랭',
    'voiture': '부아튀르',
    'telephone': '텔레폰',
    'ordinateur': '오르디나퇴르',
    'argent': '아르장',
    'magasin': '마가쟁',
    'restaurant': '레스토랑',
    'hopital': '오피탈',
    'meteo': '메테오',
    'pluie': '플뤼',
    'soleil': '솔레이',
    'chaud': '쇼',
    'froid': '프루아',
    'grand': '그랑',
    'petit': '프티',
    'bon': '봉',
    'mauvais': '모베',
    'nouveau': '누보',
    'vieux': '비외',
    'rapide': '라피드',
    'lent': '랑',
    'aller': '알레',
    'venir': '브니르',
    'manger': '망제',
    'boire': '부아르',
    'lire': '리르',
    'ecrire': '에크리르',
    'parler': '파를레',
    'ecouter': '에쿠테',
    'voir': '부아르',
    'savoir': '사부아르',
    'vouloir': '불루아르',
    'avoir besoin': '아부아르 브주앵',
    'aimer bien': '에메 비앵',
    'aimer': '에메',
    'aider': '에데',
  },
  LanguageTag.spanish: {
    'persona': '페르소나',
    'nombre': '놈브레',
    'amigo': '아미고',
    'familia': '파밀리아',
    'madre': '마드레',
    'padre': '파드레',
    'ninyo': '니뇨',
    'casa': '카사',
    'habitacion': '아비타시온',
    'puerta': '푸에르타',
    'ventana': '벤타나',
    'escuela': '에스쿠엘라',
    'oficina': '오피시나',
    'trabajo': '트라바호',
    'estudio': '에스투디오',
    'libro': '리브로',
    'palabra': '팔라브라',
    'idioma': '이디오마',
    'tiempo': '티엠포',
    'dia': '디아',
    'semana': '세마나',
    'hoy': '오이',
    'manyana': '마냐나',
    'la manyana': '라 마냐나',
    'la tarde': '라 타르데',
    'comida': '코미다',
    'agua': '아과',
    'cafe': '카페',
    'te': '테',
    'pan': '판',
    'arroz': '아로스',
    'manzana': '만사나',
    'ciudad': '시우다드',
    'pais': '파이스',
    'calle': '카예',
    'estacion': '에스타시온',
    'aeropuerto': '아에로푸에르토',
    'autobus': '아우토부스',
    'tren': '트렌',
    'coche': '코체',
    'telefono': '텔레포노',
    'computadora': '콤푸타도라',
    'dinero': '디네로',
    'tienda': '티엔다',
    'restaurante': '레스타우란테',
    'hospital': '오스피탈',
    'clima': '클리마',
    'lluvia': '유비아',
    'sol': '솔',
    'caliente': '칼리엔테',
    'frio': '프리오',
    'grande': '그란데',
    'pequenyo': '페케뇨',
    'bueno': '부에노',
    'malo': '말로',
    'nuevo': '누에보',
    'viejo': '비에호',
    'rapido': '라피도',
    'lento': '렌토',
    'ir': '이르',
    'venir': '베니르',
    'comer': '코메르',
    'beber': '베베르',
    'leer': '레에르',
    'escribir': '에스크리비르',
    'hablar': '아블라르',
    'escuchar': '에스쿠차르',
    'ver': '베르',
    'saber': '사베르',
    'querer': '케레르',
    'necesitar': '네세시타르',
    'gustar': '구스타르',
    'amar': '아마르',
    'ayudar': '아유다르',
  },
};

/// Curated words used by the bundled sentence catalog. The generic fallback
/// remains available for new text, while shipped lessons keep a readable,
/// reviewable Korean aid for irregular spelling.
const _sentenceWordOverrides = <LanguageTag, Map<String, String>>{
  LanguageTag.english: {
    'a': '어',
    'address': '어드레스',
    'allergy': '앨러지',
    'am': '앰',
    'ambulance': '앰뷸런스',
    'an': '언',
    'are': '아',
    'at': '앳',
    'back': '백',
    'by': '바이',
    'call': '콜',
    'can': '캔',
    'card': '카드',
    'check': '체크',
    'could': '쿠드',
    'delicious': '딜리셔스',
    'do': '두',
    'does': '더즈',
    'downtown': '다운타운',
    'english': '잉글리시',
    'fi': '파이',
    'file': '파일',
    'for': '포',
    'give': '기브',
    'have': '해브',
    'here': '히어',
    'how': '하우',
    'i': '아이',
    'in': '인',
    'is': '이즈',
    'it': '잇',
    'late': '레이트',
    'later': '레이터',
    'learning': '러닝',
    'lost': '로스트',
    'me': '미',
    'mean': '민',
    'meet': '미트',
    'meeting': '미팅',
    'menu': '메뉴',
    'mina': '미나',
    'minutes': '미니츠',
    'more': '모어',
    'much': '머치',
    'my': '마이',
    'nice': '나이스',
    'not': '낫',
    'open': '오픈',
    'passport': '패스포트',
    'pay': '페이',
    'practiced': '프랙티스트',
    'receipt': '리싯',
    'repeat': '리피트',
    'reservation': '레저베이션',
    'restroom': '레스트룸',
    'send': '센드',
    'slowly': '슬로울리',
    'spell': '스펠',
    'starts': '스타츠',
    'store': '스토어',
    'take': '테이크',
    'ten': '텐',
    'that': '댓',
    'the': '더',
    'there': '데어',
    'thirty': '서티',
    'this': '디스',
    'to': '투',
    'understand': '언더스탠드',
    'what': '왓',
    'where': '웨어',
    'wi': '와이',
    'will': '윌',
    'would': '우드',
    'you': '유',
  },
  LanguageTag.german: {
    'adresse': '아드레세',
    'bedeutet': '버도이텟',
    'beginnt': '버긴트',
    'besprechung': '베슈프레훙',
    'bezahlen': '베찰렌',
    'bis': '비스',
    'brauche': '브라우헤',
    'das': '다스',
    'datei': '다타이',
    'der': '데어',
    'deutsch': '도이치',
    'die': '디',
    'dieser': '디저',
    'dieses': '디저스',
    'dreissig': '드라이시히',
    'einchecken': '아인체켄',
    'eine': '아이네',
    'einen': '아이넨',
    'es': '에스',
    'fahren': '파렌',
    'freut': '프로이트',
    'faehrt': '페어트',
    'geben': '게벤',
    'gehe': '게에',
    'geht': '게트',
    'gern': '게른',
    'gevbt': '게윕트',
    'gibt': '깁트',
    'habe': '하베',
    'hat': '핫',
    'heisse': '하이세',
    'hier': '히어',
    'haette': '헤테',
    'ich': '이히',
    'ihnen': '이넨',
    'ins': '인스',
    'ist': '이스트',
    'kann': '칸',
    'karte': '카르테',
    'kennenzulernen': '케넨출레르넨',
    'kostet': '코스텟',
    'krankenwagen': '크랑켄바겐',
    'koennen': '쾨넨',
    'koennte': '쾨네',
    'koennten': '쾨넨',
    'lebensmittelallergie': '레벤스미텔알레르기',
    'lecker': '레커',
    'lerne': '레르네',
    'man': '만',
    'mehr': '메어',
    'meinen': '마이넨',
    'mich': '미히',
    'mina': '미나',
    'minuten': '미누텐',
    'mir': '미어',
    'mit': '밋',
    'moechte': '뫼히테',
    'nicht': '니히트',
    'noch': '노흐',
    'quittung': '크비퉁',
    'reisepass': '라이제파스',
    'reservierung': '레제르비룽',
    'rufe': '루페',
    'rufen': '루펜',
    'schicken': '시켄',
    'schreibt': '슈라이프트',
    'schoenen': '쇠넨',
    'sie': '지',
    'speisekarte': '슈파이제카르테',
    'spaet': '슈페트',
    'spaeter': '슈페터',
    'stadtzentrum': '슈타트첸트룸',
    'toilette': '토일레테',
    'uhr': '우어',
    'um': '움',
    'verloren': '페를로렌',
    'verspaetung': '페르슈페퉁',
    'verstehe': '페어슈테에',
    'viel': '필',
    'was': '바스',
    'wie': '비',
    'wiederholen': '비더홀렌',
    'wlan': '베란',
    'wo': '보',
    'zehn': '첸',
    'zu': '추',
    'zur': '추어',
    'zurvck': '추뤽',
    'oeffnen': '외프넨',
    'oeffnet': '외프넷',
  },
  LanguageTag.french: {
    'a': '아',
    'adresse': '아드레스',
    'ai': '에',
    'alimentaire': '알리망테르',
    'allergie': '알레르지',
    'allez': '알레',
    'ambulance': '앙뷜랑스',
    'appelez': '아플레',
    'appelle': '아펠',
    'apprends': '아프랑',
    'au': '오',
    'aujourd': '오주르',
    'beau': '보',
    'besoin': '브주앵',
    'bonne': '본',
    'carte': '카르트',
    'ce': '스',
    'cela': '슬라',
    'centre': '상트르',
    'cette': '세트',
    'combien': '콩비앵',
    'commence': '코망스',
    'comment': '코망',
    'comprends': '콩프랑',
    'coute': '쿠트',
    'de': '드',
    'dix': '디스',
    'donnez': '도네',
    'du': '뒤',
    'delicieux': '델리시외',
    'emmener': '암느',
    'en': '앙',
    'enchante': '앙샹테',
    'enregistrer': '앙르지스트레',
    'envoyez': '앙부아예',
    'est': '에',
    'fait': '페',
    'fi': '파이',
    'fichier': '피시에',
    'francais': '프랑세',
    'heure': '외르',
    'heures': '외르',
    'hui': '뒤',
    'ici': '이시',
    'il': '일',
    'j': '즈',
    'je': '즈',
    'journee': '주르네',
    'l': '르',
    'la': '라',
    'le': '르',
    'lentement': '랑트망',
    'les': '레',
    'm': '므',
    'menu': '메뉴',
    'mina': '미나',
    'minutes': '미뉘트',
    'moi': '무아',
    'mon': '몽',
    'ne': '느',
    'ouvre': '우브르',
    'ouvrez': '우브레',
    'ou': '우',
    'par': '파르',
    'parlez': '파를레',
    'pas': '파',
    'passeport': '파스포르',
    'payer': '페예',
    'pendant': '팡당',
    'perdu': '페르뒤',
    'plat': '플라',
    'plait': '플레',
    'plus': '플뤼',
    'pourrais': '푸레',
    'pourriez': '푸리에',
    'pouvez': '푸베',
    'puis': '퓌',
    'qu': '크',
    'que': '크',
    'quelle': '켈',
    'rappellerai': '라펠레',
    'rencontrer': '랑콩트레',
    'retard': '르타르',
    'recu': '르쉬',
    'repeter': '레페테',
    'reservation': '레제르바시옹',
    'reunion': '레위니옹',
    's': '스',
    'signifie': '시니피',
    'sont': '송',
    't': '트',
    'tard': '타르',
    'toilettes': '투알레트',
    'trente': '트랑트',
    'un': '앵',
    'une': '윈',
    'va': '바',
    'vais': '베',
    'veuillez': '뵈예',
    'voudrais': '부드레',
    'vous': '부',
    'wi': '위',
    'y': '이',
    'ca': '사',
    'ecrit': '에크리',
    'etudie': '에튀디',
  },
  LanguageTag.spanish: {
    'a': '아',
    'abra': '아브라',
    'abre': '아브레',
    'al': '알',
    'alergia': '알레르히아',
    'alimentaria': '알리멘타리아',
    'ambulancia': '암불란시아',
    'aprendiendo': '아프렌디엔도',
    'aqui': '아키',
    'archivo': '아르치보',
    'ayudarme': '아유다르메',
    'banyo': '바뇨',
    'buen': '부엔',
    'centro': '센트로',
    'con': '콘',
    'cuesta': '쿠에스타',
    'cuanto': '쿠안토',
    'como': '코모',
    'deliciosa': '델리시오사',
    'deme': '데메',
    'despacio': '데스파시오',
    'devolvere': '데볼베레',
    'diez': '디에스',
    'direccion': '디렉시온',
    'durante': '두란테',
    'donde': '돈데',
    'el': '엘',
    'empieza': '엠피에사',
    'entiendo': '엔티엔도',
    'envieme': '엔비에메',
    'es': '에스',
    'escribe': '에스크리베',
    'espanol': '에스파뇰',
    'esta': '에스타',
    'este': '에스테',
    'esto': '에스토',
    'estoy': '에스토이',
    'estudiado': '에스투디아도',
    'favor': '파보르',
    'hable': '아블레',
    'hace': '아세',
    'hay': '아이',
    'he': '에',
    'hora': '오라',
    'la': '라',
    'las': '라스',
    'le': '레',
    'llamada': '야마다',
    'llame': '야메',
    'llamo': '야모',
    'llega': '예가',
    'lleveme': '예베메',
    'me': '메',
    'menu': '메누',
    'mi': '미',
    'mina': '미나',
    'minutos': '미누토스',
    'mucho': '무초',
    'mas': '마스',
    'necesito': '네세시토',
    'nos': '노스',
    'pagar': '파가르',
    'pasaporte': '파사포르테',
    'perdido': '페르디도',
    'podria': '포드리아',
    'por': '포르',
    'puede': '푸에데',
    'puedo': '푸에도',
    'que': '케',
    'quisiera': '키시에라',
    'recibo': '레시보',
    'registrarme': '레히스트라르메',
    'repetirlo': '레페티를로',
    'reserva': '레세르바',
    'reunion': '레우니온',
    'se': '세',
    'significa': '시그니피카',
    'tarde': '타르데',
    'tarjeta': '타르헤타',
    'tenga': '텐가',
    'tengo': '텐고',
    'treinta': '트레인타',
    'un': '운',
    'una': '우나',
    'usted': '우스테드',
    'va': '바',
    'vemos': '베모스',
    'voy': '보이',
    'wifi': '와이파이',
  },
};
