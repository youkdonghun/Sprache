import 'learning_item.dart';
import 'progress.dart';
import 'study_subject.dart';

const learningGroupTagPrefix = 'group:';
const learningGroupColorKeys = <String>[
  'teal',
  'blue',
  'purple',
  'orange',
  'rose',
  'gray',
];

String normalizeLearningGroupName(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    throw const FormatException('학습 그룹 이름을 입력해 주세요.');
  }
  if (normalized.runes.length > 40) {
    throw const FormatException('학습 그룹 이름은 40자 이하여야 합니다.');
  }
  if (normalized.contains(RegExp(r'[\u0000-\u001F]'))) {
    throw const FormatException('학습 그룹 이름에 제어 문자를 사용할 수 없습니다.');
  }
  return normalized;
}

String learningGroupTag(String groupName) =>
    '$learningGroupTagPrefix${normalizeLearningGroupName(groupName)}';

Set<String> learningGroupsOf(LearningItem item) => item.tags
    .where((tag) => tag.startsWith(learningGroupTagPrefix))
    .map((tag) => tag.substring(learningGroupTagPrefix.length).trim())
    .where((name) => name.isNotEmpty)
    .toSet();

List<String> tagsWithLearningGroup(
  Iterable<String> tags,
  String groupName, {
  required bool keepExistingGroups,
}) {
  final target = learningGroupTag(groupName);
  final next = <String>{
    for (final tag in tags)
      if (keepExistingGroups || !tag.startsWith(learningGroupTagPrefix)) tag,
    target,
  }.toList()..sort();
  return List.unmodifiable(next);
}

List<String> tagsRenamingLearningGroup(
  Iterable<String> tags,
  String previousName,
  String nextName,
) {
  final previous = learningGroupTag(previousName);
  final next = learningGroupTag(nextName);
  final renamed = <String>{
    for (final tag in tags)
      if (tag != previous) tag,
    next,
  }.toList()..sort();
  return List.unmodifiable(renamed);
}

List<String> tagsWithoutLearningGroup(Iterable<String> tags, String groupName) {
  final target = learningGroupTag(groupName);
  final remaining = tags.where((tag) => tag != target).toSet().toList()..sort();
  return List.unmodifiable(remaining);
}

List<String> tagsWithoutLearningGroups(Iterable<String> tags) {
  final remaining =
      tags
          .where((tag) => !tag.startsWith(learningGroupTagPrefix))
          .toSet()
          .toList()
        ..sort();
  return List.unmodifiable(remaining);
}

String learningGroupDefinitionId(String subjectId, String groupName) =>
    '${normalizeStudySubjectId(subjectId)}\u001F'
    '${normalizeLearningGroupName(groupName)}';

class LearningGroupDefinition {
  LearningGroupDefinition({
    required String subjectId,
    required String name,
    String description = '',
    String colorKey = 'teal',
    this.pinned = false,
    int sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : subjectId = normalizeStudySubjectId(subjectId),
       name = normalizeLearningGroupName(name),
       description = _normalizeLearningGroupDescription(description),
       colorKey = learningGroupColorKeys.contains(colorKey) ? colorKey : 'teal',
       sortOrder = sortOrder.clamp(0, 100000),
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? createdAt ?? DateTime.now()).toUtc();

  factory LearningGroupDefinition.fromJson(Map<String, Object?> json) {
    final subjectId = json['subjectId'];
    final name = json['name'];
    if (subjectId is! String || name is! String) {
      throw const FormatException('학습 그룹의 주제와 이름이 필요합니다.');
    }
    return LearningGroupDefinition(
      subjectId: subjectId,
      name: name,
      description: json['description'] as String? ?? '',
      colorKey: json['colorKey'] as String? ?? 'teal',
      pinned: json['pinned'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: switch (json['createdAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }

  final String subjectId;
  final String name;
  final String description;
  final String colorKey;
  final bool pinned;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get id => learningGroupDefinitionId(subjectId, name);

  LearningGroupDefinition copyWith({
    String? subjectId,
    String? name,
    String? description,
    String? colorKey,
    bool? pinned,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningGroupDefinition(
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      description: description ?? this.description,
      colorKey: colorKey ?? this.colorKey,
      pinned: pinned ?? this.pinned,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'subjectId': subjectId,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'colorKey': colorKey,
    'pinned': pinned,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

String _normalizeLearningGroupDescription(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.runes.length > 120) {
    throw const FormatException('학습 그룹 설명은 120자 이하여야 합니다.');
  }
  if (normalized.contains(RegExp(r'[\u0000-\u001F]'))) {
    throw const FormatException('학습 그룹 설명에 제어 문자를 사용할 수 없습니다.');
  }
  return normalized;
}

class LearningGroupSummary {
  const LearningGroupSummary({
    required this.name,
    required this.totalCount,
    required this.wordCount,
    required this.sentenceCount,
    required this.studiedCount,
    required this.masteredCount,
    required this.correctCount,
    required this.wrongCount,
  });

  final String name;
  final int totalCount;
  final int wordCount;
  final int sentenceCount;
  final int studiedCount;
  final int masteredCount;
  final int correctCount;
  final int wrongCount;

  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
  double get studyRate => totalCount == 0 ? 0 : studiedCount / totalCount;
}

LearningGroupSummary summarizeLearningGroup(
  String groupName,
  Iterable<LearningItem> items,
  Map<String, ProgressRecord> progress,
) {
  final normalized = normalizeLearningGroupName(groupName);
  final grouped = items
      .where((item) => learningGroupsOf(item).contains(normalized))
      .toList(growable: false);
  var studiedCount = 0;
  var masteredCount = 0;
  var correctCount = 0;
  var wrongCount = 0;
  for (final item in grouped) {
    final record = progress[item.id];
    if (record == null) continue;
    if (record.attempts > 0) studiedCount += 1;
    if (record.status == LearningStatus.mastered) masteredCount += 1;
    correctCount += record.correctCount;
    wrongCount += record.wrongCount;
  }
  return LearningGroupSummary(
    name: normalized,
    totalCount: grouped.length,
    wordCount: grouped
        .where((item) => item.kind == LearningItemKind.word)
        .length,
    sentenceCount: grouped
        .where((item) => item.kind == LearningItemKind.sentence)
        .length,
    studiedCount: studiedCount,
    masteredCount: masteredCount,
    correctCount: correctCount,
    wrongCount: wrongCount,
  );
}
