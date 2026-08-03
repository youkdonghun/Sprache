import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/study_data_xlsx_exporter.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/xlsx_import_reader.dart';

void main() {
  final item = LearningItem(
    id: 'sheet-word',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'sheet',
    translations: const ['시트'],
    acceptedAnswers: const ['시트'],
  );

  test('reader exposes the logical workbook sheet name', () {
    final bytes = const StudyDataXlsxExporter().encode([item]);

    final sheets = const XlsxImportReader().read(bytes);

    expect(sheets.single.name, '개인 콘텐츠');
    expect(sheets.single.rows, isNotEmpty);
  });

  test('parser imports only the explicitly selected sheet', () {
    final bytes = const StudyDataXlsxExporter().encode([item]);

    final preview = const ContentImportParser().parseExcel(
      bytes,
      defaultLanguage: LanguageTag.english,
      sheetName: '개인 콘텐츠',
    );

    expect(preview.items.any((value) => value.id == 'sheet-word'), isTrue);
    expect(
      () => const ContentImportParser().parseExcel(
        bytes,
        defaultLanguage: LanguageTag.english,
        sheetName: '없는 시트',
      ),
      throwsFormatException,
    );
  });
}
