import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/sync/conflict_merger.dart';
import 'package:sprache/src/sync/sync_models.dart';

void main() {
  const merger = ConflictMerger();
  final time = DateTime.utc(2026, 7, 27);

  SyncRecord record({
    required String id,
    required String device,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return SyncRecord(
      id: id,
      updatedAt: updatedAt ?? time,
      deviceId: device,
      payload: const {'status': 'review'},
      deletedAt: deletedAt,
    );
  }

  test('newer item wins across devices', () {
    final result = merger.mergeRecords(
      local: [record(id: 'word', device: 'a')],
      remote: [
        record(
          id: 'word',
          device: 'b',
          updatedAt: time.add(const Duration(minutes: 1)),
        ),
      ],
    );

    expect(result['word']!.deviceId, 'b');
  });

  test('tombstone wins when timestamps are equal', () {
    final result = merger.mergeRecords(
      local: [record(id: 'word', device: 'a')],
      remote: [record(id: 'word', device: 'b', deletedAt: time)],
    );

    expect(result['word']!.deleted, isTrue);
  });

  test('events are deduplicated by event and device', () {
    final first = record(id: 'event', device: 'a');
    final result = merger.mergeEvents(
      local: [first],
      remote: [
        first,
        record(id: 'event', device: 'b'),
      ],
    );

    expect(result, hasLength(2));
  });
}
