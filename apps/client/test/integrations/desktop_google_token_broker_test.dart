import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/integrations/google/desktop_google_token_broker.dart';

void main() {
  group('DirectDesktopGoogleTokenBroker', () {
    test('is ready locally when the desktop client ID exists', () async {
      var requests = 0;
      final broker = DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client.apps.googleusercontent.com',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );

      await broker.ensureReady();

      expect(requests, 0, reason: 'Direct OAuth needs no server preflight.');
    });

    test(
      'exchanges authorization code with PKCE as a public desktop client',
      () async {
        final broker = DirectDesktopGoogleTokenBroker(
          clientId: 'desktop-client.apps.googleusercontent.com',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'https://oauth2.googleapis.com/token',
            );
            expect(
              request.headers['content-type'],
              'application/x-www-form-urlencoded',
            );
            expect(request.bodyFields, {
              'client_id': 'desktop-client.apps.googleusercontent.com',
              'code': 'one-time-authorization-code',
              'code_verifier': 'pkce-verifier',
              'redirect_uri': 'http://127.0.0.1:43123',
              'grant_type': 'authorization_code',
            });
            return http.Response(
              jsonEncode({
                'access_token': 'google-access-token',
                'expires_in': 3600,
                'refresh_token': 'google-refresh-token',
                'id_token': 'google-id-token',
                'token_type': 'Bearer',
              }),
              200,
            );
          }),
        );

        final response = await broker.exchangeAuthorizationCode(
          authorizationCode: 'one-time-authorization-code',
          codeVerifier: 'pkce-verifier',
          redirectUri: 'http://127.0.0.1:43123',
        );

        expect(response.accessToken, 'google-access-token');
        expect(response.refreshToken, 'google-refresh-token');
        expect(response.idToken, 'google-id-token');
        expect(response.expiresIn, 3600);
      },
    );

    test('refreshes using the public desktop client ID', () async {
      final broker = DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client.apps.googleusercontent.com',
        httpClient: MockClient((request) async {
          expect(request.bodyFields, {
            'client_id': 'desktop-client.apps.googleusercontent.com',
            'refresh_token': 'stored-refresh-token',
            'grant_type': 'refresh_token',
          });
          expect(request.body, isNot(contains('code_verifier')));
          return http.Response(
            jsonEncode({
              'access_token': 'refreshed-access-token',
              'expires_in': '1800',
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
      );

      final response = await broker.refresh(
        refreshToken: 'stored-refresh-token',
      );

      expect(response.accessToken, 'refreshed-access-token');
      expect(response.expiresIn, 1800);
      expect(response.refreshToken, isNull);
    });

    test('maps Google JSON errors and redacts echoed credentials', () async {
      final broker = DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client.apps.googleusercontent.com',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'invalid_grant',
              'error_description':
                  'Refresh token stored-refresh-token was rejected.',
            }),
            400,
          ),
        ),
      );

      await expectLater(
        broker.refresh(refreshToken: 'stored-refresh-token'),
        throwsA(
          isA<GoogleOAuthException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.code, 'code', 'invalid_grant')
              .having(
                (error) => error.description,
                'description',
                'Refresh token [REDACTED] was rejected.',
              )
              .having(
                (error) => error.toString(),
                'safe diagnostics',
                isNot(contains('stored-refresh-token')),
              ),
        ),
      );
    });

    test(
      'rejects malformed successful responses without exposing body',
      () async {
        const secretBody = 'not-json-with-google-access-token';
        final broker = DirectDesktopGoogleTokenBroker(
          clientId: 'desktop-client.apps.googleusercontent.com',
          httpClient: MockClient((_) async => http.Response(secretBody, 200)),
        );

        await expectLater(
          broker.refresh(refreshToken: 'stored-refresh-token'),
          throwsA(
            isA<GoogleOAuthException>()
                .having(
                  (error) => error.code,
                  'code',
                  'google_oauth_invalid_response',
                )
                .having(
                  (error) => error.toString(),
                  'safe diagnostics',
                  isNot(contains(secretBody)),
                ),
          ),
        );
      },
    );

    test('maps bounded request timeouts to a retryable OAuth error', () async {
      final pending = Completer<http.Response>();
      final broker = DirectDesktopGoogleTokenBroker(
        clientId: 'desktop-client.apps.googleusercontent.com',
        requestTimeout: const Duration(milliseconds: 5),
        httpClient: MockClient((_) => pending.future),
      );

      await expectLater(
        broker.refresh(refreshToken: 'stored-refresh-token'),
        throwsA(
          isA<GoogleOAuthException>()
              .having((error) => error.statusCode, 'statusCode', 504)
              .having((error) => error.code, 'code', 'google_oauth_timeout'),
        ),
      );
    });

    test('fails before HTTP when the desktop client ID is missing', () async {
      var requests = 0;
      final broker = DirectDesktopGoogleTokenBroker(
        clientId: '   ',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        broker.ensureReady(),
        throwsA(
          isA<GoogleOAuthException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.code,
                'code',
                'google_client_id_missing',
              ),
        ),
      );
      expect(requests, 0);
    });

    test(
      'is ready without a desktop client secret',
      () async {
        var requests = 0;
        final broker = DirectDesktopGoogleTokenBroker(
          clientId: 'desktop-client.apps.googleusercontent.com',
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        );

        await broker.ensureReady();
        expect(requests, 0);
      },
    );
  });
}
