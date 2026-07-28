import 'dart:math';

import 'answer_normalizer.dart';
import 'language.dart';

class PronunciationAssessment {
  const PronunciationAssessment({
    required this.score,
    required this.normalizedExpected,
    required this.normalizedRecognized,
  });

  final int score;
  final String normalizedExpected;
  final String normalizedRecognized;

  bool get passed => score >= 75;

  String get feedback {
    if (score >= 95) return '아주 자연스럽게 인식됐어요';
    if (score >= 75) return '좋아요. 한 번 더 말하면 더 또렷해져요';
    if (score >= 45) return '천천히 끊어서 다시 말해 보세요';
    return '발음을 듣고 짧게 나눠 따라 해 보세요';
  }
}

class PronunciationScorer {
  const PronunciationScorer({this.normalizer = const AnswerNormalizer()});

  final AnswerNormalizer normalizer;

  PronunciationAssessment assess({
    required String expected,
    required String recognized,
    required LanguageTag language,
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
    );
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
