import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/quick_content_input.dart';

void main() {
  test('normalization preview exposes NFKC and whitespace changes', () {
    final preview = QuickContentNormalizationPreview.inspect(
      text: '  ＡＢＣ   test  ',
      meanings: const ['  뜻   하나  '],
    );

    expect(preview.hasChanges, isTrue);
    expect(preview.normalizedText, 'ABC test');
    expect(preview.normalizedMeanings, const ['뜻 하나']);
  });

  test('normalization preview stays quiet for canonical values', () {
    final preview = QuickContentNormalizationPreview.inspect(
      text: 'already clean',
      meanings: const ['정리됨'],
    );

    expect(preview.hasChanges, isFalse);
  });
}
