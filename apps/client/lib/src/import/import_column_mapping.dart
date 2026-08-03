import 'package:csv/csv.dart';

import 'import_limits.dart';
import 'xlsx_import_reader.dart';

class ImportColumnField {
  const ImportColumnField({
    required this.key,
    required this.label,
    required this.aliases,
    this.required = false,
  });

  final String key;
  final String label;
  final Set<String> aliases;
  final bool required;
}

class ImportColumnMapper {
  const ImportColumnMapper();

  static const fields = <ImportColumnField>[
    ImportColumnField(
      key: 'term',
      label: '문제·표현',
      required: true,
      aliases: {
        'term',
        'text',
        'foreign',
        'word',
        'question',
        '문제',
        '표현',
        '단어',
        '외국어',
        '원문',
      },
    ),
    ImportColumnField(
      key: 'meaning',
      label: '정답·뜻',
      required: true,
      aliases: {
        'meaning',
        'translation',
        'answer',
        'ko',
        '정답',
        '뜻',
        '의미',
        '번역',
        '한국어',
      },
    ),
    ImportColumnField(
      key: 'language',
      label: '언어',
      aliases: {'language', 'language_tag', 'lang', '언어', '언어키'},
    ),
    ImportColumnField(
      key: 'type',
      label: '자료 종류',
      aliases: {'type', 'kind', '자료 종류', '유형', '타입'},
    ),
    ImportColumnField(
      key: 'reading',
      label: '읽기',
      aliases: {'reading', 'pronunciation', '읽기', '발음', '읽는 법'},
    ),
    ImportColumnField(
      key: 'korean_pronunciation',
      label: '한글 읽기',
      aliases: {'korean_pronunciation', 'hangul', '한글 읽기', '한글 발음', '한국어 발음'},
    ),
    ImportColumnField(
      key: 'part_of_speech',
      label: '품사',
      aliases: {'part_of_speech', 'pos', '품사'},
    ),
    ImportColumnField(
      key: 'group',
      label: '그룹',
      aliases: {'group', 'groups', 'deck', '학습 그룹', '그룹', '단어장'},
    ),
    ImportColumnField(key: 'tags', label: '태그', aliases: {'tags', 'tag', '태그'}),
    ImportColumnField(
      key: 'example',
      label: '예문',
      aliases: {'example', 'example_en', 'sentence', '예문', '예시 문장'},
    ),
    ImportColumnField(
      key: 'example_translation',
      label: '예문 뜻',
      aliases: {
        'example_translation',
        'example_ko',
        'sentence_translation',
        '예문 뜻',
        '예문 번역',
      },
    ),
    ImportColumnField(
      key: 'source_name',
      label: '출처',
      aliases: {'source_name', 'source', '출처'},
    ),
  ];

  Map<String, String> suggest(Iterable<String> headers) {
    final normalizedHeaders = <String, String>{};
    for (final header in headers) {
      normalizedHeaders.putIfAbsent(_normalize(header), () => header);
    }
    final result = <String, String>{};
    for (final field in fields) {
      for (final alias in {field.key, ...field.aliases}) {
        final header = normalizedHeaders[_normalize(alias)];
        if (header != null) {
          result[field.key] = header;
          break;
        }
      }
    }
    return result;
  }

  List<ImportColumnField> missingRequired(Map<String, String> mapping) => [
    for (final field in fields)
      if (field.required &&
          (mapping[field.key] == null || mapping[field.key]!.trim().isEmpty))
        field,
  ];

  Map<String, Object?> apply(
    Map<String, Object?> row,
    Map<String, String> mapping,
  ) {
    final result = Map<String, Object?>.from(row);
    final normalizedLookup = {
      for (final entry in row.entries) _normalize(entry.key): entry.value,
    };
    for (final entry in mapping.entries) {
      final value =
          row[entry.value] ?? normalizedLookup[_normalize(entry.value)];
      if (value != null) result[entry.key] = value;
    }
    return result;
  }

  List<String> inspectCsv(String input, {String? delimiter}) {
    final rows = delimiter == null
        ? csv.decode(input)
        : Csv(
            fieldDelimiter: delimiter,
            autoDetect: false,
            dynamicTyping: false,
          ).decode(input);
    if (rows.isEmpty) return const [];
    return rows.first
        .map((value) => value.toString().trim().replaceFirst('\uFEFF', ''))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<String> inspectExcel(
    List<int> bytes, {
    ImportLimits limits = const ImportLimits(),
    String? sheetName,
  }) {
    final sheets = XlsxImportReader(limits: limits).read(bytes);
    for (final sheet in sheets.where(
      (sheet) => sheetName == null || sheet.name == sheetName,
    )) {
      final index = findExcelHeaderIndex(sheet.rows);
      if (index >= 0) {
        return sheet.rows[index].values
            .map((value) => value.trim().replaceFirst('\uFEFF', ''))
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const [];
  }

  int findExcelHeaderIndex(
    List<XlsxImportRow> rows, {
    Map<String, String> mapping = const {},
  }) {
    var fallbackIndex = -1;
    var fallbackScore = 0;
    var fallbackWidth = 0;
    for (final (index, row) in rows.take(30).indexed) {
      final headers = row.values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (headers.length < 2) continue;
      final effective = mapping.isEmpty ? suggest(headers) : mapping;
      if (missingRequired(effective).isEmpty &&
          effective.values.every(
            (source) => headers.any(
              (header) => _normalize(header) == _normalize(source),
            ),
          )) {
        return index;
      }
      final score = suggest(headers).length;
      if (fallbackIndex < 0 ||
          score > fallbackScore ||
          (score == fallbackScore && headers.length > fallbackWidth)) {
        fallbackScore = score;
        fallbackWidth = headers.length;
        fallbackIndex = index;
      }
    }
    return fallbackIndex;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-·/()]+'), '');
}
