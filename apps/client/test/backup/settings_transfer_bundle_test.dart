import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/settings_transfer_bundle.dart';
import 'package:sprache/src/domain/device_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  const codec = SettingsTransferCodec();

  test('round-trips app and device settings without learning content', () {
    final bundle = SettingsTransferBundle(
      appPreferences: const StudyPreferences(
        dailyGoal: 123,
        sessionItemLimit: 20,
        showReadingAids: false,
      ),
      devicePreferences: const DevicePreferences(
        notifications: DeviceNotificationPreferences(
          enabled: false,
          lockScreenContent: NotificationLockScreenContent.hidden,
        ),
        privacy: DevicePrivacyPreferences(privacyMode: true),
      ),
      exportedAt: DateTime.utc(2026, 8, 2, 12),
    );

    final source = codec.encode(bundle);
    final restored = codec.decode(source);
    final raw = jsonDecode(source) as Map<String, Object?>;

    expect(raw.keys, <String>{
      'format',
      'exportedAt',
      'appPreferences',
      'devicePreferences',
    });
    expect(source, isNot(contains('customItems')));
    expect(source, isNot(contains('recentSessions')));
    expect(restored.appPreferences.dailyGoal, 123);
    expect(restored.appPreferences.sessionItemLimit, 20);
    expect(restored.appPreferences.showReadingAids, isFalse);
    expect(restored.devicePreferences.notifications.enabled, isFalse);
    expect(restored.devicePreferences.privacy.privacyMode, isTrue);
  });

  test('rejects backup-shaped or oversized files', () {
    expect(
      () => codec.decode(
        jsonEncode({
          'format': 'sprache-settings-v1',
          'exportedAt': DateTime.utc(2026).toIso8601String(),
          'appPreferences': const <String, Object?>{},
          'devicePreferences': const <String, Object?>{},
          'customItems': const <Object?>[],
        }),
      ),
      throwsA(isA<SettingsTransferException>()),
    );
    expect(
      () => codec.decode('x' * (SettingsTransferCodec.maxBytes + 1)),
      throwsA(isA<SettingsTransferException>()),
    );
  });
}
