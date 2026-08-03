import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/integrations/google/desktop_google_oauth.dart';
import 'package:sprache/src/integrations/google/desktop_google_token_broker.dart';
import 'package:sprache/src/integrations/google/oauth_tokens.dart';

void main() {
  test('desktop OAuth uses the Google-supported pathless loopback URI', () {
    expect(
      DesktopGoogleOAuth.loopbackRedirectUri(49152),
      'http://127.0.0.1:49152',
    );
    expect(
      DesktopGoogleOAuth.authorizationTimeout,
      const Duration(minutes: 10),
    );
  });

  test('OAuth failures retain Google error details', () {
    const error = GoogleOAuthException(
      operation: 'Google token exchange',
      statusCode: 400,
      code: 'invalid_grant',
      description: 'Bad Request',
    );

    expect(error.toString(), contains('invalid_grant'));
    expect(error.toString(), contains('Bad Request'));
  });

  test('desktop silent restore only requires a Drive token', () async {
    final vault = MemoryTokenVault();
    final oauth = DesktopGoogleOAuth(
      clientId: 'desktop-client-id',
      tokenVault: vault,
      tokenBroker: DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client-id',
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      ),
    );
    final tokens = OAuthTokens(
      accessToken: 'stored-access-token',
      refreshToken: 'stored-refresh-token',
      idToken: 'stored-id-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    expect(await oauth.hasStoredSession(), isFalse);
    await vault.write(GoogleTokenKind.identity, tokens);
    expect(await oauth.hasStoredSession(), isFalse);
    await vault.write(GoogleTokenKind.drive, tokens);
    expect(await oauth.hasStoredSession(), isTrue);
  });

  test(
    'desktop OAuth completes loopback callback, token exchange, and storage',
    () async {
      final vault = MemoryTokenVault();
      Uri? authorizationUri;
      Future<_LoopbackResponse>? callbackResponse;
      final tokenBroker = DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client-id',
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://oauth2.googleapis.com/token');
          expect(request, isA<http.Request>());
          final fields = request.bodyFields;
          expect(fields['grant_type'], 'authorization_code');
          expect(fields['client_id'], 'desktop-client-id');
          expect(fields['code'], 'test-authorization-code');
          expect(fields['code_verifier'], isNotEmpty);
          expect(
            fields['redirect_uri'],
            authorizationUri!.queryParameters['redirect_uri'],
          );
          return http.Response(
            jsonEncode({
              'access_token': 'test-access-token',
              'refresh_token': 'test-refresh-token',
              'id_token': 'test-id-token',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final oauth = DesktopGoogleOAuth(
        clientId: 'desktop-client-id',
        tokenVault: vault,
        tokenBroker: tokenBroker,
        urlLauncher: (uri) async {
          authorizationUri = uri;
          expect(uri.host, 'accounts.google.com');
          expect(uri.queryParameters['code_challenge_method'], 'S256');
          expect(uri.queryParameters['scope'], contains('drive.file'));
          expect(uri.queryParameters['scope'], contains('drive.appdata'));

          final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
          expect(redirectUri.host, '127.0.0.1');
          expect(redirectUri.path, isEmpty);
          expect(redirectUri.port, greaterThan(0));

          callbackResponse = Future<_LoopbackResponse>(() {
            return _sendLoopbackCallback(
              redirectUri.replace(
                queryParameters: {
                  'code': 'test-authorization-code',
                  'state': uri.queryParameters['state']!,
                },
              ),
            );
          });
          return true;
        },
      );

      final result = await oauth.authorizeDriveAccess();
      final browserResponse = await callbackResponse!;
      final stored = await vault.read(GoogleTokenKind.drive);

      expect(browserResponse.statusCode, 200);
      expect(browserResponse.body, contains('Drive 권한을 확인했습니다'));
      expect(browserResponse.body, contains('Sprache로 돌아가면 됩니다'));
      expect(result.tokens.accessToken, 'test-access-token');
      expect(result.tokens.refreshToken, 'test-refresh-token');
      expect(result.tokens.idToken, 'test-id-token');
      expect(stored?.accessToken, 'test-access-token');
    },
  );

  test(
    'desktop OAuth rejects a loopback callback with the wrong state',
    () async {
      Future<_LoopbackResponse>? callbackResponse;
      var tokenExchangeCalled = false;
      final tokenBroker = DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client-id',
        httpClient: MockClient((request) async {
          tokenExchangeCalled = true;
          return http.Response('{}', 500);
        }),
      );
      final oauth = DesktopGoogleOAuth(
        clientId: 'desktop-client-id',
        tokenVault: MemoryTokenVault(),
        tokenBroker: tokenBroker,
        urlLauncher: (uri) async {
          final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
          callbackResponse = Future<_LoopbackResponse>(() {
            return _sendLoopbackCallback(
              redirectUri.replace(
                queryParameters: {
                  'code': 'test-authorization-code',
                  'state': 'wrong-state',
                },
              ),
            );
          });
          return true;
        },
      );

      await expectLater(
        oauth.authorizeDriveAccess(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'OAuth state validation failed',
          ),
        ),
      );
      final browserResponse = await callbackResponse!;

      expect(browserResponse.statusCode, 400);
      expect(browserResponse.body, contains('Google 연결을 마치지 못했어요'));
      expect(tokenExchangeCalled, isFalse);
    },
  );
}

class _LoopbackResponse {
  const _LoopbackResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

Future<_LoopbackResponse> _sendLoopbackCallback(Uri uri) async {
  final socket = await Socket.connect(uri.host, uri.port);
  final requestTarget =
      '${uri.path.isEmpty ? '/' : uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
  socket.write(
    'GET $requestTarget HTTP/1.1\r\n'
    'Host: ${uri.host}:${uri.port}\r\n'
    'Connection: close\r\n'
    '\r\n',
  );
  await socket.flush();

  final responseBytes = <int>[];
  await for (final bytes in socket) {
    responseBytes.addAll(bytes);
  }
  final response = utf8.decode(responseBytes);
  final headerEnd = response.indexOf('\r\n\r\n');
  expect(headerEnd, greaterThanOrEqualTo(0));
  final headerLines = response.substring(0, headerEnd).split('\r\n');
  final statusCode = int.parse(headerLines.first.split(' ')[1]);

  return _LoopbackResponse(
    statusCode: statusCode,
    body: response.substring(headerEnd + 4),
  );
}
