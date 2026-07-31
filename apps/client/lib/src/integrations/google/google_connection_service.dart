import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';
import 'desktop_google_oauth.dart';
import 'desktop_google_token_broker.dart';
import 'google_drive_client.dart';
import 'oauth_tokens.dart';
import 'sprache_api_client.dart';

class GoogleConnectionResult {
  const GoogleConnectionResult({
    required this.folderId,
    required this.folderName,
    required this.mock,
  });

  final String folderId;
  final String folderName;
  final bool mock;
}

enum GoogleConnectionStage {
  checkingConnection,
  signIn,
  folderSelection,
  preparingDrive,
  linkingAccount,
  pulling,
  merging,
  pushing,
}

typedef GoogleConnectionStageCallback =
    void Function(GoogleConnectionStage stage);

abstract interface class GoogleConnectionService {
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  });

  Future<Map<String, Object?>?> pullSnapshot();

  Future<void> pushSnapshot(Map<String, Object?> snapshot);

  Future<void> disconnect();
}

abstract interface class RestorableGoogleConnectionService {
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  });
}

abstract interface class RemoteSnapshotQuarantineService {
  Future<DriveQuarantineRecord?> quarantineLastPulledSnapshot({
    required String reasonCode,
    required String preview,
  });
}

abstract interface class RemoteStorageRetentionService {
  Future<DriveRetentionInventory> inspectDriveRetention();

  Future<DriveRetentionCleanupResult> trashDriveRetentionItems({
    required DriveRetentionInventory inventory,
    required Set<String> selectedFileIds,
  });
}

abstract interface class AccountBindingDeletionService {
  Future<void> deleteAccountBinding();
}

class MockGoogleConnectionService
    implements
        GoogleConnectionService,
        RestorableGoogleConnectionService,
        AccountBindingDeletionService {
  Map<String, Object?>? _snapshot;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    onStage?.call(GoogleConnectionStage.signIn);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'mock_word_study_data',
      folderName: 'WordStudyData (Mock)',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> deleteAccountBinding() async {
    await disconnect();
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => _snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'mock_word_study_data',
      folderName: 'WordStudyData (Mock)',
      mock: true,
    );
  }
}

class UnavailableGoogleConnectionService implements GoogleConnectionService {
  const UnavailableGoogleConnectionService(this.message);

  final String message;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    throw StateError(message);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    throw StateError(message);
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) {
    throw StateError(message);
  }
}

class DesktopGoogleConnectionService
    implements
        GoogleConnectionService,
        RestorableGoogleConnectionService,
        RemoteSnapshotQuarantineService,
        RemoteStorageRetentionService,
        AccountBindingDeletionService {
  DesktopGoogleConnectionService({
    required AppConfig config,
    required TokenVault tokenVault,
    Future<bool> Function(Uri authorizationUri)? urlLauncher,
    DesktopGoogleTokenBroker? tokenBroker,
  }) : _oauth = DesktopGoogleOAuth(
         clientId: config.googleDesktopClientId,
         tokenVault: tokenVault,
         tokenBroker:
             tokenBroker ??
             RailwayDesktopGoogleTokenBroker(apiBaseUrl: config.apiBaseUrl),
         urlLauncher: urlLauncher,
       ),
       _api = SpracheApiClient(baseUrl: config.apiBaseUrl);

  final DesktopGoogleOAuth _oauth;
  final SpracheApiClient _api;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    await _oauth.ensureReady();
    onStage?.call(GoogleConnectionStage.signIn);
    final identity = await _oauth.signIn();
    final idToken = identity.tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not provide an ID token');
    }
    onStage?.call(GoogleConnectionStage.folderSelection);
    final driveAuthorization = await _oauth.selectDriveFolder();
    final selectedFolderId = driveAuthorization.pickedFolderId;
    if (selectedFolderId == null) {
      throw StateError('Google Picker did not return a folder ID');
    }
    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = GoogleDriveClient(
      accessTokenProvider: () => _oauth.accessToken(GoogleTokenKind.drive),
    );
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    onStage?.call(GoogleConnectionStage.linkingAccount);
    await _api.storeDriveRoot(
      idToken: idToken,
      folderId: bootstrap.appRootFolderId,
      folderName: bootstrap.appRootFolderName,
    );
    _drive = drive;
    _bootstrap = bootstrap;

    return GoogleConnectionResult(
      folderId: bootstrap.appRootFolderId,
      folderName: bootstrap.appRootFolderName,
      mock: false,
    );
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    if (!await _oauth.hasStoredSession()) return null;
    await _oauth.ensureReady();
    try {
      final idToken = await _oauth.identityToken();
      final storedBinding = await _api.getDriveRoot(idToken: idToken);
      if (storedBinding == null) return null;
      onStage?.call(GoogleConnectionStage.preparingDrive);
      final drive = GoogleDriveClient(
        accessTokenProvider: () => _oauth.accessToken(GoogleTokenKind.drive),
      );
      final bootstrap = await drive.reuseAppRoot(
        storedBinding.folderId,
        expectedFolderName: storedBinding.folderName,
      );
      _drive = drive;
      _bootstrap = bootstrap;
      return GoogleConnectionResult(
        folderId: bootstrap.appRootFolderId,
        folderName: bootstrap.appRootFolderName,
        mock: false,
      );
    } on StateError catch (error) {
      final message = error.message.toString();
      if (message.contains('authorization is required') ||
          message.contains('authorization expired') ||
          message.contains('sign-in is required') ||
          message.contains('did not return an ID token')) {
        return null;
      }
      rethrow;
    } on DriveRequestException catch (error) {
      if (error.reconnectRequired) return null;
      rethrow;
    } on DriveDataIntegrityException {
      return null;
    }
  }

  @override
  Future<void> disconnect() async {
    // Disconnect only this device. The Railway folder binding is account-wide
    // and must remain available to other devices and future reconnections.
    await _oauth.disconnect();
    _drive = null;
    _bootstrap = null;
  }

  @override
  Future<void> deleteAccountBinding() async {
    final idToken = await _oauth.identityToken();
    await _api.deleteDriveRoot(idToken: idToken);
    await disconnect();
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    return _requireDrive().readStateSnapshot(
      _requireBootstrap().appRootFolderId,
    );
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) {
    return _requireDrive().writeStateSnapshot(
      appRootId: _requireBootstrap().appRootFolderId,
      snapshot: snapshot,
    );
  }

  @override
  Future<DriveQuarantineRecord?> quarantineLastPulledSnapshot({
    required String reasonCode,
    required String preview,
  }) {
    return _requireDrive().quarantineLastPulledSnapshot(
      appRootId: _requireBootstrap().appRootFolderId,
      reasonCode: reasonCode,
      preview: preview,
    );
  }

  @override
  Future<DriveRetentionInventory> inspectDriveRetention() {
    return _requireDrive().inspectRetention(
      appRootId: _requireBootstrap().appRootFolderId,
    );
  }

  @override
  Future<DriveRetentionCleanupResult> trashDriveRetentionItems({
    required DriveRetentionInventory inventory,
    required Set<String> selectedFileIds,
  }) {
    return _requireDrive().trashRetentionItems(
      appRootId: _requireBootstrap().appRootFolderId,
      inventory: inventory,
      selectedFileIds: selectedFileIds,
    );
  }

  GoogleDriveClient _requireDrive() {
    return _drive ?? (throw StateError('Google Drive is not connected'));
  }

  DriveBootstrapResult _requireBootstrap() {
    return _bootstrap ?? (throw StateError('Google Drive is not connected'));
  }
}

class AndroidGoogleConnectionService
    implements
        GoogleConnectionService,
        RestorableGoogleConnectionService,
        RemoteSnapshotQuarantineService,
        RemoteStorageRetentionService,
        AccountBindingDeletionService {
  AndroidGoogleConnectionService({required AppConfig config})
    : _config = config,
      _api = SpracheApiClient(baseUrl: config.apiBaseUrl);

  static const _channel = MethodChannel('com.youkdonghun.sprache/google');
  final AppConfig _config;
  final SpracheApiClient _api;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  static const _driveScopes = ['https://www.googleapis.com/auth/drive.file'];

  bool _initialized = false;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    await _ensureInitialized();
    onStage?.call(GoogleConnectionStage.signIn);
    final account = await _signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not provide an ID token');
    }

    onStage?.call(GoogleConnectionStage.folderSelection);
    final storedBinding = await _api.getDriveRoot(idToken: idToken);
    if (storedBinding != null) {
      final authorization = await account.authorizationClient.authorizeScopes(
        _driveScopes,
      );
      final drive = _driveClient(
        account: account,
        fallbackAccessToken: authorization.accessToken,
      );
      try {
        final bootstrap = await drive.reuseAppRoot(
          storedBinding.folderId,
          expectedFolderName: storedBinding.folderName,
        );
        return _completeConnection(
          idToken: idToken,
          drive: drive,
          bootstrap: bootstrap,
          onStage: onStage,
        );
      } on DriveRequestException catch (error) {
        if (!error.reconnectRequired) rethrow;
      } on DriveDataIntegrityException {
        // Stale or invalid Railway metadata falls back to an explicit Picker
        // selection without overwriting or deleting local study data.
      }
    }

    final result = await _channel.invokeMapMethod<String, Object?>(
      'authorizeDrivePicker',
      {'email': account.email},
    );
    if (result == null) {
      throw StateError('Android Google connection returned no result');
    }
    final accessToken = result['accessToken'] as String?;
    final selectedFolderId = result['folderId'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Google authorization did not provide an access token');
    }
    if (selectedFolderId == null || selectedFolderId.isEmpty) {
      throw StateError('Google Picker did not return a folder ID');
    }

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: accessToken,
    );
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    return _completeConnection(
      idToken: idToken,
      drive: drive,
      bootstrap: bootstrap,
      onStage: onStage,
    );
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    await _ensureInitialized();
    final attempt = _signIn.attemptLightweightAuthentication();
    if (attempt == null) return null;
    final account = await attempt;
    if (account == null) return null;
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) return null;
    final storedBinding = await _api.getDriveRoot(idToken: idToken);
    if (storedBinding == null) return null;
    final authorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    if (authorization == null) return null;

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: authorization.accessToken,
    );
    try {
      final bootstrap = await drive.reuseAppRoot(
        storedBinding.folderId,
        expectedFolderName: storedBinding.folderName,
      );
      return _activateConnection(
        idToken: idToken,
        drive: drive,
        bootstrap: bootstrap,
      );
    } on DriveRequestException catch (error) {
      if (error.reconnectRequired) return null;
      rethrow;
    } on DriveDataIntegrityException {
      return null;
    }
  }

  GoogleDriveClient _driveClient({
    required GoogleSignInAccount account,
    required String fallbackAccessToken,
  }) {
    return GoogleDriveClient(
      accessTokenProvider: () async {
        final refreshed = await account.authorizationClient
            .authorizationForScopes(_driveScopes);
        return refreshed?.accessToken ?? fallbackAccessToken;
      },
    );
  }

  Future<GoogleConnectionResult> _completeConnection({
    required String idToken,
    required GoogleDriveClient drive,
    required DriveBootstrapResult bootstrap,
    required GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.linkingAccount);
    await _api.storeDriveRoot(
      idToken: idToken,
      folderId: bootstrap.appRootFolderId,
      folderName: bootstrap.appRootFolderName,
    );
    return _activateConnection(
      idToken: idToken,
      drive: drive,
      bootstrap: bootstrap,
    );
  }

  GoogleConnectionResult _activateConnection({
    required String idToken,
    required GoogleDriveClient drive,
    required DriveBootstrapResult bootstrap,
  }) {
    _drive = drive;
    _bootstrap = bootstrap;

    return GoogleConnectionResult(
      folderId: bootstrap.appRootFolderId,
      folderName: bootstrap.appRootFolderName,
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {
    // Disconnect only this device. The account-wide Railway binding remains
    // intact so another device is not silently detached.
    await _signIn.signOut();
    _drive = null;
    _bootstrap = null;
  }

  @override
  Future<void> deleteAccountBinding() async {
    await _ensureInitialized();
    final attempt = _signIn.attemptLightweightAuthentication();
    if (attempt == null) {
      throw StateError(
        'Google sign-in is required to delete the account binding',
      );
    }
    final account = await attempt;
    final idToken = account?.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not provide an ID token');
    }
    await _api.deleteDriveRoot(idToken: idToken);
    await disconnect();
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    return _requireDrive().readStateSnapshot(
      _requireBootstrap().appRootFolderId,
    );
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) {
    return _requireDrive().writeStateSnapshot(
      appRootId: _requireBootstrap().appRootFolderId,
      snapshot: snapshot,
    );
  }

  @override
  Future<DriveQuarantineRecord?> quarantineLastPulledSnapshot({
    required String reasonCode,
    required String preview,
  }) {
    return _requireDrive().quarantineLastPulledSnapshot(
      appRootId: _requireBootstrap().appRootFolderId,
      reasonCode: reasonCode,
      preview: preview,
    );
  }

  @override
  Future<DriveRetentionInventory> inspectDriveRetention() {
    return _requireDrive().inspectRetention(
      appRootId: _requireBootstrap().appRootFolderId,
    );
  }

  @override
  Future<DriveRetentionCleanupResult> trashDriveRetentionItems({
    required DriveRetentionInventory inventory,
    required Set<String> selectedFileIds,
  }) {
    return _requireDrive().trashRetentionItems(
      appRootId: _requireBootstrap().appRootFolderId,
      inventory: inventory,
      selectedFileIds: selectedFileIds,
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(serverClientId: _config.googleServerClientId);
    _initialized = true;
  }

  GoogleDriveClient _requireDrive() {
    return _drive ?? (throw StateError('Google Drive is not connected'));
  }

  DriveBootstrapResult _requireBootstrap() {
    return _bootstrap ?? (throw StateError('Google Drive is not connected'));
  }
}

GoogleConnectionService createGoogleConnectionService({
  required AppConfig config,
  required TokenVault tokenVault,
}) {
  if (config.mockMode) {
    return MockGoogleConnectionService();
  }
  if (defaultTargetPlatform == TargetPlatform.windows) {
    if (!config.hasDesktopGoogleCredentials) {
      return const UnavailableGoogleConnectionService(
        'GOOGLE_DESKTOP_CLIENT_ID is not configured',
      );
    }
    return DesktopGoogleConnectionService(
      config: config,
      tokenVault: tokenVault,
    );
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    if (!config.hasAndroidGoogleCredentials) {
      return const UnavailableGoogleConnectionService(
        'GOOGLE_ANDROID_CLIENT_ID or GOOGLE_SERVER_CLIENT_ID is not configured',
      );
    }
    return AndroidGoogleConnectionService(config: config);
  }
  return const UnavailableGoogleConnectionService(
    'Google connection is not supported on this platform',
  );
}
