import 'language.dart';
import 'study_subject.dart';

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
    this.sourceId,
    this.sourceUrl,
    this.author,
    this.attribution,
    this.pageNumber,
    this.excerpt,
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
    sourceVersion: '2026.09',
    contentVersion: 4,
  );

  final String name;
  final String license;
  final String sourceVersion;
  final int contentVersion;
  final String? sourceId;
  final String? sourceUrl;
  final String? author;
  final String? attribution;
  final int? pageNumber;
  final String? excerpt;

  ContentSource copyWith({
    String? name,
    String? license,
    String? sourceVersion,
    int? contentVersion,
    String? sourceId,
    String? sourceUrl,
    String? author,
    String? attribution,
    int? pageNumber,
    String? excerpt,
  }) {
    return ContentSource(
      name: name ?? this.name,
      license: license ?? this.license,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      contentVersion: contentVersion ?? this.contentVersion,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      author: author ?? this.author,
      attribution: attribution ?? this.attribution,
      pageNumber: pageNumber ?? this.pageNumber,
      excerpt: excerpt ?? this.excerpt,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'license': license,
    'sourceVersion': sourceVersion,
    'contentVersion': contentVersion,
    if (sourceId != null) 'sourceId': sourceId,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (author != null) 'author': author,
    if (attribution != null) 'attribution': attribution,
    if (pageNumber != null) 'pageNumber': pageNumber,
    if (excerpt != null) 'excerpt': excerpt,
  };

  factory ContentSource.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final license = json['license'];
    final sourceVersion = json['sourceVersion'] ?? json['version'] ?? '1';
    final sourceId = json['sourceId'] ?? json['source_id'];
    final sourceUrl = json['sourceUrl'] ?? json['source_url'] ?? json['url'];
    final author = json['author'] ?? json['creator'];
    final attribution = json['attribution'];
    final rawPageNumber = json['pageNumber'] ?? json['page_number'];
    final pageNumber = switch (rawPageNumber) {
      null => null,
      final int value => value,
      final num value when value.isFinite && value == value.round() =>
        value.toInt(),
      final String value => int.tryParse(value),
      _ => -1,
    };
    final excerpt = json['excerpt'] ?? json['context'];
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
    for (final entry in {
      'source.sourceId': sourceId,
      'source.sourceUrl': sourceUrl,
      'source.author': author,
      'source.attribution': attribution,
      'source.excerpt': excerpt,
    }.entries) {
      if (entry.value != null && entry.value is! String) {
        throw FormatException('${entry.key} 값은 문자열이어야 합니다.');
      }
    }
    if (pageNumber != null && pageNumber <= 0) {
      throw const FormatException('source.pageNumber 값은 양의 정수여야 합니다.');
    }
    return ContentSource(
      name: name,
      license: license,
      sourceVersion: sourceVersion.toString(),
      contentVersion: contentVersion,
      sourceId: sourceId as String?,
      sourceUrl: sourceUrl as String?,
      author: author as String?,
      attribution: attribution as String?,
      pageNumber: pageNumber,
      excerpt: excerpt as String?,
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
    this.subjectId,
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
  final String? subjectId;
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
  String get effectiveSubjectId =>
      subjectId ?? languageSubjectId(learningLanguage);
  String get courseId => courseIdForSubject(effectiveSubjectId);

  String? reading(ReadingScheme scheme) {
    for (final item in readings) {
      if (item.scheme == scheme) {
        return item.value;
      }
    }
    return null;
  }

  String? get koreanPronunciation => reading(ReadingScheme.hangul);

  List<Reading> get orderedReadingAids {
    final result = [...readings];
    result.sort((left, right) {
      final leftOrder = left.scheme == ReadingScheme.hangul ? 0 : 1;
      final rightOrder = right.scheme == ReadingScheme.hangul ? 0 : 1;
      return leftOrder.compareTo(rightOrder);
    });
    return result;
  }

  List<String> get readingAidLabels => orderedReadingAids
      .map((reading) {
        if (reading.scheme == ReadingScheme.hangul) {
          return reading.value;
        }
        return '${reading.scheme.koreanLabel} ${reading.value}';
      })
      .toList(growable: false);

  String get readingAidsLabel => readingAidLabels.join('\n');

  List<String> readingAidLabelsFor({
    required bool showKoreanReading,
    required bool showNativeReading,
  }) => orderedReadingAids
      .where(
        (reading) => reading.scheme == ReadingScheme.hangul
            ? showKoreanReading
            : showNativeReading,
      )
      .map((reading) {
        if (reading.scheme == ReadingScheme.hangul) {
          return reading.value;
        }
        return '${reading.scheme.koreanLabel} ${reading.value}';
      })
      .toList(growable: false);

  String readingAidsLabelFor({
    required bool showKoreanReading,
    required bool showNativeReading,
  }) => readingAidLabelsFor(
    showKoreanReading: showKoreanReading,
    showNativeReading: showNativeReading,
  ).join('\n');

  LearningItem copyWith({
    String? id,
    LearningItemKind? kind,
    LanguageTag? learningLanguage,
    String? text,
    List<String>? translations,
    List<String>? acceptedAnswers,
    String? subjectId,
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
      subjectId: subjectId ?? this.subjectId,
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
