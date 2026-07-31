import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/import/content_import_parser.dart';

void main() {
  const parser = ContentImportParser();

  test('parses valid CSV rows and reports invalid rows', () {
    const input = '''
type,term,meaning,accepted_answers,tags,priority
word,hello,안녕하세요,안녕|여보세요,인사|기초,3
word,missing meaning,,,기초,0
''';
    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.items, hasLength(1));
    expect(preview.items.single.acceptedAnswers, contains('안녕'));
    expect(preview.issues.single.row, 3);
  });

  test('imports generic study material into the active subject', () {
    const input =
        'type,language,term,meaning,group,example,example_translation\n'
        'word,ko,WHIP,이닝당 출루 허용률,투수 기록,WHIP가 1.10이다.,주자가 적게 나갔다.\n';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.korean,
      defaultSubjectId: 'general:baseball',
    );

    expect(preview.issues, isEmpty);
    expect(preview.items, hasLength(2));
    expect(
      preview.items.every(
        (item) => item.effectiveSubjectId == 'general:baseball',
      ),
      isTrue,
    );
    expect(
      preview.items.every(
        (item) => item.learningLanguage == LanguageTag.korean,
      ),
      isTrue,
    );
    expect(preview.items.expand(learningGroupsOf).toSet(), contains('투수 기록'));
  });

  test('an upload route overrides file destinations and tags every item', () {
    const input =
        'type,language,subject_id,term,meaning,group,distribution_key\n'
        'word,en,general:old,ticket,표,기존 그룹,old-route\n';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
      distributionKey: ' Travel Core ',
      distributionGroup: '여행 준비',
      routeSubjectId: 'language:ja',
      routeLanguageCode: 'ja',
    );

    expect(preview.issues, isEmpty);
    expect(preview.items, hasLength(1));
    final item = preview.items.single;
    expect(item.effectiveSubjectId, 'language:ja');
    expect(item.learningLanguage, LanguageTag.japanese);
    expect(learningGroupsOf(item), containsAll(['기존 그룹', '여행 준비']));
    expect(importDistributionKeyOf(item), 'travel-core');
  });

  test('routes multiple embedded keys with their saved subject and group', () {
    const input =
        'type,term,meaning,distribution_key\n'
        'word,brief,업무 지시,office-core\n'
        'word,bonjour,안녕하세요,french-core\n';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.japanese,
      subjectIdByDistributionKey: const {
        'office-core': 'general:office-english',
        'french-core': 'language:fr',
      },
      groupByDistributionKey: const {
        'office-core': '업무 필수',
        'french-core': '프랑스어 기초',
      },
      languageCodeByDistributionKey: const {
        'office-core': 'en',
        'french-core': 'fr',
      },
    );

    expect(preview.issues, isEmpty);
    expect(preview.items, hasLength(2));
    final byKey = {
      for (final item in preview.items) importDistributionKeyOf(item)!: item,
    };
    expect(byKey['office-core']?.effectiveSubjectId, 'general:office-english');
    expect(byKey['office-core']?.learningLanguage, LanguageTag.english);
    expect(learningGroupsOf(byKey['office-core']!), contains('업무 필수'));
    expect(byKey['french-core']?.effectiveSubjectId, 'language:fr');
    expect(byKey['french-core']?.learningLanguage, LanguageTag.french);
    expect(learningGroupsOf(byKey['french-core']!), contains('프랑스어 기초'));
  });

  test('lang fallback key overrides conflicting row language and subject', () {
    const input =
        'type,language,subject_id,term,meaning,distribution_key\n'
        'word,en,language:en,駅,역,lang:ja\n';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.issues, isEmpty);
    expect(preview.items.single.effectiveSubjectId, 'language:ja');
    expect(preview.items.single.learningLanguage, LanguageTag.japanese);
    expect(preview.items.single.learningLanguage.ttsLocale, 'ja-JP');
    expect(preview.items.single.reading(ReadingScheme.hangul), isNull);
    expect(preview.notices, hasLength(1));
    expect(preview.notices.single.message, contains('kana 또는 romaji'));
  });

  test('saved key maps override fallback language routing', () {
    const input =
        'type,language,term,meaning,distribution_key\n'
        'word,en,bonjour,안녕하세요,lang:en\n';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
      subjectIdByDistributionKey: const {'lang:en': 'language:fr'},
      languageCodeByDistributionKey: const {'lang:en': 'fr'},
    );

    expect(preview.issues, isEmpty);
    expect(preview.items.single.effectiveSubjectId, 'language:fr');
    expect(preview.items.single.learningLanguage, LanguageTag.french);
  });

  test('subject_id isolates identical material in different subjects', () {
    const input =
        'type,language,subject_id,term,meaning\n'
        'word,ko,general:baseball,팬,응원하는 사람\n'
        'word,ko,general:idol,팬,응원하는 사람\n';

    final preview = parser.parseCsv(input, defaultLanguage: LanguageTag.korean);

    expect(preview.issues, isEmpty);
    expect(preview.duplicates, isEmpty);
    expect(preview.items.map((item) => item.effectiveSubjectId).toSet(), {
      'general:baseball',
      'general:idol',
    });
    expect(preview.items.map((item) => item.id).toSet(), hasLength(2));
  });

  test('generates a stable UUID and detects duplicate rows', () {
    const input = '''
type,term,meaning
word,water,물
word,water,물
''';
    final first = parser.parseCsv(input, defaultLanguage: LanguageTag.english);
    final second = parser.parseCsv(
      'type,term,meaning\nword,water,물',
      defaultLanguage: LanguageTag.english,
    );

    expect(first.items.single.id, second.items.single.id);
    expect(first.duplicateIds, contains(first.items.single.id));
    expect(first.duplicates.single.row, 3);
    expect(first.duplicates.single.firstRow, 2);
    expect(first.duplicates.single.kind, ImportDuplicateKind.id);
  });

  test('duplicate rows keep the warning while merging supplemental fields', () {
    const input = '''
type,term,meaning,korean_pronunciation,accepted_answers,group,tags
word,water,물,,수분,기초,필수
word,water,물,워터,식수,여행,생존
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );
    final item = preview.items.single;

    expect(preview.issues, isEmpty);
    expect(preview.duplicates, hasLength(1));
    expect(preview.duplicates.single.row, 3);
    expect(preview.duplicates.single.firstRow, 2);
    expect(preview.duplicates.single.kind, ImportDuplicateKind.id);
    expect(item.reading(ReadingScheme.hangul), '워터');
    expect(item.acceptedAnswers, containsAll(['수분', '식수']));
    expect(learningGroupsOf(item), containsAll(['기초', '여행']));
    expect(item.tags, containsAll(['필수', '생존']));
  });

  test('parses Japanese reading helpers from JSONL', () {
    const input =
        '{"type":"word","term":"水","meaning":"물","kana":"みず","romaji":"mizu"}';
    final preview = parser.parseJsonLines(
      input,
      defaultLanguage: LanguageTag.japanese,
    );

    expect(
      preview.issues,
      isEmpty,
      reason: preview.issues
          .map((issue) => '행 ${issue.row}: ${issue.message}')
          .join('\n'),
    );
    expect(preview.items.single.readings, hasLength(3));
    expect(preview.items.single.reading(ReadingScheme.hangul), '미즈');
  });

  test('maps a generic Chinese reading to pinyin instead of kana', () {
    const input = '{"type":"word","term":"水","meaning":"물","reading":"shuǐ"}';
    final preview = parser.parseJsonLines(
      input,
      defaultLanguage: LanguageTag.simplifiedChinese,
    );

    expect(preview.issues, isEmpty);
    expect(preview.items.single.reading(ReadingScheme.pinyin), 'shuǐ');
    expect(preview.items.single.reading(ReadingScheme.hangul), isNotEmpty);
  });

  test('imports Korean pronunciation for every supported target language', () {
    for (final language in LanguageTag.values.where(
      (value) => value.available,
    )) {
      final preview = parser.parseCsv(
        'type,term,meaning,korean_pronunciation\nword,sample,예시,샘플',
        defaultLanguage: language,
      );

      expect(preview.issues, isEmpty, reason: language.code);
      expect(
        preview.items.single.reading(ReadingScheme.hangul),
        '샘플',
        reason: language.code,
      );
    }
  });

  test('enriches safe readings offline and keeps explicit Hangul first', () {
    final generated = parser.parseCsv(
      'type,term,meaning,kana\nword,学校,학교,がっこう',
      defaultLanguage: LanguageTag.japanese,
    );
    final explicit = parser.parseCsv(
      'type,term,meaning,romaji,korean_pronunciation\n'
      'word,学校,학교,gakkou,각코오',
      defaultLanguage: LanguageTag.japanese,
    );

    expect(generated.issues, isEmpty);
    expect(generated.notices, isEmpty);
    expect(generated.items.single.reading(ReadingScheme.hangul), '가코우');
    expect(explicit.items.single.reading(ReadingScheme.hangul), '각코오');
  });

  test('duplicate rows merge meanings and Korean pronunciation readings', () {
    final preview = parser.parseCsv(
      'type,term,meaning,korean_pronunciation\n'
      'word,record,기록,레코드\n'
      'word,record,기록하다,리코드',
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.issues, isEmpty);
    expect(preview.items, hasLength(1));
    expect(preview.items.single.translations, containsAll(['기록', '기록하다']));
    expect(
      preview.items.single.readings.map((reading) => reading.value),
      containsAll(['레코드', '리코드']),
    );
  });

  test('imports Korean pronunciation for generated example sentences', () {
    final preview = parser.parseCsv(
      'type,term,meaning,korean_pronunciation,example,'
      'example_translation,example_pronunciation\n'
      'word,hello,안녕하세요,헬로우,Hello again.,다시 안녕하세요.,헬로우 어게인.',
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.issues, isEmpty);
    final word = preview.items.singleWhere(
      (item) => item.kind == LearningItemKind.word,
    );
    final example = preview.items.singleWhere(
      (item) => item.kind == LearningItemKind.sentence,
    );
    expect(word.reading(ReadingScheme.hangul), '헬로우');
    expect(example.reading(ReadingScheme.hangul), '헬로우 어게인.');
  });

  test('reports invalid Japanese and Chinese reading formats by row', () {
    final japanese = parser.parseCsv(
      'type,term,meaning,kana,romaji\nword,水,물,mizu,みず',
      defaultLanguage: LanguageTag.japanese,
    );
    final chinese = parser.parseCsv(
      'type,term,meaning,pinyin\nword,水,물,shuǐ3',
      defaultLanguage: LanguageTag.simplifiedChinese,
    );

    expect(japanese.items, isEmpty);
    expect(japanese.issues.single.row, 2);
    expect(japanese.issues.single.message, contains('가나 읽기'));
    expect(japanese.issues.single.message, contains('로마자'));
    expect(chinese.items, isEmpty);
    expect(chinese.issues.single.row, 2);
    expect(chinese.issues.single.message, contains('섞지 마세요'));
  });

  test('reports non-object JSON rows without aborting valid rows', () {
    const input = '''
[
  {"type":"word","term":"water","meaning":"물"},
  "not an object",
  {"type":"word","term":"coffee","meaning":"커피"}
]
''';
    final preview = parser.parseJson(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.items, hasLength(2));
    expect(preview.issues.single.row, 2);
  });

  test('rejects unsupported readings and out-of-range priority', () {
    final reading = parser.parseCsv(
      'type,term,meaning,pinyin\nword,water,물,shuǐ',
      defaultLanguage: LanguageTag.english,
    );
    final priority = parser.parseCsv(
      'type,term,meaning,priority\nword,water,물,99',
      defaultLanguage: LanguageTag.english,
    );

    expect(reading.items, isEmpty);
    expect(reading.issues.single.message, contains('pinyin'));
    expect(priority.items, isEmpty);
    expect(priority.issues.single.message, contains('0부터 10'));
  });

  test('preserves part of speech and source metadata from CSV', () {
    const input = '''
type,term,meaning,part_of_speech,source,license,source_version,source_id,source_url,author,attribution,content_version
word,record,기록,verb,Personal notes,private,2026.1,entry-7,https://example.com/entry-7,Example Author,Example Author · Personal notes,3
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );
    final item = preview.items.single;

    expect(preview.issues, isEmpty);
    expect(item.partOfSpeech, PartOfSpeech.verb);
    expect(item.source.name, 'Personal notes');
    expect(item.source.license, 'private');
    expect(item.source.sourceVersion, '2026.1');
    expect(item.source.contentVersion, 3);
    expect(item.source.sourceId, 'entry-7');
    expect(item.source.sourceUrl, 'https://example.com/entry-7');
    expect(item.source.author, 'Example Author');
    expect(item.source.attribution, 'Example Author · Personal notes');
  });

  test('same spelling and meaning with different parts gets different IDs', () {
    const input = '''
type,term,meaning,part_of_speech
word,record,기록,noun
word,record,기록,verb
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.items, hasLength(2));
    expect(preview.items[0].id, isNot(preview.items[1].id));
    expect(preview.duplicateIds, isEmpty);
  });

  test('explicitly different IDs cannot bypass semantic duplicate checks', () {
    const input = '''
id,type,term,meaning,part_of_speech
first,word,record,기록,noun
second,word,record,기록,noun
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.items.single.id, 'first');
    expect(preview.duplicateIds, {'second'});
    expect(preview.duplicates.single.row, 3);
    expect(preview.duplicates.single.firstRow, 2);
    expect(preview.duplicates.single.kind, ImportDuplicateKind.semantic);
  });

  test('parses nested JSON source and rejects invalid metadata', () {
    const valid = '''
[
  {
    "type": "word",
    "term": "water",
    "meaning": "물",
    "partOfSpeech": "noun",
      "source": {
        "name": "Own list",
        "license": "private",
        "sourceVersion": "2",
        "contentVersion": 4,
        "sourceId": "own-1",
        "sourceUrl": "https://example.com/own-1",
        "author": "Owner",
        "attribution": "Owner · Own list"
      }
  }
]
''';
    const invalid =
        'type,term,meaning,content_version\nword,water,물,not-an-int';

    final parsed = parser.parseJson(
      valid,
      defaultLanguage: LanguageTag.english,
    );
    final rejected = parser.parseCsv(
      invalid,
      defaultLanguage: LanguageTag.english,
    );

    expect(parsed.items.single.source.contentVersion, 4);
    expect(parsed.items.single.source.sourceId, 'own-1');
    expect(parsed.items.single.source.sourceUrl, 'https://example.com/own-1');
    expect(parsed.items.single.source.author, 'Owner');
    expect(parsed.items.single.source.attribution, 'Owner · Own list');
    expect(rejected.items, isEmpty);
    expect(rejected.issues.single.message, contains('content_version'));
  });

  test('repository import template stays parseable', () {
    final input = File(
      '../../sample-data/import-template.csv',
    ).readAsStringSync();

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.issues, isEmpty);
    expect(preview.duplicateIds, isEmpty);
    expect(preview.items, hasLength(6));
    expect(
      preview.items
          .where((item) => item.kind == LearningItemKind.word)
          .map((item) => item.partOfSpeech),
      [PartOfSpeech.noun, PartOfSpeech.verb, PartOfSpeech.other],
    );
    expect(
      preview.items.where(
        (item) => item.effectiveSubjectId == 'general:baseball',
      ),
      hasLength(2),
    );
    expect(
      preview.items.every((item) => item.source.name == '사용자 직접 정리'),
      isTrue,
    );
  });

  test('merges meanings, examples, and learning groups for repeated words', () {
    const input = '''
language,type,term,meaning,group,part_of_speech,example,example_translation
en,word,book,책,여행 준비,noun,I read a book.,책을 읽어요.
en,word,book,예약하다,이번 주,noun,,
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );
    final item = preview.items.firstWhere(
      (item) => item.kind == LearningItemKind.word,
    );
    final example = preview.items.firstWhere(
      (item) => item.kind == LearningItemKind.sentence,
    );

    expect(preview.issues, isEmpty);
    expect(preview.duplicates, isEmpty);
    expect(item.translations, ['책', '예약하다']);
    expect(item.example, 'I read a book.');
    expect(learningGroupsOf(item), {'여행 준비', '이번 주'});
    expect(example.text, 'I read a book.');
    expect(example.translations, ['책을 읽어요.']);
    expect(learningGroupsOf(example), {'여행 준비'});
  });

  test('expands multiple word examples into independent sentence items', () {
    const input = '''
language,type,term,meaning,group,part_of_speech,example,example_translation,example_tokens,example_2,example_2_translation,example_2_tokens
en,word,reservation,예약,여행 준비,noun,I have a reservation.,예약했습니다.,I|have|a|reservation.,Can I change my reservation?,예약을 변경할 수 있나요?,Can|I|change|my|reservation?
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );
    final word = preview.items.singleWhere(
      (item) => item.kind == LearningItemKind.word,
    );
    final sentences = preview.items
        .where((item) => item.kind == LearningItemKind.sentence)
        .toList();

    expect(preview.issues, isEmpty);
    expect(preview.duplicates, isEmpty);
    expect(word.example, 'I have a reservation.');
    expect(sentences, hasLength(2));
    expect(
      sentences.map((item) => item.text),
      containsAll(['I have a reservation.', 'Can I change my reservation?']),
    );
    expect(
      sentences.every(
        (item) =>
            learningGroupsOf(item).contains('여행 준비') &&
            item.capabilities.contains(ExerciseCapability.sentenceOrder) &&
            item.capabilities.contains(ExerciseCapability.cloze),
      ),
      isTrue,
    );
  });

  test('keeps a valid word while reporting an unpaired example', () {
    const input = '''
type,term,meaning,example_2
word,ticket,표,Where can I buy a ticket?
''';

    final preview = parser.parseCsv(
      input,
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.items, hasLength(1));
    expect(preview.items.single.kind, LearningItemKind.word);
    expect(preview.issues.single.row, 2);
    expect(preview.issues.single.message, contains('예문 뜻'));
  });

  test('bundled Excel template parses all six learning languages', () {
    final bytes = File(
      'assets/templates/Sprache-word-import-template.xlsx',
    ).readAsBytesSync();

    final preview = parser.parseExcel(
      bytes,
      defaultLanguage: LanguageTag.english,
    );

    expect(
      preview.issues,
      isEmpty,
      reason: preview.issues
          .map((issue) => '행 ${issue.row}: ${issue.message}')
          .join('\n'),
    );
    expect(
      preview.items.map((item) => item.learningLanguage).toSet(),
      containsAll({
        LanguageTag.english,
        LanguageTag.japanese,
        LanguageTag.german,
        LanguageTag.french,
        LanguageTag.spanish,
        LanguageTag.simplifiedChinese,
      }),
    );
    expect(
      preview.items.any((item) => item.kind == LearningItemKind.sentence),
      isTrue,
    );
    _expectBundledDistributionRoutes(preview);
    final baseballItems = preview.items
        .where((item) => importDistributionKeyOf(item) == 'baseball-core')
        .toList(growable: false);
    expect(baseballItems, isNotEmpty);
    expect(
      baseballItems.every(
        (item) =>
            item.learningLanguage == LanguageTag.korean &&
            item.effectiveSubjectId == 'general:baseball',
      ),
      isTrue,
    );
    for (final language in LanguageTag.values.where(
      (value) => value.available,
    )) {
      expect(
        preview.items.any(
          (item) =>
              item.learningLanguage == language &&
              item.reading(ReadingScheme.hangul) != null,
        ),
        isTrue,
        reason: language.code,
      );
    }
  });

  test(
    'bundled easy Excel template merges duplicate meanings, groups, and examples',
    () {
      final bytes = File(
        'assets/templates/Sprache-easy-import-template.xlsx',
      ).readAsBytesSync();

      final preview = parser.parseExcel(
        bytes,
        defaultLanguage: LanguageTag.english,
      );

      expect(
        preview.issues,
        isEmpty,
        reason: preview.issues
            .map((issue) => '행 ${issue.row}: ${issue.message}')
            .join('\n'),
      );
      expect(preview.duplicates, isEmpty);
      expect(preview.items, hasLength(15));
      _expectBundledDistributionRoutes(preview);
      expect(
        preview.items.map((item) => item.learningLanguage).toSet(),
        containsAll({
          LanguageTag.english,
          LanguageTag.japanese,
          LanguageTag.german,
          LanguageTag.french,
          LanguageTag.spanish,
          LanguageTag.simplifiedChinese,
          LanguageTag.korean,
        }),
      );

      final reservation = preview.items.singleWhere(
        (item) =>
            item.kind == LearningItemKind.word &&
            item.learningLanguage == LanguageTag.english &&
            item.text == 'reservation',
      );
      expect(reservation.translations, containsAll(['예약', '예약한 자리']));
      expect(
        reservation.readings.map((reading) => reading.value),
        contains('레저베이션'),
      );
      expect(learningGroupsOf(reservation), containsAll(['여행 준비', '이번 주 암기']));
      expect(reservation.priority, 7);

      final reservationExample = preview.items.singleWhere(
        (item) =>
            item.kind == LearningItemKind.sentence &&
            item.text == 'I have a reservation.',
      );
      expect(
        reservationExample.capabilities,
        containsAll({
          ExerciseCapability.cloze,
          ExerciseCapability.sentenceOrder,
        }),
      );
      expect(learningGroupsOf(reservationExample), contains('여행 준비'));

      final baseball = preview.items.singleWhere(
        (item) =>
            item.kind == LearningItemKind.word &&
            item.effectiveSubjectId == 'general:baseball' &&
            item.text == 'OPS',
      );
      expect(
        baseball.translations,
        containsAll(['출루율과 장타율의 합', '타자의 공격력을 나타내는 지표']),
      );
      expect(learningGroupsOf(baseball), containsAll(['타격 지표', '이번 주 암기']));
      expect(baseball.priority, 9);
      expect(importDistributionKeyOf(baseball), 'baseball-core');
    },
  );

  test(
    'bundled Tatoeba pack preserves licensed provenance for six languages',
    () {
      final input = File(
        'assets/content/tatoeba-korean-sentence-pack-2026-07-28.json',
      ).readAsStringSync();

      final preview = parser.parseJson(
        input,
        defaultLanguage: LanguageTag.english,
      );

      expect(
        preview.issues,
        isEmpty,
        reason: preview.issues
            .map((issue) => '행 ${issue.row}: ${issue.message}')
            .join('\n'),
      );
      expect(preview.duplicates, isEmpty);
      expect(preview.items, hasLength(12));
      expect(
        preview.items.map((item) => item.learningLanguage).toSet(),
        LanguageTag.values.where((language) => language.available).toSet(),
      );
      expect(
        preview.items.every(
          (item) =>
              item.kind == LearningItemKind.sentence &&
              item.source.name == 'Tatoeba' &&
              item.source.license == 'CC BY 2.0 FR' &&
              item.source.sourceId != null &&
              item.source.sourceUrl?.startsWith('https://tatoeba.org/') ==
                  true &&
              item.source.author != null &&
              item.source.attribution?.contains('CC BY 2.0 FR') == true &&
              learningGroupsOf(item).contains('Tatoeba 웹 예문'),
        ),
        isTrue,
      );
    },
  );

  test(
    'practical Tatoeba pack is duplicate-free and keeps readings and provenance',
    () {
      final practical = parser.parseJson(
        File(
          'assets/content/tatoeba-practical-sentence-pack-2026-07-29.json',
        ).readAsStringSync(),
        defaultLanguage: LanguageTag.english,
      );
      final basic = parser.parseJson(
        File(
          'assets/content/tatoeba-korean-sentence-pack-2026-07-28.json',
        ).readAsStringSync(),
        defaultLanguage: LanguageTag.english,
      );

      expect(
        practical.issues,
        isEmpty,
        reason: practical.issues
            .map((issue) => '행 ${issue.row}: ${issue.message}')
            .join('\n'),
      );
      expect(practical.duplicates, isEmpty);
      expect(practical.items, hasLength(12));
      expect(
        practical.items.map((item) => item.learningLanguage).toSet(),
        LanguageTag.values.where((language) => language.available).toSet(),
      );
      expect(
        practical.items.every(
          (item) =>
              item.kind == LearningItemKind.sentence &&
              item.sentenceTokens.length >= 2 &&
              item.source.name == 'Tatoeba' &&
              item.source.license == 'CC BY 2.0 FR' &&
              item.source.sourceVersion == '2026-07-29' &&
              item.source.sourceId != null &&
              item.source.author != null &&
              item.source.attribution?.contains('CC BY 2.0 FR') == true &&
              learningGroupsOf(item).contains('Tatoeba 실용 예문'),
        ),
        isTrue,
      );
      expect(
        practical.items
            .where((item) => item.learningLanguage == LanguageTag.japanese)
            .every(
              (item) =>
                  item.reading(ReadingScheme.kana) != null &&
                  item.reading(ReadingScheme.romaji) != null,
            ),
        isTrue,
      );
      expect(
        practical.items
            .where(
              (item) => item.learningLanguage == LanguageTag.simplifiedChinese,
            )
            .every((item) => item.reading(ReadingScheme.pinyin) != null),
        isTrue,
      );

      final crossPackKeys = <String>{};
      for (final item in [...basic.items, ...practical.items]) {
        final key =
            '${item.learningLanguage.code}|${item.text.trim().toLowerCase()}';
        expect(crossPackKeys.add(key), isTrue, reason: '중복 표현: $key');
      }
    },
  );

  test(
    'bundled general-topic packs keep subject, groups, examples, and sources',
    () {
      final packs = {
        'assets/content/baseball-starter-pack-2026-07-28.json':
            'general:baseball',
        'assets/content/idol-fandom-starter-pack-2026-07-28.json':
            'general:idol-fandom',
      };

      for (final entry in packs.entries) {
        final preview = parser.parseJson(
          File(entry.key).readAsStringSync(),
          defaultLanguage: LanguageTag.korean,
          defaultSubjectId: entry.value,
        );

        expect(preview.issues, isEmpty, reason: entry.key);
        expect(preview.duplicates, isEmpty, reason: entry.key);
        expect(preview.items.length, greaterThanOrEqualTo(10));
        expect(
          preview.items.every(
            (item) =>
                item.effectiveSubjectId == entry.value &&
                item.learningLanguage == LanguageTag.korean &&
                item.source.sourceUrl?.startsWith('https://') == true &&
                item.source.attribution?.isNotEmpty == true &&
                learningGroupsOf(item).isNotEmpty,
          ),
          isTrue,
          reason: entry.key,
        );
        expect(
          preview.items.any((item) => item.kind == LearningItemKind.word),
          isTrue,
        );
        expect(
          preview.items.any((item) => item.kind == LearningItemKind.sentence),
          isTrue,
        );
      }
    },
  );
}

void _expectBundledDistributionRoutes(ImportPreview preview) {
  final keys = preview.items
      .map(importDistributionKeyOf)
      .whereType<String>()
      .toSet();
  expect(
    keys,
    containsAll({
      'lang:en',
      'lang:ja',
      'lang:de',
      'lang:fr',
      'lang:es',
      'lang:zh-hans',
      'baseball-core',
    }),
  );
  for (final language in LanguageTag.values.where((value) => value.available)) {
    final key = 'lang:${language.code.toLowerCase()}';
    final routed = preview.items
        .where((item) => importDistributionKeyOf(item) == key)
        .toList(growable: false);
    expect(routed, isNotEmpty, reason: key);
    expect(
      routed.every(
        (item) =>
            item.learningLanguage == language &&
            item.effectiveSubjectId == languageSubjectId(language),
      ),
      isTrue,
      reason: key,
    );
  }
}
