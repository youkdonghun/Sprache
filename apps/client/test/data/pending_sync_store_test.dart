import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/sync/pending_sync.dart';

void main() {
  test(
    'Drift store coalesces, retries, and removes snapshot operations',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = DriftStudyStore(database);
      final firstAt = DateTime.utc(2026, 7, 28, 10);
      final first = PendingSyncOperation(
        operationId: 'snapshot-first',
        entityType: PendingSyncEntityType.snapshot,
        entityId: 'state/snapshot.json',
        payload: const {'schemaVersion': 1, 'value': 'first'},
        attempts: 0,
        nextAttemptAt: firstAt,
        createdAt: firstAt,
      );
      final second = PendingSyncOperation(
        operationId: 'snapshot-second',
        entityType: PendingSyncEntityType.snapshot,
        entityId: 'state/snapshot.json',
        payload: const {'schemaVersion': 1, 'value': 'second'},
        attempts: 0,
        nextAttemptAt: firstAt.add(const Duration(minutes: 1)),
        createdAt: firstAt.add(const Duration(minutes: 1)),
      );

      try {
        await store.replacePendingSnapshotSync(first);
        await store.replacePendingSnapshotSync(second);

        final loaded = await store.loadPendingSnapshotSync();
        expect(loaded?.operationId, second.operationId);
        expect(loaded?.payload['value'], 'second');
        expect(
          await database.select(database.pendingSyncs).get(),
          hasLength(1),
        );

        final retried = second.copyWith(
          attempts: 2,
          nextAttemptAt: firstAt.add(const Duration(minutes: 2)),
        );
        await store.updatePendingSync(retried);
        expect((await store.loadPendingSnapshotSync())?.attempts, 2);

        await store.deletePendingSync(second.operationId);
        expect(await store.loadPendingSnapshotSync(), isNull);
      } finally {
        await database.close();
      }
    },
  );
}
