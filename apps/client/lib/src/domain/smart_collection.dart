import 'learning_item.dart';
import 'progress.dart';

enum SmartCollectionSort {
  weakestFirst,
  dueFirst,
  recentlyStudied,
  updatedNewest,
  alphabetical,
}

class SmartCollectionDefinition {
  const SmartCollectionDefinition({
    required this.id,
    required this.subjectId,
    required this.name,
    this.query = '',
    this.groupIds = const {},
    this.tags = const {},
    this.levels = const {},
    this.kinds = const {},
    this.partsOfSpeech = const {},
    this.learningStatuses = const {},
    this.sourceIds = const {},
    this.dueOnly = false,
    this.pinned = false,
    this.sort = SmartCollectionSort.weakestFirst,
    required this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String name;
  final String query;
  final Set<String> groupIds;
  final Set<String> tags;
  final Set<String> levels;
  final Set<LearningItemKind> kinds;
  final Set<PartOfSpeech> partsOfSpeech;
  final Set<LearningStatus> learningStatuses;
  final Set<String> sourceIds;
  final bool dueOnly;
  final bool pinned;
  final SmartCollectionSort sort;
  final DateTime updatedAt;

  SmartCollectionDefinition copyWith({
    String? id,
    String? subjectId,
    String? name,
    String? query,
    Set<String>? groupIds,
    Set<String>? tags,
    Set<String>? levels,
    Set<LearningItemKind>? kinds,
    Set<PartOfSpeech>? partsOfSpeech,
    Set<LearningStatus>? learningStatuses,
    Set<String>? sourceIds,
    bool? dueOnly,
    bool? pinned,
    SmartCollectionSort? sort,
    DateTime? updatedAt,
  }) {
    return SmartCollectionDefinition(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      query: query ?? this.query,
      groupIds: groupIds ?? this.groupIds,
      tags: tags ?? this.tags,
      levels: levels ?? this.levels,
      kinds: kinds ?? this.kinds,
      partsOfSpeech: partsOfSpeech ?? this.partsOfSpeech,
      learningStatuses: learningStatuses ?? this.learningStatuses,
      sourceIds: sourceIds ?? this.sourceIds,
      dueOnly: dueOnly ?? this.dueOnly,
      pinned: pinned ?? this.pinned,
      sort: sort ?? this.sort,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'name': name,
    'query': query,
    'groupIds': groupIds.toList()..sort(),
    'tags': tags.toList()..sort(),
    'levels': levels.toList()..sort(),
    'kinds': kinds.map((value) => value.name).toList()..sort(),
    'partsOfSpeech':
        partsOfSpeech.map((value) => value.name).toList()..sort(),
    'learningStatuses':
        learningStatuses.map((value) => value.name).toList()..sort(),
    'sourceIds': sourceIds.toList()..sort(),
    'dueOnly': dueOnly,
    'pinned': pinned,
    'sort': sort.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory SmartCollectionDefinition.fromJson(Map<String, Object?> json) {
    final id = _requiredText(json['id'], 80);
    final subjectId = _requiredText(json['subjectId'], 80);
    final name = _requiredText(json['name'], 60);
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (updatedAt == null) {
      throw const FormatException('스마트 컬렉션 갱신 시각이 올바르지 않습니다.');
    }
    return SmartCollectionDefinition(
      id: id,
      subjectId: subjectId,
      name: name,
      query: _optionalText(json['query'], 200),
      groupIds: _strings(json['groupIds'], 100),
      tags: _strings(json['tags'], 100),
      levels: _strings(json['levels'], 100),
      kinds: _enumSet(json['kinds'], LearningItemKind.values),
      partsOfSpeech: _enumSet(json['partsOfSpeech'], PartOfSpeech.values),
      learningStatuses: _enumSet(
        json['learningStatuses'],
        LearningStatus.values,
      ),
      sourceIds: _strings(json['sourceIds'], 100),
      dueOnly: json['dueOnly'] == true,
      pinned: json['pinned'] == true,
      sort: _enumValue(
        json['sort'],
        SmartCollectionSort.values,
        SmartCollectionSort.weakestFirst,
      ),
      updatedAt: updatedAt.toUtc(),
    );
  }
}

String _requiredText(Object? raw, int maximumRunes) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('필수 문자열이 비어 있습니다.');
  }
  return String.fromCharCodes(raw.trim().runes.take(maximumRunes));
}

String _optionalText(Object? raw, int maximumRunes) {
  if (raw is! String) return '';
  return String.fromCharCodes(raw.trim().runes.take(maximumRunes));
}

Set<String> _strings(Object? raw, int maximumEntries) {
  if (raw is! List<Object?>) return const {};
  return raw
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty && value.runes.length <= 160)
      .take(maximumEntries)
      .toSet();
}

Set<T> _enumSet<T extends Enum>(Object? raw, List<T> values) {
  final names = _strings(raw, 100);
  return values.where((value) => names.contains(value.name)).toSet();
}

T _enumValue<T extends Enum>(Object? raw, List<T> values, T fallback) {
  return values.where((value) => value.name == raw).firstOrNull ?? fallback;
}
