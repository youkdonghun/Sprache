import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;

// Public constructor parameter names stay readable in providers and tests.
// ignore_for_file: prefer_initializing_formals

import '../config/app_config.dart';
import '../data/study_store.dart';
import '../integrations/google/google_connection_service.dart';
import '../integrations/google/google_drive_client.dart';
import '../integrations/google/desktop_google_oauth.dart';
import '../integrations/google/oauth_tokens.dart';
import '../sync/pending_sync.dart';
import '../sync/sync_merge_report.dart';
import '../sync/sync_history.dart';
import '../sync/sync_policy.dart';
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

abstract interface class SyncNetworkInspector {
  Future<bool> isWifiConnected();
}

class PlatformSyncNetworkInspector implements SyncNetworkInspector {
  const PlatformSyncNetworkInspector();

  @override
  Future<bool> isWifiConnected() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      return interfaces.any((interface) {
        final name = interface.name.toLowerCase();
        return name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('wlan') ||
            RegExp(r'^wl[a-z0-9]').hasMatch(name);
      });
    } catch (_) {
      // Wi-Fi-only mode is deliberately conservative when the platform does
      // not expose an adapter type.
      return false;
    }
  }
}

extension GoogleConnectionStageLabel on GoogleConnectionStage {
  String get label => switch (this) {
    GoogleConnectionStage.checkingConnection => 'Google 연결 준비 확인',
    GoogleConnectionStage.signIn => '1/4 Google 계정 선택·동의',
    GoogleConnectionStage.folderSelection => '2/4 Drive 폴더 선택',
    GoogleConnectionStage.preparingDrive => '3/4 Sprache 저장 폴더 확인',
    GoogleConnectionStage.linkingAccount => '4/4 Drive 연결 정보 저장',
    GoogleConnectionStage.pulling => '1/3 Drive 데이터 확인',
    GoogleConnectionStage.merging => '2/3 로컬·Drive 안전 병합',
    GoogleConnectionStage.pushing => '3/3 변경 사항 업로드',
  };

  String get badgeLabel => switch (this) {
    GoogleConnectionStage.checkingConnection => '연결 확인',
    GoogleConnectionStage.signIn => '연결 1/4',
    GoogleConnectionStage.folderSelection => '연결 2/4',
    GoogleConnectionStage.preparingDrive => '연결 3/4',
    GoogleConnectionStage.linkingAccount => '연결 4/4',
    GoogleConnectionStage.pulling => '동기화 1/3',
    GoogleConnectionStage.merging => '동기화 2/3',
    GoogleConnectionStage.pushing => '동기화 3/3',
  };
}

class ConnectionDiagnostic {
  const ConnectionDiagnostic({
    required this.code,
    required this.operation,
    required this.message,
    required this.occurredAt,
    required this.retryable,
    this.reconnectRequired = false,
    this.detail,
    this.stageLabel,
    this.recoverySteps = const [],
    this.quarantine,
  });

  final String code;
  final String operation;
  final String message;
  final DateTime occurredAt;
  final bool retryable;
  final bool reconnectRequired;
  final String? detail;
  final String? stageLabel;
  final List<String> recoverySteps;
  final DriveQuarantineRecord? quarantine;

  String get clipboardText {
    final lines = [
      'Sprache 연결 오류 진단',
      '진단 코드: $code',
      '단계: $operation',
      if (stageLabel != null) '세부 단계: $stageLabel',
      '발생 시각(UTC): ${occurredAt.toUtc().toIso8601String()}',
      '안내: $message',
      if (detail != null && detail!.isNotEmpty) '세부 정보: $detail',
      for (var index = 0; index < recoverySteps.length; index += 1)
        '복구 ${index + 1}: ${recoverySteps[index]}',
      if (quarantine != null) ...[
        '격리 사본: ${quarantine!.fileName}',
        '격리 사유: ${quarantine!.reasonCode}',
        '안전 미리보기: ${quarantine!.preview}',
      ],
      '로컬 데이터: 유지됨',
    ];
    return lines.join('\n');
  }
}

class ReconnectSyncSummary {
  const ReconnectSyncSummary({
    required this.id,
    required this.completedAt,
    required this.comparedChanges,
    required this.uploaded,
    required this.downloaded,
    required this.conflicts,
  });

  final String id;
  final DateTime completedAt;
  final int comparedChanges;
  final int uploaded;
  final int downloaded;
  final int conflicts;

  String get message {
    if (comparedChanges == 0 && uploaded == 0 && downloaded == 0) {
      return '오프라인 변경을 Drive와 안전하게 확인했습니다.';
    }
    final parts = <String>[
      '오프라인 변경을 안전하게 병합했습니다.',
      if (uploaded > 0) '올림 $uploaded',
      if (downloaded > 0) '받음 $downloaded',
      if (conflicts > 0) '충돌 검토 $conflicts',
    ];
    return parts.join(' · ');
  }
}

class ConnectionState {
  const ConnectionState({
    required this.phase,
    this.folderId,
    this.folderName,
    this.diagnostic,
    this.mock = false,
    this.runtimeReady = false,
    this.lastSyncedAt,
    this.lastMergeReport,
    this.stage,
    this.policy = const SyncPolicy(),
    this.history = const [],
    this.lastComparison = const [],
    this.selections = const {},
    this.recoveryAvailable = false,
    this.pendingChanges = false,
    this.deviceSettingsLoaded = false,
    this.reconnectSummary,
    this.userInitiatedOperation = false,
  });

  const ConnectionState.disconnected()
    : phase = ConnectionPhase.disconnected,
      folderId = null,
      folderName = null,
      diagnostic = null,
      mock = false,
      runtimeReady = false,
      lastSyncedAt = null,
      lastMergeReport = null,
      stage = null,
      policy = const SyncPolicy(),
      history = const [],
      lastComparison = const [],
      selections = const {},
      recoveryAvailable = false,
      pendingChanges = false,
      deviceSettingsLoaded = false,
      reconnectSummary = null,
      userInitiatedOperation = false;

  final ConnectionPhase phase;
  final String? folderId;
  final String? folderName;
  final ConnectionDiagnostic? diagnostic;
  final bool mock;
  final bool runtimeReady;
  final DateTime? lastSyncedAt;
  final SyncMergeReport? lastMergeReport;
  final GoogleConnectionStage? stage;
  final SyncPolicy policy;
  final List<SyncHistoryEntry> history;
  final List<SyncItemComparison> lastComparison;
  final Map<String, SyncVersionSelection> selections;
  final bool recoveryAvailable;
  final bool pendingChanges;
  final bool deviceSettingsLoaded;
  final ReconnectSyncSummary? reconnectSummary;
  final bool userInitiatedOperation;

  String? get errorMessage => diagnostic?.message;

  bool get busy =>
      phase == ConnectionPhase.connecting ||
      phase == ConnectionPhase.syncing ||
      phase == ConnectionPhase.disconnecting;

  SyncDisplayStatus get displayStatus {
    if (phase == ConnectionPhase.syncing ||
        phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.disconnecting) {
      return SyncDisplayStatus.syncing;
    }
    if (phase == ConnectionPhase.failed) return SyncDisplayStatus.error;
    if (pendingChanges) return SyncDisplayStatus.waiting;
    if (phase == ConnectionPhase.connected && lastSyncedAt != null) {
      return SyncDisplayStatus.completed;
    }
    return SyncDisplayStatus.localSaved;
  }

  ConnectionState copyWith({
    ConnectionPhase? phase,
    Object? folderId = _keepConnectionValue,
    Object? folderName = _keepConnectionValue,
    Object? diagnostic = _keepConnectionValue,
    bool? mock,
    bool? runtimeReady,
    Object? lastSyncedAt = _keepConnectionValue,
    Object? lastMergeReport = _keepConnectionValue,
    Object? stage = _keepConnectionValue,
    SyncPolicy? policy,
    List<SyncHistoryEntry>? history,
    List<SyncItemComparison>? lastComparison,
    Map<String, SyncVersionSelection>? selections,
    bool? recoveryAvailable,
    bool? pendingChanges,
    bool? deviceSettingsLoaded,
    Object? reconnectSummary = _keepConnectionValue,
    bool? userInitiatedOperation,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      folderId: identical(folderId, _keepConnectionValue)
          ? this.folderId
          : folderId as String?,
      folderName: identical(folderName, _keepConnectionValue)
          ? this.folderName
          : folderName as String?,
      diagnostic: identical(diagnostic, _keepConnectionValue)
          ? this.diagnostic
          : diagnostic as ConnectionDiagnostic?,
      mock: mock ?? this.mock,
      runtimeReady: runtimeReady ?? this.runtimeReady,
      lastSyncedAt: identical(lastSyncedAt, _keepConnectionValue)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      lastMergeReport: identical(lastMergeReport, _keepConnectionValue)
          ? this.lastMergeReport
          : lastMergeReport as SyncMergeReport?,
      stage: identical(stage, _keepConnectionValue)
          ? this.stage
          : stage as GoogleConnectionStage?,
      policy: policy ?? this.policy,
      history: history ?? this.history,
      lastComparison: lastComparison ?? this.lastComparison,
      selections: selections ?? this.selections,
      recoveryAvailable: recoveryAvailable ?? this.recoveryAvailable,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      deviceSettingsLoaded: deviceSettingsLoaded ?? this.deviceSettingsLoaded,
      reconnectSummary: identical(reconnectSummary, _keepConnectionValue)
          ? this.reconnectSummary
          : reconnectSummary as ReconnectSyncSummary?,
      userInitiatedOperation:
          userInitiatedOperation ?? this.userInitiatedOperation,
    );
  }
}

const _keepConnectionValue = Object();

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
  ConnectionController(
    this._service,
    this._appController, {
    StudyStore? store,
    SyncNetworkInspector networkInspector =
        const PlatformSyncNetworkInspector(),
  }) : _store = store,
       _networkInspector = networkInspector,
       super(const ConnectionState.disconnected()) {
    unawaited(_loadDeviceSettings());
  }

  final GoogleConnectionService _service;
  final AppController _appController;
  final StudyStore? _store;
  final SyncNetworkInspector _networkInspector;
  final SyncSnapshotDiffer _snapshotDiffer = const SyncSnapshotDiffer();
  final SyncSnapshotResolver _snapshotResolver = const SyncSnapshotResolver();
  SyncDeviceSettings _deviceSettings = const SyncDeviceSettings();
  Timer? _retryTimer;
  bool _automaticSyncScheduled = false;

  void dismissReconnectSummary(String id) {
    if (state.reconnectSummary?.id != id) return;
    state = state.copyWith(reconnectSummary: null);
  }

  bool _completionCleanupScheduled = false;

  Future<void> _loadDeviceSettings() async {
    final store = _store;
    if (store != null) {
      _deviceSettings = await store.loadSyncDeviceSettings();
    }
    final pending = _appController.state.pendingSync;
    if (pending != null && _hasCompletionReceipt(pending)) {
      await _appController.completePendingSync(pending.operationId);
    }
    if (!mounted) return;
    state = state.copyWith(
      policy: _deviceSettings.policy,
      history: _deviceSettings.history,
      recoveryAvailable: _deviceSettings.recoveryPoint != null,
      pendingChanges: _appController.state.pendingSync != null,
      deviceSettingsLoaded: true,
    );
  }

  void observeAppState(AppState appState) {
    if (!mounted) return;
    final pendingOperation = appState.pendingSync;
    if (pendingOperation != null &&
        _hasCompletionReceipt(pendingOperation) &&
        !_completionCleanupScheduled) {
      _completionCleanupScheduled = true;
      scheduleMicrotask(() async {
        try {
          await _appController.completePendingSync(
            pendingOperation.operationId,
          );
        } finally {
          _completionCleanupScheduled = false;
        }
      });
      return;
    }
    final hadPending = state.pendingChanges;
    final hasPending = appState.pendingSync != null;
    if (hadPending != hasPending) {
      state = state.copyWith(pendingChanges: hasPending);
    }
    if (!hadPending &&
        hasPending &&
        state.phase == ConnectionPhase.connected &&
        !state.policy.offlineLock &&
        state.policy.mode != SyncMode.manual &&
        !_automaticSyncScheduled) {
      _automaticSyncScheduled = true;
      scheduleMicrotask(() async {
        try {
          await syncAutomatically();
        } finally {
          _automaticSyncScheduled = false;
        }
      });
    }
  }

  Future<void> setPolicy(SyncPolicy policy) async {
    _deviceSettings = _deviceSettings.copyWith(policy: policy);
    await _persistDeviceSettings();
    if (!mounted) return;
    state = state.copyWith(policy: policy);
    if (policy.offlineLock) {
      _resetRetry();
      return;
    }
    if (policy.mode != SyncMode.manual && state.pendingChanges) {
      unawaited(syncAutomatically());
    }
  }

  void selectSyncVersion(String comparisonKey, SyncVersionSelection selection) {
    if (!state.lastComparison.any((entry) => entry.key == comparisonKey)) {
      return;
    }
    state = state.copyWith(
      selections: {...state.selections, comparisonKey: selection},
      lastComparison: [
        for (final comparison in state.lastComparison)
          comparison.key == comparisonKey
              ? comparison.copyWith(selection: selection)
              : comparison,
      ],
    );
  }

  void clearSyncVersionSelections() {
    state = state.copyWith(
      selections: const {},
      lastComparison: [
        for (final comparison in state.lastComparison)
          SyncItemComparison(
            section: comparison.section,
            recordId: comparison.recordId,
            localExists: comparison.localExists,
            driveExists: comparison.driveExists,
            localPreview: comparison.localPreview,
            drivePreview: comparison.drivePreview,
          ),
      ],
    );
  }

  Future<void> applySelectedVersions() async {
    final recovery = _deviceSettings.recoveryPoint;
    if (recovery == null ||
        state.selections.isEmpty ||
        state.busy ||
        state.policy.offlineLock) {
      return;
    }
    final startedAt = DateTime.now().toUtc();
    final before = _appController.exportSyncSnapshot();
    final resolved = _snapshotResolver.resolve(
      local: recovery.localSnapshot,
      drive: recovery.driveSnapshot,
      merged: recovery.mergedSnapshot,
      selections: state.selections,
    );
    final selectedComparisons = [
      for (final comparison in state.lastComparison)
        comparison.copyWith(selection: state.selections[comparison.key]),
    ];
    state = state.copyWith(
      phase: state.runtimeReady
          ? ConnectionPhase.syncing
          : ConnectionPhase.connected,
      stage: state.runtimeReady ? GoogleConnectionStage.pushing : null,
      diagnostic: null,
    );
    PendingSyncOperation? operation;
    try {
      final applied = await _appController.replaceWithSyncSnapshot(resolved);
      operation = await _appController.queueSyncSnapshot(payload: applied);
      if (state.runtimeReady) {
        await _service.pushSnapshot(applied);
        await _rememberOperationCompleted(operation);
        await _appController.completePendingSync(operation.operationId);
      }
      await _rememberSuccessfulSync(
        startedAt: startedAt,
        local: before,
        drive: recovery.driveSnapshot,
        merged: applied,
        comparisons: selectedComparisons,
      );
      state = state.copyWith(
        phase: state.runtimeReady
            ? ConnectionPhase.connected
            : ConnectionPhase.disconnected,
        stage: null,
        diagnostic: null,
        lastSyncedAt: state.runtimeReady ? DateTime.now() : state.lastSyncedAt,
        pendingChanges: !state.runtimeReady,
        selections: const {},
      );
    } catch (error) {
      if (operation != null) {
        await _appController.markPendingSyncFailed(operation.operationId);
      }
      final diagnostic = _diagnostic(
        error,
        operation: '선택 버전 적용',
        stage: state.stage,
      );
      state = state.copyWith(
        phase: ConnectionPhase.failed,
        diagnostic: diagnostic,
        stage: null,
        pendingChanges: true,
      );
      await _rememberFailedSync(startedAt: startedAt, diagnostic: diagnostic);
    }
  }

  Future<void> restoreLastMerge() async {
    final recovery = _deviceSettings.recoveryPoint;
    if (recovery == null || state.busy || state.policy.offlineLock) return;
    final startedAt = DateTime.now().toUtc();
    state = state.copyWith(
      phase: state.runtimeReady
          ? ConnectionPhase.syncing
          : ConnectionPhase.disconnected,
      stage: state.runtimeReady ? GoogleConnectionStage.pushing : null,
      diagnostic: null,
    );
    PendingSyncOperation? operation;
    try {
      final restored = await _appController.replaceWithSyncSnapshot(
        recovery.localSnapshot,
      );
      operation = await _appController.queueSyncSnapshot(payload: restored);
      if (state.runtimeReady) {
        await _service.pushSnapshot(restored);
        await _rememberOperationCompleted(operation);
        await _appController.completePendingSync(operation.operationId);
      }
      final endedAt = DateTime.now().toUtc();
      final history = SyncHistoryEntry(
        id: 'restore-${endedAt.microsecondsSinceEpoch}',
        status: state.runtimeReady
            ? SyncHistoryStatus.success
            : SyncHistoryStatus.skipped,
        startedAt: startedAt,
        endedAt: endedAt,
        summary: state.runtimeReady
            ? '직전 병합 이전 상태로 복구하고 Drive에 반영'
            : '직전 병합 이전 상태로 로컬 복구 · Drive 반영 대기',
      );
      _deviceSettings = _deviceSettings.copyWith(
        history: [history, ..._deviceSettings.history].take(50).toList(),
        recoveryPoint: null,
      );
      await _persistDeviceSettings();
      state = state.copyWith(
        phase: state.runtimeReady
            ? ConnectionPhase.connected
            : ConnectionPhase.disconnected,
        history: _deviceSettings.history,
        recoveryAvailable: false,
        lastComparison: const [],
        selections: const {},
        stage: null,
        lastSyncedAt: state.runtimeReady ? endedAt : state.lastSyncedAt,
        pendingChanges: !state.runtimeReady,
      );
    } catch (error) {
      if (operation != null) {
        await _appController.markPendingSyncFailed(operation.operationId);
      }
      final diagnostic = _diagnostic(
        error,
        operation: '직전 병합 복구',
        stage: state.stage,
      );
      state = state.copyWith(
        phase: ConnectionPhase.failed,
        diagnostic: diagnostic,
        stage: null,
        pendingChanges: true,
      );
      await _rememberFailedSync(startedAt: startedAt, diagnostic: diagnostic);
    }
  }

  Future<void> clearSyncHistory() async {
    _deviceSettings = _deviceSettings.copyWith(history: const []);
    await _persistDeviceSettings();
    if (mounted) state = state.copyWith(history: const []);
  }

  String exportSyncDiagnostics() {
    Map<String, int> sectionCounts(Iterable<SyncItemComparison> comparisons) {
      final counts = <String, int>{};
      for (final comparison in comparisons) {
        counts[comparison.section] = (counts[comparison.section] ?? 0) + 1;
      }
      return counts;
    }

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'sprache-sync-diagnostic-v2',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'phase': state.phase.name,
      'displayStatus': state.displayStatus.name,
      'policy': state.policy.toJson(),
      'pendingChanges': state.pendingChanges,
      'runtimeReady': state.runtimeReady,
      'lastSyncedAt': state.lastSyncedAt?.toUtc().toIso8601String(),
      'diagnostic': state.diagnostic == null
          ? null
          : {
              'code': state.diagnostic!.code,
              'operation': state.diagnostic!.operation,
              'occurredAt': state.diagnostic!.occurredAt
                  .toUtc()
                  .toIso8601String(),
              'retryable': state.diagnostic!.retryable,
              'reconnectRequired': state.diagnostic!.reconnectRequired,
              'stageLabel': state.diagnostic!.stageLabel,
            },
      'history': [
        for (final entry in state.history)
          {
            'status': entry.status.name,
            'startedAt': entry.startedAt.toUtc().toIso8601String(),
            'endedAt': entry.endedAt.toUtc().toIso8601String(),
            'changeCount': entry.changeCount,
            if (entry.diagnosticCode != null)
              'diagnosticCode': entry.diagnosticCode,
            'comparisonSections': sectionCounts(entry.comparisons),
          },
      ],
      'lastComparisonSections': sectionCounts(state.lastComparison),
      'recoveryAvailable': state.recoveryAvailable,
    });
  }

  Future<void> _persistDeviceSettings() async {
    await _store?.saveSyncDeviceSettings(_deviceSettings);
  }

  bool _hasCompletionReceipt(PendingSyncOperation operation) {
    final fingerprint = _pendingPayloadFingerprint(operation);
    return _deviceSettings.completionReceipts.any(
      (receipt) =>
          receipt.operationId == operation.operationId &&
          receipt.payloadSha256 == fingerprint,
    );
  }

  Future<void> _rememberOperationCompleted(
    PendingSyncOperation operation,
  ) async {
    final receipt = SyncCompletionReceipt(
      operationId: operation.operationId,
      completedAt: DateTime.now().toUtc(),
      payloadSha256: _pendingPayloadFingerprint(operation),
    );
    _deviceSettings = _deviceSettings.copyWith(
      completionReceipts: [
        receipt,
        ..._deviceSettings.completionReceipts.where(
          (value) => value.operationId != operation.operationId,
        ),
      ].take(50).toList(growable: false),
    );
    await _persistDeviceSettings();
  }

  Future<void> _rememberSuccessfulSync({
    required DateTime startedAt,
    required Map<String, Object?> local,
    required Map<String, Object?>? drive,
    required Map<String, Object?> merged,
    required List<SyncItemComparison> comparisons,
  }) async {
    final endedAt = DateTime.now().toUtc();
    final report = _appController.lastMergeReport;
    final entry = SyncHistoryEntry(
      id: 'sync-${endedAt.microsecondsSinceEpoch}',
      status: SyncHistoryStatus.success,
      startedAt: startedAt,
      endedAt: endedAt,
      summary: comparisons.isEmpty
          ? '변경 없이 동기화 완료'
          : '로컬·Drive 차이 ${comparisons.length}건 병합',
      changeCount: comparisons.length,
      mergeReport: report == null
          ? null
          : {
              'syncedAt': report.syncedAt.toUtc().toIso8601String(),
              'uploadCount': report.uploadCount,
              'downloadCount': report.downloadCount,
              'conflictCount': report.conflictCount,
              'changes': [
                for (final change in report.changes)
                  {
                    'section': change.section.name,
                    'recordId': change.recordId,
                    'decision': change.decision.name,
                  },
              ],
            },
      comparisons: comparisons,
    );
    _deviceSettings = _deviceSettings.copyWith(
      history: [entry, ..._deviceSettings.history].take(50).toList(),
      recoveryPoint: SyncRecoveryPoint(
        id: entry.id,
        createdAt: endedAt,
        localSnapshot: _jsonCloneMap(local),
        driveSnapshot: drive == null ? null : _jsonCloneMap(drive),
        mergedSnapshot: _jsonCloneMap(merged),
      ),
    );
    await _persistDeviceSettings();
    if (!mounted) return;
    state = state.copyWith(
      history: _deviceSettings.history,
      lastComparison: comparisons,
      selections: const {},
      recoveryAvailable: true,
    );
  }

  Future<void> _rememberFailedSync({
    required DateTime startedAt,
    required ConnectionDiagnostic diagnostic,
  }) async {
    final endedAt = DateTime.now().toUtc();
    final entry = SyncHistoryEntry(
      id: 'sync-${endedAt.microsecondsSinceEpoch}',
      status: SyncHistoryStatus.failed,
      startedAt: startedAt,
      endedAt: endedAt,
      summary: diagnostic.message,
      diagnosticCode: diagnostic.code,
    );
    _deviceSettings = _deviceSettings.copyWith(
      history: [entry, ..._deviceSettings.history].take(50).toList(),
    );
    await _persistDeviceSettings();
    if (mounted) state = state.copyWith(history: _deviceSettings.history);
  }

  Future<void> _rememberSkippedSync(String summary) async {
    final now = DateTime.now().toUtc();
    final entry = SyncHistoryEntry(
      id: 'sync-${now.microsecondsSinceEpoch}',
      status: SyncHistoryStatus.skipped,
      startedAt: now,
      endedAt: now,
      summary: summary,
    );
    _deviceSettings = _deviceSettings.copyWith(
      history: [entry, ..._deviceSettings.history].take(50).toList(),
    );
    await _persistDeviceSettings();
    if (mounted) state = state.copyWith(history: _deviceSettings.history);
  }

  Map<String, Object?> _jsonCloneMap(Map<String, Object?> value) {
    return Map<String, Object?>.from(
      jsonDecode(jsonEncode(value)) as Map<Object?, Object?>,
    );
  }

  Future<void> connect() {
    if (state.policy.offlineLock) return Future.value();
    return _establishConnection(userInitiated: true);
  }

  Future<void> changeDriveFolder() async {
    if (state.policy.offlineLock) return;
    final reselectionService = _service is DriveFolderReselectionService
        ? _service as DriveFolderReselectionService
        : null;
    if (reselectionService == null) {
      throw StateError('이 환경에서는 Drive 폴더를 다시 선택할 수 없습니다.');
    }
    await _establishConnection(
      connectionOperation: reselectionService.reselectDriveFolder,
      preserveExistingUntilSelected: true,
      folderReselectionService: reselectionService,
      userInitiated: true,
    );
  }

  Future<void> restoreSavedConnection({bool userInitiated = false}) async {
    if (state.policy.offlineLock ||
        state.busy ||
        !_appController.state.isHydrated ||
        !_appController.state.driveConnected) {
      return;
    }
    final service = _service;
    if (service is! RestorableGoogleConnectionService) return;
    await _establishConnection(
      restorableService: service as RestorableGoogleConnectionService,
      userInitiated: userInitiated,
    );
  }

  Future<void> syncOrRestore({bool manual = false}) async {
    if (state.policy.offlineLock || !_appController.state.driveConnected) {
      return;
    }
    if (state.phase == ConnectionPhase.connected ||
        (state.phase == ConnectionPhase.failed && state.runtimeReady)) {
      return manual ? syncNow() : syncAutomatically();
    }
    if (state.busy) return;
    if (!manual && !await _automaticSyncAllowed()) return;
    return restoreSavedConnection(userInitiated: manual);
  }

  Future<void> _establishConnection({
    RestorableGoogleConnectionService? restorableService,
    Future<GoogleConnectionResult?> Function({
      GoogleConnectionStageCallback? onStage,
    })?
    connectionOperation,
    bool preserveExistingUntilSelected = false,
    DriveFolderReselectionService? folderReselectionService,
    bool userInitiated = false,
  }) async {
    if (state.busy || state.policy.offlineLock) return;
    final previousState = state;
    final startedAt = DateTime.now().toUtc();
    final localBefore = _appController.exportSyncSnapshot();
    final pendingBefore = _appController.state.pendingSync;
    final mergeReportBefore = _appController.lastMergeReport;
    final deviceSettingsBefore = _deviceSettings;
    final hadQueuedLocalChanges =
        state.pendingChanges || _appController.state.pendingSync != null;
    state = state.copyWith(
      phase: ConnectionPhase.connecting,
      stage: GoogleConnectionStage.checkingConnection,
      diagnostic: null,
      userInitiatedOperation: userInitiated,
    );
    GoogleConnectionResult? connectionResult;
    PendingSyncOperation? attemptedOperation;
    final wasDriveConnected = _appController.state.driveConnected;
    try {
      connectionResult = connectionOperation != null
          ? await connectionOperation(onStage: _setStage)
          : restorableService == null
          ? await _service.connect(onStage: _setStage)
          : await restorableService.restoreConnection(onStage: _setStage);
      if (connectionResult == null) {
        if (preserveExistingUntilSelected) {
          state = previousState;
          throw StateError('Google Picker did not return a folder ID');
        }
        state = state.copyWith(
          phase: ConnectionPhase.disconnected,
          folderId: null,
          folderName: null,
          runtimeReady: false,
          stage: null,
        );
        return;
      }
      if (folderReselectionService != null) {
        _setStage(GoogleConnectionStage.linkingAccount);
      }
      attemptedOperation =
          _appController.state.pendingSync ??
          await _appController.queueSyncSnapshot();
      _setStage(GoogleConnectionStage.pulling);
      final remote = await _service.pullSnapshot();
      final comparisons = _snapshotDiffer.compare(
        local: localBefore,
        drive: remote,
      );
      _setStage(GoogleConnectionStage.merging);
      final merged = await _appController.mergeRemoteSnapshot(
        remote,
        markDriveConnected: wasDriveConnected,
      );
      _setStage(GoogleConnectionStage.pushing);
      await _service.pushSnapshot(merged);
      await _rememberOperationCompleted(attemptedOperation);
      if (!wasDriveConnected) {
        _appController.setDriveConnected(true);
      }
      await _appController.completePendingSync(attemptedOperation.operationId);
      await _rememberSuccessfulSync(
        startedAt: startedAt,
        local: localBefore,
        drive: remote,
        merged: merged,
        comparisons: comparisons,
      );
      if (folderReselectionService != null) {
        await folderReselectionService.commitDriveFolderReselection();
      }
      _resetRetry();
      final completedAt = DateTime.now();
      final report = _appController.lastMergeReport;
      state = state.copyWith(
        phase: ConnectionPhase.connected,
        folderId: connectionResult.folderId,
        folderName: connectionResult.folderName,
        mock: connectionResult.mock,
        runtimeReady: true,
        lastSyncedAt: completedAt,
        lastMergeReport: report,
        stage: null,
        diagnostic: null,
        pendingChanges: false,
        userInitiatedOperation: false,
        reconnectSummary: hadQueuedLocalChanges
            ? ReconnectSyncSummary(
                id: attemptedOperation.operationId,
                completedAt: completedAt.toUtc(),
                comparedChanges: comparisons.length,
                uploaded: report?.uploadCount ?? 0,
                downloaded: report?.downloadCount ?? 0,
                conflicts: report?.conflictCount ?? 0,
              )
            : state.reconnectSummary,
      );
      _scheduleRemainingOperation();
    } catch (error, stackTrace) {
      if (preserveExistingUntilSelected && connectionResult == null) {
        state = previousState;
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (preserveExistingUntilSelected && connectionResult != null) {
        await _quarantineRemoteValidation(error);
        Object? rollbackFailure;
        StackTrace? rollbackStackTrace;
        try {
          await folderReselectionService?.rollbackDriveFolderReselection();
        } catch (rollbackError, rollbackStack) {
          rollbackFailure = rollbackError;
          rollbackStackTrace = rollbackStack;
        }
        try {
          await _appController.replaceWithSyncSnapshot(
            localBefore,
            driveConnected: wasDriveConnected,
            preserveEmptyActiveStudy: true,
          );
          _appController.lastMergeReport = mergeReportBefore;
          _deviceSettings = deviceSettingsBefore;
          await _persistDeviceSettings();
          await _appController.restorePendingSyncAfterFolderRollback(
            pendingBefore,
          );
        } catch (rollbackError, rollbackStack) {
          rollbackFailure ??= rollbackError;
          rollbackStackTrace ??= rollbackStack;
        }
        state = previousState;
        if (rollbackFailure != null) {
          Error.throwWithStackTrace(rollbackFailure, rollbackStackTrace!);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      final failedStage = state.stage;
      final quarantine = await _quarantineRemoteValidation(error);
      final failedOperation = attemptedOperation == null
          ? _appController.state.pendingSync
          : await _appController.markPendingSyncFailed(
              attemptedOperation.operationId,
              minimumDelay: _minimumRetryDelay(error),
            );
      final diagnostic = _diagnostic(
        error,
        operation: 'Google·Drive 연결',
        stage: failedStage,
        quarantine: quarantine,
      );
      state = state.copyWith(
        phase: ConnectionPhase.failed,
        folderId: connectionResult?.folderId,
        folderName: connectionResult?.folderName,
        diagnostic: diagnostic,
        mock: connectionResult?.mock ?? false,
        runtimeReady: connectionResult != null,
        stage: failedStage,
        pendingChanges: failedOperation != null,
        userInitiatedOperation: userInitiated,
      );
      await _rememberFailedSync(startedAt: startedAt, diagnostic: diagnostic);
      if (_shouldRetry(error) &&
          failedOperation != null &&
          connectionResult != null) {
        _scheduleRetry(failedOperation);
      } else if (_shouldRetry(error) && restorableService != null) {
        _scheduleConnectionRestore(_minimumRetryDelay(error));
      }
      if (preserveExistingUntilSelected) rethrow;
    }
  }

  Future<void> syncNow() async {
    if (state.policy.offlineLock) return;
    final canRetry =
        state.phase == ConnectionPhase.failed && state.runtimeReady;
    if (state.busy || (state.phase != ConnectionPhase.connected && !canRetry)) {
      return;
    }
    await _runSync(allowExplicitRetry: true, userInitiated: true);
  }

  Future<void> syncAutomatically() async {
    if (state.policy.offlineLock) return;
    if (!await _automaticSyncAllowed()) return;
    await _runSync();
  }

  Future<bool> _automaticSyncAllowed() async {
    if (state.policy.offlineLock) {
      return false;
    }
    switch (state.policy.mode) {
      case SyncMode.automatic:
        return true;
      case SyncMode.manual:
        await _rememberSkippedSync('수동 정책으로 자동 동기화를 건너뜀');
        return false;
      case SyncMode.wifiOnly:
        if (await _networkInspector.isWifiConnected()) return true;
        await _rememberSkippedSync('Wi-Fi 연결 대기 중');
        if (mounted) state = state.copyWith(pendingChanges: true);
        return false;
    }
  }

  Future<void> _runSync({
    bool allowExplicitRetry = false,
    bool userInitiated = false,
  }) async {
    final canRetry =
        state.phase == ConnectionPhase.failed &&
        state.runtimeReady &&
        (allowExplicitRetry || state.diagnostic?.reconnectRequired != true);
    if (state.busy || (state.phase != ConnectionPhase.connected && !canRetry)) {
      return;
    }
    final startedAt = DateTime.now().toUtc();
    final localBefore = _appController.exportSyncSnapshot();
    final hadQueuedLocalChanges =
        state.pendingChanges || _appController.state.pendingSync != null;
    final wasDriveConnected = _appController.state.driveConnected;
    final previous = state;
    state = state.copyWith(
      phase: ConnectionPhase.syncing,
      folderName: previous.folderName,
      mock: previous.mock,
      runtimeReady: previous.runtimeReady,
      lastSyncedAt: previous.lastSyncedAt,
      lastMergeReport: previous.lastMergeReport,
      stage: GoogleConnectionStage.pulling,
      diagnostic: null,
      userInitiatedOperation: userInitiated,
    );
    PendingSyncOperation? attemptedOperation;
    try {
      attemptedOperation =
          _appController.state.pendingSync ??
          await _appController.queueSyncSnapshot();
      _setStage(GoogleConnectionStage.pulling);
      final remote = await _service.pullSnapshot();
      final comparisons = _snapshotDiffer.compare(
        local: localBefore,
        drive: remote,
      );
      _setStage(GoogleConnectionStage.merging);
      final merged = await _appController.mergeRemoteSnapshot(
        remote,
        markDriveConnected: wasDriveConnected,
      );
      _setStage(GoogleConnectionStage.pushing);
      await _service.pushSnapshot(merged);
      await _rememberOperationCompleted(attemptedOperation);
      if (!wasDriveConnected) {
        _appController.setDriveConnected(true);
      }
      await _appController.completePendingSync(attemptedOperation.operationId);
      await _rememberSuccessfulSync(
        startedAt: startedAt,
        local: localBefore,
        drive: remote,
        merged: merged,
        comparisons: comparisons,
      );
      _resetRetry();
      final completedAt = DateTime.now();
      final report = _appController.lastMergeReport;
      state = state.copyWith(
        phase: ConnectionPhase.connected,
        folderName: previous.folderName,
        mock: previous.mock,
        runtimeReady: true,
        lastSyncedAt: completedAt,
        lastMergeReport: report,
        stage: null,
        diagnostic: null,
        pendingChanges: false,
        userInitiatedOperation: false,
        reconnectSummary: hadQueuedLocalChanges
            ? ReconnectSyncSummary(
                id: attemptedOperation.operationId,
                completedAt: completedAt.toUtc(),
                comparedChanges: comparisons.length,
                uploaded: report?.uploadCount ?? 0,
                downloaded: report?.downloadCount ?? 0,
                conflicts: report?.conflictCount ?? 0,
              )
            : state.reconnectSummary,
      );
      _scheduleRemainingOperation();
    } catch (error) {
      final failedStage = state.stage;
      final quarantine = await _quarantineRemoteValidation(error);
      final failedOperation = attemptedOperation == null
          ? _appController.state.pendingSync
          : await _appController.markPendingSyncFailed(
              attemptedOperation.operationId,
              minimumDelay: _minimumRetryDelay(error),
            );
      final diagnostic = _diagnostic(
        error,
        operation: 'Drive 동기화',
        stage: failedStage,
        quarantine: quarantine,
      );
      state = state.copyWith(
        phase: ConnectionPhase.failed,
        folderName: previous.folderName,
        diagnostic: diagnostic,
        mock: previous.mock,
        runtimeReady: previous.runtimeReady,
        lastSyncedAt: previous.lastSyncedAt,
        lastMergeReport: previous.lastMergeReport,
        stage: failedStage,
        pendingChanges: failedOperation != null,
        userInitiatedOperation: userInitiated,
      );
      await _rememberFailedSync(startedAt: startedAt, diagnostic: diagnostic);
      if (_shouldRetry(error) && failedOperation != null) {
        _scheduleRetry(failedOperation);
      }
    }
  }

  Future<void> disconnect() async {
    if (state.busy || state.policy.offlineLock) return;
    _resetRetry();
    state = state.copyWith(
      phase: ConnectionPhase.disconnecting,
      diagnostic: null,
      userInitiatedOperation: true,
    );
    try {
      await _service.disconnect();
      state = state.copyWith(
        phase: ConnectionPhase.disconnected,
        folderId: null,
        folderName: null,
        diagnostic: null,
        runtimeReady: false,
        stage: null,
        pendingChanges: false,
        userInitiatedOperation: false,
      );
    } catch (error) {
      state = state.copyWith(
        phase: ConnectionPhase.failed,
        diagnostic: _diagnostic(error, operation: 'Google 연결 해제'),
        userInitiatedOperation: true,
      );
    } finally {
      // A device-local disconnect must always resume the configured local
      // mirror even if token cleanup reports an error.
      _appController.setDriveConnected(false);
    }
  }

  Future<void> deleteAccountBinding() async {
    if (state.busy || state.policy.offlineLock) return;
    final deletionService = _service is AccountBindingDeletionService
        ? _service as AccountBindingDeletionService
        : null;
    if (deletionService == null) {
      throw StateError('이 환경에서는 계정 연결 기록을 삭제할 수 없습니다.');
    }
    _resetRetry();
    state = state.copyWith(
      phase: ConnectionPhase.disconnecting,
      diagnostic: null,
      userInitiatedOperation: true,
    );
    try {
      await deletionService.deleteAccountBinding();
      _appController.setDriveConnected(false);
      state = state.copyWith(
        phase: ConnectionPhase.disconnected,
        folderId: null,
        folderName: null,
        diagnostic: null,
        runtimeReady: false,
        stage: null,
        pendingChanges: false,
        userInitiatedOperation: false,
      );
    } catch (error) {
      state = state.copyWith(
        phase: ConnectionPhase.failed,
        diagnostic: _diagnostic(error, operation: '계정 연결 기록 삭제'),
        userInitiatedOperation: true,
      );
      rethrow;
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
      if (mounted) unawaited(syncAutomatically());
    });
  }

  void _scheduleConnectionRestore(Duration? minimumDelay) {
    if (!_appController.state.driveConnected) return;
    _retryTimer?.cancel();
    final delay = minimumDelay ?? const Duration(seconds: 30);
    _retryTimer = Timer(delay, () {
      if (mounted) {
        unawaited(() async {
          if (await _automaticSyncAllowed()) {
            await restoreSavedConnection();
          }
        }());
      }
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

  void _setStage(GoogleConnectionStage stage) {
    if (!mounted || !state.busy) return;
    state = state.copyWith(stage: stage);
  }

  String _friendlyMessage(Object error, {DriveQuarantineRecord? quarantine}) {
    if (error is RemoteSnapshotValidationException) {
      final quarantineMessage = quarantine == null
          ? ''
          : ' 손상 의심 snapshot은 Drive의 quarantine 폴더에 사본으로 보관했습니다.';
      return 'Drive 데이터 검증에 실패해 동기화를 중단했습니다. '
          '이 기기의 정상 데이터는 유지되었습니다.$quarantineMessage '
          '(${error.first.path})';
    }
    if (error is DriveDataIntegrityException) {
      if (error.code == 'drive_upload_conflict') {
        return '다른 기기의 변경을 감지했습니다. 로컬 데이터는 유지했으며 '
            '최신 데이터를 다시 병합해 재시도합니다.';
      }
      if (error.code == 'drive_manifest_newer_schema' ||
          error.code == 'drive_manifest_newer_layout') {
        return 'Drive 데이터가 이 앱보다 최신 형식입니다. 앱을 업데이트한 뒤 다시 시도해 주세요.';
      }
      final quarantineMessage = error.quarantine == null
          ? '원격 격리 사본은 만들지 못했지만'
          : '손상 의심 파일은 Drive의 quarantine 폴더에 사본으로 보관했고';
      return 'Drive 파일 무결성 검증에 실패했습니다. $quarantineMessage '
          '이 기기의 정상 데이터는 그대로 유지했습니다. (${error.code})';
    }
    if (error is DriveRequestException) {
      return switch (error.failure) {
        DriveRequestFailure.authenticationExpired =>
          'Google 로그인 세션이 만료되었습니다. 계정을 다시 연결하면 로컬 학습을 이어서 동기화할 수 있습니다.',
        DriveRequestFailure.permissionRevoked =>
          'Sprache의 Google Drive 권한이 해제되었습니다. Google 계정을 다시 연결하고 Drive 권한을 허용해 주세요.',
        DriveRequestFailure.resourceMissing =>
          '연결한 Drive 폴더 또는 Sprache 파일을 찾을 수 없습니다. Google을 다시 연결해 저장 폴더를 선택해 주세요.',
        DriveRequestFailure.rateLimited =>
          'Google Drive 요청이 일시적으로 제한되었습니다. 로컬 변경은 대기열에 안전하게 보관했으며 잠시 후 자동 재시도합니다.',
        DriveRequestFailure.quotaExceeded =>
          'Google Drive 저장공간이 부족하거나 사용 한도를 초과했습니다. Drive 공간을 확보한 뒤 다시 동기화해 주세요.',
        DriveRequestFailure.serviceUnavailable =>
          'Google Drive 서버가 일시적으로 응답하지 않습니다. 로컬 변경은 유지되며 잠시 후 자동 재시도합니다.',
        DriveRequestFailure.requestFailed =>
          'Google Drive 요청을 완료하지 못했습니다. 로컬 변경은 유지되었습니다. (HTTP ${error.statusCode})',
      };
    }
    if (error is GoogleOAuthException) {
      if (_isClientSecretConfigurationError(error)) {
        return '이 Windows 빌드의 Google 토큰 교환 설정이 완전하지 않습니다. '
            '로컬 학습 데이터는 그대로 유지되니 최신 Sprache 설치본으로 업데이트한 뒤 다시 연결해 주세요.';
      }
      return switch (error.code) {
        'google_client_id_missing' =>
          'Google Cloud의 Windows용 OAuth Client ID가 설정되지 않았습니다. '
              '“데스크톱 앱” 유형의 Client ID를 빌드 설정에 추가해 주세요.',
        'google_client_secret_missing' =>
          '이 Windows 빌드에 Google 토큰 교환 설정이 빠져 있습니다. 최신 설치본으로 업데이트해 주세요.',
        'google_oauth_timeout' ||
        'google_oauth_unreachable' ||
        'google_oauth_invalid_response' ||
        'google_oauth_http_error' =>
          'Google 인증 서버에 연결하지 못했습니다. 로컬 데이터는 유지됩니다. '
              '인터넷 연결을 확인하고 잠시 후 다시 시도해 주세요.',
        'redirect_uri_mismatch' =>
          'Google OAuth 리디렉션 주소가 데스크톱 클라이언트 설정과 맞지 않습니다. '
              'Google Cloud에서 앱 유형이 “데스크톱 앱”인지 확인해 주세요.',
        'invalid_grant' =>
          'Google 인증 코드가 만료되었거나 PKCE 검증에 실패했습니다. 브라우저 창을 닫고 다시 연결해 주세요.',
        'invalid_client' =>
          'Google OAuth Client ID가 잘못되었거나 삭제되었습니다. 앱 설정의 데스크톱 Client ID를 확인해 주세요.',
        'access_denied' => 'Google 권한 동의가 취소되었습니다. 다시 연결해 권한을 허용해 주세요.',
        final String code when code.isNotEmpty =>
          'Google 인증에 실패했습니다. ($code'
              '${error.description == null ? '' : ' · ${_redactCredentialText(error.description!)}'})',
        _ => 'Google 인증에 실패했습니다. (HTTP ${error.statusCode})',
      };
    }
    if (_isTransportFailure(error)) {
      return '인터넷 연결이 중간에 끊겨 Google Drive 동기화를 완료하지 못했습니다. '
          '정상 로컬 데이터와 업로드 대기 작업은 유지됩니다. 네트워크를 확인한 뒤 다시 시도해 주세요.';
    }
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('not configured')) {
      return 'Google Cloud OAuth Client ID가 아직 설정되지 않았습니다.';
    }
    if (text.contains('timeout')) {
      return 'Google 연결 시간이 초과되었습니다. 브라우저에서 계정 동의와 '
          'Drive 폴더 선택을 10분 안에 완료한 뒤 다시 시도해 주세요. '
          'Windows 주소의 127.0.0.1은 정상적인 임시 로그인 회신 주소입니다.';
    }
    if (text.contains('drive_permission_revoked')) {
      return 'Google Drive 권한이 해제되었습니다. 계정을 다시 연결해 주세요.';
    }
    if (text.contains('drive_folder_missing')) {
      return '연결한 Drive 폴더를 찾을 수 없습니다. 폴더를 다시 선택해 주세요.';
    }
    return text;
  }

  ConnectionDiagnostic _diagnostic(
    Object error, {
    required String operation,
    GoogleConnectionStage? stage,
    DriveQuarantineRecord? quarantine,
  }) {
    final effectiveQuarantine =
        quarantine ??
        (error is DriveDataIntegrityException ? error.quarantine : null);
    return ConnectionDiagnostic(
      code: _diagnosticCode(error, operation),
      operation: operation,
      message: _friendlyMessage(error, quarantine: effectiveQuarantine),
      occurredAt: DateTime.now().toUtc(),
      retryable: _shouldRetry(error),
      reconnectRequired: _requiresReconnect(error, operation),
      detail: _safeDiagnosticDetail(error),
      stageLabel: stage?.label,
      recoverySteps: _recoverySteps(error, quarantine: effectiveQuarantine),
      quarantine: effectiveQuarantine,
    );
  }

  String _diagnosticCode(Object error, String operation) {
    if (error is RemoteSnapshotValidationException) {
      return 'SYNC-REMOTE-DATA-INVALID';
    }
    if (error is DriveDataIntegrityException) {
      return _code('DRIVE', error.code.replaceFirst('drive_', ''));
    }
    if (error is DriveRequestException) {
      return _code('DRIVE', error.code.replaceFirst('drive_', ''));
    }
    if (error is GoogleOAuthException) {
      return [
        'GOOGLE',
        _segment(
          error.operation.replaceFirst(
            RegExp(r'^Google\s+', caseSensitive: false),
            '',
          ),
        ),
        error.statusCode,
        if (error.code != null && error.code!.isNotEmpty) _segment(error.code!),
      ].join('-');
    }
    if (_isTransportFailure(error)) {
      return error is TimeoutException
          ? 'NETWORK-TIMEOUT'
          : 'NETWORK-CONNECTION-INTERRUPTED';
    }
    final text = error.toString();
    if (text.contains('not configured')) return 'GOOGLE-CONFIG-MISSING';
    if (text.toLowerCase().contains('timeout')) return 'NETWORK-TIMEOUT';
    if (text.contains('drive_permission_revoked')) {
      return 'DRIVE-PERMISSION-REVOKED';
    }
    if (text.contains('drive_folder_missing')) return 'DRIVE-FOLDER-MISSING';
    return _code('CONNECTION', operation);
  }

  String? _safeDiagnosticDetail(Object error) {
    if (error is RemoteSnapshotValidationException) {
      return '검증 경로 ${error.first.path}';
    }
    if (error is DriveDataIntegrityException) return error.code;
    if (error is DriveRequestException) {
      final retry = error.retryAfter == null
          ? ''
          : ' · ${error.retryAfter!.inSeconds}초 뒤 재시도';
      final status = error.statusCode <= 0
          ? '네트워크 응답 없음'
          : 'HTTP ${error.statusCode}';
      return '$status · ${error.operation}$retry';
    }
    if (error is GoogleOAuthException) {
      final values = <String>[
        'HTTP ${error.statusCode}',
        if (error.code != null && error.code!.isNotEmpty) error.code!,
        if (error.description != null && error.description!.isNotEmpty)
          _redactCredentialText(error.description!),
      ];
      return _bounded(values.join(' · '));
    }
    if (_isTransportFailure(error)) return error.runtimeType.toString();
    return error.runtimeType.toString();
  }

  String _code(String prefix, String value) => '$prefix-${_segment(value)}';

  String _segment(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'UNKNOWN' : normalized;
  }

  String _bounded(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 237)}...';
  }

  String _redactCredentialText(String value) {
    return value
        .replaceAll(RegExp(r'GOCSPX-[A-Za-z0-9_-]+'), '[REDACTED]')
        .replaceAllMapped(
          RegExp(
            r'(client[_ -]?secret(?:\s*(?:=|:)\s*|\s+))[^\s,;]+',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}[REDACTED]',
        );
  }

  bool _shouldRetry(Object error) {
    if (error is RemoteSnapshotValidationException) return false;
    if (error is DriveRequestException) return error.retryable;
    if (error is DriveDataIntegrityException) {
      return error.code == 'drive_upload_conflict';
    }
    if (error is GoogleOAuthException) {
      if (_isClientSecretConfigurationError(error)) return false;
      return !const {
        'invalid_client',
        'redirect_uri_mismatch',
      }.contains(error.code);
    }
    if (_isTransportFailure(error)) return true;
    final text = error.toString();
    return !text.contains('앱을 업데이트한 뒤 다시 시도하세요') &&
        !text.contains('not configured');
  }

  bool _requiresReconnect(Object error, String operation) {
    if (error is RemoteSnapshotValidationException ||
        error is DriveDataIntegrityException) {
      return false;
    }
    if (error is DriveRequestException) return error.reconnectRequired;
    if (_isTransportFailure(error)) return false;
    if (operation != 'Drive 동기화') return true;
    if (error is GoogleOAuthException) return true;
    final text = error.toString();
    return text.contains('drive_permission_revoked') ||
        text.contains('drive_folder_missing');
  }

  bool _isClientSecretConfigurationError(GoogleOAuthException error) {
    return error.code == 'google_client_secret_missing' ||
        (error.code == 'invalid_request' &&
            (error.description ?? '').toLowerCase().contains('client_secret'));
  }

  Duration? _minimumRetryDelay(Object error) {
    return error is DriveRequestException ? error.retryAfter : null;
  }

  List<String> _recoverySteps(
    Object error, {
    DriveQuarantineRecord? quarantine,
  }) {
    if (error is RemoteSnapshotValidationException) {
      return [
        if (quarantine != null)
          'Drive의 Sprache/quarantine에서 격리 사본과 안전 미리보기를 확인합니다.',
        'Drive의 원격 파일을 수정하거나 정상 백업으로 교체합니다.',
        '이 기기의 내보내기 백업을 먼저 보관한 뒤 동기화를 다시 실행합니다.',
      ];
    }
    if (error is DriveDataIntegrityException) {
      if (error.code == 'drive_manifest_newer_schema' ||
          error.code == 'drive_manifest_newer_layout') {
        return const [
          'Sprache를 최신 버전으로 업데이트합니다.',
          '업데이트 후 같은 Drive 폴더로 다시 동기화합니다.',
        ];
      }
      return [
        if (error.quarantine != null)
          'Drive의 Sprache/quarantine에서 격리 사본과 안전 미리보기를 확인합니다.',
        '정상 백업을 복원하거나 손상 원격 파일을 정리한 뒤 다시 동기화합니다.',
        '복구가 끝날 때까지 이 기기의 정상 로컬 데이터를 삭제하지 않습니다.',
      ];
    }
    if (error is DriveRequestException) {
      return switch (error.failure) {
        DriveRequestFailure.authenticationExpired => const [
          'Google 다시 연결을 눌러 로그인합니다.',
          '기존과 같은 Drive 폴더를 선택합니다.',
        ],
        DriveRequestFailure.permissionRevoked => const [
          'Google 다시 연결을 눌러 Drive 권한을 다시 허용합니다.',
          '기존과 같은 Drive 폴더를 선택한 뒤 동기화합니다.',
        ],
        DriveRequestFailure.resourceMissing => const [
          'Drive 휴지통에서 기존 Sprache 폴더를 복원하거나 새 폴더를 준비합니다.',
          'Google 다시 연결에서 사용할 폴더를 다시 선택합니다.',
        ],
        DriveRequestFailure.rateLimited => const [
          '앱을 닫지 않아도 대기열이 유지됩니다.',
          '잠시 기다리거나 다시 시도를 눌러 동기화합니다.',
        ],
        DriveRequestFailure.quotaExceeded => const [
          'Google Drive 저장공간을 확보합니다.',
          '설정에서 지금 동기화를 다시 실행합니다.',
        ],
        DriveRequestFailure.serviceUnavailable => const [
          '인터넷 연결을 확인하고 잠시 기다립니다.',
          '설정에서 지금 동기화를 다시 실행합니다.',
        ],
        DriveRequestFailure.requestFailed => const [
          '진단 코드를 복사해 HTTP 상태를 확인합니다.',
          '네트워크를 확인한 뒤 동기화를 다시 실행합니다.',
        ],
      };
    }
    if (_isTransportFailure(error)) {
      return const [
        'Wi-Fi 또는 모바일 데이터 연결을 확인합니다.',
        '로컬 변경과 업로드 대기 작업은 그대로 두고 잠시 기다립니다.',
        '설정에서 지금 동기화를 다시 실행합니다.',
      ];
    }
    return const [];
  }

  bool _isTransportFailure(Object error) =>
      error is TimeoutException ||
      error is http.ClientException ||
      error is SocketException ||
      error is HandshakeException;

  Future<DriveQuarantineRecord?> _quarantineRemoteValidation(
    Object error,
  ) async {
    final service = _service;
    if (error is! RemoteSnapshotValidationException ||
        service is! RemoteSnapshotQuarantineService) {
      return null;
    }
    final quarantineService = service as RemoteSnapshotQuarantineService;
    return quarantineService.quarantineLastPulledSnapshot(
      reasonCode: 'drive_snapshot_validation_failed',
      preview: '검증 경로 ${error.first.path} · ${error.issues.length}개 문제',
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

String _pendingPayloadFingerprint(PendingSyncOperation operation) =>
    sha256.convert(utf8.encode(jsonEncode(operation.payload))).toString();

final connectionControllerProvider =
    StateNotifierProvider<ConnectionController, ConnectionState>((ref) {
      final controller = ConnectionController(
        ref.watch(googleConnectionServiceProvider),
        ref.read(appControllerProvider.notifier),
        store: ref.watch(studyStoreProvider),
      );
      ref.listen<AppState>(
        appControllerProvider,
        (previous, next) => controller.observeAppState(next),
        fireImmediately: true,
      );
      return controller;
    });
