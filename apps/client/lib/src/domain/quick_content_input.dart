import 'package:unorm_dart/unorm_dart.dart' as unicode;

String normalizeQuickContentValue(String value) =>
    unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ');

class QuickContentNormalizationPreview {
  const QuickContentNormalizationPreview({
    required this.originalText,
    required this.normalizedText,
    required this.originalMeanings,
    required this.normalizedMeanings,
  });

  factory QuickContentNormalizationPreview.inspect({
    required String text,
    required Iterable<String> meanings,
  }) {
    final originalMeanings = meanings.toList(growable: false);
    return QuickContentNormalizationPreview(
      originalText: text,
      normalizedText: normalizeQuickContentValue(text),
      originalMeanings: originalMeanings,
      normalizedMeanings: [
        for (final meaning in originalMeanings)
          normalizeQuickContentValue(meaning),
      ],
    );
  }

  final String originalText;
  final String normalizedText;
  final List<String> originalMeanings;
  final List<String> normalizedMeanings;

  bool get hasChanges =>
      originalText != normalizedText ||
      !_sameValues(originalMeanings, normalizedMeanings);
}

bool _sameValues(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
