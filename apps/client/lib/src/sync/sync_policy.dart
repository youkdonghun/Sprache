enum SyncMode { automatic, wifiOnly, manual }

extension SyncModeLabel on SyncMode {
  String get label => switch (this) {
    SyncMode.automatic => '자동',
    SyncMode.wifiOnly => 'Wi-Fi에서만',
    SyncMode.manual => '수동',
  };
}

enum SyncDisplayStatus { localSaved, waiting, syncing, error, completed }

extension SyncDisplayStatusLabel on SyncDisplayStatus {
  String get label => switch (this) {
    SyncDisplayStatus.localSaved => '로컬 저장',
    SyncDisplayStatus.waiting => '동기화 대기',
    SyncDisplayStatus.syncing => '동기화 중',
    SyncDisplayStatus.error => '동기화 오류',
    SyncDisplayStatus.completed => '동기화 완료',
  };
}

class SyncPolicy {
  const SyncPolicy({
    this.mode = SyncMode.automatic,
    this.pauseInLowPowerMode = true,
  });

  final SyncMode mode;
  final bool pauseInLowPowerMode;

  SyncPolicy copyWith({SyncMode? mode, bool? pauseInLowPowerMode}) {
    return SyncPolicy(
      mode: mode ?? this.mode,
      pauseInLowPowerMode: pauseInLowPowerMode ?? this.pauseInLowPowerMode,
    );
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'pauseInLowPowerMode': pauseInLowPowerMode,
  };

  factory SyncPolicy.fromJson(Map<String, Object?> json) {
    return SyncPolicy(
      mode: SyncMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => SyncMode.automatic,
      ),
      pauseInLowPowerMode: json['pauseInLowPowerMode'] != false,
    );
  }
}

enum SyncHistoryStatus { success, failed, skipped }

enum SyncVersionSelection { local, drive }

class SyncItemComparison {
  const SyncItemComparison({
    required this.section,
    required this.recordId,
    required this.localExists,
    required this.driveExists,
    required this.localPreview,
    required this.drivePreview,
    this.selection,
  });

  final String section;
  final String recordId;
  final bool localExists;
  final bool driveExists;
  final String localPreview;
  final String drivePreview;
  final SyncVersionSelection? selection;

  String get key => '$section::$recordId';

  SyncItemComparison copyWith({SyncVersionSelection? selection}) {
    return SyncItemComparison(
      section: section,
      recordId: recordId,
      localExists: localExists,
      driveExists: driveExists,
      localPreview: localPreview,
      drivePreview: drivePreview,
      selection: selection ?? this.selection,
    );
  }

  Map<String, Object?> toJson() => {
    'section': section,
    'recordId': recordId,
    'localExists': localExists,
    'driveExists': driveExists,
    'localPreview': localPreview,
    'drivePreview': drivePreview,
    if (selection != null) 'selection': selection!.name,
  };

  factory SyncItemComparison.fromJson(Map<String, Object?> json) {
    final section = json['section'];
    final recordId = json['recordId'];
    if (section is! String ||
        section.trim().isEmpty ||
        recordId is! String ||
        recordId.trim().isEmpty) {
      throw const FormatException('동기화 비교 항목이 올바르지 않습니다.');
    }
    return SyncItemComparison(
      section: section,
      recordId: recordId,
      localExists: json['localExists'] == true,
      driveExists: json['driveExists'] == true,
      localPreview: json['localPreview'] as String? ?? '',
      drivePreview: json['drivePreview'] as String? ?? '',
      selection: SyncVersionSelection.values
          .where((value) => value.name == json['selection'])
          .firstOrNull,
    );
  }
}

class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.summary,
    this.changeCount = 0,
    this.diagnosticCode,
    this.mergeReport,
    this.comparisons = const [],
  });

  final String id;
  final SyncHistoryStatus status;
  final DateTime startedAt;
  final DateTime endedAt;
  final String summary;
  final int changeCount;
  final String? diagnosticCode;
  final Map<String, Object?>? mergeReport;
  final List<SyncItemComparison> comparisons;

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'summary': summary,
    'changeCount': changeCount.clamp(0, 100000),
    if (diagnosticCode != null) 'diagnosticCode': diagnosticCode,
    if (mergeReport != null) 'mergeReport': mergeReport,
    if (comparisons.isNotEmpty)
      'comparisons': [
        for (final comparison in comparisons.take(100)) comparison.toJson(),
      ],
  };

  factory SyncHistoryEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final endedAt = DateTime.tryParse(json['endedAt'] as String? ?? '');
    if (id is! String ||
        id.trim().isEmpty ||
        startedAt == null ||
        endedAt == null) {
      throw const FormatException('동기화 이력이 올바르지 않습니다.');
    }
    return SyncHistoryEntry(
      id: id,
      status: SyncHistoryStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => SyncHistoryStatus.failed,
      ),
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      summary: json['summary'] as String? ?? '',
      changeCount: ((json['changeCount'] as num?)?.toInt() ?? 0).clamp(
        0,
        100000,
      ),
      diagnosticCode: json['diagnosticCode'] as String?,
      mergeReport: json['mergeReport'] is Map
          ? Map<String, Object?>.from(json['mergeReport']! as Map)
          : null,
      comparisons: [
        for (final raw
            in ((json['comparisons'] as List<Object?>?) ?? const []).take(100))
          if (raw is Map)
            SyncItemComparison.fromJson(Map<String, Object?>.from(raw)),
      ],
    );
  }
}

class SyncRecoveryPoint {
  const SyncRecoveryPoint({
    required this.id,
    required this.createdAt,
    required this.localSnapshot,
    required this.mergedSnapshot,
    this.driveSnapshot,
  });

  final String id;
  final DateTime createdAt;
  final Map<String, Object?> localSnapshot;
  final Map<String, Object?>? driveSnapshot;
  final Map<String, Object?> mergedSnapshot;

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'localSnapshot': localSnapshot,
    if (driveSnapshot != null) 'driveSnapshot': driveSnapshot,
    'mergedSnapshot': mergedSnapshot,
  };

  factory SyncRecoveryPoint.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final local = json['localSnapshot'];
    final merged = json['mergedSnapshot'];
    if (id is! String ||
        id.trim().isEmpty ||
        createdAt == null ||
        local is! Map ||
        merged is! Map) {
      throw const FormatException('동기화 복구 지점이 올바르지 않습니다.');
    }
    return SyncRecoveryPoint(
      id: id,
      createdAt: createdAt.toUtc(),
      localSnapshot: Map<String, Object?>.from(local),
      driveSnapshot: json['driveSnapshot'] is Map
          ? Map<String, Object?>.from(json['driveSnapshot']! as Map)
          : null,
      mergedSnapshot: Map<String, Object?>.from(merged),
    );
  }
}

class SyncDeviceSettings {
  const SyncDeviceSettings({
    this.policy = const SyncPolicy(),
    this.history = const [],
    this.recoveryPoint,
  });

  final SyncPolicy policy;
  final List<SyncHistoryEntry> history;
  final SyncRecoveryPoint? recoveryPoint;

  SyncDeviceSettings copyWith({
    SyncPolicy? policy,
    List<SyncHistoryEntry>? history,
    Object? recoveryPoint = _keepRecoveryPoint,
  }) {
    return SyncDeviceSettings(
      policy: policy ?? this.policy,
      history: history ?? this.history,
      recoveryPoint: identical(recoveryPoint, _keepRecoveryPoint)
          ? this.recoveryPoint
          : recoveryPoint as SyncRecoveryPoint?,
    );
  }

  Map<String, Object?> toJson() => {
    'policy': policy.toJson(),
    'history': [for (final entry in history.take(50)) entry.toJson()],
    if (recoveryPoint != null) 'recoveryPoint': recoveryPoint!.toJson(),
  };

  factory SyncDeviceSettings.fromJson(Map<String, Object?> json) {
    SyncRecoveryPoint? recoveryPoint;
    try {
      if (json['recoveryPoint'] is Map) {
        recoveryPoint = SyncRecoveryPoint.fromJson(
          Map<String, Object?>.from(json['recoveryPoint']! as Map),
        );
      }
    } on FormatException {
      recoveryPoint = null;
    }
    return SyncDeviceSettings(
      policy: json['policy'] is Map
          ? SyncPolicy.fromJson(
              Map<String, Object?>.from(json['policy']! as Map),
            )
          : const SyncPolicy(),
      history: _parseSyncHistory(json['history']),
      recoveryPoint: recoveryPoint,
    );
  }
}

const _keepRecoveryPoint = Object();

List<SyncHistoryEntry> _parseSyncHistory(Object? raw) {
  final entries = <SyncHistoryEntry>[];
  if (raw is! List<Object?>) return entries;
  for (final value in raw.take(50)) {
    if (value is! Map) continue;
    try {
      entries.add(SyncHistoryEntry.fromJson(Map<String, Object?>.from(value)));
    } on FormatException {
      // One malformed local history row must not hide the remaining history.
    }
  }
  return List.unmodifiable(entries);
}
