import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/config/app_config.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/integrations/google/oauth_tokens.dart';
import 'package:sprache/src/services/study_notification_service.dart';

void main() {
  test('Apple platforms create the real Google connection service', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final service = createGoogleConnectionService(
          config: const AppConfig(
            googleAndroidClientId: 'android-client-id',
            googleDesktopClientId: 'desktop-client-id',
            googleDesktopClientSecret: 'desktop-client-secret',
            googleAppleClientId: 'apple-client-id',
            googleServerClientId: 'server-client-id',
            appEnvironment: 'test',
            mockMode: false,
          ),
          tokenVault: MemoryTokenVault(),
        );

        expect(
          service,
          isA<AppleGoogleConnectionService>(),
          reason: '$platform must not silently fall back to local-only mode.',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });

  test('iOS Google connection is unavailable without an Apple client ID', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final service = createGoogleConnectionService(
        config: const AppConfig(
          googleAndroidClientId: 'android-client-id',
          googleDesktopClientId: 'desktop-client-id',
          googleDesktopClientSecret: 'desktop-client-secret',
          googleAppleClientId: '',
          googleServerClientId: 'server-client-id',
          appEnvironment: 'test',
          mockMode: false,
        ),
        tokenVault: MemoryTokenVault(),
      );

      expect(service, isA<UnavailableGoogleConnectionService>());
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
