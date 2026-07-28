import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
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

  test('parses Japanese reading helpers from JSONL', () {
    const input =
        '{"type":"word","term":"水","meaning":"물","kana":"みず","romaji":"mizu"}';
    final preview = parser.parseJsonLines(
      input,
      defaultLanguage: LanguageTag.japanese,
    );

    expect(preview.issues, isEmpty);
    expect(preview.items.single.readings, hasLength(2));
  });

  test('maps a generic Chinese reading to pinyin instead of kana', () {
    const input = '{"type":"word","term":"水","meaning":"물","reading":"shuǐ"}';
    final preview = parser.parseJsonLines(
      input,
      defaultLanguage: LanguageTag.simplifiedChinese,
    );

    expect(preview.issues, isEmpty);
    expect(preview.items.single.readings.single.scheme, ReadingScheme.pinyin);
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
type,term,meaning,part_of_speech,source,license,source_version,content_version
word,record,기록,verb,Personal notes,private,2026.1,3
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
      "contentVersion": 4
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
    expect(preview.items, hasLength(2));
    expect(preview.items.map((item) => item.partOfSpeech), [
      PartOfSpeech.noun,
      PartOfSpeech.verb,
    ]);
    expect(
      preview.items.every((item) => item.source.name == '사용자 직접 정리'),
      isTrue,
    );
  });
}
