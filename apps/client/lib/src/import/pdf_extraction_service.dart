import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import '../domain/language.dart';

class PdfImportLimits {
  const PdfImportLimits();

  static const maxFileBytes = 20 * 1024 * 1024;
  static const maxPages = 500;
  static const maxExtractedCharacters = 2000000;
  static const maxCandidates = 5000;
}

enum PdfCandidateKind { mappedPair, documentTerm }

class PdfImportCandidate {
  const PdfImportCandidate({
    required this.id,
    required this.term,
    required this.meaning,
    required this.excerpt,
    required this.pageNumber,
    required this.frequency,
    required this.kind,
    required this.selected,
  });

  final String id;
  final String term;
  final String meaning;
  final String excerpt;
  final int pageNumber;
  final int frequency;
  final PdfCandidateKind kind;
  final bool selected;

  bool get hasMeaning => meaning.trim().isNotEmpty;

  PdfImportCandidate copyWith({
    String? term,
    String? meaning,
    String? excerpt,
    int? pageNumber,
    int? frequency,
    PdfCandidateKind? kind,
    bool? selected,
  }) => PdfImportCandidate(
    id: id,
    term: term ?? this.term,
    meaning: meaning ?? this.meaning,
    excerpt: excerpt ?? this.excerpt,
    pageNumber: pageNumber ?? this.pageNumber,
    frequency: frequency ?? this.frequency,
    kind: kind ?? this.kind,
    selected: selected ?? this.selected,
  );
}

class PdfExtractionResult {
  const PdfExtractionResult({
    required this.fileName,
    required this.sha256Hex,
    required this.pageCount,
    required this.extractedCharacters,
    required this.candidates,
  });

  final String fileName;
  final String sha256Hex;
  final int pageCount;
  final int extractedCharacters;
  final List<PdfImportCandidate> candidates;

  int get mappedPairCount => candidates
      .where((candidate) => candidate.kind == PdfCandidateKind.mappedPair)
      .length;
}

class PdfExtractionProgress {
  const PdfExtractionProgress({
    required this.processedPages,
    required this.totalPages,
  });

  final int processedPages;
  final int totalPages;

  double get fraction => totalPages == 0 ? 0 : processedPages / totalPages;
}

class PdfExtractionCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const PdfExtractionCancelled();
  }
}

class PdfExtractionCancelled implements Exception {
  const PdfExtractionCancelled();
}

enum PdfExtractionFailure { encrypted, scanned, damaged, limitExceeded }

class PdfExtractionException implements Exception {
  const PdfExtractionException(this.failure, this.message);

  final PdfExtractionFailure failure;
  final String message;

  @override
  String toString() => message;
}

class PdfExtractionRequest {
  const PdfExtractionRequest({
    required this.fileName,
    required this.bytes,
    required this.language,
    this.password,
  });

  final String fileName;
  final Uint8List bytes;
  final LanguageTag language;
  final String? password;
}

abstract interface class PdfExtractionService {
  Future<PdfExtractionResult> extract(
    PdfExtractionRequest request, {
    void Function(PdfExtractionProgress progress)? onProgress,
    PdfExtractionCancellationToken? cancellationToken,
  });
}

class PdfrxPdfExtractionService implements PdfExtractionService {
  const PdfrxPdfExtractionService({this.parser = const PdfCandidateParser()});

  final PdfCandidateParser parser;

  @override
  Future<PdfExtractionResult> extract(
    PdfExtractionRequest request, {
    void Function(PdfExtractionProgress progress)? onProgress,
    PdfExtractionCancellationToken? cancellationToken,
  }) async {
    if (request.bytes.length > PdfImportLimits.maxFileBytes) {
      throw const PdfExtractionException(
        PdfExtractionFailure.limitExceeded,
        'PDF는 20MB 이하만 가져올 수 있습니다.',
      );
    }
    if (request.bytes.length < 5 ||
        request.bytes[0] != 0x25 ||
        request.bytes[1] != 0x50 ||
        request.bytes[2] != 0x44 ||
        request.bytes[3] != 0x46 ||
        request.bytes[4] != 0x2d) {
      throw const PdfExtractionException(
        PdfExtractionFailure.damaged,
        'PDF를 읽지 못했습니다. 파일이 손상되지 않았는지 확인해 주세요.',
      );
    }
    cancellationToken?.throwIfCancelled();
    await pdfrxFlutterInitialize();
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(
        request.bytes,
        sourceName: request.fileName,
        passwordProvider: request.password == null
            ? null
            : createSimplePasswordProvider(request.password),
        firstAttemptByEmptyPassword: request.password == null,
        useProgressiveLoading: false,
      );
      if (document.pages.length > PdfImportLimits.maxPages) {
        throw const PdfExtractionException(
          PdfExtractionFailure.limitExceeded,
          'PDF는 최대 500페이지만 분석할 수 있습니다.',
        );
      }
      final pages = <PdfExtractedPage>[];
      var extractedCharacters = 0;
      for (var index = 0; index < document.pages.length; index += 1) {
        cancellationToken?.throwIfCancelled();
        final structured = await document.pages[index].loadStructuredText();
        final text = unicode.nfkc(structured.fullText).replaceAll('\u0000', '');
        extractedCharacters += text.length;
        if (extractedCharacters > PdfImportLimits.maxExtractedCharacters) {
          throw const PdfExtractionException(
            PdfExtractionFailure.limitExceeded,
            '추출된 본문이 200만 자를 넘어 분석을 중단했습니다.',
          );
        }
        pages.add(PdfExtractedPage(pageNumber: index + 1, text: text));
        onProgress?.call(
          PdfExtractionProgress(
            processedPages: index + 1,
            totalPages: document.pages.length,
          ),
        );
      }
      if (pages.every((page) => page.text.trim().isEmpty)) {
        throw const PdfExtractionException(
          PdfExtractionFailure.scanned,
          '텍스트를 찾지 못했습니다. 스캔 PDF의 OCR은 아직 지원하지 않습니다.',
        );
      }
      final fingerprint = sha256.convert(request.bytes).toString();
      return PdfExtractionResult(
        fileName: request.fileName,
        sha256Hex: fingerprint,
        pageCount: document.pages.length,
        extractedCharacters: extractedCharacters,
        candidates: parser.parse(
          pages,
          language: request.language,
          sourceFingerprint: fingerprint,
        ),
      );
    } on PdfPasswordException {
      throw const PdfExtractionException(
        PdfExtractionFailure.encrypted,
        '암호가 필요한 PDF입니다. 이 작업에서만 사용할 암호를 입력해 주세요.',
      );
    } on PdfExtractionException {
      rethrow;
    } on PdfExtractionCancelled {
      rethrow;
    } catch (_) {
      throw const PdfExtractionException(
        PdfExtractionFailure.damaged,
        'PDF를 읽지 못했습니다. 파일이 손상되지 않았는지 확인해 주세요.',
      );
    } finally {
      document?.dispose();
    }
  }
}

class PdfExtractedPage {
  const PdfExtractedPage({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

class PdfCandidateParser {
  const PdfCandidateParser();

  List<PdfImportCandidate> parse(
    List<PdfExtractedPage> pages, {
    required LanguageTag language,
    required String sourceFingerprint,
  }) {
    final mapped = <String, PdfImportCandidate>{};
    final termStats = <String, _TermStats>{};
    for (final page in pages) {
      final lines = page.text
          .split(RegExp(r'\r?\n'))
          .map(_cleanLine)
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      for (final line in lines) {
        final pair = _pair(line);
        if (pair != null) {
          final key = '${_key(pair.$1)}|${_key(pair.$2)}';
          final previous = mapped[key];
          mapped[key] = PdfImportCandidate(
            id: _candidateId(sourceFingerprint, page.pageNumber, key),
            term: pair.$1,
            meaning: pair.$2,
            excerpt: _excerpt(line),
            pageNumber: previous?.pageNumber ?? page.pageNumber,
            frequency: (previous?.frequency ?? 0) + 1,
            kind: PdfCandidateKind.mappedPair,
            selected: true,
          );
          continue;
        }
        for (final token in _tokens(line, language)) {
          final key = _key(token);
          if (key.isEmpty || _stopwords(language).contains(key)) continue;
          final stats = termStats.putIfAbsent(
            key,
            () => _TermStats(
              term: token,
              pageNumber: page.pageNumber,
              excerpt: _excerpt(line),
            ),
          );
          stats.frequency += 1;
        }
      }
    }

    final mappedTermKeys = mapped.values
        .map((value) => _key(value.term))
        .toSet();
    final general =
        termStats.entries
            .where((entry) => !mappedTermKeys.contains(entry.key))
            .map((entry) {
              final stats = entry.value;
              return PdfImportCandidate(
                id: _candidateId(
                  sourceFingerprint,
                  stats.pageNumber,
                  entry.key,
                ),
                term: stats.term,
                meaning: '',
                excerpt: stats.excerpt,
                pageNumber: stats.pageNumber,
                frequency: stats.frequency,
                kind: PdfCandidateKind.documentTerm,
                selected: false,
              );
            })
            .toList()
          ..sort((left, right) {
            final frequency = right.frequency.compareTo(left.frequency);
            return frequency != 0 ? frequency : left.term.compareTo(right.term);
          });
    return List.unmodifiable(
      [...mapped.values, ...general].take(PdfImportLimits.maxCandidates),
    );
  }

  (String, String)? _pair(String line) {
    for (final delimiter in [
      RegExp(r'\s+[-–—=]\s+'),
      RegExp(r'[:：]\s+'),
      RegExp(r'\t+'),
      RegExp(r'\s{3,}'),
    ]) {
      final match = delimiter.firstMatch(line);
      if (match == null) continue;
      final term = _clean(line.substring(0, match.start));
      final meaning = _clean(line.substring(match.end));
      if (_validTerm(term) && _validMeaning(meaning)) return (term, meaning);
    }
    return null;
  }

  Iterable<String> _tokens(String line, LanguageTag language) sync* {
    final matches = RegExp(
      r"[A-Za-zÀ-ÖØ-öø-ÿĀ-ž]+(?:['’\-][A-Za-zÀ-ÖØ-öø-ÿĀ-ž]+)*|[가-힣]{2,}|[\u3040-\u30ff\u3400-\u9fff]{1,20}",
      unicode: true,
    ).allMatches(line);
    for (final match in matches) {
      final token = _clean(match.group(0) ?? '');
      if (token.length >= _minimumLength(language) && token.length <= 80) {
        yield token;
      }
    }
  }

  int _minimumLength(LanguageTag language) => switch (language) {
    LanguageTag.japanese || LanguageTag.simplifiedChinese => 1,
    _ => 2,
  };

  bool _validTerm(String value) =>
      value.isNotEmpty &&
      value.length <= 120 &&
      !value.contains(RegExp(r'[.!?。！？]$'));
  bool _validMeaning(String value) => value.isNotEmpty && value.length <= 500;
  String _clean(String value) =>
      unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ');
  String _cleanLine(String value) => unicode.nfkc(value).trim();
  String _key(String value) => _clean(value).toLowerCase();
  String _excerpt(String value) =>
      value.length <= 240 ? value : '${value.substring(0, 237)}...';
  String _candidateId(String fingerprint, int page, String key) =>
      sha256.convert('$fingerprint|$page|$key'.codeUnits).toString();

  Set<String> _stopwords(LanguageTag language) => switch (language) {
    LanguageTag.korean => _koStopwords,
    LanguageTag.english => _enStopwords,
    LanguageTag.japanese => _jaStopwords,
    LanguageTag.german => _deStopwords,
    LanguageTag.french => _frStopwords,
    LanguageTag.spanish => _esStopwords,
    LanguageTag.simplifiedChinese => _zhStopwords,
  };
}

class _TermStats {
  _TermStats({
    required this.term,
    required this.pageNumber,
    required this.excerpt,
  });

  final String term;
  final int pageNumber;
  final String excerpt;
  int frequency = 0;
}

const _koStopwords = {'그리고', '그러나', '에서', '으로', '하는', '있는', '것은', '이다'};
const _enStopwords = {
  'the',
  'and',
  'for',
  'that',
  'with',
  'this',
  'from',
  'are',
  'was',
};
const _jaStopwords = {'の', 'に', 'は', 'を', 'が', 'と', 'で', 'です', 'ます'};
const _deStopwords = {'der', 'die', 'das', 'und', 'ist', 'mit', 'von', 'den'};
const _frStopwords = {
  'le',
  'la',
  'les',
  'des',
  'une',
  'est',
  'avec',
  'pour',
  'que',
};
const _esStopwords = {
  'el',
  'la',
  'los',
  'las',
  'una',
  'con',
  'para',
  'que',
  'del',
};
const _zhStopwords = {'的', '了', '在', '是', '和', '与', '这', '有'};
