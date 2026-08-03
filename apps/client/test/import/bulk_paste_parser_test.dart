import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/import/bulk_paste_parser.dart';
import 'package:sprache/src/import/content_import_parser.dart';

void main() {
  test('supports every delimiter and reports a mixed detected format', () {
    final quick = const BulkPasteParser().parse(
      'hello\t안녕\n'
      'morning,아침\n'
      'thanks;고마워\n'
      'water: 물\n'
      'apple | 사과\n'
      'good night - 안녕히 주무세요',
    );

    expect(quick.entryCount, 6);
    expect(quick.detectedFormat, BulkPasteFormat.mixed);
    expect(quick.issues, isEmpty);
    expect(quick.entries.map((entry) => (entry.term, entry.meaning)), [
      ('hello', '안녕'),
      ('morning', '아침'),
      ('thanks', '고마워'),
      ('water', '물'),
      ('apple', '사과'),
      ('good night', '안녕히 주무세요'),
    ]);

    final preview = const ContentImportParser().parseCsv(
      quick.csvText,
      defaultLanguage: LanguageTag.english,
    );
    expect(preview.items.map((item) => item.text), [
      'hello',
      'morning',
      'thanks',
      'water',
      'apple',
      'good night',
    ]);
  });

  test('quoted delimiters stay in their field', () {
    final result = const BulkPasteParser().parse(
      '"good, morning","좋은, 아침"\n'
      '"A | B" | "A 또는 B"',
    );

    expect(result.detectedFormat, BulkPasteFormat.mixed);
    expect(result.entries, hasLength(2));
    expect(result.entries.first.term, 'good, morning');
    expect(result.entries.first.meaning, '좋은, 아침');
    expect(result.entries.last.term, 'A | B');
    expect(result.entries.last.meaning, 'A 또는 B');
  });

  test('plain lines are paired without mistaking occasional punctuation', () {
    final result = const BulkPasteParser().parse(
      'hello, friend\n안녕 친구\n12:30\n열두 시 반\norphan',
    );

    expect(result.detectedFormat, BulkPasteFormat.pairedLines);
    expect(result.entryCount, 2);
    expect(result.entries.first.term, 'hello, friend');
    expect(result.entries.last.term, '12:30');
    expect(result.issues.single.line, 5);
    expect(result.issues.single.kind, BulkPasteIssueKind.unmatchedLine);
    expect(result.issues.single.source, 'orphan');
  });

  test('deduplicates normalized pairs but keeps distinct meanings', () {
    final result = const BulkPasteParser().parse(
      'Ａｐｐｌｅ | 사  과\n'
      ' apple | 사 과 \n'
      'APPLE | 과일',
    );

    expect(result.entryCount, 2);
    expect(result.duplicateCount, 1);
    expect(result.entries.map((entry) => entry.meaning), ['사  과', '과일']);
    expect(result.issues.single.kind, BulkPasteIssueKind.duplicate);
    expect(result.issues.single.line, 2);
    expect(result.issues.single.message, contains('1행'));
  });

  test('reports detailed issues for malformed delimited rows', () {
    final result = const BulkPasteParser().parse(
      'hello\t안녕\n'
      'delimiter missing\n'
      '\t뜻만 있음\n'
      '"quote,not closed\n'
      'thanks;고마워',
    );

    expect(result.detectedFormat, BulkPasteFormat.mixed);
    expect(result.entryCount, 2);
    expect(result.issues.map((issue) => (issue.line, issue.kind)), [
      (2, BulkPasteIssueKind.missingDelimiter),
      (3, BulkPasteIssueKind.missingTerm),
      (4, BulkPasteIssueKind.malformedQuotes),
    ]);
    expect(result.issues.every((issue) => issue.source.isNotEmpty), isTrue);
  });

  test('paste accepts 100 candidate entries and rejects the 101st', () {
    final accepted = List.generate(
      100,
      (index) => 'q$index\ta$index',
    ).join('\n');
    final rejected = List.generate(
      101,
      (index) => 'q$index\ta$index',
    ).join('\n');

    expect(const BulkPasteParser().parse(accepted).entryCount, 100);
    expect(
      () => const BulkPasteParser().parse(rejected),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('100'),
        ),
      ),
    );
  });
}
