import 'dart:convert';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/import/text_import_decoder.dart';

void main() {
  const decoder = TextImportDecoder();

  test('detects UTF-8 BOM and semicolon while preserving Korean text', () {
    final bytes = <int>[
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('term;meaning\nhello;안녕'),
    ];

    final inspected = decoder.inspect(bytes);

    expect(inspected.encoding, TextImportEncoding.utf8);
    expect(inspected.delimiter, TextImportDelimiter.semicolon);
    expect(inspected.hadBom, isTrue);
    expect(inspected.headers, ['term', 'meaning']);
    expect(inspected.samples.single, ['hello', '안녕']);
  });

  test('detects UTF-16 little endian BOM and tab delimiter', () {
    final units = 'term\tmeaning\nwater\t물'.codeUnits;
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in units) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }

    final inspected = decoder.inspect(bytes);

    expect(inspected.encoding, TextImportEncoding.utf16Le);
    expect(inspected.delimiter, TextImportDelimiter.tab);
    expect(inspected.samples.single.last, '물');
  });

  test('falls back to strict CP949 and supports manual delimiter override', () {
    final bytes = cp949.encode('term,meaning\n사과,apple');

    final inspected = decoder.inspect(
      bytes,
      encoding: TextImportEncoding.cp949,
      delimiter: TextImportDelimiter.comma,
    );

    expect(inspected.encoding, TextImportEncoding.cp949);
    expect(inspected.samples.single, ['사과', 'apple']);
  });

  test('rejects malformed UTF-16 instead of replacing data', () {
    expect(
      () => decoder.inspect(const [
        0xFF,
        0xFE,
        0x41,
      ], encoding: TextImportEncoding.utf16Le),
      throwsFormatException,
    );
  });
}
