import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'language.dart';
import 'learning_item.dart';
import 'study_subject.dart';

enum ContentIssueSeverity { warning, error }

class ContentValidationIssue {
  const ContentValidationIssue({
    required this.code,
    required this.field,
    required this.message,
    required this.severity,
  });

  final String code;
  final String field;
  final String message;
  final ContentIssueSeverity severity;
}

class ContentValidationResult {
  const ContentValidationResult({required this.item, required this.issues});

  final LearningItem item;
  final List<ContentValidationIssue> issues;

  List<ContentValidationIssue> get errors => issues
      .where((issue) => issue.severity == ContentIssueSeverity.error)
      .toList(growable: false);

  List<ContentValidationIssue> get warnings => issues
      .where((issue) => issue.severity == ContentIssueSeverity.warning)
      .toList(growable: false);

  bool get isValid => errors.isEmpty;
}

class LearningContentValidationException implements Exception {
  const LearningContentValidationException(this.itemId, this.issues);

  final String itemId;
  final List<ContentValidationIssue> issues;

  @override
  String toString() => issues.map((issue) => issue.message).join(' ');
}

ContentValidationIssue? inspectReadingFormat(
  ReadingScheme scheme,
  String source,
) {
  final value = unicode.nfkc(source).trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) return null;

  ContentValidationIssue error(String code, String message) {
    return ContentValidationIssue(
      code: code,
      field: 'readings',
      message: message,
      severity: ContentIssueSeverity.error,
    );
  }

  bool isAsciiLetter(int rune) =>
      (rune >= 0x41 && rune <= 0x5a) || (rune >= 0x61 && rune <= 0x7a);
  bool isSharedSeparator(int rune) => const {
    0x20, // space
    0x2d, // -
    0x27, // '
    0x2019, // ’
    0x2e, // .
    0x2c, // ,
    0x21, // !
    0x3f, // ?
  }.contains(rune);

  switch (scheme) {
    case ReadingScheme.kana:
      final valid = value.runes.every(
        (rune) =>
            (rune >= 0x3040 && rune <= 0x30ff) ||
            (rune >= 0x31f0 && rune <= 0x31ff) ||
            isSharedSeparator(rune) ||
            const {
              0x20,
              0x3001, // 、
              0x3002, // 。
              0x30fb, // ・
              0xff01, // ！
              0xff1f, // ？
              0x301c, // 〜
              0xff5e, // ～
            }.contains(rune),
      );
      if (!valid) {
        return error('kana_format', '가나 읽기에는 히라가나·가타카나와 문장부호만 입력하세요. 예: みず');
      }
      break;
    case ReadingScheme.romaji:
      const romanizationLetters = 'āīūēōĀĪŪĒŌâîûêôÂÎÛÊÔ';
      final hasLetter = value.runes.any(isAsciiLetter);
      final valid = value.runes.every(
        (rune) =>
            isAsciiLetter(rune) ||
            romanizationLetters.runes.contains(rune) ||
            isSharedSeparator(rune),
      );
      if (!valid || !hasLetter) {
        return error(
          'romaji_format',
          '로마자에는 라틴 문자와 장음 부호만 입력하세요. 예: mizu 또는 Tōkyō',
        );
      }
      break;
    case ReadingScheme.pinyin:
      const markedPinyinLetters =
          'āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüê'
          'ĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛÜÊ';
      final hasLetter = value.runes.any(
        (rune) =>
            isAsciiLetter(rune) || markedPinyinLetters.runes.contains(rune),
      );
      final hasToneMark = value.runes.any(markedPinyinLetters.runes.contains);
      final hasToneNumber = value.runes.any(
        (rune) => rune >= 0x31 && rune <= 0x35,
      );
      final hasInvalidNumber = value.runes.any(
        (rune) => rune >= 0x30 && rune <= 0x39 && (rune < 0x31 || rune > 0x35),
      );
      final validCharacters = value.runes.every(
        (rune) =>
            isAsciiLetter(rune) ||
            markedPinyinLetters.runes.contains(rune) ||
            (rune >= 0x31 && rune <= 0x35) ||
            rune == 0x3a ||
            isSharedSeparator(rune),
      );
      if (!validCharacters || !hasLetter || hasInvalidNumber) {
        return error(
          'pinyin_format',
          '병음에는 라틴 문자와 성조 부호 또는 음절 끝 숫자 1~5만 입력하세요. 예: shuǐ 또는 shui3',
        );
      }
      if (hasToneMark && hasToneNumber) {
        return error(
          'pinyin_mixed_tone',
          '병음 성조 부호와 숫자 표기를 한 읽기 안에서 섞지 마세요. shuǐ 또는 shui3 중 하나를 사용하세요.',
        );
      }
      final withoutUmlautShortcut = value
          .replaceAll('u:', 'u')
          .replaceAll('U:', 'U');
      if (withoutUmlautShortcut.contains(':')) {
        return error(
          'pinyin_umlaut_format',
          '병음의 콜론 표기는 u:에만 사용할 수 있습니다. 가능하면 ü를 사용하세요.',
        );
      }
      if (hasToneNumber) {
        final syllables = value
            .split(RegExp(r"[\s\-'\u2019.,!?]+"))
            .where((part) => part.isNotEmpty);
        final numericSyllable = RegExp(r'^[A-Za-züÜvV:]+[1-5]$', unicode: true);
        if (syllables.any(
          (syllable) =>
              RegExp(r'[1-5]').hasMatch(syllable) &&
              !numericSyllable.hasMatch(syllable),
        )) {
          return error(
            'pinyin_tone_number',
            '숫자 성조는 각 병음 음절의 끝에 한 번만 적으세요. 예: ni3 hao3',
          );
        }
      }
      break;
    case ReadingScheme.hangul:
      final hasHangul = value.runes.any(
        (rune) =>
            (rune >= 0x1100 && rune <= 0x11ff) ||
            (rune >= 0x3130 && rune <= 0x318f) ||
            (rune >= 0xac00 && rune <= 0xd7a3),
      );
      final valid = value.runes.every(
        (rune) =>
            (rune >= 0x1100 && rune <= 0x11ff) ||
            (rune >= 0x3130 && rune <= 0x318f) ||
            (rune >= 0xac00 && rune <= 0xd7a3) ||
            isSharedSeparator(rune) ||
            const {
              0x2f, // /
              0x28, // (
              0x29, // )
              0xb7, // ·
              0x3001, // 、
              0x3002, // 。
              0xff01, // ！
              0xff1f, // ？
            }.contains(rune),
      );
      if (!valid || !hasHangul) {
        return error(
          'hangul_reading_format',
          '한국어 발음에는 한글과 문장부호만 입력하세요. 예: 헬로우, 니 하오',
        );
      }
  }
  return null;
}

class LearningContentValidator {
  const LearningContentValidator();

  ContentValidationResult inspect(LearningItem source) {
    final item = _normalize(source);
    final issues = <ContentValidationIssue>[];
    final profile = LanguageProfile.of(item.learningLanguage);

    _requiredLength(issues, value: item.id, field: 'id', label: 'ID', max: 160);
    _requiredLength(
      issues,
      value: item.effectiveSubjectId,
      field: 'subjectId',
      label: '학습 주제 ID',
      max: 80,
    );
    try {
      normalizeStudySubjectId(item.effectiveSubjectId);
    } on FormatException catch (error) {
      _error(issues, 'subject_id_format', 'subjectId', error.message);
    }
    if (item.id.contains(RegExp(r'[\x00-\x20]'))) {
      _error(issues, 'id_format', 'id', 'ID에는 공백이나 제어 문자를 사용할 수 없습니다.');
    }
    _requiredLength(
      issues,
      value: item.text,
      field: 'text',
      label: '학습 표현',
      max: 600,
    );
    if (item.translations.isEmpty) {
      _error(issues, 'translation_required', 'translations', '한국어 뜻이 필요합니다.');
    }
    if (item.translations.length > 20) {
      _error(
        issues,
        'translation_limit',
        'translations',
        '뜻은 항목당 20개까지 저장할 수 있습니다.',
      );
    }
    for (final translation in item.translations) {
      _requiredLength(
        issues,
        value: translation,
        field: 'translations',
        label: '뜻',
        max: 600,
      );
    }
    if (item.acceptedAnswers.isEmpty) {
      _error(
        issues,
        'answer_required',
        'acceptedAnswers',
        '허용 정답이 한 개 이상 필요합니다.',
      );
    }
    if (item.acceptedAnswers.length > 50) {
      _error(
        issues,
        'answer_limit',
        'acceptedAnswers',
        '허용 정답은 항목당 50개까지 저장할 수 있습니다.',
      );
    }
    if (item.readings.length > 8) {
      _error(
        issues,
        'reading_limit',
        'readings',
        '읽기 표기는 항목당 8개까지 저장할 수 있습니다.',
      );
    }
    for (final reading in item.readings) {
      if (!profile.readingSchemes.contains(reading.scheme)) {
        _error(
          issues,
          'reading_scheme',
          'readings',
          '${item.learningLanguage.koreanName}에서는 ${reading.scheme.name} 읽기 표기를 사용할 수 없습니다.',
        );
      }
      _requiredLength(
        issues,
        value: reading.value,
        field: 'readings',
        label: '읽기 표기',
        max: 300,
      );
      final formatIssue = inspectReadingFormat(reading.scheme, reading.value);
      if (formatIssue != null) {
        issues.add(formatIssue);
      }
    }
    if (item.tags.length > 24) {
      _error(issues, 'tag_limit', 'tags', '태그는 항목당 24개까지 저장할 수 있습니다.');
    }
    if (item.sentenceTokens.length > 200) {
      _error(
        issues,
        'token_limit',
        'sentenceTokens',
        '문장 토큰은 항목당 200개까지 저장할 수 있습니다.',
      );
    }
    if (item.level.length > 30) {
      _error(issues, 'level_limit', 'level', '난이도 이름은 30자 이하여야 합니다.');
    }
    _requiredLength(
      issues,
      value: item.source.name,
      field: 'source.name',
      label: '출처 이름',
      max: 120,
    );
    _requiredLength(
      issues,
      value: item.source.license,
      field: 'source.license',
      label: '라이선스',
      max: 80,
    );
    _requiredLength(
      issues,
      value: item.source.sourceVersion,
      field: 'source.sourceVersion',
      label: '출처 버전',
      max: 80,
    );
    _optionalLength(
      issues,
      value: item.source.sourceId,
      field: 'source.sourceId',
      label: '원문 ID',
      max: 240,
    );
    _optionalLength(
      issues,
      value: item.source.sourceUrl,
      field: 'source.sourceUrl',
      label: '원문 URL',
      max: 1000,
    );
    _optionalLength(
      issues,
      value: item.source.author,
      field: 'source.author',
      label: '원문 작성자',
      max: 240,
    );
    _optionalLength(
      issues,
      value: item.source.attribution,
      field: 'source.attribution',
      label: '출처 표시문',
      max: 1000,
    );
    final sourceUrl = item.source.sourceUrl;
    final parsedSourceUrl = sourceUrl == null ? null : Uri.tryParse(sourceUrl);
    if (sourceUrl != null &&
        (parsedSourceUrl == null ||
            !parsedSourceUrl.hasAuthority ||
            !const {'http', 'https'}.contains(parsedSourceUrl.scheme))) {
      _error(
        issues,
        'source_url_format',
        'source.sourceUrl',
        '원문 URL은 http 또는 https 주소여야 합니다.',
      );
    }
    if (item.source.contentVersion < 1 ||
        item.source.contentVersion > 1000000) {
      _error(
        issues,
        'content_version_range',
        'source.contentVersion',
        '콘텐츠 버전은 1부터 1,000,000 사이여야 합니다.',
      );
    }
    if (item.priority < 0 || item.priority > 10) {
      _error(issues, 'priority_range', 'priority', '학습 우선순위는 0부터 10 사이여야 합니다.');
    }
    if (item.capabilities.isEmpty) {
      _error(
        issues,
        'capability_required',
        'capabilities',
        '사용 가능한 학습 방식이 한 개 이상 필요합니다.',
      );
    }

    if (item.kind == LearningItemKind.word) {
      if (item.sentenceTokens.isNotEmpty) {
        _error(
          issues,
          'word_tokens',
          'sentenceTokens',
          '단어 항목에는 문장 배열 토큰을 넣을 수 없습니다.',
        );
      }
      if (item.capabilities.contains(ExerciseCapability.sentenceOrder) ||
          item.capabilities.contains(ExerciseCapability.cloze)) {
        _error(
          issues,
          'word_capability',
          'capabilities',
          '단어 항목에는 문장 배열이나 문장 빈칸 방식을 사용할 수 없습니다.',
        );
      }
      if (item.partOfSpeech == null) {
        _warning(
          issues,
          'part_of_speech_missing',
          'partOfSpeech',
          '같은 철자의 다른 용법을 구분하려면 품사를 지정하는 것이 좋습니다.',
        );
      }
    } else {
      if (item.partOfSpeech != null) {
        _error(
          issues,
          'sentence_part_of_speech',
          'partOfSpeech',
          '문장 항목에는 품사를 지정할 수 없습니다.',
        );
      }
      final usesTokenExercise =
          item.capabilities.contains(ExerciseCapability.sentenceOrder) ||
          item.capabilities.contains(ExerciseCapability.cloze);
      if (item.sentenceTokens.isNotEmpty || usesTokenExercise) {
        if (item.sentenceTokens.length < 2) {
          _error(
            issues,
            'sentence_tokens_required',
            'sentenceTokens',
            '문장 배열 학습에는 두 개 이상의 명시적 토큰이 필요합니다.',
          );
        } else if (_comparable(item.sentenceTokens.join()) !=
            _comparable(item.text)) {
          _error(
            issues,
            'sentence_tokens_mismatch',
            'sentenceTokens',
            '문장 토큰을 합친 결과가 학습 문장과 일치하지 않습니다.',
          );
        }
      }
    }

    if (profile.readingSchemes.isNotEmpty && item.readings.isEmpty) {
      _warning(
        issues,
        'reading_missing',
        'readings',
        '${item.learningLanguage.koreanName} 발음 학습을 위해 읽기 표기를 추가하는 것이 좋습니다.',
      );
    }
    if (item.translations.isNotEmpty &&
        _comparable(item.text) == _comparable(item.translations.first)) {
      _warning(
        issues,
        'translation_same_as_text',
        'translations',
        '학습 표현과 한국어 뜻이 같습니다. 번역을 다시 확인해 주세요.',
      );
    }

    return ContentValidationResult(
      item: item,
      issues: List.unmodifiable(issues),
    );
  }

  LearningItem ensureValid(LearningItem item) {
    final result = inspect(item);
    if (!result.isValid) {
      throw LearningContentValidationException(result.item.id, result.errors);
    }
    return result.item;
  }

  String duplicateKey(LearningItem item) {
    final normalized = _normalize(item);
    return [
      normalized.effectiveSubjectId,
      normalized.learningLanguage.code,
      normalized.kind.name,
      _comparable(normalized.text),
      if (normalized.translations.isNotEmpty)
        _comparable(normalized.translations.first),
      normalized.partOfSpeech?.name ?? '',
    ].join('|');
  }

  String identityKey(LearningItem item) {
    final normalized = _normalize(item);
    return [
      normalized.effectiveSubjectId,
      normalized.learningLanguage.code,
      normalized.kind.name,
      _comparable(normalized.text),
      normalized.partOfSpeech?.name ?? '',
    ].join('|');
  }

  LearningItem _normalize(LearningItem item) {
    final translations = _deduplicate(item.translations);
    final acceptedAnswers = _deduplicate([
      ...translations,
      ...item.acceptedAnswers,
    ]);
    final readings = <Reading>[];
    final readingKeys = <String>{};
    for (final reading in item.readings) {
      final value = _singleLine(reading.value);
      final key = '${reading.scheme.name}|${_comparable(value)}';
      if (value.isNotEmpty && readingKeys.add(key)) {
        readings.add(Reading(scheme: reading.scheme, value: value));
      }
    }

    return LearningItem(
      id: _singleLine(item.id),
      kind: item.kind,
      learningLanguage: item.learningLanguage,
      subjectId: normalizeStudySubjectId(item.effectiveSubjectId),
      text: _singleLine(item.text),
      translations: translations,
      acceptedAnswers: acceptedAnswers,
      readings: readings,
      sentenceTokens: _deduplicate(
        item.sentenceTokens,
        preserveRepeatedValues: true,
      ),
      example: _optional(item.example),
      exampleTranslation: _optional(item.exampleTranslation),
      partOfSpeech: item.partOfSpeech,
      tags: _deduplicate(item.tags),
      level: _singleLine(item.level),
      capabilities: Set.unmodifiable(item.capabilities),
      priority: item.priority,
      source: ContentSource(
        name: _singleLine(item.source.name),
        license: _singleLine(item.source.license),
        sourceVersion: _singleLine(item.source.sourceVersion),
        contentVersion: item.source.contentVersion,
        sourceId: _optional(item.source.sourceId),
        sourceUrl: _optional(item.source.sourceUrl),
        author: _optional(item.source.author),
        attribution: _optional(item.source.attribution),
      ),
      updatedAt: item.updatedAt?.toUtc(),
    );
  }

  List<String> _deduplicate(
    Iterable<String> values, {
    bool preserveRepeatedValues = false,
  }) {
    final normalized = <String>[];
    final keys = <String>{};
    for (final value in values) {
      final next = _singleLine(value);
      if (next.isEmpty) continue;
      if (preserveRepeatedValues || keys.add(_comparable(next))) {
        normalized.add(next);
      }
    }
    return List.unmodifiable(normalized);
  }

  String _singleLine(String value) =>
      unicode.nfkc(value).trim().replaceAll(RegExp(r'\s+'), ' ');

  String _comparable(String value) =>
      unicode.nfkc(value).toLowerCase().replaceAll(RegExp(r'\s+'), '');

  String? _optional(String? value) {
    if (value == null) return null;
    final normalized = _singleLine(value);
    return normalized.isEmpty ? null : normalized;
  }

  void _requiredLength(
    List<ContentValidationIssue> issues, {
    required String value,
    required String field,
    required String label,
    required int max,
  }) {
    if (value.isEmpty) {
      _error(issues, '${field}_required', field, '$label이 비어 있습니다.');
    } else if (value.runes.length > max) {
      _error(issues, '${field}_length', field, '$label은 $max자 이하여야 합니다.');
    }
  }

  void _optionalLength(
    List<ContentValidationIssue> issues, {
    required String? value,
    required String field,
    required String label,
    required int max,
  }) {
    if (value != null && value.runes.length > max) {
      _error(issues, '${field}_length', field, '$label은 $max자 이하여야 합니다.');
    }
  }

  void _error(
    List<ContentValidationIssue> issues,
    String code,
    String field,
    String message,
  ) {
    issues.add(
      ContentValidationIssue(
        code: code,
        field: field,
        message: message,
        severity: ContentIssueSeverity.error,
      ),
    );
  }

  void _warning(
    List<ContentValidationIssue> issues,
    String code,
    String field,
    String message,
  ) {
    issues.add(
      ContentValidationIssue(
        code: code,
        field: field,
        message: message,
        severity: ContentIssueSeverity.warning,
      ),
    );
  }
}
