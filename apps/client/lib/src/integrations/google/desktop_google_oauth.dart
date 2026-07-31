import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import 'desktop_google_token_broker.dart';
import 'oauth_tokens.dart';

export 'desktop_google_token_broker.dart' show GoogleOAuthException;

class OAuthAuthorizationResult {
  const OAuthAuthorizationResult({required this.tokens, this.pickedFolderId});

  final OAuthTokens tokens;
  final String? pickedFolderId;
}

class DesktopGoogleOAuth {
  DesktopGoogleOAuth({
    required this.clientId,
    required this.tokenVault,
    required this.tokenBroker,
    Future<bool> Function(Uri authorizationUri)? urlLauncher,
  }) : _urlLauncher = urlLauncher ?? _launchExternalUrl;

  final String clientId;
  final TokenVault tokenVault;
  final DesktopGoogleTokenBroker tokenBroker;
  final Future<bool> Function(Uri authorizationUri) _urlLauncher;

  static const _authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const authorizationTimeout = Duration(minutes: 10);

  static String loopbackRedirectUri(int port) => 'http://127.0.0.1:$port';

  Future<void> ensureReady() => tokenBroker.ensureReady();

  Future<bool> hasStoredSession() async {
    final tokens = await Future.wait([
      tokenVault.read(GoogleTokenKind.identity),
      tokenVault.read(GoogleTokenKind.drive),
    ]);
    return tokens.every((token) => token != null);
  }

  Future<OAuthAuthorizationResult> signIn() {
    return _authorize(
      kind: GoogleTokenKind.identity,
      scopes: const ['openid', 'email', 'profile'],
      usePicker: false,
    );
  }

  Future<OAuthAuthorizationResult> selectDriveFolder() {
    return _authorize(
      kind: GoogleTokenKind.drive,
      scopes: const ['https://www.googleapis.com/auth/drive.file'],
      usePicker: true,
    );
  }

  Future<String> accessToken(GoogleTokenKind kind) async {
    final stored = await tokenVault.read(kind);
    if (stored == null) {
      throw StateError('Google ${kind.name} authorization is required');
    }
    if (stored.isAccessTokenUsable) {
      return stored.accessToken;
    }
    final refreshToken = stored.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Google ${kind.name} authorization expired');
    }

    final response = await tokenBroker.refresh(refreshToken: refreshToken);
    final refreshed = OAuthTokens(
      accessToken: response.accessToken,
      refreshToken: refreshToken,
      idToken: response.idToken ?? stored.idToken,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: response.expiresIn),
      ),
    );
    await tokenVault.write(kind, refreshed);
    return refreshed.accessToken;
  }

  Future<String> identityToken() async {
    final stored = await tokenVault.read(GoogleTokenKind.identity);
    if (stored == null) {
      throw StateError('Google sign-in is required');
    }
    if (!stored.isAccessTokenUsable) {
      await accessToken(GoogleTokenKind.identity);
    }
    final refreshed = await tokenVault.read(GoogleTokenKind.identity);
    final idToken = refreshed?.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not return an ID token');
    }
    return idToken;
  }

  Future<void> disconnect() => tokenVault.clear();

  Future<OAuthAuthorizationResult> _authorize({
    required GoogleTokenKind kind,
    required List<String> scopes,
    required bool usePicker,
  }) async {
    if (clientId.isEmpty) {
      throw StateError('GOOGLE_DESKTOP_CLIENT_ID is not configured');
    }

    final callbackServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final redirectUri = loopbackRedirectUri(callbackServer.port);
    final verifier = _randomUrlSafe(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomUrlSafe(32);
    final parameters = <String, String>{
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scopes.join(' '),
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
    };
    if (usePicker) {
      parameters.addAll({
        'trigger_onepick': 'true',
        'allow_folder_selection': 'true',
        'mimetypes': 'application/vnd.google-apps.folder',
      });
    }
    final authorizationUri = Uri.parse(
      _authorizationEndpoint,
    ).replace(queryParameters: parameters);

    final launched = await _urlLauncher(authorizationUri);
    if (!launched) {
      await callbackServer.close(force: true);
      throw StateError('Could not open the system browser');
    }

    try {
      final request = await callbackServer.first.timeout(authorizationTimeout);
      final query = request.uri.queryParameters;
      final isValidState = query['state'] == state;
      final error = query['error'];
      final code = query['code'];
      final isSuccess = isValidState && error == null && code != null;
      final successHeading = usePicker
          ? 'Drive 폴더 선택이 완료되었습니다.'
          : 'Google 계정 확인을 마쳤습니다.';
      final successBody = usePicker
          ? '이 창을 닫고 Sprache로 돌아가세요.'
          : '이 창을 닫아 주세요. 잠시 후 Drive 폴더 선택 화면이 한 번 더 열립니다.';

      request.response
        ..statusCode = isSuccess ? 200 : 400
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><meta charset="utf-8">'
          '<title>Sprache</title>'
          '<body style="font-family:sans-serif;padding:40px">'
          '<h2>${isSuccess ? successHeading : '연결을 완료하지 못했습니다.'}</h2>'
          '<p>${isSuccess ? successBody : '이 창을 닫고 Sprache의 진단 안내를 확인하세요.'}</p></body>',
        );
      await request.response.close();

      if (!isValidState) {
        throw StateError('OAuth state validation failed');
      }
      if (error != null) {
        throw StateError('Google authorization failed: $error');
      }
      if (code == null || code.isEmpty) {
        throw StateError('Google authorization code is missing');
      }

      final tokenResponse = await tokenBroker.exchangeAuthorizationCode(
        authorizationCode: code,
        codeVerifier: verifier,
        redirectUri: redirectUri,
      );
      final previous = await tokenVault.read(kind);
      final tokens = OAuthTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken ?? previous?.refreshToken,
        idToken: tokenResponse.idToken,
        expiresAt: DateTime.now().toUtc().add(
          Duration(seconds: tokenResponse.expiresIn),
        ),
      );
      await tokenVault.write(kind, tokens);
      final pickedIds = query['picked_file_ids'];
      final pickedFolderId = pickedIds?.split(',').first.trim();
      return OAuthAuthorizationResult(
        tokens: tokens,
        pickedFolderId: pickedFolderId?.isEmpty ?? true ? null : pickedFolderId,
      );
    } finally {
      await callbackServer.close(force: true);
    }
  }

  String _randomUrlSafe(int bytes) {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(bytes, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  static Future<bool> _launchExternalUrl(Uri authorizationUri) {
    return launchUrl(authorizationUri, mode: LaunchMode.externalApplication);
  }
}
