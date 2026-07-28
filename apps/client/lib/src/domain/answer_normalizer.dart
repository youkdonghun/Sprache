import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'language.dart';

class AnswerPolicy {
  const AnswerPolicy({
    this.caseSensitive = false,
    this.ignorePunctuation = true,
    this.allowTypo = false,
  });

  final bool caseSensitive;
  final bool ignorePunctuation;
  final bool allowTypo;
}

class AnswerNormalizer {
  const AnswerNormalizer();

  String normalize(
    String value, {
    required LanguageTag language,
    AnswerPolicy policy = const AnswerPolicy(),
  }) {
    var normalized = unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!policy.caseSensitive) {
      normalized = normalized.toLowerCase();
    }
    if (policy.ignorePunctuation) {
      normalized = normalized.replaceAll(
        RegExp(r'''[.,!?;:'"“”‘’。、！？；：]'''),
        '',
      );
    }
    return normalized.trim();
  }

  bool matches({
    required String input,
    required Iterable<String> acceptedAnswers,
    required LanguageTag language,
    AnswerPolicy policy = const AnswerPolicy(),
  }) {
    final normalizedInput = normalize(
      input,
      language: language,
      policy: policy,
    );
    for (final answer in acceptedAnswers) {
      final normalizedAnswer = normalize(
        answer,
        language: language,
        policy: policy,
      );
      if (normalizedInput == normalizedAnswer) {
        return true;
      }
      if (policy.allowTypo &&
          normalizedAnswer.length >= 6 &&
          _damerauLevenshtein(normalizedInput, normalizedAnswer) <= 1) {
        return true;
      }
    }
    return false;
  }

  int _damerauLevenshtein(String first, String second) {
    if (first == second) return 0;
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;

    var previousPrevious = List<int>.generate(
      second.length + 1,
      (index) => index,
    );
    var previous = List<int>.generate(second.length + 1, (index) => index);
    for (var row = 1; row <= first.length; row++) {
      final current = List<int>.filled(second.length + 1, 0);
      current[0] = row;
      for (var column = 1; column <= second.length; column++) {
        final substitution = first[row - 1] == second[column - 1] ? 0 : 1;
        var distance = [
          current[column - 1] + 1,
          previous[column] + 1,
          previous[column - 1] + substitution,
        ].reduce((left, right) => left < right ? left : right);
        if (row > 1 &&
            column > 1 &&
            first[row - 1] == second[column - 2] &&
            first[row - 2] == second[column - 1]) {
          final transposition = previousPrevious[column - 2] + 1;
          if (transposition < distance) {
            distance = transposition;
          }
        }
        current[column] = distance;
      }
      previousPrevious = previous;
      previous = current;
    }
    return previous.last;
  }
}
