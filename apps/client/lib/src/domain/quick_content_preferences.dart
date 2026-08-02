class QuickContentRecentGroup {
  const QuickContentRecentGroup({required this.name, required this.selectedAt});

  factory QuickContentRecentGroup.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final selectedAt = json['selectedAt'];
    if (name is! String || selectedAt is! String) {
      throw const FormatException('최근 그룹 정보가 손상됐습니다.');
    }
    final parsed = DateTime.tryParse(selectedAt);
    if (parsed == null) {
      throw const FormatException('최근 그룹 시간이 잘못됐습니다.');
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

class QuickContentLocalPreferences {
  const QuickContentLocalPreferences({this.recentGroupBySubject = const {}});

  factory QuickContentLocalPreferences.fromJson(Map<String, Object?> json) {
    final recent = <String, QuickContentRecentGroup>{};
    if (json['recentGroupBySubject'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries) {
        final subjectId = entry.key;
        final value = entry.value;
        if (subjectId is! String || value is! Map<Object?, Object?>) continue;
        try {
          recent[subjectId] = QuickContentRecentGroup.fromJson(
            Map<String, Object?>.from(value),
          );
        } on FormatException {
          // Keep other subjects when one local preference entry is damaged.
        }
      }
    }
    return QuickContentLocalPreferences(
      recentGroupBySubject: Map.unmodifiable(recent),
    );
  }

  final Map<String, QuickContentRecentGroup> recentGroupBySubject;

  QuickContentLocalPreferences rememberGroup({
    required String subjectId,
    required String name,
    DateTime? selectedAt,
  }) => QuickContentLocalPreferences(
    recentGroupBySubject: Map.unmodifiable({
      ...recentGroupBySubject,
      subjectId: QuickContentRecentGroup(
        name: name,
        selectedAt: (selectedAt ?? DateTime.now()).toUtc(),
      ),
    }),
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'recentGroupBySubject': {
      for (final entry in recentGroupBySubject.entries)
        entry.key: entry.value.toJson(),
    },
  };
}
