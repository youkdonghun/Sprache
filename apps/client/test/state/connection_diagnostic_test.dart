import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/desktop_google_oauth.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/integrations/google/google_drive_client.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
  test('connection exposes every Google and Drive stage in order', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final controller = ConnectionController(_StagedGoogleService(), app);
    final observed = <GoogleConnectionStage>[];
    controller.addListener((next) {
      final stage = next.stage;
      if (stage != null && (observed.isEmpty || observed.last != stage)) {
        observed.add(stage);
      }
    });

    await controller.connect();

    expect(controller.state.phase, ConnectionPhase.connected);
    expect(observed, [
      GoogleConnectionStage.checkingConnection,
      GoogleConnectionStage.signIn,
      GoogleConnectionStage.folderSelection,
      GoogleConnectionStage.preparingDrive,
      GoogleConnectionStage.linkingAccount,
      GoogleConnectionStage.pulling,
      GoogleConnectionStage.merging,
      GoogleConnectionStage.pushing,
    ]);

    controller.dispose();
    app.dispose();
  });

  test('saved connection restores without interactive sign-in', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    app.setDriveConnected(true);
    final service = _RestorableGoogleService();
    final controller = ConnectionController(service, app);

    await controller.restoreSavedConnection();

    expect(service.restoreCalls, 1);
    expect(service.interactiveCalls, 0);
    expect(service.pullCalls, 1);
    expect(service.pushCalls, 1);
    expect(controller.state.phase, ConnectionPhase.connected);
    expect(controller.state.runtimeReady, isTrue);
    expect(controller.state.folderName, 'WordStudyData');
    expect(app.state.driveConnected, isTrue);

    controller.dispose();
    app.dispose();
  });

  test(
    'Drive folder reselection swaps only after selection succeeds',
    () async {
      final app = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final service = _ReselectableGoogleService();
      final controller = ConnectionController(service, app);

      await controller.connect();
      expect(controller.state.folderId, 'drive-old');
      expect(controller.state.folderName, 'WordStudyData old');

      await controller.changeDriveFolder();
      expect(controller.state.phase, ConnectionPhase.connected);
      expect(controller.state.folderId, 'drive-new');
      expect(controller.state.folderName, 'WordStudyData new');
      expect(service.boundFolderId, 'drive-new');
      expect(service.commitCalls, 1);
      expect(service.rollbackCalls, 0);
      expect(app.state.pendingSync, isNull);

      service.failReselection = true;
      await expectLater(controller.changeDriveFolder(), throwsStateError);
      expect(controller.state.phase, ConnectionPhase.connected);
      expect(controller.state.folderId, 'drive-new');
      expect(controller.state.folderName, 'WordStudyData new');
      expect(app.state.driveConnected, isTrue);

      controller.dispose();
      app.dispose();
    },
  );

  for (final failure in _FolderReselectionFailure.values) {
    test(
      'Drive folder reselection rolls back atomically after ${failure.name} failure',
      () async {
        final app = AppController(MemoryStudyStore());
        await Future<void>.delayed(Duration.zero);
        final service = _ReselectableGoogleService();
        final controller = ConnectionController(service, app);

        await controller.connect();
        final pendingBefore = await app.queueSyncSnapshot(
          now: DateTime.utc(2026, 8, 3, 12),
        );
        final localBefore = app.exportSyncSnapshot()..remove('updatedAt');
        final candidateSnapshot = app.exportSyncSnapshot();
        final profile = Map<String, Object?>.from(
          candidateSnapshot['profile']! as Map,
        );
        candidateSnapshot['profile'] = {
          ...profile,
          'totalXp': 900,
          'xpByReplica': const {'remote-replica': 900},
        };
        if (failure == _FolderReselectionFailure.merge) {
          candidateSnapshot['schemaVersion'] = 999;
        }
        service.snapshotsByFolder['drive-new'] = candidateSnapshot;
        service.failure = failure;

        await expectLater(controller.changeDriveFolder(), throwsStateError);

        final localAfter = app.exportSyncSnapshot()..remove('updatedAt');
        expect(controller.state.phase, ConnectionPhase.connected);
        expect(controller.state.folderId, 'drive-old');
        expect(controller.state.folderName, 'WordStudyData old');
        expect(service.activeFolderId, 'drive-old');
        expect(service.boundFolderId, 'drive-old');
        expect(service.rollbackCalls, 1);
        expect(
          service.commitCalls,
          failure == _FolderReselectionFailure.commit ? 1 : 0,
        );
        expect(app.state.driveConnected, isTrue);
        expect(app.state.pendingSync?.operationId, pendingBefore.operationId);
        expect(app.state.pendingSync?.attempts, pendingBefore.attempts);
        expect(
          app.state.pendingSync?.nextAttemptAt,
          pendingBefore.nextAttemptAt,
        );
        expect(app.state.pendingSync?.payload, pendingBefore.payload);
        expect(localAfter, localBefore);

        controller.dispose();
        app.dispose();
      },
    );
  }

  test('unavailable lightweight sign-in keeps the saved local link', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    app.setDriveConnected(true);
    final service = _RestorableGoogleService(restoreResult: null);
    final controller = ConnectionController(service, app);

    await controller.restoreSavedConnection();

    expect(controller.state.phase, ConnectionPhase.disconnected);
    expect(controller.state.runtimeReady, isFalse);
    expect(app.state.driveConnected, isTrue);
    expect(service.pullCalls, 0);
    expect(service.pushCalls, 0);

    controller.dispose();
    app.dispose();
  });

  test(
    'failed automatic restore preserves local data and requires restore',
    () async {
      final app = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      app.setDriveConnected(true);
      final service = _RestorableGoogleService(
        restoreError: const DriveRequestException(
          failure: DriveRequestFailure.serviceUnavailable,
          statusCode: 503,
          operation: 'restore Drive session',
        ),
      );
      final controller = ConnectionController(service, app);
      final before = app.exportSyncSnapshot()..remove('updatedAt');

      await controller.restoreSavedConnection();
      await controller.syncNow();
      final after = app.exportSyncSnapshot()..remove('updatedAt');

      expect(controller.state.phase, ConnectionPhase.failed);
      expect(controller.state.runtimeReady, isFalse);
      expect(controller.state.diagnostic?.message, contains('로컬 변경은 유지'));
      expect(controller.state.diagnostic?.retryable, isTrue);
      expect(service.pullCalls, 0);
      expect(service.pushCalls, 0);
      expect(after, before);

      controller.dispose();
      app.dispose();
    },
  );

  test('OAuth failure exposes a stable, sanitized diagnostic', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final controller = ConnectionController(_OAuthFailureService(), app);

    await controller.connect();

    final diagnostic = controller.state.diagnostic;
    expect(controller.state.phase, ConnectionPhase.failed);
    expect(diagnostic?.code, 'GOOGLE-TOKEN-EXCHANGE-400-INVALID-CLIENT');
    expect(diagnostic?.message, contains('Client ID'));
    expect(diagnostic?.retryable, isFalse);
    expect(diagnostic?.reconnectRequired, isTrue);
    expect(diagnostic?.stageLabel, '1/4 Google 계정 선택·동의');
    expect(diagnostic?.clipboardText, contains('로컬 데이터: 유지됨'));
    expect(diagnostic?.clipboardText, contains('세부 단계: 1/4'));
    expect(diagnostic?.clipboardText, isNot(contains('access_token')));

    controller.dispose();
    app.dispose();
  });

  test('desktop OAuth client secret failure stays sanitized', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final controller = ConnectionController(_ClientSecretFailureService(), app);

    await controller.connect();

    final diagnostic = controller.state.diagnostic;
    expect(diagnostic?.code, 'GOOGLE-TOKEN-EXCHANGE-400-INVALID-REQUEST');
    expect(diagnostic?.message, contains('Google 토큰 교환 설정'));
    expect(diagnostic?.message, isNot(contains('desktop-client-secret')));
    expect(diagnostic?.clipboardText, isNot(contains('desktop-client-secret')));
    expect(diagnostic?.retryable, isFalse);
    expect(diagnostic?.reconnectRequired, isTrue);
    expect(diagnostic?.stageLabel, '1/4 Google 계정 선택·동의');

    controller.dispose();
    app.dispose();
  });

  test('transport abort is shown as a safe Korean retry diagnostic', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final controller = ConnectionController(_TransportFailureService(), app);

    await controller.connect();

    final diagnostic = controller.state.diagnostic!;
    expect(controller.state.phase, ConnectionPhase.failed);
    expect(diagnostic.code, 'NETWORK-CONNECTION-INTERRUPTED');
    expect(diagnostic.message, contains('인터넷 연결이 중간에 끊겨'));
    expect(diagnostic.message, contains('로컬 데이터'));
    expect(diagnostic.message, isNot(contains('ClientException')));
    expect(diagnostic.message, isNot(contains('googleapis.com')));
    expect(diagnostic.detail, 'ClientException');
    expect(diagnostic.retryable, isTrue);
    expect(diagnostic.reconnectRequired, isFalse);
    expect(diagnostic.recoverySteps, contains(contains('지금 동기화')));
    expect(diagnostic.clipboardText, isNot(contains('sensitive-file-id')));

    controller.dispose();
    app.dispose();
  });

  test(
    'Drive recovery separates auth, rate, quota, and missing data',
    () async {
      Future<ConnectionDiagnostic> diagnose(DriveRequestException error) async {
        final app = AppController(MemoryStudyStore());
        await Future<void>.delayed(Duration.zero);
        final controller = ConnectionController(
          _DriveFailureService(error),
          app,
        );
        await controller.connect();
        final diagnostic = controller.state.diagnostic!;
        controller.dispose();
        app.dispose();
        return diagnostic;
      }

      final auth = await diagnose(
        const DriveRequestException(
          failure: DriveRequestFailure.authenticationExpired,
          statusCode: 401,
          operation: 'read Drive metadata',
        ),
      );
      expect(auth.code, 'DRIVE-AUTH-EXPIRED');
      expect(auth.reconnectRequired, isTrue);
      expect(auth.retryable, isFalse);
      expect(auth.recoverySteps, contains(contains('다시 연결')));

      final rate = await diagnose(
        const DriveRequestException(
          failure: DriveRequestFailure.rateLimited,
          statusCode: 429,
          operation: 'read Drive metadata',
          retryAfter: Duration(seconds: 30),
        ),
      );
      expect(rate.code, 'DRIVE-RATE-LIMITED');
      expect(rate.reconnectRequired, isFalse);
      expect(rate.retryable, isTrue);
      expect(rate.detail, contains('30초 뒤 재시도'));

      final quota = await diagnose(
        const DriveRequestException(
          failure: DriveRequestFailure.quotaExceeded,
          statusCode: 403,
          operation: 'upload Drive JSON',
        ),
      );
      expect(quota.code, 'DRIVE-QUOTA-EXCEEDED');
      expect(quota.reconnectRequired, isFalse);
      expect(quota.retryable, isFalse);
      expect(quota.message, contains('저장공간'));

      final missing = await diagnose(
        const DriveRequestException(
          failure: DriveRequestFailure.resourceMissing,
          statusCode: 404,
          operation: 'read Drive metadata',
        ),
      );
      expect(missing.code, 'DRIVE-RESOURCE-MISSING');
      expect(missing.reconnectRequired, isTrue);
      expect(missing.recoverySteps, contains(contains('휴지통')));
    },
  );

  test(
    'expired Drive authorization never retries from background activity',
    () async {
      final app = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final service = _DriveFailureService(
        const DriveRequestException(
          failure: DriveRequestFailure.authenticationExpired,
          statusCode: 401,
          operation: 'use cached web Drive authorization',
        ),
      );
      final controller = ConnectionController(service, app);

      await controller.connect();
      expect(controller.state.phase, ConnectionPhase.failed);
      expect(controller.state.diagnostic?.reconnectRequired, isTrue);
      expect(service.pullCalls, 1);

      await controller.syncAutomatically();
      expect(service.pullCalls, 1);

      await controller.syncNow();
      expect(service.pullCalls, 2);

      controller.dispose();
      app.dispose();
    },
  );

  test('quarantined corruption exposes only a safe preview', () async {
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final controller = ConnectionController(
      _DriveFailureService(
        DriveDataIntegrityException(
          'drive_manifest_sha_mismatch',
          'checksum mismatch',
          preview: 'snapshot.json · 123 bytes · SHA-256 0123456789abcdef…',
          quarantine: DriveQuarantineRecord(
            fileId: 'quarantine-copy',
            fileName: 'snapshot.json.sha-mismatch.copy',
            sourceFileId: 'snapshot-file',
            createdAt: DateTime.utc(2026, 7, 29),
            reasonCode: 'drive_manifest_sha_mismatch',
            preview: 'snapshot.json · 123 bytes · SHA-256 0123456789abcdef…',
          ),
        ),
      ),
      app,
    );

    await controller.connect();

    final diagnostic = controller.state.diagnostic!;
    expect(diagnostic.code, 'DRIVE-MANIFEST-SHA-MISMATCH');
    expect(diagnostic.quarantine?.fileId, 'quarantine-copy');
    expect(diagnostic.message, contains('quarantine'));
    expect(diagnostic.reconnectRequired, isFalse);
    expect(diagnostic.retryable, isFalse);
    expect(diagnostic.clipboardText, contains('안전 미리보기'));
    expect(diagnostic.clipboardText, isNot(contains('secret study content')));

    controller.dispose();
    app.dispose();
  });

  test(
    'semantic snapshot validation also requests a quarantine copy',
    () async {
      final app = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final service = _SemanticValidationFailureService();
      final controller = ConnectionController(service, app);
      final localXpBefore = controllerStateXp(app);

      await controller.connect();

      final diagnostic = controller.state.diagnostic!;
      expect(service.quarantineCalls, 1);
      expect(diagnostic.code, 'SYNC-REMOTE-DATA-INVALID');
      expect(diagnostic.quarantine?.fileId, 'semantic-quarantine-copy');
      expect(diagnostic.recoverySteps, contains(contains('quarantine')));
      expect(controllerStateXp(app), localXpBefore);

      controller.dispose();
      app.dispose();
    },
  );
}

int controllerStateXp(AppController controller) => controller.state.totalXp;

class _RestorableGoogleService
    implements GoogleConnectionService, RestorableGoogleConnectionService {
  _RestorableGoogleService({
    this.restoreResult = const GoogleConnectionResult(
      folderId: 'saved-drive-root',
      folderName: 'WordStudyData',
      mock: false,
    ),
    this.restoreError,
  });

  final GoogleConnectionResult? restoreResult;
  final Object? restoreError;
  int restoreCalls = 0;
  int interactiveCalls = 0;
  int pullCalls = 0;
  int pushCalls = 0;
  Map<String, Object?>? snapshot;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    interactiveCalls++;
    throw StateError('interactive sign-in must not run during restore');
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    restoreCalls++;
    onStage?.call(GoogleConnectionStage.checkingConnection);
    final error = restoreError;
    if (error != null) throw error;
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return restoreResult;
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() async {
    pullCalls++;
    return snapshot;
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    pushCalls++;
    this.snapshot = snapshot;
  }

  @override
  Future<void> disconnect() async {}
}

class _ReselectableGoogleService
    implements GoogleConnectionService, DriveFolderReselectionService {
  bool failReselection = false;
  _FolderReselectionFailure? failure;
  String activeFolderId = 'drive-old';
  String boundFolderId = 'drive-old';
  String? _previousFolderId;
  int commitCalls = 0;
  int rollbackCalls = 0;
  final Map<String, Map<String, Object?>?> snapshotsByFolder = {};

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    activeFolderId = boundFolderId;
    return const GoogleConnectionResult(
      folderId: 'drive-old',
      folderName: 'WordStudyData old',
      mock: false,
    );
  }

  @override
  Future<GoogleConnectionResult> reselectDriveFolder({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.folderSelection);
    if (failReselection) {
      throw StateError('picker cancelled');
    }
    _previousFolderId = activeFolderId;
    activeFolderId = 'drive-new';
    return const GoogleConnectionResult(
      folderId: 'drive-new',
      folderName: 'WordStudyData new',
      mock: false,
    );
  }

  @override
  Future<void> commitDriveFolderReselection() async {
    commitCalls++;
    boundFolderId = activeFolderId;
    if (failure == _FolderReselectionFailure.commit) {
      throw StateError('candidate binding commit result is unknown');
    }
    _previousFolderId = null;
  }

  @override
  Future<void> rollbackDriveFolderReselection() async {
    rollbackCalls++;
    final previousFolderId = _previousFolderId;
    if (previousFolderId != null) {
      activeFolderId = previousFolderId;
      boundFolderId = previousFolderId;
    }
    _previousFolderId = null;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async {
    if (activeFolderId == 'drive-new' &&
        failure == _FolderReselectionFailure.pull) {
      throw StateError('candidate pull failed');
    }
    return snapshotsByFolder[activeFolderId];
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> value) async {
    if (activeFolderId == 'drive-new' &&
        failure == _FolderReselectionFailure.push) {
      throw StateError('candidate push failed');
    }
    snapshotsByFolder[activeFolderId] = value;
  }
}

enum _FolderReselectionFailure { pull, merge, push, commit }

class _OAuthFailureService implements GoogleConnectionService {
  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    onStage?.call(GoogleConnectionStage.signIn);
    throw const GoogleOAuthException(
      operation: 'Google token exchange',
      statusCode: 400,
      code: 'invalid_client',
      description: 'The OAuth client was not found.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => null;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}

class _StagedGoogleService implements GoogleConnectionService {
  Map<String, Object?>? snapshot;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    for (final stage in const [
      GoogleConnectionStage.signIn,
      GoogleConnectionStage.folderSelection,
      GoogleConnectionStage.preparingDrive,
      GoogleConnectionStage.linkingAccount,
    ]) {
      onStage?.call(stage);
    }
    return const GoogleConnectionResult(
      folderId: 'staged-folder',
      folderName: 'Staged folder',
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    this.snapshot = snapshot;
  }
}

class _ClientSecretFailureService implements GoogleConnectionService {
  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    onStage?.call(GoogleConnectionStage.signIn);
    throw const GoogleOAuthException(
      operation: 'Google token exchange',
      statusCode: 400,
      code: 'invalid_request',
      description: 'client_secret desktop-client-secret is invalid.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => null;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}

class _TransportFailureService implements GoogleConnectionService {
  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'drive-root',
      folderName: 'WordStudyData',
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    throw http.ClientException(
      'Software caused connection abort',
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files/'
        'sensitive-file-id?uploadType=media',
      ),
    );
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}

class _DriveFailureService implements GoogleConnectionService {
  _DriveFailureService(this.error);

  final Object error;
  int pullCalls = 0;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'drive-root',
      folderName: 'WordStudyData',
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    pullCalls += 1;
    return Future.error(error);
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}

class _SemanticValidationFailureService
    implements GoogleConnectionService, RemoteSnapshotQuarantineService {
  var quarantineCalls = 0;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'drive-root',
      folderName: 'WordStudyData',
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    return Future.error(
      const RemoteSnapshotValidationException([
        SnapshotValidationIssue(
          path: r'$.customItems[0].reading',
          message: '병음 형식이 올바르지 않습니다.',
        ),
      ]),
    );
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}

  @override
  Future<DriveQuarantineRecord?> quarantineLastPulledSnapshot({
    required String reasonCode,
    required String preview,
  }) async {
    quarantineCalls += 1;
    return DriveQuarantineRecord(
      fileId: 'semantic-quarantine-copy',
      fileName: 'snapshot.json.validation-failed.copy',
      sourceFileId: 'snapshot-file',
      createdAt: DateTime.utc(2026, 7, 29),
      reasonCode: reasonCode,
      preview: preview,
    );
  }
}
