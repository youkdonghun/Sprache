import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/config/app_config.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/integrations/google/oauth_tokens.dart';
import 'package:sprache/src/services/study_notification_service.dart';

void main() {
  test('iOS Google connection stays unavailable without iOS credentials', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final service = createGoogleConnectionService(
        config: const AppConfig(
          googleAndroidClientId: 'android-client-id',
          googleDesktopClientId: 'desktop-client-id',
          googleServerClientId: 'server-client-id',
          appEnvironment: 'test',
          mockMode: false,
        ),
        tokenVault: MemoryTokenVault(),
      );

      expect(service, isA<UnavailableGoogleConnectionService>());
      expect(
        () => service.connect(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Google connection is not supported on this platform',
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('iOS study notifications stay explicitly unavailable', () async {
    final service = FlutterStudyNotificationService(
      platform: TargetPlatform.iOS,
    );

    expect(
      await service.requestPermission(),
      StudyNotificationPermission.unavailable,
    );
  });
}
