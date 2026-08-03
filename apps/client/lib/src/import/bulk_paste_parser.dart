import 'package:csv/csv.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

enum BulkPasteFormat {
  unknown,
  pairedLines,
  tab,
  comma,
  semicolon,
  colon,
  pipe,
  dash,
  mixed,
}

extension BulkPasteFormatLabel on BulkPasteFormat {
  String get label => switch (this) {
    BulkPasteFormat.unknown => '미감지',
    BulkPasteFormat.pairedLines => '두 줄씩 문제·정답',
    BulkPasteFormat.tab => '탭',
    BulkPasteFormat.comma => '쉼표',
    BulkPasteFormat.semicolon => '세미콜론',
    BulkPasteFormat.colon => '콜론',
    BulkPasteFormat.pipe => '파이프',
    BulkPasteFormat.dash => '대시',
    BulkPasteFormat.mixed => '혼합 구분자',
  };
}

enum BulkPasteIssueKind {
  missingDelimiter,
  missingTerm,
  missingMeaning,
  unmatchedLine,
  malformedQuotes,
  duplicate,
}

class BulkPasteIssue {
  const BulkPasteIssue({
    required this.line,
    required this.message,
    this.kind = BulkPasteIssueKind.missingDelimiter,
    this.source = '',
  });

  final int line;
  final String message;
  final BulkPasteIssueKind kind;
  final String source;
}

class BulkPasteEntry {
  const BulkPasteEntry({
    required this.line,
    required this.term,
    required this.meaning,
  });

  final int line;
  final String term;
  final String meaning;
}

class BulkPasteResult {
  const BulkPasteResult({
    required this.csvText,
    required this.entries,
    required this.issues,
    required this.detectedFormat,
  });

  final String csvText;
  final List<BulkPasteEntry> entries;
  final List<BulkPasteIssue> issues;
  final BulkPasteFormat detectedFormat;

  int get entryCount => entries.length;
  int get duplicateCount => issues
      .where((issue) => issue.kind == BulkPasteIssueKind.duplicate)
      .length;
  int get problemCount => issues.length - duplicateCount;
  bool get canImport => entries.isNotEmpty;
}

/// Converts quick spreadsheet-like text into the regular CSV import pipeline.
///
/// Delimited rows may use a tab, comma, semicolon, colon, pipe, or a spaced
/// dash. When delimiters do not consistently describe the input, consecutive
/// non-empty lines are treated as problem/answer pairs instead. The parser
/// never reads the clipboard itself.
class BulkPasteParser {
  const BulkPasteParser({this.maxEntries = 100});

  final int maxEntries;

  BulkPasteResult parse(String input) {
    final rawLines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final lines = <_SourceLine>[
      for (final (index, raw) in rawLines.indexed)
        if (raw.trim().isNotEmpty) _SourceLine(line: index + 1, value: raw),
    ];

    if (lines.isEmpty) {
      return const BulkPasteResult(
        csvText: 'term,meaning\r\n',
        entries: [],
        issues: [],
        detectedFormat: BulkPasteFormat.unknown,
      );
    }

    final detectedByLine = <int, BulkPasteFormat>{};
    for (final line in lines) {
      if (!_hasBalancedQuotes(line.value)) continue;
      final format = _detectFormat(line.value);
      if (format != null) detectedByLine[line.line] = format;
    }
    final delimitedMode = lines.length == 1
        ? detectedByLine.isNotEmpty
        : detectedByLine.length * 2 > lines.length;
    final candidateCount = delimitedMode
        ? lines.length
        : (lines.length / 2).ceil();
    _checkEntryLimit(candidateCount);

    final entries = <BulkPasteEntry>[];
    final issues = <BulkPasteIssue>[];
    final firstLineByPair = <String, int>{};
    final usedFormats = <BulkPasteFormat>{};

    void addPair(int line, String rawTerm, String rawMeaning, String source) {
      final term = _decodeCell(rawTerm);
      final meaning = _decodeCell(rawMeaning);
      if (term.isEmpty) {
        issues.add(
          BulkPasteIssue(
            line: line,
            kind: BulkPasteIssueKind.missingTerm,
            source: _issueSource(source),
            message: '$line행의 문제(단어)가 비어 있습니다.',
          ),
        );
        return;
      }
      if (meaning.isEmpty) {
        issues.add(
          BulkPasteIssue(
            line: line,
            kind: BulkPasteIssueKind.missingMeaning,
            source: _issueSource(source),
            message: '$line행의 정답(뜻)이 비어 있습니다.',
          ),
        );
        return;
      }
      _checkEntryLimit(entries.length + 1);
      final pairKey = '${_normalizedKey(term)}\u0000${_normalizedKey(meaning)}';
      final firstLine = firstLineByPair[pairKey];
      if (firstLine != null) {
        issues.add(
          BulkPasteIssue(
            line: line,
            kind: BulkPasteIssueKind.duplicate,
            source: _issueSource(source),
            message: '$line행은 $firstLine행과 같은 문제·정답이라 건너뛰었습니다.',
          ),
        );
        return;
      }
      firstLineByPair[pairKey] = line;
      entries.add(BulkPasteEntry(line: line, term: term, meaning: meaning));
    }

    if (delimitedMode) {
      for (final line in lines) {
        if (!_hasBalancedQuotes(line.value)) {
          issues.add(
            BulkPasteIssue(
              line: line.line,
              kind: BulkPasteIssueKind.malformedQuotes,
              source: _issueSource(line.value),
              message: '${line.line}행의 큰따옴표가 닫히지 않았습니다.',
            ),
          );
          continue;
        }
        final format = detectedByLine[line.line];
        if (format == null) {
          issues.add(
            BulkPasteIssue(
              line: line.line,
              kind: BulkPasteIssueKind.missingDelimiter,
              source: _issueSource(line.value),
              message:
                  '${line.line}행에서 구분자를 찾지 못했습니다. '
                  '탭, 쉼표, 세미콜론, 콜론, 파이프 또는 양쪽을 띄운 대시를 사용하세요.',
            ),
          );
          continue;
        }
        final split = _splitDelimitedLine(line.value, format);
        if (split == null) {
          issues.add(
            BulkPasteIssue(
              line: line.line,
              kind: BulkPasteIssueKind.missingDelimiter,
              source: _issueSource(line.value),
              message: '${line.line}행의 문제와 정답을 나누지 못했습니다.',
            ),
          );
          continue;
        }
        usedFormats.add(format);
        addPair(line.line, split.term, split.meaning, line.value);
      }
    } else {
      for (var index = 0; index < lines.length; index += 2) {
        final termLine = lines[index];
        if (index + 1 >= lines.length) {
          issues.add(
            BulkPasteIssue(
              line: termLine.line,
              kind: BulkPasteIssueKind.unmatchedLine,
              source: _issueSource(termLine.value),
              message: '${termLine.line}행 문제에 대응하는 다음 줄 정답이 없습니다.',
            ),
          );
          break;
        }
        addPair(
          termLine.line,
          termLine.value,
          lines[index + 1].value,
          '${termLine.value} / ${lines[index + 1].value}',
        );
      }
    }

    final detectedFormat = delimitedMode
        ? switch (usedFormats.length) {
            0 => BulkPasteFormat.unknown,
            1 => usedFormats.single,
            _ => BulkPasteFormat.mixed,
          }
        : BulkPasteFormat.pairedLines;
    final rows = <List<String>>[
      const ['term', 'meaning'],
      for (final entry in entries) [entry.term, entry.meaning],
    ];
    return BulkPasteResult(
      csvText: Csv().encode(rows),
      entries: List.unmodifiable(entries),
      issues: List.unmodifiable(issues),
      detectedFormat: detectedFormat,
    );
  }

  void _checkEntryLimit(int count) {
    if (count > maxEntries) {
      throw FormatException('한 번에 최대 $maxEntries개까지 붙여넣을 수 있습니다.');
    }
  }

  static BulkPasteFormat? _detectFormat(String value) {
    for (final candidate in const [
      BulkPasteFormat.tab,
      BulkPasteFormat.pipe,
      BulkPasteFormat.semicolon,
      BulkPasteFormat.comma,
      BulkPasteFormat.colon,
      BulkPasteFormat.dash,
    ]) {
      if (_delimiterIndex(value, candidate) != null) return candidate;
    }
    return null;
  }

  static ({String term, String meaning})? _splitDelimitedLine(
    String value,
    BulkPasteFormat format,
  ) {
    final index = _delimiterIndex(value, format);
    if (index == null) return null;
    return (
      term: value.substring(0, index),
      meaning: value.substring(index + 1),
    );
  }

  static int? _delimiterIndex(String value, BulkPasteFormat format) {
    if (format == BulkPasteFormat.dash) return _spacedDashIndex(value);
    final delimiter = switch (format) {
      BulkPasteFormat.tab => '\t',
      BulkPasteFormat.comma => ',',
      BulkPasteFormat.semicolon => ';',
      BulkPasteFormat.colon => ':',
      BulkPasteFormat.pipe => '|',
      _ => null,
    };
    if (delimiter == null) return null;

    var quoted = false;
    for (var index = 0; index < value.length; index++) {
      final character = value[index];
      if (character == '"') {
        if (quoted && index + 1 < value.length && value[index + 1] == '"') {
          index++;
          continue;
        }
        quoted = !quoted;
        continue;
      }
      if (!quoted && character == delimiter) {
        if (format == BulkPasteFormat.colon &&
            _isNonSeparatorColon(value, index)) {
          continue;
        }
        return index;
      }
    }
    return null;
  }

  static int? _spacedDashIndex(String value) {
    var quoted = false;
    for (var index = 0; index < value.length; index++) {
      final character = value[index];
      if (character == '"') {
        if (quoted && index + 1 < value.length && value[index + 1] == '"') {
          index++;
          continue;
        }
        quoted = !quoted;
        continue;
      }
      if (quoted ||
          (character != '-' && character != '–' && character != '—')) {
        continue;
      }
      final hasWhitespaceBefore = index > 0 && _isWhitespace(value[index - 1]);
      final hasWhitespaceAfter =
          index + 1 < value.length && _isWhitespace(value[index + 1]);
      if (hasWhitespaceBefore && hasWhitespaceAfter) return index;
    }
    return null;
  }

  static bool _isNonSeparatorColon(String value, int index) {
    final followedBySlashes =
        index + 2 < value.length &&
        value.substring(index + 1, index + 3) == '//';
    final betweenDigits =
        index > 0 &&
        index + 1 < value.length &&
        _isDigit(value[index - 1]) &&
        _isDigit(value[index + 1]);
    return followedBySlashes || betweenDigits;
  }

  static bool _hasBalancedQuotes(String value) {
    var quoted = false;
    for (var index = 0; index < value.length; index++) {
      if (value[index] != '"') continue;
      if (quoted && index + 1 < value.length && value[index + 1] == '"') {
        index++;
        continue;
      }
      quoted = !quoted;
    }
    return !quoted;
  }

  static String _decodeCell(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed
          .substring(1, trimmed.length - 1)
          .replaceAll('""', '"')
          .trim();
    }
    return trimmed;
  }

  static String _normalizedKey(String value) =>
      unicode.nfkc(value).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _issueSource(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return compact.length <= 80 ? compact : '${compact.substring(0, 77)}...';
  }

  static bool _isDigit(String value) =>
      value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;

  static bool _isWhitespace(String value) => RegExp(r'\s').hasMatch(value);
}

class _SourceLine {
  const _SourceLine({required this.line, required this.value});

  final int line;
  final String value;
}
