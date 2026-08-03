import 'language.dart';
import 'learning_item.dart';
import 'learning_item_codec.dart';

class QuickContentBasketDraftEntry {
  const QuickContentBasketDraftEntry({
    required this.item,
    required this.favorite,
  });

  factory QuickContentBasketDraftEntry.fromJson(Map<String, Object?> json) {
    final rawItem = json['item'];
    if (rawItem is! Map<Object?, Object?>) {
      throw const FormatException('등록 바구니 항목에 학습 자료가 없습니다.');
    }
    return QuickContentBasketDraftEntry(
      item: const LearningItemCodec().fromJson(
        Map<String, Object?>.from(rawItem),
      ),
      favorite: json['favorite'] as bool? ?? false,
    );
  }

  final LearningItem item;
  final bool favorite;

  Map<String, Object?> toJson() => {
    'item': const LearningItemCodec().toJson(item),
    'favorite': favorite,
  };
}

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
    this.basket = const [],
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
    final basket = <QuickContentBasketDraftEntry>[];
    if (json['basket'] case final List<Object?> rawBasket) {
      for (final rawEntry in rawBasket.take(50)) {
        if (rawEntry is! Map<Object?, Object?>) continue;
        try {
          basket.add(
            QuickContentBasketDraftEntry.fromJson(
              Map<String, Object?>.from(rawEntry),
            ),
          );
        } on Object {
          // Keep the remaining recoverable entries when one row is corrupt.
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
      basket: List.unmodifiable(basket),
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
  final List<QuickContentBasketDraftEntry> basket;

  bool get hasContent =>
      text.trim().isNotEmpty ||
      meanings.isNotEmpty ||
      acceptedAnswers.isNotEmpty ||
      readings.values.any((value) => value.trim().isNotEmpty) ||
      sentenceTokens.isNotEmpty ||
      example.trim().isNotEmpty ||
      exampleMeaning.trim().isNotEmpty ||
      tags.isNotEmpty ||
      basket.isNotEmpty;

  Map<String, Object?> toJson() => {
    'version': 2,
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
    'basket': [for (final entry in basket) entry.toJson()],
  };
}

List<String> _stringList(Object? value) => switch (value) {
  final List<Object?> values => [
    for (final value in values)
      if (value is String) value,
  ],
  _ => const [],
};
