import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'language.dart';
import 'learning_item.dart';

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

class LearningContentValidator {
  const LearningContentValidator();

  ContentValidationResult inspect(LearningItem source) {
    final item = _normalize(source);
    final issues = <ContentValidationIssue>[];
    final profile = LanguageProfile.of(item.learningLanguage);

    _requiredLength(issues, value: item.id, field: 'id', label: 'ID', max: 160);
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
    } else if (item.partOfSpeech != null) {
      _error(
        issues,
        'sentence_part_of_speech',
        'partOfSpeech',
        '문장 항목에는 품사를 지정할 수 없습니다.',
      );
    } else if (item.capabilities.contains(ExerciseCapability.sentenceOrder)) {
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
      normalized.learningLanguage.code,
      normalized.kind.name,
      _comparable(normalized.text),
      if (normalized.translations.isNotEmpty)
        _comparable(normalized.translations.first),
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
