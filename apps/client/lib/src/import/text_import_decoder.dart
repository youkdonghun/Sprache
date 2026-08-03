import 'dart:convert';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:csv/csv.dart';

enum TextImportEncoding { auto, utf8, utf16Le, utf16Be, cp949 }

extension TextImportEncodingLabel on TextImportEncoding {
  String get label => switch (this) {
    TextImportEncoding.auto => '자동 감지',
    TextImportEncoding.utf8 => 'UTF-8',
    TextImportEncoding.utf16Le => 'UTF-16 LE',
    TextImportEncoding.utf16Be => 'UTF-16 BE',
    TextImportEncoding.cp949 => 'CP949 · EUC-KR',
  };
}

enum TextImportDelimiter { auto, comma, tab, semicolon }

extension TextImportDelimiterLabel on TextImportDelimiter {
  String get value => switch (this) {
    TextImportDelimiter.auto => '',
    TextImportDelimiter.comma => ',',
    TextImportDelimiter.tab => '\t',
    TextImportDelimiter.semicolon => ';',
  };

  String get label => switch (this) {
    TextImportDelimiter.auto => '자동 감지',
    TextImportDelimiter.comma => '쉼표 (,)',
    TextImportDelimiter.tab => '탭 (TSV)',
    TextImportDelimiter.semicolon => '세미콜론 (;)',
  };
}

class TextImportInspection {
  const TextImportInspection({
    required this.text,
    required this.encoding,
    required this.delimiter,
    required this.rows,
    required this.hadBom,
  });

  final String text;
  final TextImportEncoding encoding;
  final TextImportDelimiter delimiter;
  final List<List<String>> rows;
  final bool hadBom;

  List<String> get headers => rows.isEmpty ? const [] : rows.first;
  List<List<String>> get samples =>
      rows.skip(1).take(3).toList(growable: false);
}

/// Decodes spreadsheet text without uploading it or replacing malformed bytes.
///
/// Automatic detection is deliberately conservative: BOM wins, valid UTF-8 is
/// preferred, and CP949 is only attempted after strict UTF-8 fails. The caller
/// can always re-run [inspect] with an explicit encoding and delimiter.
class TextImportDecoder {
  const TextImportDecoder();

  TextImportInspection inspect(
    List<int> bytes, {
    TextImportEncoding encoding = TextImportEncoding.auto,
    TextImportDelimiter delimiter = TextImportDelimiter.auto,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('빈 텍스트 파일은 가져올 수 없습니다.');
    }
    final detectedEncoding = encoding == TextImportEncoding.auto
        ? _detectEncoding(bytes)
        : encoding;
    final decoded = _decode(bytes, detectedEncoding);
    final normalized = decoded.text.replaceFirst('\uFEFF', '');
    final detectedDelimiter = delimiter == TextImportDelimiter.auto
        ? _detectDelimiter(normalized)
        : delimiter;
    final parsed = Csv(
      fieldDelimiter: detectedDelimiter.value,
      autoDetect: false,
      dynamicTyping: false,
    ).decode(normalized);
    final rows = parsed
        .take(4)
        .map(
          (row) => row
              .map((value) => value.toString().trim())
              .toList(growable: false),
        )
        .toList(growable: false);
    return TextImportInspection(
      text: normalized,
      encoding: detectedEncoding,
      delimiter: detectedDelimiter,
      rows: rows,
      hadBom: decoded.hadBom,
    );
  }

  TextImportEncoding _detectEncoding(List<int> bytes) {
    if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
      return TextImportEncoding.utf8;
    }
    if (_startsWith(bytes, const [0xFF, 0xFE])) {
      return TextImportEncoding.utf16Le;
    }
    if (_startsWith(bytes, const [0xFE, 0xFF])) {
      return TextImportEncoding.utf16Be;
    }
    try {
      utf8.decode(bytes, allowMalformed: false);
      return TextImportEncoding.utf8;
    } on FormatException {
      try {
        cp949.decode(bytes, allowInvalid: false);
        return TextImportEncoding.cp949;
      } on FormatException {
        throw const FormatException(
          '문자 인코딩을 자동 판별하지 못했습니다. UTF-8·UTF-16·CP949 중 하나를 선택해 주세요.',
        );
      }
    }
  }

  ({String text, bool hadBom}) _decode(
    List<int> bytes,
    TextImportEncoding encoding,
  ) {
    return switch (encoding) {
      TextImportEncoding.auto => throw const FormatException('인코딩을 선택해 주세요.'),
      TextImportEncoding.utf8 => (
        text: utf8.decode(
          _skipBom(bytes, const [0xEF, 0xBB, 0xBF]),
          allowMalformed: false,
        ),
        hadBom: _startsWith(bytes, const [0xEF, 0xBB, 0xBF]),
      ),
      TextImportEncoding.utf16Le => (
        text: _decodeUtf16(
          _skipBom(bytes, const [0xFF, 0xFE]),
          littleEndian: true,
        ),
        hadBom: _startsWith(bytes, const [0xFF, 0xFE]),
      ),
      TextImportEncoding.utf16Be => (
        text: _decodeUtf16(
          _skipBom(bytes, const [0xFE, 0xFF]),
          littleEndian: false,
        ),
        hadBom: _startsWith(bytes, const [0xFE, 0xFF]),
      ),
      TextImportEncoding.cp949 => (
        text: cp949.decode(bytes, allowInvalid: false),
        hadBom: false,
      ),
    };
  }

  TextImportDelimiter _detectDelimiter(String text) {
    TextImportDelimiter? best;
    var bestScore = -1;
    for (final candidate in const [
      TextImportDelimiter.tab,
      TextImportDelimiter.comma,
      TextImportDelimiter.semicolon,
    ]) {
      try {
        final rows = Csv(
          fieldDelimiter: candidate.value,
          autoDetect: false,
          dynamicTyping: false,
        ).decode(text).take(6).toList(growable: false);
        if (rows.isEmpty) continue;
        final widths = rows
            .where(
              (row) => row.any((value) => value.toString().trim().isNotEmpty),
            )
            .map((row) => row.length)
            .toList(growable: false);
        if (widths.isEmpty) continue;
        final width = widths.first;
        final consistent = widths.where((value) => value == width).length;
        final score = width > 1 ? width * 10 + consistent : 0;
        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        }
      } on FormatException {
        // Try the next supported delimiter.
      }
    }
    if (best == null || bestScore <= 0) {
      throw const FormatException('쉼표·탭·세미콜론 구분자를 찾지 못했습니다.');
    }
    return best;
  }

  String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    if (bytes.length.isOdd) {
      throw const FormatException('UTF-16 파일의 바이트 길이가 올바르지 않습니다.');
    }
    final units = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      units.add(
        littleEndian
            ? bytes[index] | (bytes[index + 1] << 8)
            : (bytes[index] << 8) | bytes[index + 1],
      );
    }
    return String.fromCharCodes(units);
  }

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }

  List<int> _skipBom(List<int> bytes, List<int> bom) =>
      _startsWith(bytes, bom) ? bytes.sublist(bom.length) : bytes;
}
