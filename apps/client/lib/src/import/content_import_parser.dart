import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;
import 'package:uuid/uuid.dart';

import '../domain/content_validation.dart';
import '../domain/import_distribution.dart';
import '../domain/korean_pronunciation.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/study_subject.dart';
import 'import_limits.dart';
import 'import_column_mapping.dart';
import 'xlsx_import_reader.dart';

class ImportIssue {
  const ImportIssue({required this.row, required this.message});

  final int row;
  final String message;
}

class ImportNotice {
  const ImportNotice({required this.row, required this.message});

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
    this.notices = const [],
  });

  final List<ParsedImportEntry> entries;
  final List<ImportIssue> issues;
  final List<ImportDuplicate> duplicates;
  final List<ImportNotice> notices;

  List<LearningItem> get items =>
      entries.map((entry) => entry.item).toList(growable: false);

  Set<String> get duplicateIds =>
      duplicates.map((duplicate) => duplicate.item.id).toSet();
}

class ContentImportParser {
  const ContentImportParser({
    this.validator = const LearningContentValidator(),
    this.limits = const ImportLimits(),
  });

  final LearningContentValidator validator;
  final ImportLimits limits;

  void validateFileSize(int byteLength) => limits.ensureFileSize(byteLength);

  ImportPreview parseCsv(
    String input, {
    required LanguageTag defaultLanguage,
    String? defaultSubjectId,
    String? distributionKey,
    String? distributionGroup,
    String? routeSubjectId,
    String? routeLanguageCode,
    Map<String, String> subjectIdByDistributionKey = const {},
    Map<String, String> groupByDistributionKey = const {},
    Map<String, String> languageCodeByDistributionKey = const {},
    Map<String, String> columnMapping = const {},
  }) {
    limits.ensureTextLength(input.length);
    final rows = csv.decode(input);
    if (rows.isEmpty) {
      return const ImportPreview(entries: [], issues: [], duplicates: []);
    }
    limits.ensureRowCount(rows.length - 1);
    limits.ensureColumnCount(rows.first.length);
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
    final effectiveMapping = columnMapping.isEmpty
        ? const ImportColumnMapper().suggest(headers)
        : columnMapping;
    for (final (index, row) in rows.skip(1).indexed) {
      limits.ensureColumnCount(row.length);
      for (var column = 0; column < row.length; column++) {
        limits.ensureCellLength(
          row[column].toString().length,
          row: index + 2,
          field: column < headers.length ? headers[column] : '열 ${column + 1}',
        );
      }
      final values = <String, Object?>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < row.length ? row[index] : null,
      };
      parsedRows.add(
        _ImportRow(
          index + 2,
          const ImportColumnMapper().apply(values, effectiveMapping),
        ),
      );
    }
    return _parseRows(
      parsedRows,
      defaultLanguage: defaultLanguage,
      defaultSubjectId: defaultSubjectId,
      distributionKey: distributionKey,
      distributionGroup: distributionGroup,
      routeSubjectId: routeSubjectId,
      routeLanguageCode: routeLanguageCode,
      subjectIdByDistributionKey: subjectIdByDistributionKey,
      groupByDistributionKey: groupByDistributionKey,
      languageCodeByDistributionKey: languageCodeByDistributionKey,
    );
  }

  ImportPreview parseExcel(
    List<int> bytes, {
    required LanguageTag defaultLanguage,
    String? defaultSubjectId,
    String? distributionKey,
    String? distributionGroup,
    String? routeSubjectId,
    String? routeLanguageCode,
    Map<String, String> subjectIdByDistributionKey = const {},
    Map<String, String> groupByDistributionKey = const {},
    Map<String, String> languageCodeByDistributionKey = const {},
    Map<String, String> columnMapping = const {},
  }) {
    limits.ensureFileSize(bytes.length);
    final sheets = XlsxImportReader(limits: limits).read(bytes);
    const mapper = ImportColumnMapper();
    for (final sheet in sheets) {
      if (sheet.rows.isEmpty) continue;
      final headerIndex = mapper.findExcelHeaderIndex(
        sheet.rows,
        mapping: columnMapping,
      );
      if (headerIndex < 0) continue;
      final headers = sheet.rows[headerIndex].values
          .map((value) => value.trim().replaceFirst('\uFEFF', ''))
          .toList(growable: false);
      if (headers.any((header) => header.isEmpty)) {
        throw FormatException('${sheet.name} 시트의 헤더 이름은 비어 있을 수 없습니다.');
      }
      if (headers.toSet().length != headers.length) {
        throw FormatException('${sheet.name} 시트에 중복된 헤더 이름이 있습니다.');
      }
      final effectiveMapping = columnMapping.isEmpty
          ? mapper.suggest(headers)
          : columnMapping;
      final missing = mapper.missingRequired(effectiveMapping);
      if (missing.isNotEmpty) {
        throw FormatException(
          '${sheet.name} 시트에서 ${missing.map((field) => field.label).join('·')} 열을 찾지 못했습니다.',
        );
      }
      final parsedRows = <_ImportRow>[];
      for (final row in sheet.rows.skip(headerIndex + 1)) {
        if (row.values.every((value) => value.trim().isEmpty)) continue;
        final values = <String, Object?>{
          for (var column = 0; column < headers.length; column++)
            headers[column]: column < row.values.length
                ? row.values[column]
                : null,
        };
        parsedRows.add(
          _ImportRow(row.number, mapper.apply(values, effectiveMapping)),
        );
      }
      limits.ensureRowCount(parsedRows.length);
      return _parseRows(
        parsedRows,
        defaultLanguage: defaultLanguage,
        defaultSubjectId: defaultSubjectId,
        distributionKey: distributionKey,
        distributionGroup: distributionGroup,
        routeSubjectId: routeSubjectId,
        routeLanguageCode: routeLanguageCode,
        subjectIdByDistributionKey: subjectIdByDistributionKey,
        groupByDistributionKey: groupByDistributionKey,
        languageCodeByDistributionKey: languageCodeByDistributionKey,
      );
    }
    throw const FormatException(
      '엑셀에서 term(표현)과 meaning(뜻) 헤더가 있는 시트를 찾지 못했습니다.',
    );
  }

  ImportPreview parseJson(
    String input, {
    required LanguageTag defaultLanguage,
    String? defaultSubjectId,
    String? distributionKey,
    String? distributionGroup,
    String? routeSubjectId,
    String? routeLanguageCode,
    Map<String, String> subjectIdByDistributionKey = const {},
    Map<String, String> groupByDistributionKey = const {},
    Map<String, String> languageCodeByDistributionKey = const {},
  }) {
    limits.ensureTextLength(input.length);
    final decoded = jsonDecode(input);
    final rows = decoded is List<Object?>
        ? decoded
        : decoded is Map<String, Object?> && decoded['items'] is List<Object?>
        ? decoded['items']! as List<Object?>
        : throw const FormatException('JSON은 배열 또는 items 배열이어야 합니다.');
    limits.ensureRowCount(rows.length);
    final parsedRows = <_ImportRow>[];
    final issues = <ImportIssue>[];
    for (final (index, raw) in rows.indexed) {
      final map = _mapOrNull(raw);
      if (map == null) {
        issues.add(
          ImportIssue(row: index + 1, message: '각 항목은 JSON 객체여야 합니다.'),
        );
      } else {
        limits.ensureMapCells(map, rowNumber: index + 1);
        parsedRows.add(_ImportRow(index + 1, map));
      }
    }
    final parsed = _parseRows(
      parsedRows,
      defaultLanguage: defaultLanguage,
      defaultSubjectId: defaultSubjectId,
      distributionKey: distributionKey,
      distributionGroup: distributionGroup,
      routeSubjectId: routeSubjectId,
      routeLanguageCode: routeLanguageCode,
      subjectIdByDistributionKey: subjectIdByDistributionKey,
      groupByDistributionKey: groupByDistributionKey,
      languageCodeByDistributionKey: languageCodeByDistributionKey,
    );
    return ImportPreview(
      entries: parsed.entries,
      issues: [...issues, ...parsed.issues],
      duplicates: parsed.duplicates,
      notices: parsed.notices,
    );
  }

  ImportPreview parseJsonLines(
    String input, {
    required LanguageTag defaultLanguage,
    String? defaultSubjectId,
    String? distributionKey,
    String? distributionGroup,
    String? routeSubjectId,
    String? routeLanguageCode,
    Map<String, String> subjectIdByDistributionKey = const {},
    Map<String, String> groupByDistributionKey = const {},
    Map<String, String> languageCodeByDistributionKey = const {},
  }) {
    limits.ensureTextLength(input.length);
    final rows = <_ImportRow>[];
    final issues = <ImportIssue>[];
    final lines = const LineSplitter().convert(input);
    limits.ensureRowCount(lines.where((line) => line.trim().isNotEmpty).length);
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(lines[index]);
        final map = _mapOrNull(decoded);
        if (map == null) {
          throw const FormatException();
        }
        limits.ensureMapCells(map, rowNumber: index + 1);
        rows.add(_ImportRow(index + 1, map));
      } on ImportLimitException {
        rethrow;
      } catch (_) {
        issues.add(ImportIssue(row: index + 1, message: '올바른 JSON 객체가 아닙니다.'));
      }
    }
    final parsed = _parseRows(
      rows,
      defaultLanguage: defaultLanguage,
      defaultSubjectId: defaultSubjectId,
      distributionKey: distributionKey,
      distributionGroup: distributionGroup,
      routeSubjectId: routeSubjectId,
      routeLanguageCode: routeLanguageCode,
      subjectIdByDistributionKey: subjectIdByDistributionKey,
      groupByDistributionKey: groupByDistributionKey,
      languageCodeByDistributionKey: languageCodeByDistributionKey,
    );
    return ImportPreview(
      entries: parsed.entries,
      issues: [...issues, ...parsed.issues],
      duplicates: parsed.duplicates,
      notices: parsed.notices,
    );
  }

  ImportPreview _parseRows(
    List<_ImportRow> rows, {
    required LanguageTag defaultLanguage,
    String? defaultSubjectId,
    String? distributionKey,
    String? distributionGroup,
    String? routeSubjectId,
    String? routeLanguageCode,
    Map<String, String> subjectIdByDistributionKey = const {},
    Map<String, String> groupByDistributionKey = const {},
    Map<String, String> languageCodeByDistributionKey = const {},
  }) {
    limits.ensureRowCount(rows.length);
    final entries = <ParsedImportEntry>[];
    final issues = <ImportIssue>[];
    final notices = <ImportNotice>[];
    final seenIds = <String, int>{};
    final seenContentKeys = <String, int>{};
    final entryIndexesByIdentity = <String, int>{};
    final duplicates = <ImportDuplicate>[];
    var generatedCandidates = 0;

    void addCandidate(LearningItem item, int rowNumber) {
      generatedCandidates++;
      limits.ensureGeneratedItemCount(generatedCandidates);
      final contentKey = validator.duplicateKey(item);
      final identityKey = validator.identityKey(item);
      final mergeIndex = entryIndexesByIdentity[identityKey];
      final duplicateIdRow = seenIds[item.id];
      final duplicateContentRow = seenContentKeys[contentKey];
      if (duplicateIdRow != null || duplicateContentRow != null) {
        if (mergeIndex != null) {
          final previous = entries[mergeIndex];
          entries[mergeIndex] = ParsedImportEntry(
            row: previous.row,
            item: _mergeRows(previous.item, item),
          );
        }
        duplicates.add(
          ImportDuplicate(
            row: rowNumber,
            firstRow: duplicateIdRow ?? duplicateContentRow!,
            item: item,
            kind: duplicateIdRow != null
                ? ImportDuplicateKind.id
                : ImportDuplicateKind.semantic,
          ),
        );
        return;
      }
      if (mergeIndex != null) {
        final previous = entries[mergeIndex];
        entries[mergeIndex] = ParsedImportEntry(
          row: previous.row,
          item: _mergeRows(previous.item, item),
        );
        seenIds[item.id] = rowNumber;
        seenContentKeys[contentKey] = rowNumber;
        return;
      }
      seenIds[item.id] = rowNumber;
      seenContentKeys[contentKey] = rowNumber;
      entryIndexesByIdentity[identityKey] = entries.length;
      entries.add(ParsedImportEntry(row: rowNumber, item: item));
    }

    for (final row in rows) {
      final noticeStart = notices.length;
      try {
        final item = _parseItem(
          row.value,
          defaultLanguage: defaultLanguage,
          defaultSubjectId: defaultSubjectId,
          distributionKey: distributionKey,
          distributionGroup: distributionGroup,
          routeSubjectId: routeSubjectId,
          routeLanguageCode: routeLanguageCode,
          subjectIdByDistributionKey: subjectIdByDistributionKey,
          groupByDistributionKey: groupByDistributionKey,
          languageCodeByDistributionKey: languageCodeByDistributionKey,
          rowNumber: row.number,
          notices: notices,
        );
        addCandidate(item, row.number);
        for (final example in _parseExampleSentences(
          row.value,
          parent: item,
          rowNumber: row.number,
          issues: issues,
          notices: notices,
        )) {
          addCandidate(example, row.number);
        }
      } on ImportLimitException {
        rethrow;
      } on FormatException catch (error) {
        notices.removeRange(noticeStart, notices.length);
        issues.add(ImportIssue(row: row.number, message: error.message));
      } on LearningContentValidationException catch (error) {
        notices.removeRange(noticeStart, notices.length);
        issues.add(ImportIssue(row: row.number, message: error.toString()));
      }
    }
    return ImportPreview(
      entries: entries,
      issues: issues,
      duplicates: duplicates,
      notices: notices,
    );
  }

  List<LearningItem> _parseExampleSentences(
    Map<String, Object?> row, {
    required LearningItem parent,
    required int rowNumber,
    required List<ImportIssue> issues,
    required List<ImportNotice> notices,
  }) {
    if (parent.kind != LearningItemKind.word) return const [];
    final pairs =
        <
          ({
            String text,
            String translation,
            List<String> tokens,
            String koreanPronunciation,
          })
        >[];

    void addPair({
      required String label,
      required String text,
      required String translation,
      List<String> tokens = const [],
      String koreanPronunciation = '',
    }) {
      if (text.isEmpty && translation.isEmpty) return;
      if (text.isEmpty || translation.isEmpty) {
        issues.add(
          ImportIssue(
            row: rowNumber,
            message: '$label은 예문과 예문 뜻을 모두 입력해야 문장 학습 항목으로 추가됩니다.',
          ),
        );
        return;
      }
      pairs.add((
        text: text,
        translation: translation,
        tokens: tokens,
        koreanPronunciation: koreanPronunciation,
      ));
    }

    addPair(
      label: '첫 번째 예문',
      text: _string(row, ['example_en', 'example']),
      translation: _string(row, ['example_ko', 'example_translation']),
      tokens: _split(_string(row, ['example_tokens', 'example_1_tokens'])),
      koreanPronunciation: _string(row, [
        'example_pronunciation',
        'example_korean_pronunciation',
        'example_1_pronunciation',
        'example_1_korean_pronunciation',
      ]),
    );
    for (var index = 2; index <= 10; index++) {
      addPair(
        label: '$index번째 예문',
        text: _string(row, [
          'example_$index',
          'example${index}_en',
          'example_${index}_en',
        ]),
        translation: _string(row, [
          'example_${index}_translation',
          'example${index}_translation',
          'example_${index}_ko',
        ]),
        tokens: _split(
          _string(row, ['example_${index}_tokens', 'example${index}_tokens']),
        ),
        koreanPronunciation: _string(row, [
          'example_${index}_pronunciation',
          'example${index}_pronunciation',
          'example_${index}_korean_pronunciation',
          'example${index}_korean_pronunciation',
        ]),
      );
    }

    final examples = _splitExampleList(_string(row, ['examples']));
    final translations = _splitExampleList(
      _string(row, ['example_translations']),
    );
    final pronunciations = _splitExampleList(
      _string(row, ['example_pronunciations']),
    );
    final listLength = examples.length > translations.length
        ? examples.length
        : translations.length;
    for (var index = 0; index < listLength; index++) {
      addPair(
        label: 'examples ${index + 1}번',
        text: index < examples.length ? examples[index] : '',
        translation: index < translations.length ? translations[index] : '',
        koreanPronunciation: index < pronunciations.length
            ? pronunciations[index]
            : '',
      );
    }

    final unique =
        <
              String,
              ({
                String text,
                String translation,
                List<String> tokens,
                String koreanPronunciation,
              })
            >{
              for (final pair in pairs)
                '${_stable(pair.text)}|${_stable(pair.translation)}': pair,
            }
            .values;
    return [
      for (final pair in unique)
        _exampleSentence(
          parent: parent,
          pair: pair,
          rowNumber: rowNumber,
          notices: notices,
        ),
    ];
  }

  LearningItem _exampleSentence({
    required LearningItem parent,
    required ({
      String text,
      String translation,
      List<String> tokens,
      String koreanPronunciation,
    })
    pair,
    required int rowNumber,
    required List<ImportNotice> notices,
  }) {
    final stableName = [
      parent.effectiveSubjectId,
      parent.learningLanguage.code,
      LearningItemKind.sentence.name,
      _stable(pair.text),
      _stable(pair.translation),
      '',
    ].join('|');
    final capabilities = <ExerciseCapability>{
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.listening,
      if (pair.tokens.length >= 2) ExerciseCapability.cloze,
      if (pair.tokens.length >= 2) ExerciseCapability.sentenceOrder,
    };
    final koreanPronunciation = parent.learningLanguage == LanguageTag.korean
        ? null
        : pair.koreanPronunciation.isNotEmpty
        ? pair.koreanPronunciation
        : tryDeriveKoreanPronunciation(
            language: parent.learningLanguage,
            text: pair.text,
          );
    if (koreanPronunciation == null &&
        _needsReadingHelper(parent.learningLanguage)) {
      notices.add(
        ImportNotice(
          row: rowNumber,
          message: _missingReadingNotice(
            parent.learningLanguage,
            target: '예문 "${_previewLabel(pair.text)}"',
          ),
        ),
      );
    }
    return validator.ensureValid(
      LearningItem(
        id: const Uuid().v5(Namespace.url.value, 'sprache:$stableName'),
        kind: LearningItemKind.sentence,
        learningLanguage: parent.learningLanguage,
        subjectId: parent.effectiveSubjectId,
        text: pair.text,
        translations: [pair.translation],
        acceptedAnswers: [pair.translation],
        readings: [
          if (koreanPronunciation != null)
            Reading(scheme: ReadingScheme.hangul, value: koreanPronunciation),
        ],
        sentenceTokens: pair.tokens,
        tags: parent.tags,
        level: parent.level,
        capabilities: capabilities,
        priority: parent.priority,
        source: parent.source,
      ),
    );
  }

  LearningItem _parseItem(
    Map<String, Object?> row, {
    required LanguageTag defaultLanguage,
    String? defaultSubjectId,
    String? distributionKey,
    String? distributionGroup,
    String? routeSubjectId,
    String? routeLanguageCode,
    Map<String, String> subjectIdByDistributionKey = const {},
    Map<String, String> groupByDistributionKey = const {},
    Map<String, String> languageCodeByDistributionKey = const {},
    required int rowNumber,
    required List<ImportNotice> notices,
  }) {
    final type = _string(row, ['type', 'kind'], fallback: 'word');
    final kind = switch (type.toLowerCase()) {
      'word' || '단어' => LearningItemKind.word,
      'sentence' || '문장' => LearningItemKind.sentence,
      _ => throw const FormatException('type은 word 또는 sentence여야 합니다.'),
    };
    final text = _string(row, ['term', 'text', 'en', 'foreign']);
    final rawMeaning = _string(row, ['meaning', 'translation', 'ko']);
    if (text.isEmpty) {
      throw const FormatException('학습할 외국어 텍스트가 비어 있습니다.');
    }
    final meanings = _splitMeanings(rawMeaning);
    if (meanings.isEmpty) {
      throw const FormatException('한국어 뜻이 비어 있습니다.');
    }
    final routeDistributionKey = distributionKey?.trim() ?? '';
    final rawDistributionKey = routeDistributionKey.isNotEmpty
        ? routeDistributionKey
        : _string(row, [
            'distribution_key',
            'routing_key',
            'upload_key',
            '분배_키',
          ]);
    final effectiveDistributionKey = rawDistributionKey.isEmpty
        ? ''
        : normalizeImportDistributionKey(rawDistributionKey);
    final fallbackRoute = effectiveDistributionKey.isEmpty
        ? null
        : fallbackImportDistributionRouteFor(effectiveDistributionKey);
    final keyedLanguageCode = effectiveDistributionKey.isEmpty
        ? null
        : languageCodeByDistributionKey[effectiveDistributionKey] ??
              fallbackRoute?.languageCode;
    final rowLanguageCode = _string(row, ['language', 'language_tag']);
    final languageCode =
        routeLanguageCode ??
        keyedLanguageCode ??
        (rowLanguageCode.isEmpty ? defaultLanguage.code : rowLanguageCode);
    final language = LanguageTag.values.firstWhere(
      (value) => value.code == languageCode,
      orElse: () =>
          throw FormatException('지원하지 않는 language 값입니다: $languageCode'),
    );
    final keyedSubjectId = effectiveDistributionKey.isEmpty
        ? null
        : subjectIdByDistributionKey[effectiveDistributionKey] ??
              fallbackRoute?.subjectId;
    final subjectId = normalizeStudySubjectId(
      routeSubjectId ??
          keyedSubjectId ??
          _string(row, [
            'subject_id',
            'subjectId',
            'course_id',
          ], fallback: defaultSubjectId ?? languageSubjectId(language)),
    );
    final accepted = [
      ...meanings,
      ..._split(_string(row, ['accepted_answers'])),
    ];
    final genericReading = _string(row, ['reading']);
    final kana = _string(row, ['kana']);
    final romaji = _string(row, ['romaji']);
    final pinyin = _string(row, ['pinyin']);
    final hangul = _string(row, [
      'korean_pronunciation',
      'korean_reading',
      'hangul',
      'ko_pronunciation',
      '한국어_발음',
      '한글_발음',
    ]);
    if (genericReading.isNotEmpty && language == LanguageTag.korean) {
      throw FormatException(
        '${language.koreanName} 학습 항목에는 별도 읽기 표기가 필요하지 않습니다.',
      );
    }
    final effectiveKana = kana.isNotEmpty
        ? kana
        : language == LanguageTag.japanese
        ? genericReading
        : '';
    final effectivePinyin = pinyin.isNotEmpty
        ? pinyin
        : language == LanguageTag.simplifiedChinese
        ? genericReading
        : '';
    final explicitHangul = hangul.isNotEmpty
        ? hangul
        : language != LanguageTag.japanese &&
              language != LanguageTag.simplifiedChinese &&
              language != LanguageTag.korean
        ? genericReading
        : '';
    final generatedHangul = explicitHangul.isNotEmpty
        ? null
        : language == LanguageTag.korean
        ? null
        : tryDeriveKoreanPronunciation(
            language: language,
            text: text,
            reading: language == LanguageTag.japanese
                ? effectiveKana
                : language == LanguageTag.simplifiedChinese
                ? effectivePinyin
                : null,
            romanization: romaji,
          );
    final effectiveHangul = explicitHangul.isNotEmpty
        ? explicitHangul
        : generatedHangul;
    if (effectiveHangul == null && _needsReadingHelper(language)) {
      notices.add(
        ImportNotice(
          row: rowNumber,
          message: _missingReadingNotice(
            language,
            target: '"${_previewLabel(text)}"',
          ),
        ),
      );
    }
    final readings = <Reading>[
      if (effectiveKana.isNotEmpty)
        Reading(scheme: ReadingScheme.kana, value: effectiveKana),
      if (romaji.isNotEmpty)
        Reading(scheme: ReadingScheme.romaji, value: romaji),
      if (effectivePinyin.isNotEmpty)
        Reading(scheme: ReadingScheme.pinyin, value: effectivePinyin),
      if (effectiveHangul != null)
        Reading(scheme: ReadingScheme.hangul, value: effectiveHangul),
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
    final sourceId = _string(row, [
      'source_id',
      'sourceId',
    ], fallback: _string(sourceMap ?? const {}, ['sourceId', 'source_id']));
    final sourceUrl = _string(
      row,
      ['source_url', 'sourceUrl'],
      fallback: _string(sourceMap ?? const {}, [
        'sourceUrl',
        'source_url',
        'url',
      ]),
    );
    final author = _string(row, [
      'author',
      'creator',
    ], fallback: _string(sourceMap ?? const {}, ['author', 'creator']));
    final attribution = _string(row, [
      'attribution',
    ], fallback: _string(sourceMap ?? const {}, ['attribution']));
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
    final keyedGroup = effectiveDistributionKey.isEmpty
        ? null
        : groupByDistributionKey[effectiveDistributionKey];
    final effectiveDistributionGroup =
        distributionGroup != null && distributionGroup.trim().isNotEmpty
        ? distributionGroup
        : keyedGroup;
    final groups = <String>{
      ..._split(_string(row, ['group', 'groups', 'learning_group', 'deck'])),
      if (effectiveDistributionGroup != null &&
          effectiveDistributionGroup.trim().isNotEmpty)
        normalizeLearningGroupName(effectiveDistributionGroup),
    };
    final tags = <String>{
      ..._split(_string(row, ['tags'])),
      for (final group in groups) learningGroupTag(group),
      if (effectiveDistributionKey.isNotEmpty)
        importDistributionTag(effectiveDistributionKey),
    }.toList();
    final stableName = [
      subjectId,
      language.code,
      kind.name,
      _stable(text),
      _stable(meanings.first),
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
        subjectId: subjectId,
        text: text,
        translations: meanings,
        acceptedAnswers: accepted,
        readings: readings,
        sentenceTokens: sentenceTokens,
        example: _nullable(_string(row, ['example_en', 'example'])),
        exampleTranslation: _nullable(
          _string(row, ['example_ko', 'example_translation']),
        ),
        partOfSpeech: partOfSpeech,
        tags: tags,
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
          sourceId: _nullable(sourceId),
          sourceUrl: _nullable(sourceUrl),
          author: _nullable(author),
          attribution: _nullable(attribution),
        ),
      ),
    );
  }

  LearningItem _mergeRows(LearningItem previous, LearningItem incoming) {
    final translations = <String>{
      ...previous.translations,
      ...incoming.translations,
    }.toList();
    final accepted = <String>{
      ...previous.acceptedAnswers,
      ...incoming.acceptedAnswers,
      ...translations,
    }.toList();
    final readings = <String, Reading>{
      for (final reading in [...previous.readings, ...incoming.readings])
        '${reading.scheme.name}:${_stable(reading.value)}': reading,
    }.values.toList(growable: false);
    final distributionKey =
        importDistributionKeyOf(previous) ?? importDistributionKeyOf(incoming);
    final mergedTags = tagsWithoutImportDistributionKeys([
      ...previous.tags,
      ...incoming.tags,
    ]);
    return validator.ensureValid(
      previous.copyWith(
        translations: translations,
        acceptedAnswers: accepted,
        readings: readings,
        tags: distributionKey == null
            ? mergedTags
            : tagsWithImportDistributionKey(mergedTags, distributionKey),
        example: previous.example ?? incoming.example,
        exampleTranslation:
            previous.exampleTranslation ?? incoming.exampleTranslation,
        priority: previous.priority >= incoming.priority
            ? previous.priority
            : incoming.priority,
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

  List<String> _splitMeanings(String value) => value
      .split('|')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  List<String> _splitExampleList(String value) => value
      .split(RegExp(r'\r?\n|\|'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  String? _nullable(String value) => value.isEmpty ? null : value;

  String _stable(String value) =>
      unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _needsReadingHelper(LanguageTag language) =>
      language == LanguageTag.japanese ||
      language == LanguageTag.simplifiedChinese;

  String _missingReadingNotice(
    LanguageTag language, {
    required String target,
  }) => switch (language) {
    LanguageTag.japanese =>
      '$target의 한자 발음을 추측하지 않았습니다. kana 또는 romaji를 추가하면 '
          '한국어 읽기를 자동으로 보완할 수 있습니다. 기기 음성 재생은 계속 사용할 수 있습니다.',
    LanguageTag.simplifiedChinese =>
      '$target의 한자 발음을 추측하지 않았습니다. pinyin을 추가하면 '
          '한국어 읽기를 자동으로 보완할 수 있습니다. 기기 음성 재생은 계속 사용할 수 있습니다.',
    _ => '',
  };

  String _previewLabel(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.runes.length <= 24) return normalized;
    return '${String.fromCharCodes(normalized.runes.take(24))}…';
  }

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
