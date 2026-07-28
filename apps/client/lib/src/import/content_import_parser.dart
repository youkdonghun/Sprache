import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;
import 'package:uuid/uuid.dart';

import '../domain/content_validation.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';

class ImportIssue {
  const ImportIssue({required this.row, required this.message});

  final int row;
  final String message;
}

class ParsedImportEntry {
  const ParsedImportEntry({required this.row, required this.item});

  final int row;
  final LearningItem item;
}

enum ImportDuplicateKind { id, semantic }

extension ImportDuplicateKindLabel on ImportDuplicateKind {
  String get label => switch (this) {
    ImportDuplicateKind.id => '같은 ID',
    ImportDuplicateKind.semantic => '같은 표현·뜻·품사',
  };
}

class ImportDuplicate {
  const ImportDuplicate({
    required this.row,
    required this.firstRow,
    required this.item,
    required this.kind,
  });

  final int row;
  final int firstRow;
  final LearningItem item;
  final ImportDuplicateKind kind;
}

class ImportPreview {
  const ImportPreview({
    required this.entries,
    required this.issues,
    required this.duplicates,
  });

  final List<ParsedImportEntry> entries;
  final List<ImportIssue> issues;
  final List<ImportDuplicate> duplicates;

  List<LearningItem> get items =>
      entries.map((entry) => entry.item).toList(growable: false);

  Set<String> get duplicateIds =>
      duplicates.map((duplicate) => duplicate.item.id).toSet();
}

class ContentImportParser {
  const ContentImportParser({
    this.validator = const LearningContentValidator(),
  });

  final LearningContentValidator validator;

  ImportPreview parseCsv(String input, {required LanguageTag defaultLanguage}) {
    final rows = csv.decode(input);
    if (rows.isEmpty) {
      return const ImportPreview(entries: [], issues: [], duplicates: []);
    }
    final headers = rows.first
        .map((value) => value.toString().trim().replaceFirst('\uFEFF', ''))
        .toList();
    if (headers.any((header) => header.isEmpty)) {
      throw const FormatException('CSV 헤더 이름은 비어 있을 수 없습니다.');
    }
    if (headers.toSet().length != headers.length) {
      throw const FormatException('CSV에 중복된 헤더 이름이 있습니다.');
    }
    final parsedRows = <_ImportRow>[];
    for (final (index, row) in rows.skip(1).indexed) {
      parsedRows.add(
        _ImportRow(index + 2, {
          for (var index = 0; index < headers.length; index++)
            headers[index]: index < row.length ? row[index] : null,
        }),
      );
    }
    return _parseRows(parsedRows, defaultLanguage: defaultLanguage);
  }

  ImportPreview parseJson(
    String input, {
    required LanguageTag defaultLanguage,
  }) {
    final decoded = jsonDecode(input);
    final rows = decoded is List<Object?>
        ? decoded
        : decoded is Map<String, Object?> && decoded['items'] is List<Object?>
        ? decoded['items']! as List<Object?>
        : throw const FormatException('JSON은 배열 또는 items 배열이어야 합니다.');
    final parsedRows = <_ImportRow>[];
    final issues = <ImportIssue>[];
    for (final (index, raw) in rows.indexed) {
      final map = _mapOrNull(raw);
      if (map == null) {
        issues.add(
          ImportIssue(row: index + 1, message: '각 항목은 JSON 객체여야 합니다.'),
        );
      } else {
        parsedRows.add(_ImportRow(index + 1, map));
      }
    }
    final parsed = _parseRows(parsedRows, defaultLanguage: defaultLanguage);
    return ImportPreview(
      entries: parsed.entries,
      issues: [...issues, ...parsed.issues],
      duplicates: parsed.duplicates,
    );
  }

  ImportPreview parseJsonLines(
    String input, {
    required LanguageTag defaultLanguage,
  }) {
    final rows = <_ImportRow>[];
    final issues = <ImportIssue>[];
    final lines = const LineSplitter().convert(input);
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(lines[index]);
        final map = _mapOrNull(decoded);
        if (map == null) {
          throw const FormatException();
        }
        rows.add(_ImportRow(index + 1, map));
      } catch (_) {
        issues.add(ImportIssue(row: index + 1, message: '올바른 JSON 객체가 아닙니다.'));
      }
    }
    final parsed = _parseRows(rows, defaultLanguage: defaultLanguage);
    return ImportPreview(
      entries: parsed.entries,
      issues: [...issues, ...parsed.issues],
      duplicates: parsed.duplicates,
    );
  }

  ImportPreview _parseRows(
    List<_ImportRow> rows, {
    required LanguageTag defaultLanguage,
  }) {
    final entries = <ParsedImportEntry>[];
    final issues = <ImportIssue>[];
    final seenIds = <String, int>{};
    final seenContentKeys = <String, int>{};
    final duplicates = <ImportDuplicate>[];

    for (final row in rows) {
      try {
        final item = _parseItem(row.value, defaultLanguage: defaultLanguage);
        final contentKey = validator.duplicateKey(item);
        final duplicateIdRow = seenIds[item.id];
        final duplicateContentRow = seenContentKeys[contentKey];
        if (duplicateIdRow != null || duplicateContentRow != null) {
          duplicates.add(
            ImportDuplicate(
              row: row.number,
              firstRow: duplicateIdRow ?? duplicateContentRow!,
              item: item,
              kind: duplicateIdRow != null
                  ? ImportDuplicateKind.id
                  : ImportDuplicateKind.semantic,
            ),
          );
          continue;
        }
        seenIds[item.id] = row.number;
        seenContentKeys[contentKey] = row.number;
        entries.add(ParsedImportEntry(row: row.number, item: item));
      } on FormatException catch (error) {
        issues.add(ImportIssue(row: row.number, message: error.message));
      } on LearningContentValidationException catch (error) {
        issues.add(ImportIssue(row: row.number, message: error.toString()));
      }
    }
    return ImportPreview(
      entries: entries,
      issues: issues,
      duplicates: duplicates,
    );
  }

  LearningItem _parseItem(
    Map<String, Object?> row, {
    required LanguageTag defaultLanguage,
  }) {
    final type = _string(row, ['type', 'kind'], fallback: 'word');
    final kind = switch (type.toLowerCase()) {
      'word' || '단어' => LearningItemKind.word,
      'sentence' || '문장' => LearningItemKind.sentence,
      _ => throw const FormatException('type은 word 또는 sentence여야 합니다.'),
    };
    final text = _string(row, ['term', 'text', 'en', 'foreign']);
    final meaning = _string(row, ['meaning', 'translation', 'ko']);
    if (text.isEmpty) {
      throw const FormatException('학습할 외국어 텍스트가 비어 있습니다.');
    }
    if (meaning.isEmpty) {
      throw const FormatException('한국어 뜻이 비어 있습니다.');
    }
    final languageCode = _string(row, [
      'language',
      'language_tag',
    ], fallback: defaultLanguage.code);
    final language = LanguageTag.values.firstWhere(
      (value) => value.code == languageCode,
      orElse: () =>
          throw FormatException('지원하지 않는 language 값입니다: $languageCode'),
    );
    final accepted = [
      meaning,
      ..._split(_string(row, ['accepted_answers'])),
    ];
    final genericReading = _string(row, ['reading']);
    final kana = _string(row, ['kana']);
    final romaji = _string(row, ['romaji']);
    final pinyin = _string(row, ['pinyin']);
    if (genericReading.isNotEmpty &&
        language != LanguageTag.japanese &&
        language != LanguageTag.simplifiedChinese) {
      throw FormatException(
        '${language.koreanName}의 reading 필드는 현재 지원하지 않습니다. 일본어는 kana·romaji, 중국어는 pinyin을 사용하세요.',
      );
    }
    final readings = <Reading>[
      if (kana.isNotEmpty) Reading(scheme: ReadingScheme.kana, value: kana),
      if (romaji.isNotEmpty)
        Reading(scheme: ReadingScheme.romaji, value: romaji),
      if (pinyin.isNotEmpty)
        Reading(scheme: ReadingScheme.pinyin, value: pinyin),
      if (genericReading.isNotEmpty &&
          language == LanguageTag.japanese &&
          kana.isEmpty)
        Reading(scheme: ReadingScheme.kana, value: genericReading),
      if (genericReading.isNotEmpty &&
          language == LanguageTag.simplifiedChinese &&
          pinyin.isEmpty)
        Reading(scheme: ReadingScheme.pinyin, value: genericReading),
    ];
    final sentenceTokens = _split(_string(row, ['sentence_tokens', 'tokens']));
    final capabilities = <ExerciseCapability>{
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.listening,
      if (kind == LearningItemKind.sentence && sentenceTokens.length >= 2)
        ExerciseCapability.cloze,
      if (kind == LearningItemKind.sentence && sentenceTokens.length >= 2)
        ExerciseCapability.sentenceOrder,
    };
    final rawPartOfSpeech = _string(row, [
      'part_of_speech',
      'partOfSpeech',
      'pos',
    ]);
    final partOfSpeech = rawPartOfSpeech.isEmpty
        ? null
        : parsePartOfSpeech(rawPartOfSpeech);
    final rawSource = row['source'];
    final sourceMap = _mapOrNull(rawSource);
    final sourceName = _string(
      row,
      ['source_name', 'sourceName'],
      fallback: switch (rawSource) {
        final String value when value.trim().isNotEmpty => value.trim(),
        _ => _string(sourceMap ?? const {}, ['name'], fallback: '사용자 가져오기'),
      },
    );
    final license = _string(
      row,
      ['license'],
      fallback: _string(sourceMap ?? const {}, [
        'license',
      ], fallback: 'private'),
    );
    final sourceVersion = _string(
      row,
      ['source_version', 'sourceVersion'],
      fallback: _string(sourceMap ?? const {}, [
        'sourceVersion',
        'version',
      ], fallback: '1'),
    );
    final rawContentVersion = _string(
      row,
      ['content_version', 'contentVersion'],
      fallback: _string(sourceMap ?? const {}, [
        'contentVersion',
      ], fallback: '1'),
    );
    final contentVersion =
        int.tryParse(rawContentVersion) ??
        (throw const FormatException('content_version은 정수여야 합니다.'));
    final stableName = [
      language.code,
      kind.name,
      _stable(text),
      _stable(meaning),
      partOfSpeech?.name ?? '',
    ].join('|');
    final id = _string(row, ['id']).isNotEmpty
        ? _string(row, ['id'])
        : const Uuid().v5(Namespace.url.value, 'sprache:$stableName');

    return validator.ensureValid(
      LearningItem(
        id: id,
        kind: kind,
        learningLanguage: language,
        text: text,
        translations: [meaning],
        acceptedAnswers: accepted,
        readings: readings,
        sentenceTokens: sentenceTokens,
        example: _nullable(_string(row, ['example_en', 'example'])),
        exampleTranslation: _nullable(
          _string(row, ['example_ko', 'example_translation']),
        ),
        partOfSpeech: partOfSpeech,
        tags: _split(_string(row, ['tags'])),
        level: _string(row, ['level'], fallback: '입문'),
        capabilities: capabilities,
        priority:
            int.tryParse(_string(row, ['priority'], fallback: '0')) ??
            (throw const FormatException('priority는 정수여야 합니다.')),
        source: ContentSource(
          name: sourceName,
          license: license,
          sourceVersion: sourceVersion,
          contentVersion: contentVersion,
        ),
      ),
    );
  }

  String _string(
    Map<String, Object?> row,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[|,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  String? _nullable(String value) => value.isEmpty ? null : value;

  String _stable(String value) =>
      unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Map<String, Object?>? _mapOrNull(Object? raw) {
    if (raw is! Map) return null;
    try {
      return Map<String, Object?>.from(raw);
    } catch (_) {
      return null;
    }
  }
}

class _ImportRow {
  const _ImportRow(this.number, this.value);

  final int number;
  final Map<String, Object?> value;
}
