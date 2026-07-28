import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'oauth_tokens.dart';

class OAuthAuthorizationResult {
  const OAuthAuthorizationResult({required this.tokens, this.pickedFolderId});

  final OAuthTokens tokens;
  final String? pickedFolderId;
}

class DesktopGoogleOAuth {
  DesktopGoogleOAuth({
    required this.clientId,
    required this.tokenVault,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String clientId;
  final TokenVault tokenVault;
  final http.Client _httpClient;

  static const _authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';

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

    final response = await _httpClient.post(
      Uri.parse(_tokenEndpoint),
      body: {
        'client_id': clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Google token refresh failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final refreshed = OAuthTokens(
      accessToken: body['access_token']! as String,
      refreshToken: refreshToken,
      idToken: body['id_token'] as String? ?? stored.idToken,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: body['expires_in']! as int),
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
    final redirectUri =
        'http://127.0.0.1:${callbackServer.port}/oauth2/callback';
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

    final launched = await launchUrl(
      authorizationUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await callbackServer.close(force: true);
      throw StateError('Could not open the system browser');
    }

    try {
      final request = await callbackServer.first.timeout(
        const Duration(minutes: 5),
      );
      final query = request.uri.queryParameters;
      final isValidState = query['state'] == state;
      final error = query['error'];
      final code = query['code'];

      request.response
        ..statusCode = isValidState && error == null && code != null ? 200 : 400
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><meta charset="utf-8">'
          '<title>Sprache</title>'
          '<body style="font-family:sans-serif;padding:40px">'
          '<h2>${error == null ? 'Sprache 연결이 완료되었습니다.' : '연결이 취소되었습니다.'}</h2>'
          '<p>이 창을 닫고 앱으로 돌아가세요.</p></body>',
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

      final tokenResponse = await _httpClient.post(
        Uri.parse(_tokenEndpoint),
        body: {
          'client_id': clientId,
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );
      if (tokenResponse.statusCode != 200) {
        throw StateError(
          'Google token exchange failed (${tokenResponse.statusCode})',
        );
      }
      final body = jsonDecode(tokenResponse.body) as Map<String, Object?>;
      final previous = await tokenVault.read(kind);
      final tokens = OAuthTokens(
        accessToken: body['access_token']! as String,
        refreshToken:
            body['refresh_token'] as String? ?? previous?.refreshToken,
        idToken: body['id_token'] as String?,
        expiresAt: DateTime.now().toUtc().add(
          Duration(seconds: body['expires_in']! as int),
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
}
