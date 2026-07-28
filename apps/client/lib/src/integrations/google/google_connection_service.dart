import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';
import 'desktop_google_oauth.dart';
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

abstract interface class GoogleConnectionService {
  Future<GoogleConnectionResult> connect();

  Future<Map<String, Object?>?> pullSnapshot();

  Future<void> pushSnapshot(Map<String, Object?> snapshot);

  Future<void> disconnect();
}

class MockGoogleConnectionService implements GoogleConnectionService {
  Map<String, Object?>? _snapshot;

  @override
  Future<GoogleConnectionResult> connect() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const GoogleConnectionResult(
      folderId: 'mock_word_study_data',
      folderName: 'WordStudyData (Mock)',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => _snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    _snapshot = snapshot;
  }
}

class UnavailableGoogleConnectionService implements GoogleConnectionService {
  const UnavailableGoogleConnectionService(this.message);

  final String message;

  @override
  Future<GoogleConnectionResult> connect() {
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

class DesktopGoogleConnectionService implements GoogleConnectionService {
  DesktopGoogleConnectionService({
    required AppConfig config,
    required TokenVault tokenVault,
  }) : _oauth = DesktopGoogleOAuth(
         clientId: config.googleDesktopClientId,
         tokenVault: tokenVault,
       ),
       _api = SpracheApiClient(baseUrl: config.apiBaseUrl);

  final DesktopGoogleOAuth _oauth;
  final SpracheApiClient _api;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;

  @override
  Future<GoogleConnectionResult> connect() async {
    final identity = await _oauth.signIn();
    final idToken = identity.tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not provide an ID token');
    }
    final driveAuthorization = await _oauth.selectDriveFolder();
    final selectedFolderId = driveAuthorization.pickedFolderId;
    if (selectedFolderId == null) {
      throw StateError('Google Picker did not return a folder ID');
    }
    final drive = GoogleDriveClient(
      accessTokenProvider: () => _oauth.accessToken(GoogleTokenKind.drive),
    );
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
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
  Future<void> disconnect() async {
    try {
      final idToken = await _oauth.identityToken();
      await _api.deleteDriveRoot(idToken: idToken);
    } finally {
      await _oauth.disconnect();
      _drive = null;
      _bootstrap = null;
    }
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

  GoogleDriveClient _requireDrive() {
    return _drive ?? (throw StateError('Google Drive is not connected'));
  }

  DriveBootstrapResult _requireBootstrap() {
    return _bootstrap ?? (throw StateError('Google Drive is not connected'));
  }
}

class AndroidGoogleConnectionService implements GoogleConnectionService {
  AndroidGoogleConnectionService({required AppConfig config})
    : _config = config,
      _api = SpracheApiClient(baseUrl: config.apiBaseUrl);

  static const _channel = MethodChannel('com.youkdonghun.sprache/google');
  final AppConfig _config;
  final SpracheApiClient _api;
  final GoogleSignIn _signIn = GoogleSignIn.instance;

  bool _initialized = false;
  String? _lastIdToken;
  GoogleDriveClient? _drive;
  DriveBootstrapResult? _bootstrap;

  @override
  Future<GoogleConnectionResult> connect() async {
    await _ensureInitialized();
    final account = await _signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not provide an ID token');
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

    final drive = GoogleDriveClient(
      accessTokenProvider: () async {
        final refreshed = await account.authorizationClient
            .authorizationForScopes(const [
              'https://www.googleapis.com/auth/drive.file',
            ]);
        return refreshed?.accessToken ?? accessToken;
      },
    );
    final bootstrap = await drive.ensureAppRoot(selectedFolderId);
    await _api.storeDriveRoot(
      idToken: idToken,
      folderId: bootstrap.appRootFolderId,
      folderName: bootstrap.appRootFolderName,
    );
    _lastIdToken = idToken;
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
    try {
      final idToken = _lastIdToken;
      if (idToken != null) {
        await _api.deleteDriveRoot(idToken: idToken);
      }
    } finally {
      await _signIn.signOut();
      _lastIdToken = null;
      _drive = null;
      _bootstrap = null;
    }
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
