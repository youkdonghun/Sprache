import 'sync_models.dart';

class ConflictMerger {
  const ConflictMerger();

  Map<String, SyncRecord> mergeRecords({
    required Iterable<SyncRecord> local,
    required Iterable<SyncRecord> remote,
  }) {
    final merged = <String, SyncRecord>{
      for (final record in local) record.id: record,
    };
    for (final candidate in remote) {
      final current = merged[candidate.id];
      if (current == null || _candidateWins(candidate, current)) {
        merged[candidate.id] = candidate;
      }
    }
    return merged;
  }

  List<SyncRecord> mergeEvents({
    required Iterable<SyncRecord> local,
    required Iterable<SyncRecord> remote,
  }) {
    final events = <String, SyncRecord>{};
    for (final event in [...local, ...remote]) {
      final key = '${event.id}:${event.deviceId}';
      final current = events[key];
      if (current == null || _candidateWins(event, current)) {
        events[key] = event;
      }
    }
    final result = events.values.toList()
      ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    return result;
  }

  bool _candidateWins(SyncRecord candidate, SyncRecord current) {
    final timeOrder = candidate.updatedAt.compareTo(current.updatedAt);
    if (timeOrder != 0) return timeOrder > 0;
    if (candidate.deleted != current.deleted) return candidate.deleted;
    return candidate.deviceId.compareTo(current.deviceId) > 0;
  }
}
