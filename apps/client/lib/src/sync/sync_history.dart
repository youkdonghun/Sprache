import 'dart:convert';

import 'sync_policy.dart';

class SyncSnapshotDiffer {
  const SyncSnapshotDiffer();

  List<SyncItemComparison> compare({
    required Map<String, Object?> local,
    required Map<String, Object?>? drive,
  }) {
    if (drive == null) {
      return _allLocalOnly(local);
    }
    final comparisons = <SyncItemComparison>[
      ..._recordComparisons(
        section: 'progress',
        local: _records(local['progress'], 'itemId'),
        drive: _records(drive['progress'], 'itemId'),
      ),
      ..._recordComparisons(
        section: 'content',
        local: _contentRecords(local),
        drive: _contentRecords(drive),
      ),
      ..._singletonComparison(
        section: 'settings',
        recordId: 'settings',
        local: local['settings'],
        drive: drive['settings'],
        localExists: local.containsKey('settings'),
        driveExists: drive.containsKey('settings'),
      ),
      ..._singletonComparison(
        section: 'profile',
        recordId: 'profile',
        local: local['profile'],
        drive: drive['profile'],
        localExists: local.containsKey('profile'),
        driveExists: drive.containsKey('profile'),
      ),
      ..._recordComparisons(
        section: 'recentSessions',
        local: _records(local['recentSessions'], 'sessionId'),
        drive: _records(drive['recentSessions'], 'sessionId'),
      ),
      ..._singletonComparison(
        section: 'activeSession',
        recordId: 'activeStudy',
        local: local['activeStudy'],
        drive: drive['activeStudy'],
        localExists: local.containsKey('activeStudy'),
        driveExists: drive.containsKey('activeStudy'),
      ),
    ]..sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(comparisons.take(100));
  }

  List<SyncItemComparison> _allLocalOnly(Map<String, Object?> local) {
    return compare(local: local, drive: const <String, Object?>{});
  }

  List<SyncItemComparison> _recordComparisons({
    required String section,
    required Map<String, Object?> local,
    required Map<String, Object?> drive,
  }) {
    final ids = {...local.keys, ...drive.keys}.toList()..sort();
    return [
      for (final id in ids)
        if (!_same(local[id], drive[id]) ||
            local.containsKey(id) != drive.containsKey(id))
          SyncItemComparison(
            section: section,
            recordId: id,
            localExists: local.containsKey(id),
            driveExists: drive.containsKey(id),
            localPreview: _preview(local[id]),
            drivePreview: _preview(drive[id]),
          ),
    ];
  }

  List<SyncItemComparison> _singletonComparison({
    required String section,
    required String recordId,
    required Object? local,
    required Object? drive,
    required bool localExists,
    required bool driveExists,
  }) {
    if (localExists == driveExists && _same(local, drive)) return const [];
    return [
      SyncItemComparison(
        section: section,
        recordId: recordId,
        localExists: localExists,
        driveExists: driveExists,
        localPreview: _preview(local),
        drivePreview: _preview(drive),
      ),
    ];
  }

  Map<String, Object?> _records(Object? raw, String idKey) {
    if (raw is! List<Object?>) return const {};
    return {
      for (final value in raw)
        if (value is Map && value[idKey] is String)
          value[idKey]! as String: Map<String, Object?>.from(value),
    };
  }

  Map<String, Object?> _contentRecords(Map<String, Object?> snapshot) {
    final records = <String, Object?>{};
    for (final entry in _records(snapshot['customItems'], 'id').entries) {
      records[entry.key] = {'state': 'item', 'value': entry.value};
    }
    for (final entry in _records(
      snapshot['customItemTombstones'],
      'id',
    ).entries) {
      records[entry.key] = {'state': 'deleted', 'value': entry.value};
    }
    return records;
  }

  bool _same(Object? left, Object? right) {
    return jsonEncode(_canonical(left)) == jsonEncode(_canonical(right));
  }

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

  String _preview(Object? value) {
    if (value == null) return '없음';
    final encoded = jsonEncode(_canonical(value));
    return encoded.length <= 600 ? encoded : '${encoded.substring(0, 597)}...';
  }
}

class SyncSnapshotResolver {
  const SyncSnapshotResolver();

  Map<String, Object?> resolve({
    required Map<String, Object?> local,
    required Map<String, Object?>? drive,
    required Map<String, Object?> merged,
    required Map<String, SyncVersionSelection> selections,
  }) {
    final result = _cloneMap(merged);
    if (drive == null || selections.isEmpty) {
      result['schemaVersion'] = 2;
      result['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      return result;
    }
    for (final entry in selections.entries) {
      final splitAt = entry.key.indexOf('::');
      if (splitAt <= 0 || splitAt == entry.key.length - 2) continue;
      final section = entry.key.substring(0, splitAt);
      final recordId = entry.key.substring(splitAt + 2);
      final source = entry.value == SyncVersionSelection.local ? local : drive;
      switch (section) {
        case 'progress':
          _replaceListRecord(
            result,
            source,
            field: 'progress',
            idKey: 'itemId',
            recordId: recordId,
          );
          break;
        case 'content':
          _replaceContentRecord(result, source, recordId);
          break;
        case 'recentSessions':
          _replaceListRecord(
            result,
            source,
            field: 'recentSessions',
            idKey: 'sessionId',
            recordId: recordId,
          );
          break;
        case 'settings':
          _replaceSingleton(result, source, 'settings');
          break;
        case 'profile':
          _replaceSingleton(result, source, 'profile');
          break;
        case 'activeSession':
          _replaceSingleton(result, source, 'activeStudy');
          break;
      }
    }
    result['schemaVersion'] = 2;
    result['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    return result;
  }

  void _replaceSingleton(
    Map<String, Object?> result,
    Map<String, Object?> source,
    String field,
  ) {
    if (source.containsKey(field)) {
      result[field] = _clone(source[field]);
    } else {
      result.remove(field);
    }
  }

  void _replaceListRecord(
    Map<String, Object?> result,
    Map<String, Object?> source, {
    required String field,
    required String idKey,
    required String recordId,
  }) {
    final next = <Object?>[
      for (final value in (result[field] as List<Object?>?) ?? const [])
        if (value is! Map || value[idKey] != recordId) _clone(value),
    ];
    for (final value in (source[field] as List<Object?>?) ?? const []) {
      if (value is Map && value[idKey] == recordId) {
        next.add(_clone(value));
        break;
      }
    }
    result[field] = next;
  }

  void _replaceContentRecord(
    Map<String, Object?> result,
    Map<String, Object?> source,
    String recordId,
  ) {
    _replaceListRecord(
      result,
      const <String, Object?>{},
      field: 'customItems',
      idKey: 'id',
      recordId: recordId,
    );
    _replaceListRecord(
      result,
      const <String, Object?>{},
      field: 'customItemTombstones',
      idKey: 'id',
      recordId: recordId,
    );
    for (final field in const ['customItems', 'customItemTombstones']) {
      final idKey = 'id';
      for (final value in (source[field] as List<Object?>?) ?? const []) {
        if (value is Map && value[idKey] == recordId) {
          final target = (result[field] as List<Object?>?)?.toList() ?? [];
          target.add(_clone(value));
          result[field] = target;
          return;
        }
      }
    }
  }

  Map<String, Object?> _cloneMap(Map<String, Object?> value) {
    return Map<String, Object?>.from(
      jsonDecode(jsonEncode(value)) as Map<Object?, Object?>,
    );
  }

  Object? _clone(Object? value) => jsonDecode(jsonEncode(value));
}
