import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/learning_item.dart';
import 'study_data_export_table.dart';

class StudyDataXlsxExporter {
  const StudyDataXlsxExporter({this.table = const StudyDataExportTable()});

  final StudyDataExportTable table;

  Uint8List encode(Iterable<LearningItem> items, {DateTime? exportedAt}) {
    final rows = table.rows(items);
    final timestamp = (exportedAt ?? DateTime.now()).toUtc();
    final archive = Archive();
    final modifiedAtSeconds = timestamp.millisecondsSinceEpoch ~/ 1000;

    void addXml(String path, String contents) {
      final bytes = utf8.encode(contents);
      final file = ArchiveFile(path, bytes.length, bytes)
        ..lastModTime = modifiedAtSeconds;
      archive.addFile(file);
    }

    addXml('[Content_Types].xml', _contentTypes);
    addXml('_rels/.rels', _packageRelationships);
    addXml('docProps/app.xml', _appProperties);
    addXml('docProps/core.xml', _coreProperties(timestamp));
    addXml('xl/workbook.xml', _workbook);
    addXml('xl/_rels/workbook.xml.rels', _workbookRelationships);
    addXml('xl/styles.xml', _styles);
    addXml('xl/worksheets/sheet1.xml', _worksheet(rows));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  String _worksheet(List<List<String>> rows) {
    final lastColumn = _columnName(StudyDataExportTable.headers.length - 1);
    final rowCount = rows.length;
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    buffer
      ..write('<dimension ref="A1:$lastColumn$rowCount"/>')
      ..write(
        '<sheetViews><sheetView workbookViewId="0" showGridLines="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        '<selection pane="bottomLeft" activeCell="A2" sqref="A2"/>'
        '</sheetView></sheetViews>',
      )
      ..write('<sheetFormatPr defaultRowHeight="18"/>')
      ..write(_columns)
      ..write('<sheetData>');

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final excelRow = rowIndex + 1;
      final values = rows[rowIndex];
      buffer.write(
        '<row r="$excelRow"${rowIndex == 0 ? ' ht="30" customHeight="1"' : ''}>',
      );
      for (var column = 0; column < values.length; column++) {
        final reference = '${_columnName(column)}$excelRow';
        final numeric =
            rowIndex > 0 &&
            _numericColumns.contains(StudyDataExportTable.headers[column]);
        if (numeric) {
          buffer
            ..write('<c r="$reference" s="3" t="n"><v>')
            ..write(values[column])
            ..write('</v></c>');
          continue;
        }
        final style = rowIndex == 0 ? 1 : 2;
        buffer
          ..write('<c r="$reference" s="$style" t="inlineStr"><is><t')
          ..write(_preserveSpace(values[column]) ? ' xml:space="preserve"' : '')
          ..write('>')
          ..write(_escapeXml(_sanitizeXmlText(values[column])))
          ..write('</t></is></c>');
      }
      buffer.write('</row>');
    }

    buffer
      ..write('</sheetData>')
      ..write('<autoFilter ref="A1:$lastColumn$rowCount"/>')
      ..write(
        '<pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" '
        'header="0.2" footer="0.2"/>',
      )
      ..write('</worksheet>');
    return buffer.toString();
  }

  String _columnName(int zeroBasedIndex) {
    var value = zeroBasedIndex + 1;
    final result = StringBuffer();
    while (value > 0) {
      value--;
      result.writeCharCode(65 + value % 26);
      value ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  bool _preserveSpace(String value) =>
      value.isNotEmpty &&
      (value.trim() != value || value.contains('\n') || value.contains('\t'));

  String _sanitizeXmlText(String value) => String.fromCharCodes(
    value.runes.where(
      (rune) =>
          rune == 0x09 ||
          rune == 0x0A ||
          rune == 0x0D ||
          rune >= 0x20 && rune != 0xFFFE && rune != 0xFFFF,
    ),
  );

  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _packageRelationships =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

const _appProperties =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>Sprache</Application>'
    '<DocSecurity>0</DocSecurity>'
    '<ScaleCrop>false</ScaleCrop>'
    '<HeadingPairs><vt:vector size="2" baseType="variant">'
    '<vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>'
    '<vt:variant><vt:i4>1</vt:i4></vt:variant>'
    '</vt:vector></HeadingPairs>'
    '<TitlesOfParts><vt:vector size="1" baseType="lpstr">'
    '<vt:lpstr>개인 콘텐츠</vt:lpstr>'
    '</vt:vector></TitlesOfParts>'
    '<Company></Company>'
    '<LinksUpToDate>false</LinksUpToDate>'
    '<SharedDoc>false</SharedDoc>'
    '<HyperlinksChanged>false</HyperlinksChanged>'
    '<AppVersion>1.22</AppVersion>'
    '</Properties>';

String _coreProperties(DateTime timestamp) {
  final value = timestamp.toIso8601String();
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties '
      'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>Sprache 개인 콘텐츠</dc:title>'
      '<dc:creator>Sprache</dc:creator>'
      '<cp:lastModifiedBy>Sprache</cp:lastModifiedBy>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">$value</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">$value</dcterms:modified>'
      '</cp:coreProperties>';
}

const _workbook =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<fileVersion appName="xl" lastEdited="7" lowestEdited="7" rupBuild="0"/>'
    '<workbookPr defaultThemeVersion="166925"/>'
    '<bookViews><workbookView xWindow="0" yWindow="0" windowWidth="28800" '
    'windowHeight="16000" activeTab="0"/></bookViews>'
    '<sheets><sheet name="개인 콘텐츠" sheetId="1" r:id="rId1"/></sheets>'
    '<calcPr calcId="191029" fullCalcOnLoad="1"/>'
    '</workbook>';

const _workbookRelationships =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="2">'
    '<font><sz val="10"/><color theme="1"/><name val="Aptos"/><family val="2"/></font>'
    '<font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="Aptos"/><family val="2"/></font>'
    '</fonts>'
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF227A4B"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="2">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left/><right/><top/><bottom style="thin"><color rgb="FFD9E2D8"/></bottom><diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="4">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" '
    'applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="center" vertical="center" wrapText="1"/>'
    '</xf>'
    '<xf numFmtId="49" fontId="0" fillId="0" borderId="1" xfId="0" '
    'applyNumberFormat="1" applyBorder="1" applyAlignment="1">'
    '<alignment vertical="top" wrapText="1"/>'
    '</xf>'
    '<xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" '
    'applyNumberFormat="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="right" vertical="top"/>'
    '</xf>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '<dxfs count="0"/>'
    '<tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>'
    '</styleSheet>';

const _columns =
    '<cols>'
    '<col min="1" max="2" width="12" customWidth="1"/>'
    '<col min="3" max="4" width="28" customWidth="1"/>'
    '<col min="5" max="6" width="20" customWidth="1"/>'
    '<col min="7" max="12" width="18" customWidth="1"/>'
    '<col min="13" max="14" width="32" customWidth="1"/>'
    '<col min="15" max="16" width="24" customWidth="1"/>'
    '<col min="17" max="18" width="12" customWidth="1"/>'
    '<col min="19" max="21" width="20" customWidth="1"/>'
    '<col min="22" max="22" width="22" customWidth="1"/>'
    '<col min="23" max="23" width="36" customWidth="1"/>'
    '<col min="24" max="25" width="26" customWidth="1"/>'
    '<col min="26" max="26" width="14" customWidth="1"/>'
    '<col min="27" max="27" width="30" customWidth="1"/>'
    '<col min="28" max="28" width="28" customWidth="1"/>'
    '</cols>';

const _numericColumns = {'priority', 'content_version'};
