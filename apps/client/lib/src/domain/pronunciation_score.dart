import 'dart:math';

import 'answer_normalizer.dart';
import 'language.dart';

class PronunciationAssessment {
  const PronunciationAssessment({
    required this.score,
    required this.normalizedExpected,
    required this.normalizedRecognized,
    this.tokenDiffs = const [],
  });

  final int score;
  final String normalizedExpected;
  final String normalizedRecognized;
  final List<PronunciationTokenDiff> tokenDiffs;

  bool get passed => score >= 75;

  String get feedback {
    if (score >= 95) return '아주 자연스럽게 인식됐어요';
    if (score >= 75) return '좋아요. 한 번 더 말하면 더 또렷해져요';
    if (score >= 45) return '천천히 끊어서 다시 말해 보세요';
    return '발음을 듣고 짧게 나눠 따라 해 보세요';
  }
}

enum PronunciationTokenDiffKind { match, missing, added, substituted }

class PronunciationTokenDiff {
  const PronunciationTokenDiff({
    required this.kind,
    this.expected,
    this.recognized,
  });

  final PronunciationTokenDiffKind kind;
  final String? expected;
  final String? recognized;

  String get spokenLabel => switch (kind) {
    PronunciationTokenDiffKind.match => '${expected ?? recognized} 일치',
    PronunciationTokenDiffKind.missing => '${expected ?? ''} 누락',
    PronunciationTokenDiffKind.added => '${recognized ?? ''} 추가',
    PronunciationTokenDiffKind.substituted =>
      '${expected ?? ''} 대신 ${recognized ?? ''}',
  };
}

class PronunciationScorer {
  const PronunciationScorer({this.normalizer = const AnswerNormalizer()});

  final AnswerNormalizer normalizer;

  PronunciationAssessment assess({
    required String expected,
    required String recognized,
    required LanguageTag language,
    Iterable<String> expectedTokens = const [],
  }) {
    const policy = AnswerPolicy(ignorePunctuation: true);
    final normalizedExpected = normalizer.normalize(
      expected,
      language: language,
      policy: policy,
    );
    final normalizedRecognized = normalizer.normalize(
      recognized,
      language: language,
      policy: policy,
    );
    if (normalizedExpected.isEmpty || normalizedRecognized.isEmpty) {
      return PronunciationAssessment(
        score: 0,
        normalizedExpected: normalizedExpected,
        normalizedRecognized: normalizedRecognized,
        tokenDiffs: _alignTokens(
          _tokensFor(normalizedExpected, language, explicit: expectedTokens),
          _tokensFor(normalizedRecognized, language),
        ),
      );
    }

    final expectedRunes = normalizedExpected.runes.toList(growable: false);
    final recognizedRunes = normalizedRecognized.runes.toList(growable: false);
    final distance = _levenshtein(expectedRunes, recognizedRunes);
    final longest = max(expectedRunes.length, recognizedRunes.length);
    final score = ((1 - distance / longest) * 100).round().clamp(0, 100);
    return PronunciationAssessment(
      score: score,
      normalizedExpected: normalizedExpected,
      normalizedRecognized: normalizedRecognized,
      tokenDiffs: _alignTokens(
        _tokensFor(normalizedExpected, language, explicit: expectedTokens),
        _tokensFor(normalizedRecognized, language),
      ),
    );
  }

  List<String> _tokensFor(
    String normalized,
    LanguageTag language, {
    Iterable<String> explicit = const [],
  }) {
    final provided = explicit
        .map(
          (token) => normalizer.normalize(
            token,
            language: language,
            policy: const AnswerPolicy(ignorePunctuation: true),
          ),
        )
        .where((token) => token.isNotEmpty)
        .take(200)
        .toList(growable: false);
    if (provided.isNotEmpty) return provided;
    if (language == LanguageTag.japanese ||
        language == LanguageTag.simplifiedChinese) {
      return normalized.runes
          .take(200)
          .map(String.fromCharCode)
          .toList(growable: false);
    }
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .take(200)
        .toList(growable: false);
  }

  List<PronunciationTokenDiff> _alignTokens(
    List<String> expected,
    List<String> recognized,
  ) {
    final rows = expected.length + 1;
    final columns = recognized.length + 1;
    final matrix = List.generate(
      rows,
      (row) => List<int>.filled(columns, 0),
      growable: false,
    );
    for (var row = 0; row < rows; row++) {
      matrix[row][0] = row;
    }
    for (var column = 0; column < columns; column++) {
      matrix[0][column] = column;
    }
    for (var row = 1; row < rows; row++) {
      for (var column = 1; column < columns; column++) {
        final substitution =
            matrix[row - 1][column - 1] +
            (expected[row - 1] == recognized[column - 1] ? 0 : 1);
        matrix[row][column] = min(
          substitution,
          min(matrix[row - 1][column] + 1, matrix[row][column - 1] + 1),
        );
      }
    }

    final reversed = <PronunciationTokenDiff>[];
    var row = expected.length;
    var column = recognized.length;
    while (row > 0 || column > 0) {
      if (row > 0 && column > 0) {
        final matches = expected[row - 1] == recognized[column - 1];
        final diagonal = matrix[row - 1][column - 1] + (matches ? 0 : 1);
        if (matrix[row][column] == diagonal) {
          reversed.add(
            PronunciationTokenDiff(
              kind: matches
                  ? PronunciationTokenDiffKind.match
                  : PronunciationTokenDiffKind.substituted,
              expected: expected[row - 1],
              recognized: recognized[column - 1],
            ),
          );
          row--;
          column--;
          continue;
        }
      }
      if (row > 0 && matrix[row][column] == matrix[row - 1][column] + 1) {
        reversed.add(
          PronunciationTokenDiff(
            kind: PronunciationTokenDiffKind.missing,
            expected: expected[row - 1],
          ),
        );
        row--;
      } else {
        reversed.add(
          PronunciationTokenDiff(
            kind: PronunciationTokenDiffKind.added,
            recognized: recognized[column - 1],
          ),
        );
        column--;
      }
    }
    return List.unmodifiable(reversed.reversed);
  }

  int _levenshtein(List<int> first, List<int> second) {
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;
    var previous = List<int>.generate(second.length + 1, (index) => index);
    for (var row = 1; row <= first.length; row++) {
      final current = List<int>.filled(second.length + 1, 0);
      current[0] = row;
      for (var column = 1; column <= second.length; column++) {
        final substitution = first[row - 1] == second[column - 1] ? 0 : 1;
        current[column] = min(
          min(current[column - 1] + 1, previous[column] + 1),
          previous[column - 1] + substitution,
        );
      }
      previous = current;
    }
    return previous.last;
  }
}
