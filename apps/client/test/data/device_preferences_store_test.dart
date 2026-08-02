import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/device_preferences.dart';

void main() {
  test(
    'memory store keeps device preferences outside study preferences',
    () async {
      final store = MemoryStudyStore();
      const preferences = DevicePreferences(
        notifications: DeviceNotificationPreferences(enabled: false),
        privacy: DevicePrivacyPreferences(privacyMode: true),
        voice: DeviceVoicePreferences(pitch: 1.4),
      );

      await store.saveDevicePreferences(preferences);

      expect(
        (await store.loadDevicePreferences()).toJson(),
        preferences.toJson(),
      );
      expect(store.savedPreferences.toJson(), isNot(contains('privacyMode')));
    },
  );

  test(
    'Drift round-trips device-only settings under an isolated key',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = DriftStudyStore(database);
      const preferences = DevicePreferences(
        notifications: DeviceNotificationPreferences(
          quietStartMinutes: 21 * 60,
          quietEndMinutes: 8 * 60,
          lockScreenContent: NotificationLockScreenContent.hidden,
        ),
        privacy: DevicePrivacyPreferences(
          privacyMode: true,
          curtainDelay: PrivacyCurtainDelay.seconds60,
        ),
      );
      try {
        await store.saveDevicePreferences(preferences);

        final restored = await store.loadDevicePreferences();
        final rows = await database.select(database.appSettings).get();

        expect(restored.toJson(), preferences.toJson());
        expect(rows.map((row) => row.key), contains('device_preferences'));
        expect(
          rows.map((row) => row.key),
          isNot(contains('study_preferences')),
        );
      } finally {
        await database.close();
      }
    },
  );
}
