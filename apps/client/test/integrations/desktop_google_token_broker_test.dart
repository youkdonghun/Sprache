import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/integrations/google/desktop_google_token_broker.dart';

void main() {
  test(
    'Railway broker confirms server readiness before browser login',
    () async {
      final broker = RailwayDesktopGoogleTokenBroker(
        apiBaseUrl: 'https://sprache-api.example',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://sprache-api.example/health');
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'service': 'sprache-api',
              'desktopOAuthBroker': 'ready',
            }),
            200,
          );
        }),
      );

      await broker.ensureReady();
    },
  );

  test(
    'Railway broker refreshes without exposing a desktop client secret',
    () async {
      final broker = RailwayDesktopGoogleTokenBroker(
        apiBaseUrl: 'https://sprache-api.example/',
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://sprache-api.example/v1/oauth/google/desktop/token',
          );
          final payload = jsonDecode(request.body) as Map<String, Object?>;
          expect(payload, {
            'grantType': 'refresh_token',
            'refreshToken': 'stored-refresh-token',
          });
          expect(request.body, isNot(contains('clientSecret')));
          return http.Response(
            jsonEncode({'accessToken': 'fresh-access', 'expiresIn': 1800}),
            200,
          );
        }),
      );

      final token = await broker.refresh(refreshToken: 'stored-refresh-token');

      expect(token.accessToken, 'fresh-access');
      expect(token.expiresIn, 1800);
      expect(token.refreshToken, isNull);
    },
  );

  test('Railway broker preserves actionable, bounded API errors', () async {
    final broker = RailwayDesktopGoogleTokenBroker(
      apiBaseUrl: 'https://sprache-api.example',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'oauth_broker_not_configured',
            'message': 'Desktop Google OAuth is not configured on Railway',
          }),
          503,
        ),
      ),
    );

    await expectLater(
      broker.refresh(refreshToken: 'stored-refresh-token'),
      throwsA(
        isA<GoogleOAuthException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.code,
              'code',
              'oauth_broker_not_configured',
            ),
      ),
    );
  });

  test('Railway broker turns network failures into a retryable code', () async {
    final broker = RailwayDesktopGoogleTokenBroker(
      apiBaseUrl: 'https://sprache-api.example',
      httpClient: MockClient((_) async {
        throw http.ClientException('offline');
      }),
    );

    await expectLater(
      broker.ensureReady(),
      throwsA(
        isA<GoogleOAuthException>().having(
          (error) => error.code,
          'code',
          'oauth_broker_unreachable',
        ),
      ),
    );
  });
}
