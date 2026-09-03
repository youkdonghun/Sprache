import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/korean_pronunciation.dart';

part 'sample_content_practical.dart';
part 'sample_content_everyday.dart';

final sampleContent = <LearningItem>[
  ..._buildWords(LanguageTag.english, _englishWords),
  ..._buildSentences(LanguageTag.english, [
    ..._englishSentences,
    ..._englishPracticalSentences,
    ..._englishEverydaySentences,
  ]),
  ..._buildWords(LanguageTag.japanese, _japaneseWords),
  ..._buildSentences(LanguageTag.japanese, [
    ..._japaneseSentences,
    ..._japanesePracticalSentences,
    ..._japaneseEverydaySentences,
  ]),
  ..._buildWords(LanguageTag.german, _germanWords),
  ..._buildSentences(LanguageTag.german, [
    ..._germanSentences,
    ..._germanPracticalSentences,
    ..._germanEverydaySentences,
  ]),
  ..._buildWords(LanguageTag.french, _frenchWords),
  ..._buildSentences(LanguageTag.french, [
    ..._frenchSentences,
    ..._frenchPracticalSentences,
    ..._frenchEverydaySentences,
  ]),
  ..._buildWords(LanguageTag.spanish, _spanishWords),
  ..._buildSentences(LanguageTag.spanish, [
    ..._spanishSentences,
    ..._spanishPracticalSentences,
    ..._spanishEverydaySentences,
  ]),
  ..._buildWords(LanguageTag.simplifiedChinese, _chineseWords),
  ..._buildSentences(LanguageTag.simplifiedChinese, [
    ..._chineseSentences,
    ..._chinesePracticalSentences,
    ..._chineseEverydaySentences,
  ]),
];

List<LearningItem> _buildWords(LanguageTag language, List<_WordSeed> seeds) {
  return [
    for (final (index, seed) in seeds.indexed)
      LearningItem(
        id: '${language.code}-starter-word-${index + 1}',
        kind: LearningItemKind.word,
        learningLanguage: language,
        text: seed.text,
        translations: [seed.korean],
        acceptedAnswers: [seed.korean],
        readings: [
          if (_safeBundledHangulReading(language, seed) case final reading?)
            Reading(scheme: ReadingScheme.hangul, value: reading),
          if (seed.reading != null)
            Reading(
              scheme: language == LanguageTag.simplifiedChinese
                  ? ReadingScheme.pinyin
                  : ReadingScheme.kana,
              value: seed.reading!,
            ),
          if (seed.romanization != null)
            Reading(scheme: ReadingScheme.romaji, value: seed.romanization!),
        ],
        partOfSpeech: _partOfSpeechFor(seed.korean),
        tags: ['입문', '기초 단어', 'unit-${_wordUnit(seed.korean)}'],
        capabilities: const {
          ExerciseCapability.recognition,
          ExerciseCapability.production,
          ExerciseCapability.listening,
        },
        priority: index < 5 ? 5 : 0,
        source: ContentSource.starterCatalog,
      ),
  ];
}

List<LearningItem> _buildSentences(
  LanguageTag language,
  List<_SentenceSeed> seeds,
) {
  return [
    for (final (index, seed) in seeds.indexed)
      LearningItem(
        id: '${language.code}-starter-sentence-${index + 1}',
        kind: LearningItemKind.sentence,
        learningLanguage: language,
        text: seed.text,
        translations: [seed.korean],
        acceptedAnswers: [seed.korean],
        readings: [
          if (_safeBundledHangulReading(language, seed) case final reading?)
            Reading(scheme: ReadingScheme.hangul, value: reading),
          if (seed.reading != null)
            Reading(
              scheme: language == LanguageTag.simplifiedChinese
                  ? ReadingScheme.pinyin
                  : ReadingScheme.kana,
              value: seed.reading!,
            ),
          if (seed.romanization != null)
            Reading(scheme: ReadingScheme.romaji, value: seed.romanization!),
        ],
        sentenceTokens: seed.tokens,
        tags: ['입문', '기초 문장', 'unit-${_sentenceUnit(seed.korean)}'],
        capabilities: const {
          ExerciseCapability.recognition,
          ExerciseCapability.production,
          ExerciseCapability.cloze,
          ExerciseCapability.listening,
          ExerciseCapability.sentenceOrder,
        },
        priority: index < 5 ? 4 : 0,
        source: ContentSource.starterCatalog,
      ),
  ];
}

String? _safeBundledHangulReading(LanguageTag language, Object seed) {
  final (text, reading, romanization, reviewed) = switch (seed) {
    final _WordSeed value => (
      value.text,
      value.reading,
      value.romanization,
      value.koreanPronunciation,
    ),
    final _SentenceSeed value => (
      value.text,
      value.reading,
      value.romanization,
      value.koreanPronunciation,
    ),
    _ => throw ArgumentError.value(seed, 'seed'),
  };
  if (reviewed != null && reviewed.trim().isNotEmpty) return reviewed.trim();

  // Latin spelling is not a pronunciation alphabet. Guessing from the written
  // form produced misleading aids such as `beef` -> `비`, so bundled Latin-
  // script courses expose only editor-reviewed Hangul. Japanese and Chinese
  // remain safe to derive because the source supplies kana/romaji or pinyin.
  if (language != LanguageTag.japanese &&
      language != LanguageTag.simplifiedChinese) {
    return null;
  }
  return tryDeriveKoreanPronunciation(
    language: language,
    text: text,
    reading: reading,
    romanization: romanization,
  );
}

class _WordSeed {
  const _WordSeed(
    this.text,
    this.korean, {
    this.reading,
    this.romanization,
    this.koreanPronunciation,
  });

  final String text;
  final String korean;
  final String? reading;
  final String? romanization;
  final String? koreanPronunciation;
}

class _SentenceSeed {
  const _SentenceSeed(
    this.text,
    this.korean,
    this.tokens, {
    this.reading,
    this.romanization,
    this.koreanPronunciation,
  });

  final String text;
  final String korean;
  final List<String> tokens;
  final String? reading;
  final String? romanization;
  final String? koreanPronunciation;
}

PartOfSpeech _partOfSpeechFor(String korean) => switch (korean) {
  '안녕하세요' ||
  '안녕히 가세요' ||
  '부탁합니다' ||
  '감사합니다' ||
  '네' ||
  '아니요' => PartOfSpeech.interjection,
  '덥다' ||
  '춥다' ||
  '크다' ||
  '작다' ||
  '좋다' ||
  '나쁘다' ||
  '새롭다' ||
  '오래되다' ||
  '빠르다' ||
  '느리다' => PartOfSpeech.adjective,
  '배우다' ||
  '가다' ||
  '오다' ||
  '먹다' ||
  '마시다' ||
  '읽다' ||
  '쓰다' ||
  '말하다' ||
  '듣다' ||
  '보다' ||
  '알다' ||
  '원하다' ||
  '필요하다' ||
  '좋아하다' ||
  '사랑하다' ||
  '돕다' => PartOfSpeech.verb,
  _ => PartOfSpeech.noun,
};

int _wordUnit(String korean) => switch (korean) {
  '안녕하세요' || '안녕히 가세요' || '부탁합니다' || '감사합니다' || '네' || '아니요' || '이름' => 0,
  '사람' ||
  '친구' ||
  '가족' ||
  '어머니' ||
  '아버지' ||
  '아이' ||
  '집' ||
  '방' ||
  '문' ||
  '창문' ||
  '학교' ||
  '사무실' ||
  '회사' ||
  '일' ||
  '공부' ||
  '배우다' ||
  '책' ||
  '단어' ||
  '언어' => 1,
  '시간' ||
  '날' ||
  '주' ||
  '오늘' ||
  '내일' ||
  '아침' ||
  '저녁' ||
  '날씨' ||
  '비' ||
  '해' ||
  '덥다' ||
  '춥다' => 2,
  '음식' ||
  '물' ||
  '커피' ||
  '차' ||
  '빵' ||
  '밥' ||
  '사과' ||
  '돈' ||
  '가게' ||
  '식당' ||
  '먹다' ||
  '마시다' ||
  '원하다' ||
  '좋아하다' => 3,
  '도시' ||
  '나라' ||
  '거리' ||
  '길' ||
  '역' ||
  '공항' ||
  '버스' ||
  '기차' ||
  '자동차' ||
  '빠르다' ||
  '느리다' ||
  '가다' ||
  '오다' => 4,
  _ => 5,
};

int _sentenceUnit(String korean) => switch (korean) {
  '어떻게 지내세요?' || '잘 지내세요?' || '제 이름은 미나예요.' || '만나서 반가워요.' || '처음 뵙겠습니다.' => 0,
  '저는 영어를 배우고 있어요.' ||
  '저는 일본어를 배우고 있어요.' ||
  '저는 독일어를 배워요.' ||
  '저는 프랑스어를 배워요.' ||
  '저는 스페인어를 배워요.' ||
  '저는 중국어를 배워요.' ||
  '일본어를 공부하고 있어요.' ||
  '저는 오늘 출근해요.' ||
  '오늘은 회사에 가요.' ||
  '창문을 열어 주세요.' ||
  '좋은 하루 보내세요.' => 1,
  '날씨가 좋아요.' ||
  '오늘은 날씨가 좋아요.' ||
  '몇 시예요?' ||
  '지금 몇 시예요?' ||
  '내일 만나요.' ||
  '내일 다시 만나요.' => 2,
  '물 좀 주세요.' ||
  '물을 주세요.' ||
  '커피를 주세요.' ||
  '커피를 부탁합니다.' ||
  '이것은 얼마예요?' ||
  '이 음식은 맛있어요.' ||
  '예약했습니다.' ||
  '예약이 있습니다.' => 3,
  '역이 어디에 있나요?' || '역은 어디예요?' || '버스가 늦어요.' || '버스가 늦고 있어요.' => 4,
  _ => 5,
};

const _englishWords = <_WordSeed>[
  _WordSeed('hello', '안녕하세요', koreanPronunciation: '헬로'),
  _WordSeed('goodbye', '안녕히 가세요', koreanPronunciation: '굿바이'),
  _WordSeed('please', '부탁합니다', koreanPronunciation: '플리즈'),
  _WordSeed('thank you', '감사합니다', koreanPronunciation: '땡큐'),
  _WordSeed('yes', '네', koreanPronunciation: '예스'),
  _WordSeed('no', '아니요', koreanPronunciation: '노우'),
  _WordSeed('person', '사람'),
  _WordSeed('name', '이름'),
  _WordSeed('friend', '친구'),
  _WordSeed('family', '가족'),
  _WordSeed('mother', '어머니'),
  _WordSeed('father', '아버지'),
  _WordSeed('child', '아이'),
  _WordSeed('house', '집'),
  _WordSeed('room', '방'),
  _WordSeed('door', '문'),
  _WordSeed('window', '창문'),
  _WordSeed('school', '학교'),
  _WordSeed('office', '사무실'),
  _WordSeed('work', '일'),
  _WordSeed('study', '공부'),
  _WordSeed('book', '책'),
  _WordSeed('word', '단어'),
  _WordSeed('language', '언어'),
  _WordSeed('time', '시간'),
  _WordSeed('day', '날'),
  _WordSeed('week', '주'),
  _WordSeed('today', '오늘'),
  _WordSeed('tomorrow', '내일'),
  _WordSeed('morning', '아침'),
  _WordSeed('evening', '저녁'),
  _WordSeed('food', '음식'),
  _WordSeed('water', '물'),
  _WordSeed('coffee', '커피'),
  _WordSeed('tea', '차'),
  _WordSeed('bread', '빵'),
  _WordSeed('rice', '밥'),
  _WordSeed('apple', '사과'),
  _WordSeed('city', '도시'),
  _WordSeed('country', '나라'),
  _WordSeed('street', '거리'),
  _WordSeed('station', '역'),
  _WordSeed('airport', '공항'),
  _WordSeed('bus', '버스'),
  _WordSeed('train', '기차'),
  _WordSeed('car', '자동차'),
  _WordSeed('phone', '전화'),
  _WordSeed('computer', '컴퓨터'),
  _WordSeed('money', '돈'),
  _WordSeed('shop', '가게'),
  _WordSeed('restaurant', '식당'),
  _WordSeed('hospital', '병원'),
  _WordSeed('weather', '날씨'),
  _WordSeed('rain', '비'),
  _WordSeed('sun', '해'),
  _WordSeed('hot', '덥다'),
  _WordSeed('cold', '춥다'),
  _WordSeed('big', '크다'),
  _WordSeed('small', '작다'),
  _WordSeed('good', '좋다'),
  _WordSeed('bad', '나쁘다'),
  _WordSeed('new', '새롭다'),
  _WordSeed('old', '오래되다'),
  _WordSeed('fast', '빠르다'),
  _WordSeed('slow', '느리다'),
  _WordSeed('go', '가다'),
  _WordSeed('come', '오다'),
  _WordSeed('eat', '먹다'),
  _WordSeed('drink', '마시다'),
  _WordSeed('read', '읽다'),
  _WordSeed('write', '쓰다'),
  _WordSeed('speak', '말하다'),
  _WordSeed('listen', '듣다'),
  _WordSeed('see', '보다'),
  _WordSeed('know', '알다'),
  _WordSeed('want', '원하다'),
  _WordSeed('need', '필요하다'),
  _WordSeed('like', '좋아하다'),
  _WordSeed('love', '사랑하다'),
  _WordSeed('help', '돕다'),
];

const _englishSentences = <_SentenceSeed>[
  _SentenceSeed('How are you?', '어떻게 지내세요?', [
    'How',
    'are',
    'you?',
  ], koreanPronunciation: '하우 아 유?'),
  _SentenceSeed('My name is Mina.', '제 이름은 미나예요.', [
    'My',
    'name',
    'is',
    'Mina.',
  ], koreanPronunciation: '마이 네임 이즈 미나.'),
  _SentenceSeed('Nice to meet you.', '만나서 반가워요.', [
    'Nice',
    'to',
    'meet',
    'you.',
  ], koreanPronunciation: '나이스 투 미트 유.'),
  _SentenceSeed('Where is the station?', '역이 어디에 있나요?', [
    'Where',
    'is',
    'the',
    'station?',
  ]),
  _SentenceSeed('Please give me water.', '물 좀 주세요.', [
    'Please',
    'give',
    'me',
    'water.',
  ]),
  _SentenceSeed('I would like coffee.', '커피를 주세요.', [
    'I',
    'would',
    'like',
    'coffee.',
  ]),
  _SentenceSeed('How much is this?', '이것은 얼마예요?', [
    'How',
    'much',
    'is',
    'this?',
  ]),
  _SentenceSeed('I do not understand.', '이해하지 못했어요.', [
    'I',
    'do',
    'not',
    'understand.',
  ]),
  _SentenceSeed('Please speak slowly.', '천천히 말해 주세요.', [
    'Please',
    'speak',
    'slowly.',
  ]),
  _SentenceSeed('Can you help me?', '저를 도와주실 수 있나요?', [
    'Can',
    'you',
    'help',
    'me?',
  ]),
  _SentenceSeed('I am learning English.', '저는 영어를 배우고 있어요.', [
    'I',
    'am',
    'learning',
    'English.',
  ]),
  _SentenceSeed('The weather is good.', '날씨가 좋아요.', [
    'The',
    'weather',
    'is',
    'good.',
  ]),
  _SentenceSeed('I go to work today.', '저는 오늘 출근해요.', [
    'I',
    'go',
    'to',
    'work',
    'today.',
  ]),
  _SentenceSeed('This food is delicious.', '이 음식은 맛있어요.', [
    'This',
    'food',
    'is',
    'delicious.',
  ]),
  _SentenceSeed('What time is it?', '몇 시예요?', ['What', 'time', 'is', 'it?']),
  _SentenceSeed('See you tomorrow.', '내일 만나요.', ['See', 'you', 'tomorrow.']),
  _SentenceSeed('I have a reservation.', '예약했습니다.', [
    'I',
    'have',
    'a',
    'reservation.',
  ]),
  _SentenceSeed('The bus is late.', '버스가 늦어요.', ['The', 'bus', 'is', 'late.']),
  _SentenceSeed('Please open the window.', '창문을 열어 주세요.', [
    'Please',
    'open',
    'the',
    'window.',
  ]),
  _SentenceSeed('Have a good day.', '좋은 하루 보내세요.', [
    'Have',
    'a',
    'good',
    'day.',
  ]),
];

const _japaneseWords = <_WordSeed>[
  _WordSeed(
    'こんにちは',
    '안녕하세요',
    reading: 'こんにちは',
    romanization: 'konnichiwa',
    koreanPronunciation: '곤니치와',
  ),
  _WordSeed(
    'さようなら',
    '안녕히 가세요',
    reading: 'さようなら',
    romanization: 'sayounara',
    koreanPronunciation: '사요나라',
  ),
  _WordSeed(
    'お願いします',
    '부탁합니다',
    reading: 'おねがいします',
    romanization: 'onegaishimasu',
    koreanPronunciation: '오네가이시마스',
  ),
  _WordSeed(
    'ありがとう',
    '감사합니다',
    reading: 'ありがとう',
    romanization: 'arigatou',
    koreanPronunciation: '아리가토',
  ),
  _WordSeed(
    'はい',
    '네',
    reading: 'はい',
    romanization: 'hai',
    koreanPronunciation: '하이',
  ),
  _WordSeed(
    'いいえ',
    '아니요',
    reading: 'いいえ',
    romanization: 'iie',
    koreanPronunciation: '이이에',
  ),
  _WordSeed('人', '사람', reading: 'ひと', romanization: 'hito'),
  _WordSeed('名前', '이름', reading: 'なまえ', romanization: 'namae'),
  _WordSeed('友達', '친구', reading: 'ともだち', romanization: 'tomodachi'),
  _WordSeed('家族', '가족', reading: 'かぞく', romanization: 'kazoku'),
  _WordSeed('母', '어머니', reading: 'はは', romanization: 'haha'),
  _WordSeed('父', '아버지', reading: 'ちち', romanization: 'chichi'),
  _WordSeed('子供', '아이', reading: 'こども', romanization: 'kodomo'),
  _WordSeed('家', '집', reading: 'いえ', romanization: 'ie'),
  _WordSeed('部屋', '방', reading: 'へや', romanization: 'heya'),
  _WordSeed('ドア', '문', reading: 'ドア', romanization: 'doa'),
  _WordSeed('窓', '창문', reading: 'まど', romanization: 'mado'),
  _WordSeed('学校', '학교', reading: 'がっこう', romanization: 'gakkou'),
  _WordSeed('会社', '회사', reading: 'かいしゃ', romanization: 'kaisha'),
  _WordSeed('仕事', '일', reading: 'しごと', romanization: 'shigoto'),
  _WordSeed('勉強', '공부', reading: 'べんきょう', romanization: 'benkyou'),
  _WordSeed('本', '책', reading: 'ほん', romanization: 'hon'),
  _WordSeed('言葉', '단어', reading: 'ことば', romanization: 'kotoba'),
  _WordSeed('言語', '언어', reading: 'げんご', romanization: 'gengo'),
  _WordSeed('時間', '시간', reading: 'じかん', romanization: 'jikan'),
  _WordSeed('日', '날', reading: 'ひ', romanization: 'hi'),
  _WordSeed('週', '주', reading: 'しゅう', romanization: 'shuu'),
  _WordSeed('今日', '오늘', reading: 'きょう', romanization: 'kyou'),
  _WordSeed('明日', '내일', reading: 'あした', romanization: 'ashita'),
  _WordSeed('朝', '아침', reading: 'あさ', romanization: 'asa'),
  _WordSeed('夜', '저녁', reading: 'よる', romanization: 'yoru'),
  _WordSeed('食べ物', '음식', reading: 'たべもの', romanization: 'tabemono'),
  _WordSeed('水', '물', reading: 'みず', romanization: 'mizu'),
  _WordSeed('コーヒー', '커피', reading: 'コーヒー', romanization: 'koohii'),
  _WordSeed('お茶', '차', reading: 'おちゃ', romanization: 'ocha'),
  _WordSeed('パン', '빵', reading: 'パン', romanization: 'pan'),
  _WordSeed('ご飯', '밥', reading: 'ごはん', romanization: 'gohan'),
  _WordSeed('りんご', '사과', reading: 'りんご', romanization: 'ringo'),
  _WordSeed('市', '도시', reading: 'し', romanization: 'shi'),
  _WordSeed('国', '나라', reading: 'くに', romanization: 'kuni'),
  _WordSeed('道', '길', reading: 'みち', romanization: 'michi'),
  _WordSeed('駅', '역', reading: 'えき', romanization: 'eki'),
  _WordSeed('空港', '공항', reading: 'くうこう', romanization: 'kuukou'),
  _WordSeed('バス', '버스', reading: 'バス', romanization: 'basu'),
  _WordSeed('電車', '기차', reading: 'でんしゃ', romanization: 'densha'),
  _WordSeed('車', '자동차', reading: 'くるま', romanization: 'kuruma'),
  _WordSeed('電話', '전화', reading: 'でんわ', romanization: 'denwa'),
  _WordSeed('パソコン', '컴퓨터', reading: 'パソコン', romanization: 'pasokon'),
  _WordSeed('お金', '돈', reading: 'おかね', romanization: 'okane'),
  _WordSeed('店', '가게', reading: 'みせ', romanization: 'mise'),
  _WordSeed('レストラン', '식당', reading: 'レストラン', romanization: 'resutoran'),
  _WordSeed('病院', '병원', reading: 'びょういん', romanization: 'byouin'),
  _WordSeed('天気', '날씨', reading: 'てんき', romanization: 'tenki'),
  _WordSeed('雨', '비', reading: 'あめ', romanization: 'ame'),
  _WordSeed('太陽', '해', reading: 'たいよう', romanization: 'taiyou'),
  _WordSeed('暑い', '덥다', reading: 'あつい', romanization: 'atsui'),
  _WordSeed('寒い', '춥다', reading: 'さむい', romanization: 'samui'),
  _WordSeed('大きい', '크다', reading: 'おおきい', romanization: 'ookii'),
  _WordSeed('小さい', '작다', reading: 'ちいさい', romanization: 'chiisai'),
  _WordSeed('良い', '좋다', reading: 'よい', romanization: 'yoi'),
  _WordSeed('悪い', '나쁘다', reading: 'わるい', romanization: 'warui'),
  _WordSeed('新しい', '새롭다', reading: 'あたらしい', romanization: 'atarashii'),
  _WordSeed('古い', '오래되다', reading: 'ふるい', romanization: 'furui'),
  _WordSeed('速い', '빠르다', reading: 'はやい', romanization: 'hayai'),
  _WordSeed('遅い', '느리다', reading: 'おそい', romanization: 'osoi'),
  _WordSeed('行く', '가다', reading: 'いく', romanization: 'iku'),
  _WordSeed('来る', '오다', reading: 'くる', romanization: 'kuru'),
  _WordSeed('食べる', '먹다', reading: 'たべる', romanization: 'taberu'),
  _WordSeed('飲む', '마시다', reading: 'のむ', romanization: 'nomu'),
  _WordSeed('読む', '읽다', reading: 'よむ', romanization: 'yomu'),
  _WordSeed('書く', '쓰다', reading: 'かく', romanization: 'kaku'),
  _WordSeed('話す', '말하다', reading: 'はなす', romanization: 'hanasu'),
  _WordSeed('聞く', '듣다', reading: 'きく', romanization: 'kiku'),
  _WordSeed('見る', '보다', reading: 'みる', romanization: 'miru'),
  _WordSeed('知る', '알다', reading: 'しる', romanization: 'shiru'),
  _WordSeed('欲しい', '원하다', reading: 'ほしい', romanization: 'hoshii'),
  _WordSeed('必要', '필요하다', reading: 'ひつよう', romanization: 'hitsuyou'),
  _WordSeed('好き', '좋아하다', reading: 'すき', romanization: 'suki'),
  _WordSeed('愛', '사랑', reading: 'あい', romanization: 'ai'),
  _WordSeed('助け', '도움', reading: 'たすけ', romanization: 'tasuke'),
];

const _japaneseSentences = <_SentenceSeed>[
  _SentenceSeed(
    'お元気ですか。',
    '잘 지내세요?',
    ['お元気', 'ですか。'],
    reading: 'おげんきですか',
    romanization: 'ogenki desu ka',
    koreanPronunciation: '오겐키 데스카',
  ),
  _SentenceSeed(
    '私の名前はミナです。',
    '제 이름은 미나예요.',
    ['私の名前は', 'ミナです。'],
    reading: 'わたしのなまえはミナです',
    romanization: 'watashi no namae wa Mina desu',
    koreanPronunciation: '와타시노 나마에와 미나 데스',
  ),
  _SentenceSeed(
    'はじめまして。',
    '처음 뵙겠습니다.',
    ['はじめ', 'まして。'],
    reading: 'はじめまして',
    romanization: 'hajimemashite',
    koreanPronunciation: '하지메마시테',
  ),
  _SentenceSeed(
    '駅はどこですか。',
    '역은 어디예요?',
    ['駅は', 'どこですか。'],
    reading: 'えきはどこですか',
    romanization: 'eki wa doko desu ka',
  ),
  _SentenceSeed(
    '水をください。',
    '물을 주세요.',
    ['水を', 'ください。'],
    reading: 'みずをください',
    romanization: 'mizu o kudasai',
  ),
  _SentenceSeed(
    'コーヒーをお願いします。',
    '커피를 부탁합니다.',
    ['コーヒーを', 'お願いします。'],
    reading: 'コーヒーをおねがいします',
    romanization: 'koohii o onegaishimasu',
  ),
  _SentenceSeed(
    'これはいくらですか。',
    '이것은 얼마예요?',
    ['これは', 'いくらですか。'],
    reading: 'これはいくらですか',
    romanization: 'kore wa ikura desu ka',
  ),
  _SentenceSeed(
    '分かりません。',
    '모르겠습니다.',
    ['分かり', 'ません。'],
    reading: 'わかりません',
    romanization: 'wakarimasen',
  ),
  _SentenceSeed(
    'ゆっくり話してください。',
    '천천히 말해 주세요.',
    ['ゆっくり', '話して', 'ください。'],
    reading: 'ゆっくりはなしてください',
    romanization: 'yukkuri hanashite kudasai',
  ),
  _SentenceSeed(
    '手伝ってもらえますか。',
    '도와주실 수 있나요?',
    ['手伝って', 'もらえますか。'],
    reading: 'てつだってもらえますか',
    romanization: 'tetsudatte moraemasu ka',
  ),
  _SentenceSeed(
    '日本語を勉強しています。',
    '일본어를 공부하고 있어요.',
    ['日本語を', '勉強して', 'います。'],
    reading: 'にほんごをべんきょうしています',
    romanization: 'nihongo o benkyou shiteimasu',
  ),
  _SentenceSeed(
    '今日はいい天気です。',
    '오늘은 날씨가 좋아요.',
    ['今日は', 'いい', '天気です。'],
    reading: 'きょうはいいてんきです',
    romanization: 'kyou wa ii tenki desu',
  ),
  _SentenceSeed(
    '今日は会社へ行きます。',
    '오늘은 회사에 가요.',
    ['今日は', '会社へ', '行きます。'],
    reading: 'きょうはかいしゃへいきます',
    romanization: 'kyou wa kaisha e ikimasu',
  ),
  _SentenceSeed(
    'この料理はおいしいです。',
    '이 음식은 맛있어요.',
    ['この料理は', 'おいしい', 'です。'],
    reading: 'このりょうりはおいしいです',
    romanization: 'kono ryouri wa oishii desu',
  ),
  _SentenceSeed(
    '今何時ですか。',
    '지금 몇 시예요?',
    ['今', '何時', 'ですか。'],
    reading: 'いまなんじですか',
    romanization: 'ima nanji desu ka',
  ),
  _SentenceSeed(
    'また明日会いましょう。',
    '내일 다시 만나요.',
    ['また', '明日', '会いましょう。'],
    reading: 'またあしたあいましょう',
    romanization: 'mata ashita aimashou',
  ),
  _SentenceSeed(
    '予約があります。',
    '예약이 있습니다.',
    ['予約が', 'あります。'],
    reading: 'よやくがあります',
    romanization: 'yoyaku ga arimasu',
  ),
  _SentenceSeed(
    'バスが遅れています。',
    '버스가 늦어요.',
    ['バスが', '遅れて', 'います。'],
    reading: 'バスがおくれています',
    romanization: 'basu ga okureteimasu',
  ),
  _SentenceSeed(
    '窓を開けてください。',
    '창문을 열어 주세요.',
    ['窓を', '開けて', 'ください。'],
    reading: 'まどをあけてください',
    romanization: 'mado o akete kudasai',
  ),
  _SentenceSeed(
    '良い一日を。',
    '좋은 하루 보내세요.',
    ['良い', '一日を。'],
    reading: 'よいいちにちを',
    romanization: 'yoi ichinichi o',
  ),
];

const _germanWords = <_WordSeed>[
  _WordSeed('Hallo', '안녕하세요', koreanPronunciation: '할로'),
  _WordSeed('Auf Wiedersehen', '안녕히 가세요', koreanPronunciation: '아우프 비더제엔'),
  _WordSeed('Bitte', '부탁합니다', koreanPronunciation: '비테'),
  _WordSeed('Danke', '감사합니다', koreanPronunciation: '당케'),
  _WordSeed('Ja', '네', koreanPronunciation: '야'),
  _WordSeed('Nein', '아니요', koreanPronunciation: '나인'),
  _WordSeed('Person', '사람'),
  _WordSeed('Name', '이름'),
  _WordSeed('Freund', '친구'),
  _WordSeed('Familie', '가족'),
  _WordSeed('Mutter', '어머니'),
  _WordSeed('Vater', '아버지'),
  _WordSeed('Kind', '아이'),
  _WordSeed('Haus', '집'),
  _WordSeed('Zimmer', '방'),
  _WordSeed('Tür', '문'),
  _WordSeed('Fenster', '창문'),
  _WordSeed('Schule', '학교'),
  _WordSeed('Büro', '사무실'),
  _WordSeed('Arbeit', '일'),
  _WordSeed('Lernen', '공부'),
  _WordSeed('Buch', '책'),
  _WordSeed('Wort', '단어'),
  _WordSeed('Sprache', '언어'),
  _WordSeed('Zeit', '시간'),
  _WordSeed('Tag', '날'),
  _WordSeed('Woche', '주'),
  _WordSeed('heute', '오늘'),
  _WordSeed('morgen', '내일'),
  _WordSeed('Morgen', '아침'),
  _WordSeed('Abend', '저녁'),
  _WordSeed('Essen', '음식'),
  _WordSeed('Wasser', '물'),
  _WordSeed('Kaffee', '커피'),
  _WordSeed('Tee', '차'),
  _WordSeed('Brot', '빵'),
  _WordSeed('Reis', '밥'),
  _WordSeed('Apfel', '사과'),
  _WordSeed('Stadt', '도시'),
  _WordSeed('Land', '나라'),
  _WordSeed('Straße', '거리'),
  _WordSeed('Bahnhof', '역'),
  _WordSeed('Flughafen', '공항'),
  _WordSeed('Bus', '버스'),
  _WordSeed('Zug', '기차'),
  _WordSeed('Auto', '자동차'),
  _WordSeed('Telefon', '전화'),
  _WordSeed('Computer', '컴퓨터'),
  _WordSeed('Geld', '돈'),
  _WordSeed('Geschäft', '가게'),
  _WordSeed('Restaurant', '식당'),
  _WordSeed('Krankenhaus', '병원'),
  _WordSeed('Wetter', '날씨'),
  _WordSeed('Regen', '비'),
  _WordSeed('Sonne', '해'),
  _WordSeed('heiß', '덥다'),
  _WordSeed('kalt', '춥다'),
  _WordSeed('groß', '크다'),
  _WordSeed('klein', '작다'),
  _WordSeed('gut', '좋다'),
  _WordSeed('schlecht', '나쁘다'),
  _WordSeed('neu', '새롭다'),
  _WordSeed('alt', '오래되다'),
  _WordSeed('schnell', '빠르다'),
  _WordSeed('langsam', '느리다'),
  _WordSeed('gehen', '가다'),
  _WordSeed('kommen', '오다'),
  _WordSeed('essen', '먹다'),
  _WordSeed('trinken', '마시다'),
  _WordSeed('lesen', '읽다'),
  _WordSeed('schreiben', '쓰다'),
  _WordSeed('sprechen', '말하다'),
  _WordSeed('zuhören', '듣다'),
  _WordSeed('sehen', '보다'),
  _WordSeed('wissen', '알다'),
  _WordSeed('wollen', '원하다'),
  _WordSeed('brauchen', '필요하다'),
  _WordSeed('mögen', '좋아하다'),
  _WordSeed('lieben', '사랑하다'),
  _WordSeed('helfen', '돕다'),
];
const _germanSentences = <_SentenceSeed>[
  _SentenceSeed('Wie geht es Ihnen?', '어떻게 지내세요?', [
    'Wie',
    'geht',
    'es',
    'Ihnen?',
  ], koreanPronunciation: '비 게트 에스 이넨?'),
  _SentenceSeed('Ich heiße Mina.', '제 이름은 미나예요.', [
    'Ich',
    'heiße',
    'Mina.',
  ], koreanPronunciation: '이히 하이세 미나.'),
  _SentenceSeed(
    'Freut mich, Sie kennenzulernen.',
    '만나서 반가워요.',
    ['Freut', 'mich,', 'Sie', 'kennenzulernen.'],
    koreanPronunciation: '프로이트 미히, 지 케넨추레르넨.',
  ),
  _SentenceSeed('Wo ist der Bahnhof?', '역은 어디예요?', [
    'Wo',
    'ist',
    'der',
    'Bahnhof?',
  ]),
  _SentenceSeed('Bitte geben Sie mir Wasser.', '물 좀 주세요.', [
    'Bitte',
    'geben',
    'Sie',
    'mir',
    'Wasser.',
  ]),
  _SentenceSeed('Ich hätte gern einen Kaffee.', '커피를 주세요.', [
    'Ich',
    'hätte',
    'gern',
    'einen',
    'Kaffee.',
  ]),
  _SentenceSeed('Wie viel kostet das?', '이것은 얼마예요?', [
    'Wie',
    'viel',
    'kostet',
    'das?',
  ]),
  _SentenceSeed('Ich verstehe nicht.', '이해하지 못했어요.', [
    'Ich',
    'verstehe',
    'nicht.',
  ]),
  _SentenceSeed('Bitte sprechen Sie langsam.', '천천히 말해 주세요.', [
    'Bitte',
    'sprechen',
    'Sie',
    'langsam.',
  ]),
  _SentenceSeed('Können Sie mir helfen?', '저를 도와주실 수 있나요?', [
    'Können',
    'Sie',
    'mir',
    'helfen?',
  ]),
  _SentenceSeed('Ich lerne Deutsch.', '저는 독일어를 배워요.', [
    'Ich',
    'lerne',
    'Deutsch.',
  ]),
  _SentenceSeed('Das Wetter ist gut.', '날씨가 좋아요.', [
    'Das',
    'Wetter',
    'ist',
    'gut.',
  ]),
  _SentenceSeed('Ich gehe heute zur Arbeit.', '저는 오늘 출근해요.', [
    'Ich',
    'gehe',
    'heute',
    'zur',
    'Arbeit.',
  ]),
  _SentenceSeed('Dieses Essen ist lecker.', '이 음식은 맛있어요.', [
    'Dieses',
    'Essen',
    'ist',
    'lecker.',
  ]),
  _SentenceSeed('Wie spät ist es?', '몇 시예요?', ['Wie', 'spät', 'ist', 'es?']),
  _SentenceSeed('Bis morgen.', '내일 만나요.', ['Bis', 'morgen.']),
  _SentenceSeed('Ich habe eine Reservierung.', '예약했습니다.', [
    'Ich',
    'habe',
    'eine',
    'Reservierung.',
  ]),
  _SentenceSeed('Der Bus hat Verspätung.', '버스가 늦어요.', [
    'Der',
    'Bus',
    'hat',
    'Verspätung.',
  ]),
  _SentenceSeed('Bitte öffnen Sie das Fenster.', '창문을 열어 주세요.', [
    'Bitte',
    'öffnen',
    'Sie',
    'das',
    'Fenster.',
  ]),
  _SentenceSeed('Einen schönen Tag noch.', '좋은 하루 보내세요.', [
    'Einen',
    'schönen',
    'Tag',
    'noch.',
  ]),
];

const _frenchWords = <_WordSeed>[
  _WordSeed('bonjour', '안녕하세요', koreanPronunciation: '봉주르'),
  _WordSeed('au revoir', '안녕히 가세요', koreanPronunciation: '오 르부아르'),
  _WordSeed("s'il vous plaît", '부탁합니다', koreanPronunciation: '실 부 플레'),
  _WordSeed('merci', '감사합니다', koreanPronunciation: '메르시'),
  _WordSeed('oui', '네', koreanPronunciation: '위'),
  _WordSeed('non', '아니요', koreanPronunciation: '농'),
  _WordSeed('personne', '사람'),
  _WordSeed('nom', '이름'),
  _WordSeed('ami', '친구'),
  _WordSeed('famille', '가족'),
  _WordSeed('mère', '어머니'),
  _WordSeed('père', '아버지'),
  _WordSeed('enfant', '아이'),
  _WordSeed('maison', '집'),
  _WordSeed('chambre', '방'),
  _WordSeed('porte', '문'),
  _WordSeed('fenêtre', '창문'),
  _WordSeed('école', '학교'),
  _WordSeed('bureau', '사무실'),
  _WordSeed('travail', '일'),
  _WordSeed('étude', '공부'),
  _WordSeed('livre', '책'),
  _WordSeed('mot', '단어'),
  _WordSeed('langue', '언어'),
  _WordSeed('temps', '시간'),
  _WordSeed('jour', '날'),
  _WordSeed('semaine', '주'),
  _WordSeed("aujourd'hui", '오늘'),
  _WordSeed('demain', '내일'),
  _WordSeed('matin', '아침'),
  _WordSeed('soir', '저녁'),
  _WordSeed('nourriture', '음식'),
  _WordSeed('eau', '물'),
  _WordSeed('café', '커피'),
  _WordSeed('thé', '차'),
  _WordSeed('pain', '빵'),
  _WordSeed('riz', '밥'),
  _WordSeed('pomme', '사과'),
  _WordSeed('ville', '도시'),
  _WordSeed('pays', '나라'),
  _WordSeed('rue', '거리'),
  _WordSeed('gare', '역'),
  _WordSeed('aéroport', '공항'),
  _WordSeed('bus', '버스'),
  _WordSeed('train', '기차'),
  _WordSeed('voiture', '자동차'),
  _WordSeed('téléphone', '전화'),
  _WordSeed('ordinateur', '컴퓨터'),
  _WordSeed('argent', '돈'),
  _WordSeed('magasin', '가게'),
  _WordSeed('restaurant', '식당'),
  _WordSeed('hôpital', '병원'),
  _WordSeed('météo', '날씨'),
  _WordSeed('pluie', '비'),
  _WordSeed('soleil', '해'),
  _WordSeed('chaud', '덥다'),
  _WordSeed('froid', '춥다'),
  _WordSeed('grand', '크다'),
  _WordSeed('petit', '작다'),
  _WordSeed('bon', '좋다'),
  _WordSeed('mauvais', '나쁘다'),
  _WordSeed('nouveau', '새롭다'),
  _WordSeed('vieux', '오래되다'),
  _WordSeed('rapide', '빠르다'),
  _WordSeed('lent', '느리다'),
  _WordSeed('aller', '가다'),
  _WordSeed('venir', '오다'),
  _WordSeed('manger', '먹다'),
  _WordSeed('boire', '마시다'),
  _WordSeed('lire', '읽다'),
  _WordSeed('écrire', '쓰다'),
  _WordSeed('parler', '말하다'),
  _WordSeed('écouter', '듣다'),
  _WordSeed('voir', '보다'),
  _WordSeed('savoir', '알다'),
  _WordSeed('vouloir', '원하다'),
  _WordSeed('avoir besoin', '필요하다'),
  _WordSeed('aimer bien', '좋아하다'),
  _WordSeed('aimer', '사랑하다'),
  _WordSeed('aider', '돕다'),
];
const _frenchSentences = <_SentenceSeed>[
  _SentenceSeed('Comment allez-vous ?', '어떻게 지내세요?', [
    'Comment',
    'allez-vous',
    '?',
  ], koreanPronunciation: '코망 탈레 부?'),
  _SentenceSeed("Je m'appelle Mina.", '제 이름은 미나예요.', [
    'Je',
    "m'appelle",
    'Mina.',
  ], koreanPronunciation: '즈 마펠 미나.'),
  _SentenceSeed(
    'Enchanté de vous rencontrer.',
    '만나서 반가워요.',
    ['Enchanté', 'de', 'vous', 'rencontrer.'],
    koreanPronunciation: '앙샹테 드 부 랑콩트레.',
  ),
  _SentenceSeed('Où est la gare ?', '역은 어디예요?', [
    'Où',
    'est',
    'la',
    'gare',
    '?',
  ]),
  _SentenceSeed("Donnez-moi de l'eau, s'il vous plaît.", '물 좀 주세요.', [
    'Donnez-moi',
    "de",
    "l'eau,",
    "s'il",
    'vous',
    'plaît.',
  ]),
  _SentenceSeed('Je voudrais un café.', '커피를 주세요.', [
    'Je',
    'voudrais',
    'un',
    'café.',
  ]),
  _SentenceSeed('Combien ça coûte ?', '이것은 얼마예요?', [
    'Combien',
    'ça',
    'coûte',
    '?',
  ]),
  _SentenceSeed('Je ne comprends pas.', '이해하지 못했어요.', [
    'Je',
    'ne',
    'comprends',
    'pas.',
  ]),
  _SentenceSeed("Parlez lentement, s'il vous plaît.", '천천히 말해 주세요.', [
    'Parlez',
    'lentement,',
    "s'il",
    'vous',
    'plaît.',
  ]),
  _SentenceSeed("Pouvez-vous m'aider ?", '저를 도와주실 수 있나요?', [
    'Pouvez-vous',
    "m'aider",
    '?',
  ]),
  _SentenceSeed("J'apprends le français.", '저는 프랑스어를 배워요.', [
    "J'apprends",
    'le',
    'français.',
  ]),
  _SentenceSeed('Il fait beau.', '날씨가 좋아요.', ['Il', 'fait', 'beau.']),
  _SentenceSeed("Je vais au travail aujourd'hui.", '저는 오늘 출근해요.', [
    'Je',
    'vais',
    'au',
    'travail',
    "aujourd'hui.",
  ]),
  _SentenceSeed('Ce plat est délicieux.', '이 음식은 맛있어요.', [
    'Ce',
    'plat',
    'est',
    'délicieux.',
  ]),
  _SentenceSeed('Quelle heure est-il ?', '몇 시예요?', [
    'Quelle',
    'heure',
    'est-il',
    '?',
  ]),
  _SentenceSeed('À demain.', '내일 만나요.', ['À', 'demain.']),
  _SentenceSeed("J'ai une réservation.", '예약했습니다.', [
    "J'ai",
    'une',
    'réservation.',
  ]),
  _SentenceSeed('Le bus est en retard.', '버스가 늦어요.', [
    'Le',
    'bus',
    'est',
    'en',
    'retard.',
  ]),
  _SentenceSeed("Ouvrez la fenêtre, s'il vous plaît.", '창문을 열어 주세요.', [
    'Ouvrez',
    'la',
    'fenêtre,',
    "s'il",
    'vous',
    'plaît.',
  ]),
  _SentenceSeed('Bonne journée.', '좋은 하루 보내세요.', ['Bonne', 'journée.']),
];

const _spanishWords = <_WordSeed>[
  _WordSeed('hola', '안녕하세요', koreanPronunciation: '올라'),
  _WordSeed('adiós', '안녕히 가세요', koreanPronunciation: '아디오스'),
  _WordSeed('por favor', '부탁합니다', koreanPronunciation: '포르 파보르'),
  _WordSeed('gracias', '감사합니다', koreanPronunciation: '그라시아스'),
  _WordSeed('sí', '네', koreanPronunciation: '시'),
  _WordSeed('no', '아니요', koreanPronunciation: '노'),
  _WordSeed('persona', '사람'),
  _WordSeed('nombre', '이름'),
  _WordSeed('amigo', '친구'),
  _WordSeed('familia', '가족'),
  _WordSeed('madre', '어머니'),
  _WordSeed('padre', '아버지'),
  _WordSeed('niño', '아이'),
  _WordSeed('casa', '집'),
  _WordSeed('habitación', '방'),
  _WordSeed('puerta', '문'),
  _WordSeed('ventana', '창문'),
  _WordSeed('escuela', '학교'),
  _WordSeed('oficina', '사무실'),
  _WordSeed('trabajo', '일'),
  _WordSeed('estudio', '공부'),
  _WordSeed('libro', '책'),
  _WordSeed('palabra', '단어'),
  _WordSeed('idioma', '언어'),
  _WordSeed('tiempo', '시간'),
  _WordSeed('día', '날'),
  _WordSeed('semana', '주'),
  _WordSeed('hoy', '오늘'),
  _WordSeed('mañana', '내일'),
  _WordSeed('la mañana', '아침'),
  _WordSeed('la tarde', '저녁'),
  _WordSeed('comida', '음식'),
  _WordSeed('agua', '물'),
  _WordSeed('café', '커피'),
  _WordSeed('té', '차'),
  _WordSeed('pan', '빵'),
  _WordSeed('arroz', '밥'),
  _WordSeed('manzana', '사과'),
  _WordSeed('ciudad', '도시'),
  _WordSeed('país', '나라'),
  _WordSeed('calle', '거리'),
  _WordSeed('estación', '역'),
  _WordSeed('aeropuerto', '공항'),
  _WordSeed('autobús', '버스'),
  _WordSeed('tren', '기차'),
  _WordSeed('coche', '자동차'),
  _WordSeed('teléfono', '전화'),
  _WordSeed('computadora', '컴퓨터'),
  _WordSeed('dinero', '돈'),
  _WordSeed('tienda', '가게'),
  _WordSeed('restaurante', '식당'),
  _WordSeed('hospital', '병원'),
  _WordSeed('clima', '날씨'),
  _WordSeed('lluvia', '비'),
  _WordSeed('sol', '해'),
  _WordSeed('caliente', '덥다'),
  _WordSeed('frío', '춥다'),
  _WordSeed('grande', '크다'),
  _WordSeed('pequeño', '작다'),
  _WordSeed('bueno', '좋다'),
  _WordSeed('malo', '나쁘다'),
  _WordSeed('nuevo', '새롭다'),
  _WordSeed('viejo', '오래되다'),
  _WordSeed('rápido', '빠르다'),
  _WordSeed('lento', '느리다'),
  _WordSeed('ir', '가다'),
  _WordSeed('venir', '오다'),
  _WordSeed('comer', '먹다'),
  _WordSeed('beber', '마시다'),
  _WordSeed('leer', '읽다'),
  _WordSeed('escribir', '쓰다'),
  _WordSeed('hablar', '말하다'),
  _WordSeed('escuchar', '듣다'),
  _WordSeed('ver', '보다'),
  _WordSeed('saber', '알다'),
  _WordSeed('querer', '원하다'),
  _WordSeed('necesitar', '필요하다'),
  _WordSeed('gustar', '좋아하다'),
  _WordSeed('amar', '사랑하다'),
  _WordSeed('ayudar', '돕다'),
];
const _spanishSentences = <_SentenceSeed>[
  _SentenceSeed('¿Cómo está usted?', '어떻게 지내세요?', [
    '¿Cómo',
    'está',
    'usted?',
  ], koreanPronunciation: '코모 에스타 우스테드?'),
  _SentenceSeed('Me llamo Mina.', '제 이름은 미나예요.', [
    'Me',
    'llamo',
    'Mina.',
  ], koreanPronunciation: '메 야모 미나.'),
  _SentenceSeed('Mucho gusto.', '만나서 반가워요.', [
    'Mucho',
    'gusto.',
  ], koreanPronunciation: '무초 구스토.'),
  _SentenceSeed('¿Dónde está la estación?', '역은 어디예요?', [
    '¿Dónde',
    'está',
    'la',
    'estación?',
  ]),
  _SentenceSeed('Deme agua, por favor.', '물 좀 주세요.', [
    'Deme',
    'agua,',
    'por',
    'favor.',
  ]),
  _SentenceSeed('Quisiera un café.', '커피를 주세요.', ['Quisiera', 'un', 'café.']),
  _SentenceSeed('¿Cuánto cuesta esto?', '이것은 얼마예요?', [
    '¿Cuánto',
    'cuesta',
    'esto?',
  ]),
  _SentenceSeed('No entiendo.', '이해하지 못했어요.', ['No', 'entiendo.']),
  _SentenceSeed('Hable despacio, por favor.', '천천히 말해 주세요.', [
    'Hable',
    'despacio,',
    'por',
    'favor.',
  ]),
  _SentenceSeed('¿Puede ayudarme?', '저를 도와주실 수 있나요?', ['¿Puede', 'ayudarme?']),
  _SentenceSeed('Estoy aprendiendo español.', '저는 스페인어를 배워요.', [
    'Estoy',
    'aprendiendo',
    'español.',
  ]),
  _SentenceSeed('Hace buen tiempo.', '날씨가 좋아요.', ['Hace', 'buen', 'tiempo.']),
  _SentenceSeed('Hoy voy al trabajo.', '저는 오늘 출근해요.', [
    'Hoy',
    'voy',
    'al',
    'trabajo.',
  ]),
  _SentenceSeed('Esta comida está deliciosa.', '이 음식은 맛있어요.', [
    'Esta',
    'comida',
    'está',
    'deliciosa.',
  ]),
  _SentenceSeed('¿Qué hora es?', '몇 시예요?', ['¿Qué', 'hora', 'es?']),
  _SentenceSeed('Nos vemos mañana.', '내일 만나요.', ['Nos', 'vemos', 'mañana.']),
  _SentenceSeed('Tengo una reserva.', '예약했습니다.', ['Tengo', 'una', 'reserva.']),
  _SentenceSeed('El autobús llega tarde.', '버스가 늦어요.', [
    'El',
    'autobús',
    'llega',
    'tarde.',
  ]),
  _SentenceSeed('Abra la ventana, por favor.', '창문을 열어 주세요.', [
    'Abra',
    'la',
    'ventana,',
    'por',
    'favor.',
  ]),
  _SentenceSeed('Que tenga un buen día.', '좋은 하루 보내세요.', [
    'Que',
    'tenga',
    'un',
    'buen',
    'día.',
  ]),
];

const _chineseWords = <_WordSeed>[
  _WordSeed('你好', '안녕하세요', reading: 'nǐ hǎo', koreanPronunciation: '니 하오'),
  _WordSeed('再见', '안녕히 가세요', reading: 'zài jiàn', koreanPronunciation: '짜이 지앤'),
  _WordSeed('请', '부탁합니다', reading: 'qǐng', koreanPronunciation: '칭'),
  _WordSeed('谢谢', '감사합니다', reading: 'xiè xie', koreanPronunciation: '시에시에'),
  _WordSeed('是', '네', reading: 'shì', koreanPronunciation: '스'),
  _WordSeed('不是', '아니요', reading: 'bú shì', koreanPronunciation: '부 스'),
  _WordSeed('人', '사람', reading: 'rén'),
  _WordSeed('名字', '이름', reading: 'míng zi'),
  _WordSeed('朋友', '친구', reading: 'péng you'),
  _WordSeed('家人', '가족', reading: 'jiā rén'),
  _WordSeed('母亲', '어머니', reading: 'mǔ qīn'),
  _WordSeed('父亲', '아버지', reading: 'fù qīn'),
  _WordSeed('孩子', '아이', reading: 'hái zi'),
  _WordSeed('家', '집', reading: 'jiā'),
  _WordSeed('房间', '방', reading: 'fáng jiān'),
  _WordSeed('门', '문', reading: 'mén'),
  _WordSeed('窗户', '창문', reading: 'chuāng hu'),
  _WordSeed('学校', '학교', reading: 'xué xiào'),
  _WordSeed('办公室', '사무실', reading: 'bàn gōng shì'),
  _WordSeed('工作', '일', reading: 'gōng zuò'),
  _WordSeed('学习', '공부', reading: 'xué xí'),
  _WordSeed('书', '책', reading: 'shū'),
  _WordSeed('词', '단어', reading: 'cí'),
  _WordSeed('语言', '언어', reading: 'yǔ yán'),
  _WordSeed('时间', '시간', reading: 'shí jiān'),
  _WordSeed('天', '날', reading: 'tiān'),
  _WordSeed('星期', '주', reading: 'xīng qī'),
  _WordSeed('今天', '오늘', reading: 'jīn tiān'),
  _WordSeed('明天', '내일', reading: 'míng tiān'),
  _WordSeed('早上', '아침', reading: 'zǎo shang'),
  _WordSeed('晚上', '저녁', reading: 'wǎn shang'),
  _WordSeed('食物', '음식', reading: 'shí wù'),
  _WordSeed('水', '물', reading: 'shuǐ'),
  _WordSeed('咖啡', '커피', reading: 'kā fēi'),
  _WordSeed('茶', '차', reading: 'chá'),
  _WordSeed('面包', '빵', reading: 'miàn bāo'),
  _WordSeed('米饭', '밥', reading: 'mǐ fàn'),
  _WordSeed('苹果', '사과', reading: 'píng guǒ'),
  _WordSeed('城市', '도시', reading: 'chéng shì'),
  _WordSeed('国家', '나라', reading: 'guó jiā'),
  _WordSeed('街道', '거리', reading: 'jiē dào'),
  _WordSeed('车站', '역', reading: 'chē zhàn'),
  _WordSeed('机场', '공항', reading: 'jī chǎng'),
  _WordSeed('公交车', '버스', reading: 'gōng jiāo chē'),
  _WordSeed('火车', '기차', reading: 'huǒ chē'),
  _WordSeed('汽车', '자동차', reading: 'qì chē'),
  _WordSeed('电话', '전화', reading: 'diàn huà'),
  _WordSeed('电脑', '컴퓨터', reading: 'diàn nǎo'),
  _WordSeed('钱', '돈', reading: 'qián'),
  _WordSeed('商店', '가게', reading: 'shāng diàn'),
  _WordSeed('餐厅', '식당', reading: 'cān tīng'),
  _WordSeed('医院', '병원', reading: 'yī yuàn'),
  _WordSeed('天气', '날씨', reading: 'tiān qì'),
  _WordSeed('雨', '비', reading: 'yǔ'),
  _WordSeed('太阳', '해', reading: 'tài yáng'),
  _WordSeed('热', '덥다', reading: 'rè'),
  _WordSeed('冷', '춥다', reading: 'lěng'),
  _WordSeed('大', '크다', reading: 'dà'),
  _WordSeed('小', '작다', reading: 'xiǎo'),
  _WordSeed('好', '좋다', reading: 'hǎo'),
  _WordSeed('坏', '나쁘다', reading: 'huài'),
  _WordSeed('新', '새롭다', reading: 'xīn'),
  _WordSeed('旧', '오래되다', reading: 'jiù'),
  _WordSeed('快', '빠르다', reading: 'kuài'),
  _WordSeed('慢', '느리다', reading: 'màn'),
  _WordSeed('去', '가다', reading: 'qù'),
  _WordSeed('来', '오다', reading: 'lái'),
  _WordSeed('吃', '먹다', reading: 'chī'),
  _WordSeed('喝', '마시다', reading: 'hē'),
  _WordSeed('读', '읽다', reading: 'dú'),
  _WordSeed('写', '쓰다', reading: 'xiě'),
  _WordSeed('说', '말하다', reading: 'shuō'),
  _WordSeed('听', '듣다', reading: 'tīng'),
  _WordSeed('看', '보다', reading: 'kàn'),
  _WordSeed('知道', '알다', reading: 'zhī dào'),
  _WordSeed('想要', '원하다', reading: 'xiǎng yào'),
  _WordSeed('需要', '필요하다', reading: 'xū yào'),
  _WordSeed('喜欢', '좋아하다', reading: 'xǐ huan'),
  _WordSeed('爱', '사랑하다', reading: 'ài'),
  _WordSeed('帮助', '돕다', reading: 'bāng zhù'),
];
const _chineseSentences = <_SentenceSeed>[
  _SentenceSeed(
    '你好吗？',
    '어떻게 지내세요?',
    ['你', '好吗？'],
    reading: 'nǐ hǎo ma',
    koreanPronunciation: '니 하오 마?',
  ),
  _SentenceSeed(
    '我叫米娜。',
    '제 이름은 미나예요.',
    ['我叫', '米娜。'],
    reading: 'wǒ jiào Mǐnà',
    koreanPronunciation: '워 지아오 미나.',
  ),
  _SentenceSeed(
    '很高兴认识你。',
    '만나서 반가워요.',
    ['很高兴', '认识你。'],
    reading: 'hěn gāo xìng rèn shi nǐ',
    koreanPronunciation: '헌 가오싱 런스 니.',
  ),
  _SentenceSeed('车站在哪里？', '역은 어디예요?', [
    '车站',
    '在哪里？',
  ], reading: 'chē zhàn zài nǎ lǐ'),
  _SentenceSeed('请给我水。', '물 좀 주세요.', [
    '请',
    '给我',
    '水。',
  ], reading: 'qǐng gěi wǒ shuǐ'),
  _SentenceSeed('我想要咖啡。', '커피를 주세요.', [
    '我',
    '想要',
    '咖啡。',
  ], reading: 'wǒ xiǎng yào kā fēi'),
  _SentenceSeed('这个多少钱？', '이것은 얼마예요?', [
    '这个',
    '多少',
    '钱？',
  ], reading: 'zhè ge duō shao qián'),
  _SentenceSeed('我不明白。', '이해하지 못했어요.', [
    '我',
    '不明白。',
  ], reading: 'wǒ bù míng bai'),
  _SentenceSeed('请说慢一点。', '천천히 말해 주세요.', [
    '请',
    '说慢',
    '一点。',
  ], reading: 'qǐng shuō màn yì diǎn'),
  _SentenceSeed('你能帮助我吗？', '저를 도와주실 수 있나요?', [
    '你能',
    '帮助',
    '我吗？',
  ], reading: 'nǐ néng bāng zhù wǒ ma'),
  _SentenceSeed('我在学中文。', '저는 중국어를 배워요.', [
    '我在',
    '学',
    '中文。',
  ], reading: 'wǒ zài xué zhōng wén'),
  _SentenceSeed('天气很好。', '날씨가 좋아요.', ['天气', '很好。'], reading: 'tiān qì hěn hǎo'),
  _SentenceSeed('我今天去上班。', '저는 오늘 출근해요.', [
    '我',
    '今天',
    '去上班。',
  ], reading: 'wǒ jīn tiān qù shàng bān'),
  _SentenceSeed('这个菜很好吃。', '이 음식은 맛있어요.', [
    '这个菜',
    '很好吃。',
  ], reading: 'zhè ge cài hěn hǎo chī'),
  _SentenceSeed('现在几点？', '몇 시예요?', ['现在', '几点？'], reading: 'xiàn zài jǐ diǎn'),
  _SentenceSeed('明天见。', '내일 만나요.', ['明天', '见。'], reading: 'míng tiān jiàn'),
  _SentenceSeed('我有预订。', '예약했습니다.', ['我有', '预订。'], reading: 'wǒ yǒu yù dìng'),
  _SentenceSeed('公交车晚点了。', '버스가 늦어요.', [
    '公交车',
    '晚点了。',
  ], reading: 'gōng jiāo chē wǎn diǎn le'),
  _SentenceSeed('请打开窗户。', '창문을 열어 주세요.', [
    '请',
    '打开',
    '窗户。',
  ], reading: 'qǐng dǎ kāi chuāng hu'),
  _SentenceSeed('祝你今天愉快。', '좋은 하루 보내세요.', [
    '祝你',
    '今天',
    '愉快。',
  ], reading: 'zhù nǐ jīn tiān yú kuài'),
];
