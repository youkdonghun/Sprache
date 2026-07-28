import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/sync/pending_sync.dart';

void main() {
  test('retry backoff grows and caps at five minutes', () {
    expect(pendingSyncBackoff(1), const Duration(seconds: 5));
    expect(pendingSyncBackoff(4), const Duration(seconds: 40));
    expect(pendingSyncBackoff(7), const Duration(minutes: 5));
    expect(pendingSyncBackoff(100), const Duration(minutes: 5));
  });

  test('operation due state and retry copy preserve identity', () {
    final now = DateTime.utc(2026, 7, 28, 10);
    final operation = PendingSyncOperation(
      operationId: 'snapshot-1',
      entityType: PendingSyncEntityType.snapshot,
      entityId: 'state/snapshot.json',
      payload: const {'schemaVersion': 1},
      attempts: 0,
      nextAttemptAt: now,
      createdAt: now,
    );

    expect(operation.isDue(now), isTrue);
    final retried = operation.copyWith(
      attempts: 1,
      nextAttemptAt: now.add(const Duration(seconds: 5)),
    );

    expect(retried.operationId, operation.operationId);
    expect(retried.createdAt, operation.createdAt);
    expect(retried.isDue(now), isFalse);
  });
}
