import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../integrations/google/google_connection_service.dart';
import '../integrations/google/google_drive_client.dart';
import '../integrations/google/oauth_tokens.dart';
import '../sync/pending_sync.dart';
import '../sync/snapshot_validator.dart';
import 'app_state.dart';

enum ConnectionPhase {
  disconnected,
  connecting,
  connected,
  syncing,
  disconnecting,
  failed,
}

class ConnectionState {
  const ConnectionState({
    required this.phase,
    this.folderName,
    this.errorMessage,
    this.mock = false,
    this.lastSyncedAt,
  });

  const ConnectionState.disconnected()
    : phase = ConnectionPhase.disconnected,
      folderName = null,
      errorMessage = null,
      mock = false,
      lastSyncedAt = null;

  final ConnectionPhase phase;
  final String? folderName;
  final String? errorMessage;
  final bool mock;
  final DateTime? lastSyncedAt;

  bool get busy =>
      phase == ConnectionPhase.connecting ||
      phase == ConnectionPhase.syncing ||
      phase == ConnectionPhase.disconnecting;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final tokenVaultProvider = Provider<TokenVault>((ref) => SecureTokenVault());

final googleConnectionServiceProvider = Provider<GoogleConnectionService>(
  (ref) => createGoogleConnectionService(
    config: ref.watch(appConfigProvider),
    tokenVault: ref.watch(tokenVaultProvider),
  ),
);

class ConnectionController extends StateNotifier<ConnectionState> {
  ConnectionController(this._service, this._appController)
    : super(const ConnectionState.disconnected());

  final GoogleConnectionService _service;
  final AppController _appController;
  Timer? _retryTimer;

  Future<void> connect() async {
    if (state.busy) return;
    state = const ConnectionState(phase: ConnectionPhase.connecting);
    GoogleConnectionResult? connectionResult;
    PendingSyncOperation? attemptedOperation;
    try {
      connectionResult = await _service.connect();
      _appController.setDriveConnected(true);
      attemptedOperation =
          _appController.state.pendingSync ??
          await _appController.queueSyncSnapshot();
      final merged = await _appController.mergeRemoteSnapshot(
        await _service.pullSnapshot(),
      );
      await _service.pushSnapshot(merged);
      await _appController.completePendingSync(attemptedOperation.operationId);
      _resetRetry();
      state = ConnectionState(
        phase: ConnectionPhase.connected,
        folderName: connectionResult.folderName,
        mock: connectionResult.mock,
        lastSyncedAt: DateTime.now(),
      );
      _scheduleRemainingOperation();
    } catch (error) {
      final failedOperation = attemptedOperation == null
          ? _appController.state.pendingSync
          : await _appController.markPendingSyncFailed(
              attemptedOperation.operationId,
            );
      state = ConnectionState(
        phase: ConnectionPhase.failed,
        folderName: connectionResult?.folderName,
        errorMessage: _friendlyMessage(error),
        mock: connectionResult?.mock ?? false,
      );
      if (_shouldRetry(error) && failedOperation != null) {
        _scheduleRetry(failedOperation);
      }
    }
  }

  Future<void> syncNow() async {
    final canRetry =
        state.phase == ConnectionPhase.failed &&
        _appController.state.driveConnected;
    if (state.busy || (state.phase != ConnectionPhase.connected && !canRetry)) {
      return;
    }
    final previous = state;
    state = ConnectionState(
      phase: ConnectionPhase.syncing,
      folderName: previous.folderName,
      mock: previous.mock,
      lastSyncedAt: previous.lastSyncedAt,
    );
    PendingSyncOperation? attemptedOperation;
    try {
      attemptedOperation =
          _appController.state.pendingSync ??
          await _appController.queueSyncSnapshot();
      final merged = await _appController.mergeRemoteSnapshot(
        await _service.pullSnapshot(),
      );
      await _service.pushSnapshot(merged);
      await _appController.completePendingSync(attemptedOperation.operationId);
      _resetRetry();
      state = ConnectionState(
        phase: ConnectionPhase.connected,
        folderName: previous.folderName,
        mock: previous.mock,
        lastSyncedAt: DateTime.now(),
      );
      _scheduleRemainingOperation();
    } catch (error) {
      final failedOperation = attemptedOperation == null
          ? _appController.state.pendingSync
          : await _appController.markPendingSyncFailed(
              attemptedOperation.operationId,
            );
      state = ConnectionState(
        phase: ConnectionPhase.failed,
        folderName: previous.folderName,
        errorMessage: _friendlyMessage(error),
        mock: previous.mock,
        lastSyncedAt: previous.lastSyncedAt,
      );
      if (_shouldRetry(error) && failedOperation != null) {
        _scheduleRetry(failedOperation);
      }
    }
  }

  Future<void> disconnect() async {
    if (state.busy) return;
    _resetRetry();
    state = const ConnectionState(phase: ConnectionPhase.disconnecting);
    try {
      await _service.disconnect();
      _appController.setDriveConnected(false);
      state = const ConnectionState.disconnected();
    } catch (error) {
      state = ConnectionState(
        phase: ConnectionPhase.failed,
        errorMessage: _friendlyMessage(error),
      );
    }
  }

  void _scheduleRetry(PendingSyncOperation operation) {
    if (!_appController.state.driveConnected) return;
    _retryTimer?.cancel();
    final now = DateTime.now().toUtc();
    final delay = operation.nextAttemptAt.isAfter(now)
        ? operation.nextAttemptAt.difference(now)
        : Duration.zero;
    _retryTimer = Timer(delay, () {
      if (mounted) unawaited(syncNow());
    });
  }

  void _scheduleRemainingOperation() {
    final remaining = _appController.state.pendingSync;
    if (remaining != null) _scheduleRetry(remaining);
  }

  void _resetRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  String _friendlyMessage(Object error) {
    if (error is RemoteSnapshotValidationException) {
      return 'Drive 데이터 검증에 실패해 동기화를 중단했습니다. '
          '이 기기의 정상 데이터는 유지되었습니다. (${error.first.path})';
    }
    if (error is DriveDataIntegrityException) {
      if (error.code == 'drive_upload_conflict') {
        return '다른 기기의 변경을 감지했습니다. 로컬 데이터는 유지했으며 '
            '최신 데이터를 다시 병합해 재시도합니다.';
      }
      if (error.code == 'drive_manifest_newer_schema') {
        return 'Drive 데이터가 이 앱보다 최신 형식입니다. 앱을 업데이트한 뒤 다시 시도해 주세요.';
      }
      return 'Drive 파일 무결성 검증에 실패했습니다. 로컬 데이터는 유지되었습니다. '
          '(${error.code})';
    }
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('not configured')) {
      return 'Google Cloud OAuth Client ID가 아직 설정되지 않았습니다.';
    }
    if (text.contains('timeout')) {
      return 'Google 연결 시간이 초과되었습니다. 다시 시도해 주세요.';
    }
    if (text.contains('drive_permission_revoked')) {
      return 'Google Drive 권한이 해제되었습니다. 계정을 다시 연결해 주세요.';
    }
    if (text.contains('drive_folder_missing')) {
      return '연결한 Drive 폴더를 찾을 수 없습니다. 폴더를 다시 선택해 주세요.';
    }
    return text;
  }

  bool _shouldRetry(Object error) {
    if (error is RemoteSnapshotValidationException) return false;
    if (error is DriveDataIntegrityException) {
      return error.code == 'drive_upload_conflict';
    }
    final text = error.toString();
    return !text.contains('앱을 업데이트한 뒤 다시 시도하세요');
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

final connectionControllerProvider =
    StateNotifierProvider<ConnectionController, ConnectionState>((ref) {
      return ConnectionController(
        ref.watch(googleConnectionServiceProvider),
        ref.read(appControllerProvider.notifier),
      );
    });
