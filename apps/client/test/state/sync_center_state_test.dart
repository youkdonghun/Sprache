import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/sync/sync_policy.dart';
import 'package:sprache/src/sync/pending_sync.dart';

void main() {
  test(
    'complete offline lock blocks Drive calls until explicitly disabled',
    () async {
      final store = MemoryStudyStore(
        syncDeviceSettings: const SyncDeviceSettings(
          policy: SyncPolicy(offlineLock: true),
        ),
      );
      final app = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final service = _TestDriveService();
      final controller = ConnectionController(service, app, store: store);
      await Future<void>.delayed(Duration.zero);

      await app.queueSyncSnapshot();
      controller.observeAppState(app.state);
      await controller.connect();
      await controller.restoreSavedConnection();
      await controller.syncNow();
      await controller.disconnect();

      expect(service.connectCount, 0);
      expect(service.pushCount, 0);
      expect(service.disconnectCount, 0);
      expect(controller.state.policy.offlineLock, isTrue);

      await controller.setPolicy(
        controller.state.policy.copyWith(offlineLock: false),
      );
      await controller.connect();
      expect(service.connectCount, 1);

      controller.dispose();
      app.dispose();
    },
  );

  test(
    'policy and sync history stay device-local and manual sync always works',
    () async {
      final store = MemoryStudyStore(
        syncDeviceSettings: const SyncDeviceSettings(
          policy: SyncPolicy(mode: SyncMode.manual),
        ),
      );
      final app = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final service = _TestDriveService();
      final controller = ConnectionController(
        service,
        app,
        store: store,
        networkInspector: const _NetworkInspector(false),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.policy.mode, SyncMode.manual);
      await controller.connect();
      expect(controller.state.displayStatus, SyncDisplayStatus.completed);
      final pushCountAfterConnect = service.pushCount;

      await app.queueSyncSnapshot();
      controller.observeAppState(app.state);
      expect(controller.state.displayStatus, SyncDisplayStatus.waiting);
      await controller.syncAutomatically();
      expect(service.pushCount, pushCountAfterConnect);
      expect(controller.state.history.first.status, SyncHistoryStatus.skipped);

      await controller.syncNow();
      expect(service.pushCount, pushCountAfterConnect + 1);
      expect(controller.state.displayStatus, SyncDisplayStatus.completed);
      expect(controller.state.recoveryAvailable, isTrue);

      final recreated = ConnectionController(
        service,
        app,
        store: store,
        networkInspector: const _NetworkInspector(true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(recreated.state.policy.mode, SyncMode.manual);
      expect(recreated.state.history, isNotEmpty);
      expect(recreated.state.recoveryAvailable, isTrue);

      final diagnostic = recreated.exportSyncDiagnostics();
      expect(diagnostic, contains('sprache-sync-diagnostic-v2'));
      expect(diagnostic, isNot(contains('folder-secret-id')));

      recreated.dispose();
      controller.dispose();
      app.dispose();
    },
  );

  test('diagnostic bundle excludes record ids and source previews', () async {
    final now = DateTime.utc(2026, 8, 2, 12);
    final store = MemoryStudyStore(
      syncDeviceSettings: SyncDeviceSettings(
        history: [
          SyncHistoryEntry(
            id: 'private-operation-id',
            status: SyncHistoryStatus.failed,
            startedAt: now,
            endedAt: now,
            summary: 'private summary',
            comparisons: const [
              SyncItemComparison(
                section: 'content',
                recordId: 'private-record-id',
                localExists: true,
                driveExists: true,
                localPreview: 'SECRET LOCAL ORIGINAL',
                drivePreview: 'SECRET DRIVE ORIGINAL',
              ),
            ],
          ),
        ],
      ),
    );
    final app = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final controller = ConnectionController(
      _TestDriveService(),
      app,
      store: store,
    );
    await Future<void>.delayed(Duration.zero);

    final diagnostic = controller.exportSyncDiagnostics();

    expect(diagnostic, contains('"content": 1'));
    expect(diagnostic, isNot(contains('private-operation-id')));
    expect(diagnostic, isNot(contains('private-record-id')));
    expect(diagnostic, isNot(contains('SECRET')));
    expect(diagnostic, isNot(contains('private summary')));
    controller.dispose();
    app.dispose();
  });

  test(
    'completed operation receipt prevents duplicate upload after restart',
    () async {
      final now = DateTime.utc(2026, 8, 2, 13);
      final payload = <String, Object?>{
        'schemaVersion': 2,
        'updatedAt': now.toIso8601String(),
      };
      final operation = PendingSyncOperation(
        operationId: 'snapshot-stable-restart',
        entityType: PendingSyncEntityType.snapshot,
        entityId: 'state/snapshot.json',
        payload: payload,
        attempts: 0,
        nextAttemptAt: now,
        createdAt: now,
      );
      final receipt = SyncCompletionReceipt(
        operationId: operation.operationId,
        completedAt: now,
        payloadSha256: sha256
            .convert(utf8.encode(jsonEncode(payload)))
            .toString(),
      );
      final store = MemoryStudyStore(
        pendingSnapshotSync: operation,
        syncDeviceSettings: SyncDeviceSettings(completionReceipts: [receipt]),
      );
      final app = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final service = _TestDriveService();
      final controller = ConnectionController(service, app, store: store);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(app.state.pendingSync, isNull);
      expect(store.pendingSnapshotSync, isNull);
      expect(service.pushCount, 0);
      controller.dispose();
      app.dispose();
    },
  );

  test('last merge recovery restores exact local account totals', () async {
    final store = MemoryStudyStore();
    final app = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final remote = app.exportSyncSnapshot();
    remote['profile'] = {
      ...Map<String, Object?>.from(remote['profile']! as Map),
      'totalXp': 50,
      'xpByReplica': {'remote-device': 50},
    };
    final service = _TestDriveService(snapshot: remote);
    final controller = ConnectionController(service, app, store: store);
    await Future<void>.delayed(Duration.zero);

    await controller.connect();
    expect(app.state.totalXp, 50);
    expect(controller.state.recoveryAvailable, isTrue);

    await controller.restoreLastMerge();

    expect(app.state.totalXp, 0);
    expect(controller.state.recoveryAvailable, isFalse);
    expect(service.snapshot?['schemaVersion'], 2);

    controller.dispose();
    app.dispose();
  });

  test(
    'queued offline work produces one dismissible reconnect summary',
    () async {
      final store = MemoryStudyStore();
      final app = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final service = _TestDriveService();
      final controller = ConnectionController(service, app, store: store);
      await Future<void>.delayed(Duration.zero);

      await controller.connect();
      final initialSummary = controller.state.reconnectSummary;
      if (initialSummary != null) {
        controller.dismissReconnectSummary(initialSummary.id);
      }
      expect(controller.state.reconnectSummary, isNull);

      await app.queueSyncSnapshot();
      controller.observeAppState(app.state);
      expect(controller.state.pendingChanges, isTrue);
      await controller.syncNow();

      final summary = controller.state.reconnectSummary;
      expect(summary, isNotNull);
      expect(summary!.id, isNotEmpty);
      expect(summary.completedAt.isUtc, isTrue);
      expect(summary.message, contains('안전하게'));

      controller.dismissReconnectSummary('another-operation');
      expect(controller.state.reconnectSummary, same(summary));
      controller.dismissReconnectSummary(summary.id);
      expect(controller.state.reconnectSummary, isNull);

      controller.dispose();
      app.dispose();
    },
  );

  test('background sync stays silent after queued local work', () async {
    final store = MemoryStudyStore();
    final app = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final service = _TestDriveService();
    final controller = ConnectionController(service, app, store: store);
    await Future<void>.delayed(Duration.zero);

    await controller.connect();
    final initialSummary = controller.state.reconnectSummary;
    if (initialSummary != null) {
      controller.dismissReconnectSummary(initialSummary.id);
    }
    await app.queueSyncSnapshot();
    controller.observeAppState(app.state);

    await controller.syncAutomatically();

    expect(service.pushCount, greaterThan(0));
    expect(controller.state.pendingChanges, isFalse);
    expect(controller.state.reconnectSummary, isNull);
    expect(controller.state.userInitiatedOperation, isFalse);

    controller.dispose();
    app.dispose();
  });
}

class _NetworkInspector implements SyncNetworkInspector {
  const _NetworkInspector(this.wifi);

  final bool wifi;

  @override
  Future<bool> isWifiConnected() async => wifi;
}

class _TestDriveService implements GoogleConnectionService {
  _TestDriveService({this.snapshot});

  Map<String, Object?>? snapshot;
  int connectCount = 0;
  int disconnectCount = 0;
  int pushCount = 0;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    connectCount += 1;
    onStage?.call(GoogleConnectionStage.checkingConnection);
    return const GoogleConnectionResult(
      folderId: 'folder-secret-id',
      folderName: 'WordStudyData',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    pushCount += 1;
    this.snapshot = Map<String, Object?>.from(snapshot);
  }
}
