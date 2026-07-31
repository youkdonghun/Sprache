import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/config/app_config.dart';
import 'package:sprache/src/integrations/google/desktop_google_token_broker.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/integrations/google/oauth_tokens.dart';

void main() {
  test('Windows checks the Railway broker before opening Google', () async {
    var browserLaunched = false;
    final stages = <GoogleConnectionStage>[];
    final service = DesktopGoogleConnectionService(
      config: const AppConfig(
        apiBaseUrl: 'https://sprache-api.example',
        googleAndroidClientId: '',
        googleDesktopClientId: 'desktop-client-id',
        googleServerClientId: '',
        appEnvironment: 'test',
        mockMode: false,
      ),
      tokenVault: MemoryTokenVault(),
      tokenBroker: _UnavailableBroker(),
      urlLauncher: (_) async {
        browserLaunched = true;
        return true;
      },
    );

    await expectLater(
      service.connect(onStage: stages.add),
      throwsA(
        isA<GoogleOAuthException>().having(
          (error) => error.code,
          'code',
          'oauth_broker_not_configured',
        ),
      ),
    );

    expect(stages, [GoogleConnectionStage.checkingConnection]);
    expect(browserLaunched, isFalse);
  });
}

class _UnavailableBroker implements DesktopGoogleTokenBroker {
  @override
  Future<void> ensureReady() {
    throw const GoogleOAuthException(
      operation: 'Railway Google OAuth preflight',
      statusCode: 503,
      code: 'oauth_broker_not_configured',
    );
  }

  @override
  Future<DesktopGoogleTokenResponse> exchangeAuthorizationCode({
    required String authorizationCode,
    required String codeVerifier,
    required String redirectUri,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<DesktopGoogleTokenResponse> refresh({required String refreshToken}) {
    throw UnimplementedError();
  }
}
