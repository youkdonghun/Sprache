import 'language.dart';

enum LearningItemKind { word, sentence }

enum PartOfSpeech {
  noun,
  verb,
  adjective,
  adverb,
  pronoun,
  determiner,
  preposition,
  conjunction,
  interjection,
  auxiliary,
  particle,
  classifier,
  numeral,
  phrase,
  other,
}

extension PartOfSpeechLabel on PartOfSpeech {
  String get koreanLabel => switch (this) {
    PartOfSpeech.noun => '명사',
    PartOfSpeech.verb => '동사',
    PartOfSpeech.adjective => '형용사',
    PartOfSpeech.adverb => '부사',
    PartOfSpeech.pronoun => '대명사',
    PartOfSpeech.determiner => '한정사',
    PartOfSpeech.preposition => '전치사',
    PartOfSpeech.conjunction => '접속사',
    PartOfSpeech.interjection => '감탄사',
    PartOfSpeech.auxiliary => '조동사',
    PartOfSpeech.particle => '조사·불변화사',
    PartOfSpeech.classifier => '분류사·양사',
    PartOfSpeech.numeral => '수사',
    PartOfSpeech.phrase => '구·표현',
    PartOfSpeech.other => '기타',
  };
}

PartOfSpeech parsePartOfSpeech(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_-]+'),
    '',
  );
  for (final part in PartOfSpeech.values) {
    final names = {
      part.name.toLowerCase(),
      part.koreanLabel.replaceAll(RegExp(r'[\s·-]+'), ''),
      ...switch (part) {
        PartOfSpeech.noun => {'n', '명'},
        PartOfSpeech.verb => {'v', '동'},
        PartOfSpeech.adjective => {'adj', '형'},
        PartOfSpeech.adverb => {'adv', '부'},
        PartOfSpeech.pronoun => {'pron'},
        PartOfSpeech.determiner => {'det'},
        PartOfSpeech.preposition => {'prep'},
        PartOfSpeech.conjunction => {'conj'},
        PartOfSpeech.interjection => {'interj'},
        PartOfSpeech.auxiliary => {'aux'},
        PartOfSpeech.particle => {'part'},
        PartOfSpeech.classifier => {'class', 'measureword', '양사'},
        PartOfSpeech.numeral => {'num'},
        PartOfSpeech.phrase => {'expression', '표현'},
        PartOfSpeech.other => {'etc', '기타'},
      },
    };
    if (names.contains(normalized)) return part;
  }
  throw FormatException('지원하지 않는 품사입니다: $value');
}

class ContentSource {
  const ContentSource({
    required this.name,
    required this.license,
    required this.sourceVersion,
    required this.contentVersion,
  });

  static const userCreated = ContentSource(
    name: '사용자 직접 입력',
    license: 'private',
    sourceVersion: '1',
    contentVersion: 1,
  );

  static const starterCatalog = ContentSource(
    name: 'Sprache starter catalog',
    license: 'project-internal',
    sourceVersion: '2026.07',
    contentVersion: 1,
  );

  final String name;
  final String license;
  final String sourceVersion;
  final int contentVersion;

  ContentSource copyWith({
    String? name,
    String? license,
    String? sourceVersion,
    int? contentVersion,
  }) {
    return ContentSource(
      name: name ?? this.name,
      license: license ?? this.license,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      contentVersion: contentVersion ?? this.contentVersion,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'license': license,
    'sourceVersion': sourceVersion,
    'contentVersion': contentVersion,
  };

  factory ContentSource.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final license = json['license'];
    final sourceVersion = json['sourceVersion'] ?? json['version'] ?? '1';
    final rawContentVersion = json['contentVersion'] ?? 1;
    final contentVersion = switch (rawContentVersion) {
      final int value => value,
      final num value when value.isFinite && value == value.round() =>
        value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('source.name 값이 필요합니다.');
    }
    if (license is! String || license.trim().isEmpty) {
      throw const FormatException('source.license 값이 필요합니다.');
    }
    if (sourceVersion is! String && sourceVersion is! num) {
      throw const FormatException('source.sourceVersion 값은 문자열이어야 합니다.');
    }
    if (contentVersion == null) {
      throw const FormatException('source.contentVersion 값은 정수여야 합니다.');
    }
    return ContentSource(
      name: name,
      license: license,
      sourceVersion: sourceVersion.toString(),
      contentVersion: contentVersion,
    );
  }
}

enum ExerciseCapability {
  recognition,
  production,
  cloze,
  listening,
  sentenceOrder,
}

class LearningItem {
  const LearningItem({
    required this.id,
    required this.kind,
    required this.learningLanguage,
    required this.text,
    required this.translations,
    required this.acceptedAnswers,
    this.readings = const [],
    this.sentenceTokens = const [],
    this.example,
    this.exampleTranslation,
    this.partOfSpeech,
    this.tags = const [],
    this.level = '입문',
    this.capabilities = const {
      ExerciseCapability.recognition,
      ExerciseCapability.production,
    },
    this.priority = 0,
    this.source = ContentSource.userCreated,
    this.updatedAt,
  });

  final String id;
  final LearningItemKind kind;
  final LanguageTag learningLanguage;
  final String text;
  final List<String> translations;
  final List<String> acceptedAnswers;
  final List<Reading> readings;
  final List<String> sentenceTokens;
  final String? example;
  final String? exampleTranslation;
  final PartOfSpeech? partOfSpeech;
  final List<String> tags;
  final String level;
  final Set<ExerciseCapability> capabilities;
  final int priority;
  final ContentSource source;
  final DateTime? updatedAt;

  String get primaryTranslation => translations.first;

  String? reading(ReadingScheme scheme) {
    for (final item in readings) {
      if (item.scheme == scheme) {
        return item.value;
      }
    }
    return null;
  }

  LearningItem copyWith({
    String? id,
    LearningItemKind? kind,
    LanguageTag? learningLanguage,
    String? text,
    List<String>? translations,
    List<String>? acceptedAnswers,
    List<Reading>? readings,
    List<String>? sentenceTokens,
    String? example,
    String? exampleTranslation,
    PartOfSpeech? partOfSpeech,
    bool clearPartOfSpeech = false,
    List<String>? tags,
    String? level,
    Set<ExerciseCapability>? capabilities,
    int? priority,
    ContentSource? source,
    DateTime? updatedAt,
  }) {
    return LearningItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      text: text ?? this.text,
      translations: translations ?? this.translations,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
      readings: readings ?? this.readings,
      sentenceTokens: sentenceTokens ?? this.sentenceTokens,
      example: example ?? this.example,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      partOfSpeech: clearPartOfSpeech
          ? null
          : partOfSpeech ?? this.partOfSpeech,
      tags: tags ?? this.tags,
      level: level ?? this.level,
      capabilities: capabilities ?? this.capabilities,
      priority: priority ?? this.priority,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
