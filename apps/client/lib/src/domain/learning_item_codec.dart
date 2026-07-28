import 'content_validation.dart';
import 'language.dart';
import 'learning_item.dart';

class LearningItemCodec {
  const LearningItemCodec({this.validator = const LearningContentValidator()});

  final LearningContentValidator validator;

  Map<String, Object?> toJson(LearningItem item) {
    final normalized = validator.ensureValid(item);
    return {
      'id': normalized.id,
      'kind': normalized.kind.name,
      'language': normalized.learningLanguage.code,
      'text': normalized.text,
      'translations': normalized.translations,
      'acceptedAnswers': normalized.acceptedAnswers,
      'readings': [
        for (final reading in normalized.readings)
          {'scheme': reading.scheme.name, 'value': reading.value},
      ],
      'sentenceTokens': normalized.sentenceTokens,
      'example': normalized.example,
      'exampleTranslation': normalized.exampleTranslation,
      'partOfSpeech': normalized.partOfSpeech?.name,
      'tags': normalized.tags,
      'level': normalized.level,
      'capabilities':
          normalized.capabilities.map((value) => value.name).toList()..sort(),
      'priority': normalized.priority,
      'source': normalized.source.toJson(),
      'updatedAt': normalized.updatedAt?.toUtc().toIso8601String(),
    };
  }

  LearningItem fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    final text = _requiredString(json, 'text');
    final languageCode = _requiredString(json, 'language');
    final language = LanguageTag.values.firstWhere(
      (value) => value.code == languageCode,
      orElse: () => throw FormatException('지원하지 않는 언어 코드입니다: $languageCode'),
    );
    final kindName = json['kind'] as String? ?? LearningItemKind.word.name;
    final kind = LearningItemKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => throw FormatException('지원하지 않는 콘텐츠 종류입니다: $kindName'),
    );
    final translations = _stringList(
      json['translations'],
      field: 'translations',
      required: true,
    );
    final acceptedAnswers = json.containsKey('acceptedAnswers')
        ? _stringList(json['acceptedAnswers'], field: 'acceptedAnswers')
        : translations;
    final readings = <Reading>[];
    final rawReadings = json['readings'];
    if (rawReadings != null && rawReadings is! List<Object?>) {
      throw const FormatException('readings는 배열이어야 합니다.');
    }
    for (final raw in (rawReadings as List<Object?>?) ?? const []) {
      if (raw is! Map) {
        throw const FormatException('readings 항목은 객체여야 합니다.');
      }
      final reading = Map<String, Object?>.from(raw);
      final schemeName = _requiredString(reading, 'scheme');
      final scheme = ReadingScheme.values.firstWhere(
        (value) => value.name == schemeName,
        orElse: () => throw FormatException('지원하지 않는 읽기 방식입니다: $schemeName'),
      );
      readings.add(
        Reading(scheme: scheme, value: _requiredString(reading, 'value')),
      );
    }

    final capabilityNames = json.containsKey('capabilities')
        ? _stringList(json['capabilities'], field: 'capabilities').toSet()
        : const <String>{};
    final unknownCapabilities = capabilityNames.difference({
      for (final capability in ExerciseCapability.values) capability.name,
    });
    if (unknownCapabilities.isNotEmpty) {
      throw FormatException(
        '지원하지 않는 학습 방식입니다: ${unknownCapabilities.join(', ')}',
      );
    }
    final rawPartOfSpeech = json['partOfSpeech'];
    final partOfSpeech = switch (rawPartOfSpeech) {
      null => null,
      final String value => parsePartOfSpeech(value),
      _ => throw const FormatException('partOfSpeech 값은 문자열이어야 합니다.'),
    };
    final rawSource = json['source'];
    final source = switch (rawSource) {
      null => ContentSource.userCreated,
      final Map value => ContentSource.fromJson(
        Map<String, Object?>.from(value),
      ),
      _ => throw const FormatException('source 값은 객체여야 합니다.'),
    };

    return validator.ensureValid(
      LearningItem(
        id: id,
        kind: kind,
        learningLanguage: language,
        text: text,
        translations: translations,
        acceptedAnswers: acceptedAnswers,
        readings: readings,
        sentenceTokens: _stringList(
          json['sentenceTokens'],
          field: 'sentenceTokens',
        ),
        example: _optionalString(json, 'example'),
        exampleTranslation: _optionalString(json, 'exampleTranslation'),
        partOfSpeech: partOfSpeech,
        tags: _stringList(json['tags'], field: 'tags'),
        level: _optionalString(json, 'level') ?? '입문',
        capabilities: capabilityNames.isEmpty
            ? const {
                ExerciseCapability.recognition,
                ExerciseCapability.production,
              }
            : ExerciseCapability.values
                  .where((value) => capabilityNames.contains(value.name))
                  .toSet(),
        priority: _integer(json['priority'], field: 'priority') ?? 0,
        source: source,
        updatedAt: _optionalDate(json, 'updatedAt'),
      ),
    );
  }

  String _requiredString(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field 값이 필요합니다.');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$field 값은 문자열이어야 합니다.');
    }
    return value;
  }

  List<String> _stringList(
    Object? raw, {
    required String field,
    bool required = false,
  }) {
    if (raw == null && !required) return const [];
    if (raw is! List<Object?> || raw.any((value) => value is! String)) {
      throw FormatException('$field 값은 문자열 배열이어야 합니다.');
    }
    return raw.cast<String>();
  }

  int? _integer(Object? raw, {required String field}) {
    if (raw == null) return null;
    if (raw is! num || raw.isNaN || raw.isInfinite || raw != raw.round()) {
      throw FormatException('$field 값은 정수여야 합니다.');
    }
    return raw.toInt();
  }

  DateTime? _optionalDate(Map<String, Object?> json, String field) {
    final raw = json[field];
    if (raw == null) return null;
    if (raw is! String || DateTime.tryParse(raw) == null) {
      throw FormatException('$field 값은 ISO 8601 날짜 문자열이어야 합니다.');
    }
    return DateTime.parse(raw).toUtc();
  }
}
