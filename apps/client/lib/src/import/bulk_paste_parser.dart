import 'package:csv/csv.dart';

class BulkPasteIssue {
  const BulkPasteIssue({required this.line, required this.message});

  final int line;
  final String message;
}

class BulkPasteResult {
  const BulkPasteResult({
    required this.csvText,
    required this.entryCount,
    required this.issues,
  });

  final String csvText;
  final int entryCount;
  final List<BulkPasteIssue> issues;

  bool get canImport => entryCount > 0;
}

/// Converts quick spreadsheet-like text into the regular CSV import pipeline.
///
/// A row can use a tab, comma or semicolon. When no delimiter is present,
/// consecutive non-empty lines are treated as problem/answer pairs.
class BulkPasteParser {
  const BulkPasteParser({this.maxEntries = 100});

  final int maxEntries;

  BulkPasteResult parse(String input) {
    final lines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final nonEmpty = <({int line, String value})>[
      for (final (index, raw) in lines.indexed)
        if (raw.trim().isNotEmpty) (line: index + 1, value: raw.trim()),
    ];
    final hasDelimitedRows = nonEmpty.any(
      (line) =>
          line.value.contains('\t') ||
          line.value.contains(',') ||
          line.value.contains(';'),
    );
    final candidateCount = hasDelimitedRows
        ? nonEmpty.length
        : (nonEmpty.length / 2).ceil();
    if (candidateCount > maxEntries) {
      throw FormatException('한 번에 최대 $maxEntries개까지 붙여넣을 수 있습니다.');
    }
    final rows = <List<String>>[
      const ['term', 'meaning'],
    ];
    final issues = <BulkPasteIssue>[];

    void addPair(int line, String term, String meaning) {
      if (rows.length - 1 >= maxEntries) {
        throw FormatException('한 번에 최대 $maxEntries개까지 붙여넣을 수 있습니다.');
      }
      final normalizedTerm = term.trim();
      final normalizedMeaning = meaning.trim();
      if (normalizedTerm.isEmpty || normalizedMeaning.isEmpty) {
        issues.add(BulkPasteIssue(line: line, message: '문제와 정답을 모두 입력해 주세요.'));
        return;
      }
      rows.add([normalizedTerm, normalizedMeaning]);
    }

    if (hasDelimitedRows) {
      for (final entry in nonEmpty) {
        final delimiter = entry.value.contains('\t')
            ? '\t'
            : entry.value.contains(';')
            ? ';'
            : ',';
        try {
          final parsed = Csv(
            fieldDelimiter: delimiter,
            autoDetect: false,
            dynamicTyping: false,
          ).decode(entry.value).first;
          if (parsed.length < 2) {
            issues.add(
              BulkPasteIssue(
                line: entry.line,
                message: '문제와 정답 사이에 탭, 쉼표 또는 세미콜론을 넣어 주세요.',
              ),
            );
            continue;
          }
          addPair(
            entry.line,
            parsed.first.toString(),
            parsed.skip(1).map((value) => value.toString()).join(delimiter),
          );
        } on FormatException catch (error) {
          issues.add(
            BulkPasteIssue(line: entry.line, message: error.message.toString()),
          );
        }
      }
    } else {
      for (var index = 0; index < nonEmpty.length; index += 2) {
        if (index + 1 >= nonEmpty.length) {
          issues.add(
            BulkPasteIssue(
              line: nonEmpty[index].line,
              message: '마지막 문제에 대응하는 정답이 없습니다.',
            ),
          );
          break;
        }
        addPair(
          nonEmpty[index].line,
          nonEmpty[index].value,
          nonEmpty[index + 1].value,
        );
      }
    }

    return BulkPasteResult(
      csvText: Csv().encode(rows),
      entryCount: rows.length - 1,
      issues: List.unmodifiable(issues),
    );
  }
}
