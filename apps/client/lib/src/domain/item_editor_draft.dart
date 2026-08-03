import 'learning_item.dart';

/// Device-local recovery state for the full content editor.
///
/// It is intentionally stored outside snapshots and account sync.
class ItemEditorDraft {
  const ItemEditorDraft({
    required this.itemId,
    required this.baseFingerprint,
    required this.subjectId,
    required this.kind,
    required this.partOfSpeech,
    required this.priority,
    required this.group,
    required this.sentenceTokens,
    required this.text,
    required this.translation,
    required this.acceptedAnswers,
    required this.reading,
    required this.secondaryReading,
    required this.koreanPronunciation,
    required this.example,
    required this.exampleTranslation,
    required this.tags,
    required this.level,
    required this.sourceName,
    required this.license,
    required this.sourceVersion,
    required this.sourceId,
    required this.sourceUrl,
    required this.author,
    required this.attribution,
    required this.updatedAt,
  });

  factory ItemEditorDraft.fromJson(Map<String, Object?> json) {
    final subjectId = json['subjectId'];
    final kindName = json['kind'];
    final baseFingerprint = json['baseFingerprint'];
    if (subjectId is! String ||
        kindName is! String ||
        baseFingerprint is! String) {
      throw const FormatException('전체 편집기 초안의 필수 정보가 없습니다.');
    }
    final kind = LearningItemKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => LearningItemKind.word,
    );
    final partName = json['partOfSpeech'];
    final partOfSpeech = PartOfSpeech.values.firstWhere(
      (value) => value.name == partName,
      orElse: () => PartOfSpeech.noun,
    );
    return ItemEditorDraft(
      itemId: json['itemId'] as String?,
      baseFingerprint: baseFingerprint,
      subjectId: subjectId,
      kind: kind,
      partOfSpeech: partOfSpeech,
      priority: ((json['priority'] as num?)?.toInt() ?? 0).clamp(0, 10),
      group: json['group'] as String?,
      sentenceTokens: _stringList(json['sentenceTokens']),
      text: _string(json, 'text'),
      translation: _string(json, 'translation'),
      acceptedAnswers: _string(json, 'acceptedAnswers'),
      reading: _string(json, 'reading'),
      secondaryReading: _string(json, 'secondaryReading'),
      koreanPronunciation: _string(json, 'koreanPronunciation'),
      example: _string(json, 'example'),
      exampleTranslation: _string(json, 'exampleTranslation'),
      tags: _string(json, 'tags'),
      level: _string(json, 'level'),
      sourceName: _string(json, 'sourceName'),
      license: _string(json, 'license'),
      sourceVersion: _string(json, 'sourceVersion'),
      sourceId: _string(json, 'sourceId'),
      sourceUrl: _string(json, 'sourceUrl'),
      author: _string(json, 'author'),
      attribution: _string(json, 'attribution'),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String? itemId;
  final String baseFingerprint;
  final String subjectId;
  final LearningItemKind kind;
  final PartOfSpeech partOfSpeech;
  final int priority;
  final String? group;
  final List<String> sentenceTokens;
  final String text;
  final String translation;
  final String acceptedAnswers;
  final String reading;
  final String secondaryReading;
  final String koreanPronunciation;
  final String example;
  final String exampleTranslation;
  final String tags;
  final String level;
  final String sourceName;
  final String license;
  final String sourceVersion;
  final String sourceId;
  final String sourceUrl;
  final String author;
  final String attribution;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'version': 1,
    'itemId': itemId,
    'baseFingerprint': baseFingerprint,
    'subjectId': subjectId,
    'kind': kind.name,
    'partOfSpeech': partOfSpeech.name,
    'priority': priority,
    'group': group,
    'sentenceTokens': sentenceTokens,
    'text': text,
    'translation': translation,
    'acceptedAnswers': acceptedAnswers,
    'reading': reading,
    'secondaryReading': secondaryReading,
    'koreanPronunciation': koreanPronunciation,
    'example': example,
    'exampleTranslation': exampleTranslation,
    'tags': tags,
    'level': level,
    'sourceName': sourceName,
    'license': license,
    'sourceVersion': sourceVersion,
    'sourceId': sourceId,
    'sourceUrl': sourceUrl,
    'author': author,
    'attribution': attribution,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

String _string(Map<String, Object?> json, String key) =>
    json[key] as String? ?? '';

List<String> _stringList(Object? value) => switch (value) {
  final List<Object?> values => [
    for (final value in values)
      if (value is String) value,
  ],
  _ => const [],
};
