import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_column_mapping.dart';

void main() {
  test(
    'Korean columns are suggested without requiring the Sprache template',
    () {
      const mapper = ImportColumnMapper();
      final mapping = mapper.suggest(['내 문제', '정답', '한글 발음', '단어장']);
      expect(mapping['meaning'], '정답');
      expect(mapping['korean_pronunciation'], '한글 발음');
      expect(mapping['group'], '단어장');
      expect(mapper.missingRequired(mapping).map((field) => field.key), [
        'term',
      ]);
    },
  );

  test('explicit arbitrary column mapping parses through CSV importer', () {
    final preview = const ContentImportParser().parseCsv(
      '앞면,뒷면,내분류\nbonjour,안녕하세요,여행\n',
      defaultLanguage: LanguageTag.french,
      columnMapping: const {'term': '앞면', 'meaning': '뒷면', 'group': '내분류'},
    );
    expect(preview.items.single.text, 'bonjour');
    expect(preview.items.single.primaryTranslation, '안녕하세요');
  });
}
