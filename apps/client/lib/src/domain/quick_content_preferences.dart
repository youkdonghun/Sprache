import 'learning_item.dart';

const quickContentTemplateLimit = 20;

enum QuickContentTemplateSort { recent, name, created }

class QuickContentRecentGroup {
  const QuickContentRecentGroup({required this.name, required this.selectedAt});

  factory QuickContentRecentGroup.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final selectedAt = json['selectedAt'];
    if (name is! String || selectedAt is! String) {
      throw const FormatException('최근 그룹 정보가 정상적이지 않습니다.');
    }
    final parsed = DateTime.tryParse(selectedAt);
    if (parsed == null) {
      throw const FormatException('최근 그룹 시간이 잘못되었습니다.');
    }
    return QuickContentRecentGroup(name: name, selectedAt: parsed.toUtc());
  }

  final String name;
  final DateTime selectedAt;

  Map<String, Object?> toJson() => {
    'name': name,
    'selectedAt': selectedAt.toUtc().toIso8601String(),
  };
}

/// A device-local metadata preset for quick registration.
///
/// Text and meanings deliberately are not part of a template. Applying one can
/// therefore never replace the learner's source text or translation.
class QuickContentTemplate {
  QuickContentTemplate({
    required String id,
    required String name,
    required this.kind,
    required this.partOfSpeech,
    required this.group,
    required Iterable<Object?> tags,
    required this.favorite,
    required int priority,
    this.pinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = _boundedRequired(id, maxRunes: 80, field: '템플릿 ID'),
       name = _boundedRequired(name, maxRunes: 40, field: '템플릿 이름'),
       tags = _safeRecentTags(tags),
       priority = priority.clamp(0, 5),
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? createdAt ?? DateTime.now()).toUtc();

  factory QuickContentTemplate.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final kind = _enumByName(LearningItemKind.values, json['kind']);
    final partOfSpeech = _enumByName(PartOfSpeech.values, json['partOfSpeech']);
    final group = json['group'];
    final tags = json['tags'];
    final favorite = json['favorite'];
    final priority = _safeInt(json['priority']);
    final pinned = json['pinned'];
    final createdAt = _safeDate(json['createdAt']);
    final updatedAt = _safeDate(json['updatedAt']);
    if (id is! String ||
        name is! String ||
        kind == null ||
        partOfSpeech == null ||
        (group != null && group is! String) ||
        tags is! List<Object?> ||
        favorite is! bool ||
        priority == null ||
        pinned is! bool ||
        createdAt == null ||
        updatedAt == null) {
      throw const FormatException('빠른 등록 템플릿 정보가 정상적이지 않습니다.');
    }
    return QuickContentTemplate(
      id: id,
      name: name,
      kind: kind,
      partOfSpeech: partOfSpeech,
      group: _optionalBounded(group as String?, 40),
      tags: tags,
      favorite: favorite,
      priority: priority,
      pinned: pinned,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String name;
  final LearningItemKind kind;
  final PartOfSpeech partOfSpeech;
  final String? group;
  final List<String> tags;
  final bool favorite;
  final int priority;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickContentTemplate copyWith({
    String? id,
    String? name,
    LearningItemKind? kind,
    PartOfSpeech? partOfSpeech,
    String? group,
    bool clearGroup = false,
    Iterable<String>? tags,
    bool? favorite,
    int? priority,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => QuickContentTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    partOfSpeech: partOfSpeech ?? this.partOfSpeech,
    group: clearGroup ? null : group ?? this.group,
    tags: tags ?? this.tags,
    favorite: favorite ?? this.favorite,
    priority: priority ?? this.priority,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'partOfSpeech': partOfSpeech.name,
    if (group != null) 'group': group,
    'tags': tags,
    'favorite': favorite,
    'priority': priority,
    'pinned': pinned,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class QuickContentLocalPreferences {
  const QuickContentLocalPreferences({
    this.recentGroupBySubject = const {},
    this.lastKindBySubject = const {},
    this.recentTagsBySubject = const {},
    this.templatesBySubject = const {},
    this.templateSort = QuickContentTemplateSort.recent,
  });

  factory QuickContentLocalPreferences.fromJson(Map<String, Object?> json) {
    final recent = <String, QuickContentRecentGroup>{};
    if (json['recentGroupBySubject'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(100)) {
        final subjectId = entry.key;
        final value = entry.value;
        if (subjectId is! String ||
            !_isSafeMapKey(subjectId) ||
            value is! Map<Object?, Object?>) {
          continue;
        }
        try {
          recent[subjectId] = QuickContentRecentGroup.fromJson(
            _stringKeyed(value),
          );
        } on FormatException {
          // Keep other subjects when one local preference entry is damaged.
        }
      }
    }
    final lastKinds = <String, LearningItemKind>{};
    if (json['lastKindBySubject'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(100)) {
        final subjectId = entry.key;
        final kind = _enumByName(LearningItemKind.values, entry.value);
        if (subjectId is String && _isSafeMapKey(subjectId) && kind != null) {
          lastKinds[subjectId] = kind;
        }
      }
    }
    final recentTags = <String, List<String>>{};
    if (json['recentTagsBySubject'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(100)) {
        final subjectId = entry.key;
        final values = entry.value;
        if (subjectId is! String ||
            !_isSafeMapKey(subjectId) ||
            values is! List<Object?>) {
          continue;
        }
        final safe = _safeRecentTags(values);
        if (safe.isNotEmpty) recentTags[subjectId] = safe;
      }
    }
    final templates = <String, List<QuickContentTemplate>>{};
    if (json['templatesBySubject'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(100)) {
        final subjectId = entry.key;
        final values = entry.value;
        if (subjectId is! String ||
            !_isSafeMapKey(subjectId) ||
            values is! List<Object?>) {
          continue;
        }
        final safe = <QuickContentTemplate>[];
        final ids = <String>{};
        for (final item in values.take(quickContentTemplateLimit)) {
          if (item is! Map<Object?, Object?>) continue;
          try {
            final template = QuickContentTemplate.fromJson(_stringKeyed(item));
            if (ids.add(template.id)) safe.add(template);
          } on FormatException {
            // A single corrupt local template must not hide healthy templates.
          }
        }
        if (safe.isNotEmpty) {
          templates[subjectId] = List.unmodifiable(safe);
        }
      }
    }
    return QuickContentLocalPreferences(
      recentGroupBySubject: Map.unmodifiable(recent),
      lastKindBySubject: Map.unmodifiable(lastKinds),
      recentTagsBySubject: _freezeStringLists(recentTags),
      templatesBySubject: _freezeTemplates(templates),
      templateSort:
          _enumByName(QuickContentTemplateSort.values, json['templateSort']) ??
          QuickContentTemplateSort.recent,
    );
  }

  final Map<String, QuickContentRecentGroup> recentGroupBySubject;
  final Map<String, LearningItemKind> lastKindBySubject;
  final Map<String, List<String>> recentTagsBySubject;
  final Map<String, List<QuickContentTemplate>> templatesBySubject;
  final QuickContentTemplateSort templateSort;

  QuickContentLocalPreferences rememberGroup({
    required String subjectId,
    required String name,
    DateTime? selectedAt,
  }) => copyWith(
    recentGroupBySubject: {
      ...recentGroupBySubject,
      subjectId: QuickContentRecentGroup(
        name: name,
        selectedAt: (selectedAt ?? DateTime.now()).toUtc(),
      ),
    },
  );

  QuickContentLocalPreferences rememberKind({
    required String subjectId,
    required LearningItemKind kind,
  }) => copyWith(lastKindBySubject: {...lastKindBySubject, subjectId: kind});

  QuickContentLocalPreferences rememberTags({
    required String subjectId,
    required Iterable<String> tags,
  }) {
    final combined = <String>[
      ...tags,
      ...(recentTagsBySubject[subjectId] ?? const <String>[]),
    ];
    return copyWith(
      recentTagsBySubject: {
        ...recentTagsBySubject,
        subjectId: _safeRecentTags(combined),
      },
    );
  }

  List<QuickContentTemplate> orderedTemplates(String subjectId) {
    final result = <QuickContentTemplate>[
      ...templatesBySubject[subjectId] ?? const <QuickContentTemplate>[],
    ];
    result.sort((left, right) {
      final pin = (right.pinned ? 1 : 0).compareTo(left.pinned ? 1 : 0);
      if (pin != 0) return pin;
      return switch (templateSort) {
        QuickContentTemplateSort.recent => right.updatedAt.compareTo(
          left.updatedAt,
        ),
        QuickContentTemplateSort.name => left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        ),
        QuickContentTemplateSort.created => left.createdAt.compareTo(
          right.createdAt,
        ),
      };
    });
    return List.unmodifiable(result);
  }

  QuickContentLocalPreferences saveTemplate({
    required String subjectId,
    required QuickContentTemplate template,
  }) {
    final existing = <QuickContentTemplate>[
      ...templatesBySubject[subjectId] ?? const <QuickContentTemplate>[],
    ]..removeWhere((item) => item.id == template.id);
    existing.insert(0, template);
    if (existing.length > quickContentTemplateLimit) {
      final removable = existing.lastIndexWhere((item) => !item.pinned);
      existing.removeAt(removable < 0 ? existing.length - 1 : removable);
    }
    return copyWith(
      templatesBySubject: {...templatesBySubject, subjectId: existing},
    );
  }

  QuickContentLocalPreferences renameTemplate({
    required String subjectId,
    required String id,
    required String name,
    DateTime? at,
  }) => _updateTemplate(
    subjectId,
    id,
    (item) => item.copyWith(name: name, updatedAt: at ?? DateTime.now()),
  );

  QuickContentLocalPreferences toggleTemplatePinned({
    required String subjectId,
    required String id,
    DateTime? at,
  }) => _updateTemplate(
    subjectId,
    id,
    (item) =>
        item.copyWith(pinned: !item.pinned, updatedAt: at ?? DateTime.now()),
  );

  QuickContentLocalPreferences deleteTemplate({
    required String subjectId,
    required String id,
  }) {
    final next = <QuickContentTemplate>[
      ...templatesBySubject[subjectId] ?? const <QuickContentTemplate>[],
    ]..removeWhere((item) => item.id == id);
    return copyWith(
      templatesBySubject: {...templatesBySubject, subjectId: next},
    );
  }

  QuickContentLocalPreferences duplicateTemplate({
    required String subjectId,
    required String sourceId,
    required String newId,
    required String newName,
    DateTime? at,
  }) {
    final source =
        (templatesBySubject[subjectId] ?? const <QuickContentTemplate>[])
            .where((item) => item.id == sourceId)
            .firstOrNull;
    if (source == null) return this;
    final timestamp = (at ?? DateTime.now()).toUtc();
    return saveTemplate(
      subjectId: subjectId,
      template: source.copyWith(
        id: newId,
        name: newName,
        pinned: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }

  QuickContentLocalPreferences _updateTemplate(
    String subjectId,
    String id,
    QuickContentTemplate Function(QuickContentTemplate) update,
  ) {
    final next = [
      for (final item
          in templatesBySubject[subjectId] ?? const <QuickContentTemplate>[])
        if (item.id == id) update(item) else item,
    ];
    return copyWith(
      templatesBySubject: {...templatesBySubject, subjectId: next},
    );
  }

  QuickContentLocalPreferences copyWith({
    Map<String, QuickContentRecentGroup>? recentGroupBySubject,
    Map<String, LearningItemKind>? lastKindBySubject,
    Map<String, List<String>>? recentTagsBySubject,
    Map<String, List<QuickContentTemplate>>? templatesBySubject,
    QuickContentTemplateSort? templateSort,
  }) => QuickContentLocalPreferences(
    recentGroupBySubject: Map.unmodifiable(
      recentGroupBySubject ?? this.recentGroupBySubject,
    ),
    lastKindBySubject: Map.unmodifiable(
      lastKindBySubject ?? this.lastKindBySubject,
    ),
    recentTagsBySubject: _freezeStringLists(
      recentTagsBySubject ?? this.recentTagsBySubject,
    ),
    templatesBySubject: _freezeTemplates(
      templatesBySubject ?? this.templatesBySubject,
    ),
    templateSort: templateSort ?? this.templateSort,
  );

  Map<String, Object?> toJson() => {
    'version': 3,
    'recentGroupBySubject': {
      for (final entry in recentGroupBySubject.entries)
        entry.key: entry.value.toJson(),
    },
    'lastKindBySubject': {
      for (final entry in lastKindBySubject.entries)
        entry.key: entry.value.name,
    },
    'recentTagsBySubject': {
      for (final entry in recentTagsBySubject.entries) entry.key: entry.value,
    },
    'templatesBySubject': {
      for (final entry in templatesBySubject.entries)
        entry.key: entry.value.map((item) => item.toJson()).toList(),
    },
    'templateSort': templateSort.name,
  };
}

Map<String, List<String>> _freezeStringLists(
  Map<String, List<String>> source,
) => Map<String, List<String>>.unmodifiable({
  for (final entry in source.entries)
    entry.key: List<String>.unmodifiable(entry.value),
});

Map<String, List<QuickContentTemplate>> _freezeTemplates(
  Map<String, List<QuickContentTemplate>> source,
) => Map<String, List<QuickContentTemplate>>.unmodifiable({
  for (final entry in source.entries)
    entry.key: List<QuickContentTemplate>.unmodifiable(entry.value),
});

List<String> _safeRecentTags(Iterable<Object?> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in values) {
    if (raw is! String) continue;
    final tag = String.fromCharCodes(raw.trim().runes.take(40));
    if (tag.isEmpty ||
        tag.contains(RegExp(r'[\u0000-\u001F]')) ||
        !seen.add(tag.toLowerCase())) {
      continue;
    }
    result.add(tag);
    if (result.length == 12) break;
  }
  return List.unmodifiable(result);
}

T? _enumByName<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

int? _safeInt(Object? raw) => switch (raw) {
  final int value => value,
  final num value when value.isFinite && value == value.round() =>
    value.toInt(),
  _ => null,
};

DateTime? _safeDate(Object? raw) => switch (raw) {
  final String value => DateTime.tryParse(value)?.toUtc(),
  _ => null,
};

String _boundedRequired(
  String value, {
  required int maxRunes,
  required String field,
}) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty || normalized.runes.length > maxRunes) {
    throw FormatException('$field은(는) 1~$maxRunes자여야 합니다.');
  }
  if (normalized.contains(RegExp(r'[\u0000-\u001F]'))) {
    throw FormatException('$field에 제어 문자를 사용할 수 없습니다.');
  }
  return normalized;
}

String? _optionalBounded(String? value, int maxRunes) {
  if (value == null) return null;
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return null;
  if (normalized.contains(RegExp(r'[\u0000-\u001F]'))) return null;
  return String.fromCharCodes(normalized.runes.take(maxRunes));
}

bool _isSafeMapKey(String value) =>
    value.isNotEmpty &&
    value.runes.length <= 120 &&
    !value.contains(RegExp(r'[\u0000-\u001F]'));

Map<String, Object?> _stringKeyed(Map<Object?, Object?> source) => {
  for (final entry in source.entries)
    if (entry.key is String) entry.key! as String: entry.value,
};
