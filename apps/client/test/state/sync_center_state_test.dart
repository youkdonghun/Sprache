import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/sync/sync_policy.dart';

void main() {
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
      expect(diagnostic, contains('sprache-sync-diagnostic-v1'));
      expect(diagnostic, isNot(contains('folder-secret-id')));

      recreated.dispose();
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
  int pushCount = 0;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    return const GoogleConnectionResult(
      folderId: 'folder-secret-id',
      folderName: 'WordStudyData',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    pushCount += 1;
    this.snapshot = Map<String, Object?>.from(snapshot);
  }
}
