import 'dart:convert';

enum SyncChangeSection {
  progress,
  content,
  settings,
  profile,
  recentSessions,
  activeSession,
}

extension SyncChangeSectionLabel on SyncChangeSection {
  String get label => switch (this) {
    SyncChangeSection.progress => '학습 진도',
    SyncChangeSection.content => '개인 콘텐츠',
    SyncChangeSection.settings => '학습 설정·일정',
    SyncChangeSection.profile => 'XP·배지·연속 학습',
    SyncChangeSection.recentSessions => '최근 학습 기록',
    SyncChangeSection.activeSession => '진행 중 세션',
  };
}

enum SyncMergeDecision {
  uploadLocal,
  downloadRemote,
  keepLocal,
  useRemote,
  merge,
}

extension SyncMergeDecisionLabel on SyncMergeDecision {
  String get label => switch (this) {
    SyncMergeDecision.uploadLocal => '이 기기 변경을 Drive에 반영',
    SyncMergeDecision.downloadRemote => 'Drive 변경을 이 기기에 반영',
    SyncMergeDecision.keepLocal => '충돌 검토 · 이 기기의 최신값 유지',
    SyncMergeDecision.useRemote => '충돌 검토 · Drive의 최신값 적용',
    SyncMergeDecision.merge => '충돌 검토 · 양쪽 값을 안전하게 병합',
  };

  bool get isConflict => switch (this) {
    SyncMergeDecision.keepLocal ||
    SyncMergeDecision.useRemote ||
    SyncMergeDecision.merge => true,
    _ => false,
  };
}

class SyncMergeChange {
  const SyncMergeChange({
    required this.section,
    required this.recordId,
    required this.decision,
  });

  final SyncChangeSection section;
  final String recordId;
  final SyncMergeDecision decision;
}

class SyncMergeReport {
  const SyncMergeReport({required this.syncedAt, required this.changes});

  final DateTime syncedAt;
  final List<SyncMergeChange> changes;

  int get uploadCount => changes
      .where((change) => change.decision == SyncMergeDecision.uploadLocal)
      .length;
  int get downloadCount => changes
      .where((change) => change.decision == SyncMergeDecision.downloadRemote)
      .length;
  int get conflictCount =>
      changes.where((change) => change.decision.isConflict).length;
  bool get isEmpty => changes.isEmpty;
}

class SyncMergeReporter {
  const SyncMergeReporter();

  SyncMergeReport build({
    required Map<String, Object?> local,
    required Map<String, Object?>? remote,
    required Map<String, Object?> merged,
    required DateTime syncedAt,
  }) {
    final changes =
        <SyncMergeChange>[
          ..._recordChanges(
            section: SyncChangeSection.progress,
            local: _records(local['progress'], idKey: 'itemId'),
            remote: _records(remote?['progress'], idKey: 'itemId'),
            merged: _records(merged['progress'], idKey: 'itemId'),
          ),
          ..._recordChanges(
            section: SyncChangeSection.content,
            local: _contentRecords(local),
            remote: remote == null ? const {} : _contentRecords(remote),
            merged: _contentRecords(merged),
          ),
          ..._singletonChange(
            section: SyncChangeSection.settings,
            recordId: 'settings',
            local: local['settings'],
            remote: remote?['settings'],
            merged: merged['settings'],
            remoteExists: remote?.containsKey('settings') ?? false,
          ),
          ..._singletonChange(
            section: SyncChangeSection.profile,
            recordId: 'profile',
            local: local['profile'],
            remote: remote?['profile'],
            merged: merged['profile'],
            remoteExists: remote?.containsKey('profile') ?? false,
          ),
          ..._recordChanges(
            section: SyncChangeSection.recentSessions,
            local: _records(local['recentSessions'], idKey: 'sessionId'),
            remote: _records(remote?['recentSessions'], idKey: 'sessionId'),
            merged: _records(merged['recentSessions'], idKey: 'sessionId'),
          ),
          ..._singletonChange(
            section: SyncChangeSection.activeSession,
            recordId: 'activeStudy',
            local: local['activeStudy'],
            remote: remote?['activeStudy'],
            merged: merged['activeStudy'],
            remoteExists: remote?.containsKey('activeStudy') ?? false,
          ),
        ]..sort((left, right) {
          final sectionOrder = left.section.index.compareTo(
            right.section.index,
          );
          if (sectionOrder != 0) return sectionOrder;
          return left.recordId.compareTo(right.recordId);
        });
    return SyncMergeReport(
      syncedAt: syncedAt.toUtc(),
      changes: List.unmodifiable(changes.take(100)),
    );
  }

  List<SyncMergeChange> _recordChanges({
    required SyncChangeSection section,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
    required Map<String, Object?> merged,
  }) {
    final ids = {...local.keys, ...remote.keys}.toList()..sort();
    final changes = <SyncMergeChange>[];
    for (final id in ids) {
      final localExists = local.containsKey(id);
      final remoteExists = remote.containsKey(id);
      if (!localExists && remoteExists) {
        changes.add(
          SyncMergeChange(
            section: section,
            recordId: id,
            decision: SyncMergeDecision.downloadRemote,
          ),
        );
        continue;
      }
      if (localExists && !remoteExists) {
        changes.add(
          SyncMergeChange(
            section: section,
            recordId: id,
            decision: SyncMergeDecision.uploadLocal,
          ),
        );
        continue;
      }
      if (_same(local[id], remote[id])) continue;
      changes.add(
        SyncMergeChange(
          section: section,
          recordId: id,
          decision: _conflictDecision(
            local: local[id],
            remote: remote[id],
            merged: merged[id],
          ),
        ),
      );
    }
    return changes;
  }

  List<SyncMergeChange> _singletonChange({
    required SyncChangeSection section,
    required String recordId,
    required Object? local,
    required Object? remote,
    required Object? merged,
    required bool remoteExists,
  }) {
    if (!remoteExists) {
      return _isEmpty(local)
          ? const []
          : [
              SyncMergeChange(
                section: section,
                recordId: recordId,
                decision: SyncMergeDecision.uploadLocal,
              ),
            ];
    }
    if (_same(local, remote)) return const [];
    return [
      SyncMergeChange(
        section: section,
        recordId: recordId,
        decision: _conflictDecision(
          local: local,
          remote: remote,
          merged: merged,
        ),
      ),
    ];
  }

  SyncMergeDecision _conflictDecision({
    required Object? local,
    required Object? remote,
    required Object? merged,
  }) {
    if (_same(merged, local)) return SyncMergeDecision.keepLocal;
    if (_same(merged, remote)) return SyncMergeDecision.useRemote;
    return SyncMergeDecision.merge;
  }

  Map<String, Object?> _records(Object? raw, {required String idKey}) {
    if (raw is! List<Object?>) return const {};
    return {
      for (final value in raw)
        if (value is Map && value[idKey] is String)
          value[idKey]! as String: Map<String, Object?>.from(value),
    };
  }

  Map<String, Object?> _contentRecords(Map<String, Object?> snapshot) {
    final result = <String, Object?>{};
    for (final entry in _records(
      snapshot['customItems'],
      idKey: 'id',
    ).entries) {
      result[entry.key] = {'state': 'item', 'value': entry.value};
    }
    for (final entry in _records(
      snapshot['customItemTombstones'],
      idKey: 'id',
    ).entries) {
      result[entry.key] = {'state': 'deleted', 'value': entry.value};
    }
    return result;
  }

  bool _same(Object? left, Object? right) =>
      jsonEncode(_canonical(left)) == jsonEncode(_canonical(right));

  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) {
      return [for (final item in value) _canonical(item)];
    }
    return value;
  }

  bool _isEmpty(Object? value) =>
      value == null ||
      (value is Map && value.isEmpty) ||
      (value is List && value.isEmpty);
}
