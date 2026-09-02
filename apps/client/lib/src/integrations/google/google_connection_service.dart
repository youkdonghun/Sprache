import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';
import 'desktop_google_oauth.dart';
import 'desktop_google_token_broker.dart';
import 'google_drive_client.dart';
import 'google_web_oauth.dart';
import 'oauth_tokens.dart';

typedef GoogleDriveClientFactory =
    GoogleDriveClient Function(Future<String> Function() accessTokenProvider);

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

/// Selects a new Drive destination without deleting the Drive app-data binding
/// first. Implementations must keep the current runtime connection usable until
/// the new folder has been selected and initialized successfully.
abstract interface class DriveFolderReselectionService {
  Future<GoogleConnectionResult> reselectDriveFolder({
    GoogleConnectionStageCallback? onStage,
  });

  /// Persists the staged folder in Drive app data only after the
  /// controller has completed pull, validation, merge, and push successfully.
  Future<void> commitDriveFolderReselection();

  /// Restores the runtime connection (and, when a commit may have reached
  /// Drive, the previous app-data binding) without deleting either
  /// folder.
  Future<void> rollbackDriveFolderReselection();
}

class _PendingDriveFolderReselection {
  _PendingDriveFolderReselection({
    required this.previousDrive,
    required this.previousBootstrap,
    required this.candidateBootstrap,
  });

  final GoogleDriveClient? previousDrive;
  final DriveBootstrapResult? previousBootstrap;
  final DriveBootstrapResult candidateBootstrap;
  bool bindingCommitAttempted = false;
}

Future<DriveBootstrapResult?> _restoreBootstrapFromDrive(
  GoogleDriveClient drive, {
  required bool appDataScopeGranted,
}) async {
  DriveAppDataBinding? binding;
  var canWriteBinding = appDataScopeGranted;
  if (appDataScopeGranted) {
    try {
      binding = await drive.readAppDataBinding();
    } on DriveRequestException catch (error) {
      if (error.failure != DriveRequestFailure.permissionRevoked) rethrow;
      // Tokens created before the serverless migration only contain
      // drive.file. Discovery below keeps those users connected until their
      // next explicit consent grants drive.appdata.
      canWriteBinding = false;
    } on DriveDataIntegrityException {
      // Never overwrite a damaged or future-schema binding automatically.
      canWriteBinding = false;
    }
  }

  if (binding != null) {
    try {
      return await drive.reuseAppRoot(
        binding.folderId,
        expectedFolderName: binding.folderName,
      );
    } on DriveRequestException catch (error) {
      if (error.failure != DriveRequestFailure.resourceMissing) rethrow;
    } on DriveDataIntegrityException {
      // A stale pointer must not block safe discovery of the one valid root.
    }
  }

  final discovered = await drive.discoverAppRoot();
  if (discovered == null) return null;
  if (canWriteBinding) {
    await drive.upsertAppDataBinding(
      folderId: discovered.appRootFolderId,
      folderName: discovered.appRootFolderName,
    );
  }
  return discovered;
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
        DriveFolderReselectionService,
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
      folderName: 'Sprache (Mock)',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<GoogleConnectionResult> reselectDriveFolder({
    GoogleConnectionStageCallback? onStage,
  }) => connect(onStage: onStage);

  @override
  Future<void> commitDriveFolderReselection() async {}

  @override
  Future<void> rollbackDriveFolderReselection() async {}

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
      folderName: 'Sprache (Mock)',
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
        DriveFolderReselectionService,
        RemoteSnapshotQuarantineService,
        RemoteStorageRetentionService,
        AccountBindingDeletionService {
  DesktopGoogleConnectionService({
    required AppConfig config,
    required TokenVault tokenVault,
    Future<bool> Function(Uri authorizationUri)? urlLauncher,
    DesktopGoogleTokenBroker? tokenBroker,
    GoogleDriveClientFactory? driveClientFactory,
  }) : _oauth = DesktopGoogleOAuth(
         clientId: config.googleDesktopClientId,
         tokenVault: tokenVault,
         tokenBroker:
             tokenBroker ??
             DirectDesktopGoogleTokenBroker(
               clientId: config.googleDesktopClientId,
             ),
         urlLauncher: urlLauncher,
       ),
       _driveClientFactory =
           driveClientFactory ??
           ((accessTokenProvider) =>
               GoogleDriveClient(accessTokenProvider: accessTokenProvider));

  final DesktopGoogleOAuth _oauth;
  final GoogleDriveClientFactory _driveClientFactory;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;
  _PendingDriveFolderReselection? _pendingFolderReselection;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    await _oauth.ensureReady();
    onStage?.call(GoogleConnectionStage.signIn);
    onStage?.call(GoogleConnectionStage.folderSelection);
    final driveAuthorization = await _oauth.selectDriveFolder();
    final selectedFolderId = driveAuthorization.pickedFolderId;
    if (selectedFolderId == null) {
      throw StateError('Google Picker did not return a folder ID');
    }
    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _createDriveClient();
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    onStage?.call(GoogleConnectionStage.linkingAccount);
    await drive.upsertAppDataBinding(
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
  Future<GoogleConnectionResult> reselectDriveFolder({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    await _oauth.ensureReady();
    onStage?.call(GoogleConnectionStage.folderSelection);
    final driveAuthorization = await _oauth.selectDriveFolder();
    final selectedFolderId = driveAuthorization.pickedFolderId;
    if (selectedFolderId == null) {
      throw StateError('Google Picker did not return a folder ID');
    }
    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _createDriveClient();
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    _pendingFolderReselection = _PendingDriveFolderReselection(
      previousDrive: _drive,
      previousBootstrap: _bootstrap,
      candidateBootstrap: bootstrap,
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
  Future<void> commitDriveFolderReselection() async {
    final pending = _pendingFolderReselection;
    if (pending == null) {
      throw StateError('No Drive folder reselection is pending');
    }
    pending.bindingCommitAttempted = true;
    await _requireDrive().upsertAppDataBinding(
      folderId: pending.candidateBootstrap.appRootFolderId,
      folderName: pending.candidateBootstrap.appRootFolderName,
    );
    _pendingFolderReselection = null;
  }

  @override
  Future<void> rollbackDriveFolderReselection() async {
    final pending = _pendingFolderReselection;
    if (pending == null) return;
    final bindingDrive = _drive;
    try {
      final previous = pending.previousBootstrap;
      if (pending.bindingCommitAttempted && bindingDrive != null) {
        if (previous == null) {
          await bindingDrive.deleteAppDataBinding();
        } else {
          await bindingDrive.upsertAppDataBinding(
            folderId: previous.appRootFolderId,
            folderName: previous.appRootFolderName,
          );
        }
      }
    } finally {
      _drive = pending.previousDrive;
      _bootstrap = pending.previousBootstrap;
      _pendingFolderReselection = null;
    }
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    if (!await _oauth.hasStoredSession()) return null;
    await _oauth.ensureReady();
    try {
      onStage?.call(GoogleConnectionStage.preparingDrive);
      final drive = _createDriveClient();
      final bootstrap = await _restoreBootstrapFromDrive(
        drive,
        appDataScopeGranted: true,
      );
      if (bootstrap == null) return null;
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
          message.contains('sign-in is required')) {
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
    // Disconnect only this device. The Drive app-data binding remains available
    // to other devices and future reconnections.
    await _oauth.disconnect();
    _drive = null;
    _bootstrap = null;
    _pendingFolderReselection = null;
  }

  @override
  Future<void> deleteAccountBinding() async {
    await _oauth.ensureReady();
    if (!await _oauth.hasStoredSession()) {
      await _oauth.authorizeDriveAccess();
    }
    final drive = _createDriveClient();
    await drive.deleteAppDataBinding();
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

  GoogleDriveClient _createDriveClient() {
    return _driveClientFactory(() => _oauth.accessToken(GoogleTokenKind.drive));
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
        DriveFolderReselectionService,
        RemoteSnapshotQuarantineService,
        RemoteStorageRetentionService,
        AccountBindingDeletionService {
  AndroidGoogleConnectionService({required this._config});

  static const _channel = MethodChannel('com.youkdonghun.sprache/google');
  final AppConfig _config;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  static const _legacyDriveScopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];
  static const _driveScopes = [
    ..._legacyDriveScopes,
    GoogleDriveClient.appDataOAuthScope,
  ];

  bool _initialized = false;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;
  _PendingDriveFolderReselection? _pendingFolderReselection;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    await _ensureInitialized();
    onStage?.call(GoogleConnectionStage.signIn);
    final account = await _signIn.authenticate();

    onStage?.call(GoogleConnectionStage.folderSelection);
    final existingAuthorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    if (existingAuthorization != null) {
      final drive = _driveClient(
        account: account,
        fallbackAccessToken: existingAuthorization.accessToken,
      );
      final bootstrap = await _restoreBootstrapFromDrive(
        drive,
        appDataScopeGranted: true,
      );
      if (bootstrap != null) {
        onStage?.call(GoogleConnectionStage.preparingDrive);
        return _activateConnection(drive: drive, bootstrap: bootstrap);
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

    // OnePick must be requested with drive.file alone. Request app-data access
    // separately so the binding used for cross-device restore remains valid.
    final driveAuthorization = await account.authorizationClient
        .authorizeScopes(_driveScopes);

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: driveAuthorization.accessToken,
    );
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    return _completeConnection(
      drive: drive,
      bootstrap: bootstrap,
      onStage: onStage,
    );
  }

  @override
  Future<GoogleConnectionResult> reselectDriveFolder({
    GoogleConnectionStageCallback? onStage,
  }) async {
    await _ensureInitialized();
    onStage?.call(GoogleConnectionStage.signIn);
    final attempt = _signIn.attemptLightweightAuthentication();
    final account =
        (attempt == null ? null : await attempt) ??
        await _signIn.authenticate();

    onStage?.call(GoogleConnectionStage.folderSelection);
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

    final driveAuthorization = await account.authorizationClient
        .authorizeScopes(_driveScopes);

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: driveAuthorization.accessToken,
    );
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    _pendingFolderReselection = _PendingDriveFolderReselection(
      previousDrive: _drive,
      previousBootstrap: _bootstrap,
      candidateBootstrap: bootstrap,
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
  Future<void> commitDriveFolderReselection() async {
    final pending = _pendingFolderReselection;
    if (pending == null) {
      throw StateError('No Drive folder reselection is pending');
    }
    pending.bindingCommitAttempted = true;
    await _requireDrive().upsertAppDataBinding(
      folderId: pending.candidateBootstrap.appRootFolderId,
      folderName: pending.candidateBootstrap.appRootFolderName,
    );
    _pendingFolderReselection = null;
  }

  @override
  Future<void> rollbackDriveFolderReselection() async {
    final pending = _pendingFolderReselection;
    if (pending == null) return;
    final bindingDrive = _drive;
    try {
      final previous = pending.previousBootstrap;
      if (pending.bindingCommitAttempted && bindingDrive != null) {
        if (previous == null) {
          await bindingDrive.deleteAppDataBinding();
        } else {
          await bindingDrive.upsertAppDataBinding(
            folderId: previous.appRootFolderId,
            folderName: previous.appRootFolderName,
          );
        }
      }
    } finally {
      _drive = pending.previousDrive;
      _bootstrap = pending.previousBootstrap;
      _pendingFolderReselection = null;
    }
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
    var appDataScopeGranted = true;
    var authorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    if (authorization == null) {
      appDataScopeGranted = false;
      authorization = await account.authorizationClient.authorizationForScopes(
        _legacyDriveScopes,
      );
    }
    if (authorization == null) return null;

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: authorization.accessToken,
    );
    try {
      final bootstrap = await _restoreBootstrapFromDrive(
        drive,
        appDataScopeGranted: appDataScopeGranted,
      );
      if (bootstrap == null) return null;
      return _activateConnection(drive: drive, bootstrap: bootstrap);
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
    required GoogleDriveClient drive,
    required DriveBootstrapResult bootstrap,
    required GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.linkingAccount);
    await drive.upsertAppDataBinding(
      folderId: bootstrap.appRootFolderId,
      folderName: bootstrap.appRootFolderName,
    );
    return _activateConnection(drive: drive, bootstrap: bootstrap);
  }

  GoogleConnectionResult _activateConnection({
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
    // Disconnect only this device. The Drive app-data binding remains intact
    // so another device is not silently detached.
    await _signIn.signOut();
    _drive = null;
    _bootstrap = null;
    _pendingFolderReselection = null;
  }

  @override
  Future<void> deleteAccountBinding() async {
    await _ensureInitialized();
    final attempt = _signIn.attemptLightweightAuthentication();
    final account =
        (attempt == null ? null : await attempt) ??
        await _signIn.authenticate();
    final authorization = await account.authorizationClient.authorizeScopes(
      _driveScopes,
    );
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: authorization.accessToken,
    );
    await drive.deleteAppDataBinding();
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

/// Browser-only Google Identity Services connection. Access tokens stay in
/// memory and are requested again after expiration or a PWA restart.
class GoogleWebConnectionService
    implements
        GoogleConnectionService,
        RestorableGoogleConnectionService,
        DriveFolderReselectionService,
        RemoteSnapshotQuarantineService,
        RemoteStorageRetentionService,
        AccountBindingDeletionService {
  GoogleWebConnectionService({required this.config})
    : _oauth = GoogleWebOAuthClient(clientId: config.googleWebClientId);

  final AppConfig config;
  final GoogleWebOAuthClient _oauth;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;
  _PendingDriveFolderReselection? _pendingFolderReselection;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.signIn);
    final authorization = await _oauth.authorize();
    final drive = _driveClient();

    onStage?.call(GoogleConnectionStage.preparingDrive);
    var bootstrap = await _restoreBootstrapFromDrive(
      drive,
      appDataScopeGranted: true,
    );
    if (bootstrap == null) {
      onStage?.call(GoogleConnectionStage.folderSelection);
      final selectedFolderId = config.googlePickerApiKey.isEmpty
          ? 'root'
          : await _oauth.pickDriveFolder(
              accessToken: authorization.accessToken,
              apiKey: config.googlePickerApiKey,
            );
      if (selectedFolderId == null) {
        throw StateError('Google Drive folder selection was cancelled.');
      }
      onStage?.call(GoogleConnectionStage.preparingDrive);
      bootstrap = await drive.ensureAppRoot(selectedFolderId);
      onStage?.call(GoogleConnectionStage.linkingAccount);
      await drive.upsertAppDataBinding(
        folderId: bootstrap.appRootFolderId,
        folderName: bootstrap.appRootFolderName,
      );
    }
    return _activateConnection(drive: drive, bootstrap: bootstrap);
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.checkingConnection);
    // Access tokens remain memory-only, but GIS can silently mint a new token
    // from the browser's already-approved Google session. This keeps a PWA
    // restart connected without persisting secrets or showing login UI.
    final authorization =
        _oauth.currentAuthorization ?? await _oauth.restoreAuthorization();
    if (authorization == null) return null;
    final drive = _driveClient();
    onStage?.call(GoogleConnectionStage.preparingDrive);
    try {
      final bootstrap = await _restoreBootstrapFromDrive(
        drive,
        appDataScopeGranted: true,
      );
      if (bootstrap == null) return null;
      return _activateConnection(drive: drive, bootstrap: bootstrap);
    } on DriveRequestException catch (error) {
      if (error.reconnectRequired) return null;
      rethrow;
    } on DriveDataIntegrityException {
      return null;
    }
  }

  @override
  Future<GoogleConnectionResult> reselectDriveFolder({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.signIn);
    final authorization = await _oauth.authorize();
    onStage?.call(GoogleConnectionStage.folderSelection);
    final selectedFolderId = config.googlePickerApiKey.isEmpty
        ? 'root'
        : await _oauth.pickDriveFolder(
            accessToken: authorization.accessToken,
            apiKey: config.googlePickerApiKey,
          );
    if (selectedFolderId == null) {
      throw StateError('Google Drive folder selection was cancelled.');
    }
    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient();
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    _pendingFolderReselection = _PendingDriveFolderReselection(
      previousDrive: _drive,
      previousBootstrap: _bootstrap,
      candidateBootstrap: bootstrap,
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
  Future<void> commitDriveFolderReselection() async {
    final pending = _pendingFolderReselection;
    if (pending == null) throw StateError('No Drive folder change is pending.');
    pending.bindingCommitAttempted = true;
    await _requireDrive().upsertAppDataBinding(
      folderId: pending.candidateBootstrap.appRootFolderId,
      folderName: pending.candidateBootstrap.appRootFolderName,
    );
    _pendingFolderReselection = null;
  }

  @override
  Future<void> rollbackDriveFolderReselection() async {
    final pending = _pendingFolderReselection;
    if (pending == null) return;
    final bindingDrive = _drive;
    try {
      final previous = pending.previousBootstrap;
      if (pending.bindingCommitAttempted && bindingDrive != null) {
        if (previous == null) {
          await bindingDrive.deleteAppDataBinding();
        } else {
          await bindingDrive.upsertAppDataBinding(
            folderId: previous.appRootFolderId,
            folderName: previous.appRootFolderName,
          );
        }
      }
    } finally {
      _drive = pending.previousDrive;
      _bootstrap = pending.previousBootstrap;
      _pendingFolderReselection = null;
    }
  }

  GoogleDriveClient _driveClient() {
    return GoogleDriveClient(
      accessTokenProvider: () async {
        final current = _oauth.currentAuthorization;
        if (current != null) return current.accessToken;
        // Refresh from an already-approved Google browser session without an
        // account picker or consent screen. If that session is gone, fail once
        // and let the explicit reconnect action handle interactive OAuth.
        final restored = await _oauth.restoreAuthorization();
        if (restored != null) return restored.accessToken;
        throw const DriveRequestException(
          failure: DriveRequestFailure.authenticationExpired,
          statusCode: 401,
          operation: 'use cached web Drive authorization',
        );
      },
    );
  }

  GoogleConnectionResult _activateConnection({
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
    await _oauth.disconnect();
    _drive = null;
    _bootstrap = null;
    _pendingFolderReselection = null;
  }

  @override
  Future<void> deleteAccountBinding() async {
    await _oauth.authorize();
    await _driveClient().deleteAppDataBinding();
    await disconnect();
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() =>
      _requireDrive().readStateSnapshot(_requireBootstrap().appRootFolderId);

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) =>
      _requireDrive().writeStateSnapshot(
        appRootId: _requireBootstrap().appRootFolderId,
        snapshot: snapshot,
      );

  @override
  Future<DriveQuarantineRecord?> quarantineLastPulledSnapshot({
    required String reasonCode,
    required String preview,
  }) => _requireDrive().quarantineLastPulledSnapshot(
    appRootId: _requireBootstrap().appRootFolderId,
    reasonCode: reasonCode,
    preview: preview,
  );

  @override
  Future<DriveRetentionInventory> inspectDriveRetention() => _requireDrive()
      .inspectRetention(appRootId: _requireBootstrap().appRootFolderId);

  @override
  Future<DriveRetentionCleanupResult> trashDriveRetentionItems({
    required DriveRetentionInventory inventory,
    required Set<String> selectedFileIds,
  }) => _requireDrive().trashRetentionItems(
    appRootId: _requireBootstrap().appRootFolderId,
    inventory: inventory,
    selectedFileIds: selectedFileIds,
  );

  GoogleDriveClient _requireDrive() =>
      _drive ?? (throw StateError('Google Drive is not connected'));

  DriveBootstrapResult _requireBootstrap() =>
      _bootstrap ?? (throw StateError('Google Drive is not connected'));
}

/// Google Sign-In and Drive synchronization for iOS and macOS.
///
/// Apple platforms do not expose Google's native OnePick folder selector. A
/// first-time connection therefore creates the app-owned `Sprache`
/// folder in My Drive. If another Sprache device already wrote an app-data
/// binding, that exact folder is restored instead.
class AppleGoogleConnectionService
    implements
        GoogleConnectionService,
        RestorableGoogleConnectionService,
        RemoteSnapshotQuarantineService,
        RemoteStorageRetentionService,
        AccountBindingDeletionService {
  AppleGoogleConnectionService({required this.config});

  final AppConfig config;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  static const _driveScopes = [
    'https://www.googleapis.com/auth/drive.file',
    GoogleDriveClient.appDataOAuthScope,
  ];

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
    final existingAuthorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    final authorization =
        existingAuthorization ??
        await account.authorizationClient.authorizeScopes(_driveScopes);

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: authorization.accessToken,
    );
    var bootstrap = await _restoreBootstrapFromDrive(
      drive,
      appDataScopeGranted: true,
    );
    if (bootstrap == null) {
      bootstrap = await drive.ensureAppRoot('root');
      onStage?.call(GoogleConnectionStage.linkingAccount);
      await drive.upsertAppDataBinding(
        folderId: bootstrap.appRootFolderId,
        folderName: bootstrap.appRootFolderName,
      );
    }
    return _activateConnection(drive: drive, bootstrap: bootstrap);
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
    final authorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    if (authorization == null) return null;

    onStage?.call(GoogleConnectionStage.preparingDrive);
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: authorization.accessToken,
    );
    try {
      final bootstrap = await _restoreBootstrapFromDrive(
        drive,
        appDataScopeGranted: true,
      );
      if (bootstrap == null) return null;
      return _activateConnection(drive: drive, bootstrap: bootstrap);
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

  GoogleConnectionResult _activateConnection({
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
    await _signIn.signOut();
    _drive = null;
    _bootstrap = null;
  }

  @override
  Future<void> deleteAccountBinding() async {
    await _ensureInitialized();
    final attempt = _signIn.attemptLightweightAuthentication();
    final account =
        (attempt == null ? null : await attempt) ??
        await _signIn.authenticate();
    final authorization = await account.authorizationClient.authorizeScopes(
      _driveScopes,
    );
    final drive = _driveClient(
      account: account,
      fallbackAccessToken: authorization.accessToken,
    );
    await drive.deleteAppDataBinding();
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
    await _signIn.initialize(clientId: config.googleAppleClientId);
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
  if (kIsWeb) {
    if (!config.hasWebGoogleCredentials) {
      return const UnavailableGoogleConnectionService(
        'GOOGLE_WEB_CLIENT_ID is not configured',
      );
    }
    return GoogleWebConnectionService(config: config);
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
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    if (!config.hasAppleGoogleCredentials) {
      return const UnavailableGoogleConnectionService(
        'GOOGLE_APPLE_CLIENT_ID is not configured',
      );
    }
    return AppleGoogleConnectionService(config: config);
  }
  return const UnavailableGoogleConnectionService(
    'Google connection is not supported on this platform',
  );
}
