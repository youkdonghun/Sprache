import 'language.dart';
import 'learning_group.dart';
import 'learning_item.dart';
import 'study_subject.dart';

const importDistributionTagPrefix = 'import-key:';

class ImportDistributionRoute {
  const ImportDistributionRoute({
    required this.key,
    required this.subjectId,
    required this.languageCode,
    this.groupName,
  });

  final String key;
  final String subjectId;
  final String languageCode;
  final String? groupName;
}

List<ImportDistributionRoute> get fallbackImportDistributionRoutes => [
  for (final language in LanguageTag.values)
    if (language.available)
      ImportDistributionRoute(
        key: 'lang:${language.code.toLowerCase()}',
        subjectId: languageSubjectId(language),
        languageCode: language.code,
      ),
];

ImportDistributionRoute? fallbackImportDistributionRouteFor(String value) {
  final key = normalizeImportDistributionKey(value);
  for (final route in fallbackImportDistributionRoutes) {
    if (route.key == key) return route;
  }
  return null;
}

ImportDistributionRoute? resolveImportDistributionRoute(
  String value, {
  Iterable<ImportDistributionRule> savedRules = const [],
  Iterable<StudySubject> subjects = const [],
}) {
  final key = normalizeImportDistributionKey(value);
  ImportDistributionRule? savedRule;
  for (final rule in savedRules) {
    if (rule.key == key) {
      savedRule = rule;
      break;
    }
  }
  if (savedRule == null) return fallbackImportDistributionRouteFor(key);

  String? languageCode;
  for (final subject in subjects) {
    if (subject.id == savedRule.subjectId) {
      languageCode = subject.contentLanguage.code;
      break;
    }
  }
  languageCode ??= _languageCodeFromSubjectId(savedRule.subjectId);
  return ImportDistributionRoute(
    key: savedRule.key,
    subjectId: savedRule.subjectId,
    languageCode: languageCode ?? LanguageTag.korean.code,
    groupName: savedRule.groupName,
  );
}

String normalizeImportDistributionKey(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  if (normalized.isEmpty) {
    throw const FormatException('분배 키를 입력해 주세요.');
  }
  if (normalized.runes.length > 48) {
    throw const FormatException('분배 키는 48자 이하여야 합니다.');
  }
  if (normalized.contains(RegExp(r'[\u0000-\u001F|,;/\\]'))) {
    throw const FormatException('분배 키에는 쉼표, 세미콜론, 슬래시, 역슬래시, 세로줄을 사용할 수 없습니다.');
  }
  return normalized;
}

String importDistributionTag(String key) =>
    '$importDistributionTagPrefix${normalizeImportDistributionKey(key)}';

String? importDistributionKeyOf(LearningItem item) {
  for (final tag in item.tags) {
    if (!tag.startsWith(importDistributionTagPrefix)) continue;
    final raw = tag.substring(importDistributionTagPrefix.length);
    try {
      return normalizeImportDistributionKey(raw);
    } on FormatException {
      return null;
    }
  }
  return null;
}

List<String> tagsWithImportDistributionKey(Iterable<String> tags, String key) {
  final next = <String>{
    for (final tag in tags)
      if (!tag.startsWith(importDistributionTagPrefix)) tag,
    importDistributionTag(key),
  }.toList()..sort();
  return List.unmodifiable(next);
}

List<String> tagsWithoutImportDistributionKeys(Iterable<String> tags) {
  final next =
      tags
          .where((tag) => !tag.startsWith(importDistributionTagPrefix))
          .toSet()
          .toList()
        ..sort();
  return List.unmodifiable(next);
}

class ImportDistributionRule {
  ImportDistributionRule({
    required String key,
    required String subjectId,
    String? groupName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : key = normalizeImportDistributionKey(key),
       subjectId = normalizeStudySubjectId(subjectId),
       groupName = _normalizeOptionalGroupName(groupName),
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? createdAt ?? DateTime.now()).toUtc();

  factory ImportDistributionRule.fromJson(Map<String, Object?> json) {
    final key = json['key'];
    final subjectId = json['subjectId'];
    if (key is! String || subjectId is! String) {
      throw const FormatException('분배 키와 대상 주제가 필요합니다.');
    }
    return ImportDistributionRule(
      key: key,
      subjectId: subjectId,
      groupName: json['groupName'] as String?,
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

  final String key;
  final String subjectId;
  final String? groupName;
  final DateTime createdAt;
  final DateTime updatedAt;

  ImportDistributionRule copyWith({
    String? key,
    String? subjectId,
    Object? groupName = _notProvided,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ImportDistributionRule(
      key: key ?? this.key,
      subjectId: subjectId ?? this.subjectId,
      groupName: identical(groupName, _notProvided)
          ? this.groupName
          : groupName as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'subjectId': subjectId,
    if (groupName != null) 'groupName': groupName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

const _notProvided = Object();

String? _normalizeOptionalGroupName(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalizeLearningGroupName(normalized);
}

String? _languageCodeFromSubjectId(String subjectId) {
  final normalized = normalizeStudySubjectId(subjectId);
  for (final language in LanguageTag.values) {
    if (languageSubjectId(language) == normalized) return language.code;
  }
  return null;
}
