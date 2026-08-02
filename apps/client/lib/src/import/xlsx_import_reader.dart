import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'import_limits.dart';

class XlsxImportRow {
  const XlsxImportRow({required this.number, required this.values});

  final int number;
  final List<String> values;
}

class XlsxImportSheet {
  const XlsxImportSheet({required this.name, required this.rows});

  final String name;
  final List<XlsxImportRow> rows;
}

class XlsxImportReader {
  const XlsxImportReader({this.limits = const ImportLimits()});

  final ImportLimits limits;

  List<XlsxImportSheet> read(List<int> bytes) {
    limits.ensureFileSize(bytes.length);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const FormatException('올바른 .xlsx 파일이 아닙니다.');
    }
    if (archive.files.length > 1000) {
      throw const FormatException('엑셀 파일 안의 항목이 너무 많습니다.');
    }
    final expandedSize = archive.files.fold<int>(
      0,
      (total, file) => total + file.size,
    );
    if (expandedSize > 100 * 1024 * 1024) {
      throw const FormatException('압축을 푼 엑셀 파일이 너무 큽니다.');
    }
    final files = {
      for (final file in archive.files.where((file) => file.isFile))
        file.name.replaceAll(r'\', '/'): file,
    };
    final sharedStrings = _sharedStrings(files['xl/sharedStrings.xml']);
    final workbookSheets = _workbookSheets(files);
    final worksheetFiles = <({String path, String name, ArchiveFile file})>[
      for (final sheet in workbookSheets)
        if (files[sheet.path] case final file?)
          (path: sheet.path, name: sheet.name, file: file),
    ];
    final knownPaths = workbookSheets.map((sheet) => sheet.path).toSet();
    final unlisted =
        files.entries
            .where(
              (entry) =>
                  entry.key.startsWith('xl/worksheets/') &&
                  entry.key.endsWith('.xml') &&
                  !knownPaths.contains(entry.key),
            )
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    worksheetFiles.addAll([
      for (final entry in unlisted)
        (path: entry.key, name: entry.key.split('/').last, file: entry.value),
    ]);
    if (worksheetFiles.isEmpty) {
      throw const FormatException('엑셀에 워크시트가 없습니다.');
    }
    return [
      for (final entry in worksheetFiles)
        XlsxImportSheet(
          name: entry.name,
          rows: _rows(entry.file, sharedStrings),
        ),
    ];
  }

  List<({String path, String name})> _workbookSheets(
    Map<String, ArchiveFile> files,
  ) {
    final workbook = files['xl/workbook.xml'];
    final relationships = files['xl/_rels/workbook.xml.rels'];
    if (workbook == null || relationships == null) return const [];
    final targets = <String, String>{};
    for (final relation
        in _document(relationships).descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'Relationship',
        )) {
      final id = relation.getAttribute('Id');
      final target = relation.getAttribute('Target');
      if (id == null || target == null) continue;
      final normalized = _worksheetTarget(target);
      if (normalized != null) targets[id] = normalized;
    }
    final result = <({String path, String name})>[];
    for (final sheet
        in _document(workbook).descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'sheet',
        )) {
      final id = sheet.attributes
          .where((attribute) => attribute.name.local == 'id')
          .map((attribute) => attribute.value)
          .firstOrNull;
      final path = id == null ? null : targets[id];
      final name = sheet.getAttribute('name')?.trim();
      if (path == null || name == null || name.isEmpty) continue;
      result.add((path: path, name: name));
    }
    return result;
  }

  String? _worksheetTarget(String rawTarget) {
    var target = rawTarget.replaceAll(r'\', '/');
    target = target.startsWith('/')
        ? target.substring(1)
        : 'xl/${target.replaceFirst(RegExp(r'^\./'), '')}';
    final parts = <String>[];
    for (final part in target.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isEmpty) return null;
        parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    final normalized = parts.join('/');
    return normalized.startsWith('xl/worksheets/') &&
            normalized.endsWith('.xml')
        ? normalized
        : null;
  }

  List<String> _sharedStrings(ArchiveFile? file) {
    if (file == null) return const [];
    final document = _document(file);
    return document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'si')
        .map(
          (element) => element.descendants
              .whereType<XmlElement>()
              .where((child) => child.name.local == 't')
              .map((child) => child.innerText)
              .join(),
        )
        .take(100000)
        .toList(growable: false);
  }

  List<XlsxImportRow> _rows(ArchiveFile file, List<String> sharedStrings) {
    final document = _document(file);
    final rows = <XlsxImportRow>[];
    var fallbackRow = 0;
    for (final row in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'row',
    )) {
      if (rows.length >= limits.maxRows + 30) {
        throw ImportLimitException(
          '엑셀은 헤더를 포함해 ${limits.maxRows + 30}행까지만 읽을 수 있습니다. '
          '파일을 나누어 다시 가져와 주세요.',
        );
      }
      fallbackRow++;
      final rowNumber =
          int.tryParse(row.getAttribute('r') ?? '') ?? fallbackRow;
      final values = <String>[];
      for (final cell in row.childElements.where(
        (element) => element.name.local == 'c',
      )) {
        final reference = cell.getAttribute('r') ?? '';
        final columnIndex = _columnIndex(reference);
        limits.ensureColumnCount(columnIndex + 1);
        while (values.length <= columnIndex) {
          values.add('');
        }
        final cellText = _cellText(cell, sharedStrings);
        limits.ensureCellLength(
          cellText.length,
          row: rowNumber,
          field: '열 ${columnIndex + 1}',
        );
        values[columnIndex] = cellText;
      }
      rows.add(XlsxImportRow(number: rowNumber, values: values));
    }
    return rows;
  }

  String _cellText(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return cell.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText)
          .join();
    }
    String? value;
    for (final element in cell.childElements) {
      if (element.name.local == 'v') {
        value = element.innerText;
        break;
      }
    }
    if (value == null) return '';
    if (type == 's') {
      final index = int.tryParse(value);
      return index != null && index >= 0 && index < sharedStrings.length
          ? sharedStrings[index]
          : '';
    }
    if (type == 'b') return value == '1' ? 'true' : 'false';
    return value;
  }

  XmlDocument _document(ArchiveFile file) {
    try {
      return XmlDocument.parse(utf8.decode(file.content as List<int>));
    } catch (_) {
      throw const FormatException('엑셀 내부 XML을 읽을 수 없습니다.');
    }
  }

  int _columnIndex(String reference) {
    var result = 0;
    var hasColumn = false;
    for (final rune in reference.toUpperCase().runes) {
      if (rune < 65 || rune > 90) break;
      hasColumn = true;
      result = result * 26 + rune - 64;
    }
    return hasColumn ? result - 1 : 0;
  }
}
