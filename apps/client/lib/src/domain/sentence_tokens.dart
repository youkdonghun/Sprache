import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'language.dart';

enum SentenceTokenIssue { tooFew, tooMany, mismatch }

class SentenceTokenInspection {
  const SentenceTokenInspection({required this.tokens, required this.issue});

  final List<String> tokens;
  final SentenceTokenIssue? issue;

  bool get canSave => issue == null;

  bool get enablesSentenceExercises => canSave && tokens.length >= 2;

  String? get message => switch (issue) {
    SentenceTokenIssue.tooFew => '문장 배열 토큰은 2개 이상 입력하거나 모두 지우세요.',
    SentenceTokenIssue.tooMany => '문장 토큰은 최대 200개까지 저장할 수 있어요.',
    SentenceTokenIssue.mismatch => '토큰을 순서대로 합친 내용이 학습 문장과 다릅니다.',
    null => null,
  };
}

/// Creates a token suggestion only after an explicit user action.
///
/// Saving content must never call this parser implicitly. Users remain the
/// source of truth for sentence-order boundaries, especially for Japanese and
/// Chinese where automatic segmentation is ambiguous.
class SentenceTokenParser {
  const SentenceTokenParser();

  List<String> suggest(String source, {required LanguageTag language}) {
    final normalized = unicode
        .nfkc(source)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const [];

    final whitespaceParts = normalized
        .split(RegExp(r'\s+'))
        .map(_normalizeToken)
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (LanguageProfile.of(language).usesSpaces || whitespaceParts.length > 1) {
      return List.unmodifiable(whitespaceParts);
    }

    return List.unmodifiable(
      normalized.runes
          .map(String.fromCharCode)
          .where((token) => token.trim().isNotEmpty),
    );
  }
}

class SentenceTokenValidator {
  const SentenceTokenValidator();

  SentenceTokenInspection inspect({
    required String sentence,
    required Iterable<String> tokens,
  }) {
    final normalizedTokens = List<String>.unmodifiable(
      tokens.map(_normalizeToken).where((token) => token.isNotEmpty),
    );
    if (normalizedTokens.isEmpty) {
      return const SentenceTokenInspection(tokens: [], issue: null);
    }
    if (normalizedTokens.length < 2) {
      return SentenceTokenInspection(
        tokens: normalizedTokens,
        issue: SentenceTokenIssue.tooFew,
      );
    }
    if (normalizedTokens.length > 200) {
      return SentenceTokenInspection(
        tokens: normalizedTokens,
        issue: SentenceTokenIssue.tooMany,
      );
    }
    if (_comparable(normalizedTokens.join()) != _comparable(sentence)) {
      return SentenceTokenInspection(
        tokens: normalizedTokens,
        issue: SentenceTokenIssue.mismatch,
      );
    }
    return SentenceTokenInspection(tokens: normalizedTokens, issue: null);
  }
}

String _normalizeToken(String value) =>
    unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ');

String _comparable(String value) =>
    unicode.nfkc(value).toLowerCase().replaceAll(RegExp(r'\s+'), '');
