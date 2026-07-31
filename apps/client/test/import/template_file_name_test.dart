import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/import/template_file_name.dart';

void main() {
  test('upload template filename uses Korean label and YYYYMMDD date', () {
    expect(
      buildUploadTemplateFileName(DateTime(2026, 7, 30)),
      'Sprache 업로드 템플릿_20260730.xlsx',
    );
  });
}
