import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/import/bulk_paste_parser.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  test('tab, comma and semicolon rows enter the regular import pipeline', () {
    final quick = const BulkPasteParser().parse(
      'hello\t안녕\n'
      '"good, morning",좋은 아침\n'
      'thanks;고마워',
    );
    expect(quick.entryCount, 3);
    expect(quick.issues, isEmpty);

    final preview = const ContentImportParser().parseCsv(
      quick.csvText,
      defaultLanguage: LanguageTag.english,
    );
    expect(preview.items.map((item) => item.text), [
      'hello',
      'good, morning',
      'thanks',
    ]);
  });

  test('plain lines are paired and an unmatched line is reported', () {
    final result = const BulkPasteParser().parse(
      'hello\n안녕\nthanks\n고마워\norphan',
    );
    expect(result.entryCount, 2);
    expect(result.issues.single.line, 5);
  });

  test('paste is limited to 100 entries', () {
    final input = List.generate(101, (index) => 'q$index\ta$index').join('\n');
    expect(
      () => const BulkPasteParser().parse(input),
      throwsA(isA<FormatException>()),
    );
  });
}
