import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_limits.dart';

void main() {
  test('parses the full 20,000-row CSV limit without dropping items', () {
    final csv = StringBuffer('type,term,meaning,part_of_speech\n');
    for (var index = 0; index < 20000; index++) {
      csv.writeln('word,term-$index,뜻-$index,noun');
    }

    final preview = const ContentImportParser().parseCsv(
      csv.toString(),
      defaultLanguage: LanguageTag.english,
    );

    expect(preview.entries, hasLength(20000));
    expect(preview.issues, isEmpty);
    expect(preview.duplicates, isEmpty);
    expect(preview.items.first.text, 'term-0');
    expect(preview.items.last.text, 'term-19999');
  });

  test(
    'rejects a file over the configured row limit with recovery guidance',
    () {
      const parser = ContentImportParser(limits: ImportLimits(maxRows: 2));

      expect(
        () => parser.parseCsv(
          'type,term,meaning\n'
          'word,one,하나\n'
          'word,two,둘\n'
          'word,three,셋',
          defaultLanguage: LanguageTag.english,
        ),
        throwsA(
          isA<ImportLimitException>()
              .having((error) => error.message, 'message', contains('2행 제한'))
              .having((error) => error.message, 'message', contains('나누어')),
        ),
      );
    },
  );

  test('rejects an oversized cell instead of retaining a partial preview', () {
    const parser = ContentImportParser(
      limits: ImportLimits(maxCellCharacters: 5),
    );

    expect(
      () => parser.parseJson(
        '[{"type":"word","term":"toolong","meaning":"뜻"}]',
        defaultLanguage: LanguageTag.english,
      ),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.message,
          'message',
          allOf(contains('term'), contains('5자 제한')),
        ),
      ),
    );
  });

  test('caps word and generated example items as one workload', () {
    const parser = ContentImportParser(
      limits: ImportLimits(maxGeneratedItems: 1),
    );

    expect(
      () => parser.parseCsv(
        'type,term,meaning,example,example_translation\n'
        'word,book,책,I read a book.,책을 읽어요.',
        defaultLanguage: LanguageTag.english,
      ),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.message,
          'message',
          contains('자동 생성 예문'),
        ),
      ),
    );
  });
}
