import 'language.dart';
import 'learning_item.dart';

/// Device-local recovery state for the quick content sheet.
///
/// This value is stored in the local app-settings table only. It is not part
/// of the learning snapshot or account sync contract.
class QuickContentDraft {
  const QuickContentDraft({
    required this.subjectId,
    required this.kind,
    required this.text,
    required this.meanings,
    required this.acceptedAnswers,
    required this.readings,
    required this.sentenceTokens,
    required this.example,
    required this.exampleMeaning,
    required this.partOfSpeech,
    required this.group,
    required this.tags,
    required this.favorite,
    required this.priority,
    required this.updatedAt,
  });

  factory QuickContentDraft.fromJson(Map<String, Object?> json) {
    final subjectId = json['subjectId'];
    final kindName = json['kind'];
    if (subjectId is! String || kindName is! String) {
      throw const FormatException('빠른 등록 초안의 필수 필드가 없습니다.');
    }
    final kind = LearningItemKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => LearningItemKind.word,
    );
    final partName = json['partOfSpeech'] as String?;
    final part = partName == null
        ? PartOfSpeech.noun
        : PartOfSpeech.values.firstWhere(
            (value) => value.name == partName,
            orElse: () => PartOfSpeech.noun,
          );
    final readingMap = <ReadingScheme, String>{};
    if (json['readings'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final scheme = ReadingScheme.values.where(
          (value) => value.name == entry.key,
        );
        if (scheme.isNotEmpty) {
          readingMap[scheme.first] = entry.value! as String;
        }
      }
    }
    return QuickContentDraft(
      subjectId: subjectId,
      kind: kind,
      text: json['text'] as String? ?? '',
      meanings: _stringList(json['meanings']),
      acceptedAnswers: _stringList(json['acceptedAnswers']),
      readings: Map.unmodifiable(readingMap),
      sentenceTokens: _stringList(json['sentenceTokens']),
      example: json['example'] as String? ?? '',
      exampleMeaning: json['exampleMeaning'] as String? ?? '',
      partOfSpeech: part,
      group: json['group'] as String?,
      tags: _stringList(json['tags']),
      favorite: json['favorite'] as bool? ?? false,
      priority: ((json['priority'] as num?)?.toInt() ?? 0).clamp(0, 5),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String subjectId;
  final LearningItemKind kind;
  final String text;
  final List<String> meanings;
  final List<String> acceptedAnswers;
  final Map<ReadingScheme, String> readings;
  final List<String> sentenceTokens;
  final String example;
  final String exampleMeaning;
  final PartOfSpeech partOfSpeech;
  final String? group;
  final List<String> tags;
  final bool favorite;
  final int priority;
  final DateTime updatedAt;

  bool get hasContent =>
      text.trim().isNotEmpty ||
      meanings.isNotEmpty ||
      acceptedAnswers.isNotEmpty ||
      readings.values.any((value) => value.trim().isNotEmpty) ||
      sentenceTokens.isNotEmpty ||
      example.trim().isNotEmpty ||
      exampleMeaning.trim().isNotEmpty ||
      tags.isNotEmpty;

  Map<String, Object?> toJson() => {
    'version': 1,
    'subjectId': subjectId,
    'kind': kind.name,
    'text': text,
    'meanings': meanings,
    'acceptedAnswers': acceptedAnswers,
    'readings': {
      for (final entry in readings.entries) entry.key.name: entry.value,
    },
    'sentenceTokens': sentenceTokens,
    'example': example,
    'exampleMeaning': exampleMeaning,
    'partOfSpeech': partOfSpeech.name,
    'group': group,
    'tags': tags,
    'favorite': favorite,
    'priority': priority,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

List<String> _stringList(Object? value) => switch (value) {
  final List<Object?> values => [
    for (final value in values)
      if (value is String) value,
  ],
  _ => const [],
};
