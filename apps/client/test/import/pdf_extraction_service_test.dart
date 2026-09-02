import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/import/pdf_extraction_service.dart';

void main() {
  final nativePdfTestSkip = Platform.isLinux
      ? 'The Flutter Linux test shell does not bundle the PDFium runtime; '
            'this native integration is verified by the Windows CI job.'
      : false;
  setUpAll(() {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
  });
  const parser = PdfCandidateParser();
  const fingerprint =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'maps dash, colon, tab, and two-column term pairs with page context',
    () {
      final candidates = parser.parse(
        const [
          PdfExtractedPage(
            pageNumber: 3,
            text: 'curveball - 커브\nERA: 평균자책점\nhomerun\t홈런\nwalk   볼넷',
          ),
        ],
        language: LanguageTag.english,
        sourceFingerprint: fingerprint,
      );

      final mapped = candidates
          .where((candidate) => candidate.kind == PdfCandidateKind.mappedPair)
          .toList();
      expect(mapped, hasLength(4));
      expect(mapped.map((candidate) => candidate.term), contains('curveball'));
      expect(mapped.map((candidate) => candidate.meaning), contains('평균자책점'));
      expect(mapped.every((candidate) => candidate.selected), isTrue);
      expect(mapped.every((candidate) => candidate.pageNumber == 3), isTrue);
    },
  );

  test(
    'general prose candidates require a meaning and are not preselected',
    () {
      final candidates = parser.parse(
        const [
          PdfExtractedPage(
            pageNumber: 1,
            text: 'Pitchers practice control. Control matters in every inning.',
          ),
        ],
        language: LanguageTag.english,
        sourceFingerprint: fingerprint,
      );

      final control = candidates.firstWhere(
        (candidate) => candidate.term.toLowerCase() == 'control',
      );
      expect(control.frequency, 2);
      expect(control.meaning, isEmpty);
      expect(control.selected, isFalse);
    },
  );

  test('normalizes equivalent Unicode before deduplicating pairs', () {
    final candidates = parser.parse(
      const [PdfExtractedPage(pageNumber: 1, text: 'Ｃａｆｅ́ - 카페\nCafé - 카페')],
      language: LanguageTag.french,
      sourceFingerprint: fingerprint,
    );

    final mapped = candidates.where(
      (candidate) => candidate.kind == PdfCandidateKind.mappedPair,
    );
    expect(mapped, hasLength(1));
    expect(mapped.single.frequency, 2);
  });

  test('supports term pairs for all seven configured languages', () {
    const fixtures = <LanguageTag, String>{
      LanguageTag.korean: '직구 - fastball',
      LanguageTag.english: 'fastball - 직구',
      LanguageTag.japanese: '野球 - 야구',
      LanguageTag.german: 'Ball - 공',
      LanguageTag.french: 'équipe - 팀',
      LanguageTag.spanish: 'entrada - 이닝',
      LanguageTag.simplifiedChinese: '棒球 - 야구',
    };

    for (final entry in fixtures.entries) {
      final candidates = parser.parse(
        [PdfExtractedPage(pageNumber: 1, text: entry.value)],
        language: entry.key,
        sourceFingerprint: fingerprint,
      );
      expect(
        candidates.where(
          (candidate) => candidate.kind == PdfCandidateKind.mappedPair,
        ),
        hasLength(1),
        reason: entry.key.code,
      );
    }
  });

  test('caps the review list at 5000 candidates', () {
    final text = List.generate(
      5100,
      (index) => 'term$index - 뜻$index',
    ).join('\n');
    final candidates = parser.parse(
      [PdfExtractedPage(pageNumber: 1, text: text)],
      language: LanguageTag.english,
      sourceFingerprint: fingerprint,
    );
    expect(candidates, hasLength(PdfImportLimits.maxCandidates));
  });

  test('pdfrx extracts text from a real PDF fixture', () async {
    final result = await const PdfrxPdfExtractionService().extract(
      PdfExtractionRequest(
        fileName: 'terms.pdf',
        bytes: _pdfFixture('fastball - pitch'),
        language: LanguageTag.english,
      ),
    );

    expect(result.pageCount, 1);
    expect(result.candidates, isNotEmpty);
    expect(
      result.candidates.where(
        (candidate) => candidate.kind == PdfCandidateKind.mappedPair,
      ),
      isNotEmpty,
    );
  }, skip: nativePdfTestSkip);

  test('reports a text-free PDF as OCR unsupported', () async {
    expect(
      () => const PdfrxPdfExtractionService().extract(
        PdfExtractionRequest(
          fileName: 'scan.pdf',
          bytes: _pdfFixture(null),
          language: LanguageTag.english,
        ),
      ),
      throwsA(
        isA<PdfExtractionException>().having(
          (error) => error.failure,
          'failure',
          PdfExtractionFailure.scanned,
        ),
      ),
    );
  }, skip: nativePdfTestSkip);

  test('rejects damaged and oversized PDF input before import', () async {
    const service = PdfrxPdfExtractionService();
    expect(
      () => service.extract(
        PdfExtractionRequest(
          fileName: 'broken.pdf',
          bytes: Uint8List.fromList(utf8.encode('not a pdf')),
          language: LanguageTag.english,
        ),
      ),
      throwsA(
        isA<PdfExtractionException>().having(
          (error) => error.failure,
          'failure',
          PdfExtractionFailure.damaged,
        ),
      ),
    );
    expect(
      () => service.extract(
        PdfExtractionRequest(
          fileName: 'huge.pdf',
          bytes: Uint8List(PdfImportLimits.maxFileBytes + 1),
          language: LanguageTag.english,
        ),
      ),
      throwsA(
        isA<PdfExtractionException>().having(
          (error) => error.failure,
          'failure',
          PdfExtractionFailure.limitExceeded,
        ),
      ),
    );
  });

  test('honors cancellation before opening a PDF', () async {
    final token = PdfExtractionCancellationToken()..cancel();
    expect(
      () => const PdfrxPdfExtractionService().extract(
        PdfExtractionRequest(
          fileName: 'terms.pdf',
          bytes: _pdfFixture('word - meaning'),
          language: LanguageTag.english,
        ),
        cancellationToken: token,
      ),
      throwsA(isA<PdfExtractionCancelled>()),
    );
  });
}

Uint8List _pdfFixture(String? text) {
  final stream = text == null
      ? '0 0 10 10 re S'
      : 'BT /F1 12 Tf 72 720 Td (${_pdfEscape(text)}) Tj ET';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var index = 0; index < objects.length; index += 1) {
    offsets.add(buffer.length);
    buffer.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final xrefOffset = buffer.length;
  buffer
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

String _pdfEscape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('(', '\\(')
    .replaceAll(')', '\\)');
