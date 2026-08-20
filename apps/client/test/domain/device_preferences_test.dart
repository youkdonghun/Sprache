import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/device_preferences.dart';

void main() {
  test('device-only settings round-trip and enforce bounds', () {
    final restored = DevicePreferences.fromJson({
      'notifications': {
        'enabled': false,
        'quietStartMinutes': -1,
        'quietEndMinutes': 2000,
        'lockScreenContent': 'detailed',
      },
      'privacy': {'privacyMode': true, 'curtainDelay': 'seconds60'},
      'voice': {
        'pitch': 9,
        'voiceIdByLanguage': {
          'en': 'voice-1',
          '': 'bad',
          for (var index = 0; index < 30; index++) 'x$index': 'voice-$index',
        },
        'soundStrength': 'light',
        'hapticStrength': 'strong',
      },
    });

    expect(restored.notifications.enabled, isFalse);
    expect(restored.notifications.quietStartMinutes, 0);
    expect(restored.notifications.quietEndMinutes, 1439);
    expect(restored.privacy.privacyMode, isTrue);
    expect(restored.privacy.toJson(), isNot(contains('curtainDelay')));
    expect(restored.voice.pitch, maximumNaturalVoicePitch);
    expect(restored.voice.voiceIdByLanguage.length, lessThanOrEqualTo(20));
    expect(restored.voice.soundStrength, DeviceFeedbackStrength.light);
    expect(
      DevicePreferences.fromJson(restored.toJson()).toJson(),
      restored.toJson(),
    );
  });

  test('overnight quiet time and lock-screen redaction are predictable', () {
    const preferences = DeviceNotificationPreferences(
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 7 * 60,
      lockScreenContent: NotificationLockScreenContent.hidden,
    );
    expect(preferences.isQuietAt(DateTime(2026, 8, 2, 23)), isTrue);
    expect(preferences.isQuietAt(DateTime(2026, 8, 2, 6, 59)), isTrue);
    expect(preferences.isQuietAt(DateTime(2026, 8, 2, 12)), isFalse);
    expect(
      preferences.nextAllowedAt(DateTime(2026, 8, 2, 23)),
      DateTime(2026, 8, 3, 7),
    );
    final visible = preferences.visibleNotification(
      title: '비밀 세션',
      body: 'private word',
    );
    expect(visible.title, 'Sprache');
    expect(visible.body, isNot(contains('private')));
  });

  test('malformed optional fields recover without throwing', () {
    final restored = DevicePreferences.fromJson({
      'notifications': {'enabled': 'yes', 'lockScreenContent': 3},
      'privacy': {'curtainDelay': 'unknown'},
      'voice': {'pitch': 'high', 'voiceIdByLanguage': []},
    });
    expect(restored.notifications.enabled, isTrue);
    expect(
      restored.notifications.lockScreenContent,
      NotificationLockScreenContent.generic,
    );
    expect(restored.privacy.privacyMode, isFalse);
    expect(restored.voice.pitch, 1);
  });

  test('legacy curtain delay is ignored without changing privacy mode', () {
    final restored = DevicePreferences.fromJson({
      'privacy': {'privacyMode': true, 'curtainDelay': 'immediate'},
    });

    expect(restored.privacy.privacyMode, isTrue);
    expect(restored.privacy.toJson(), {'privacyMode': true});
    expect(restored.toJson().toString(), isNot(contains('curtainDelay')));
  });

  test('voice selection and feedback strengths stay device scoped', () {
    final selected = const DeviceVoicePreferences()
        .selectVoice('en', 'en-us::Local Voice')
        .copyWith(
          pitch: 1.35,
          soundStrength: DeviceFeedbackStrength.strong,
          hapticStrength: DeviceFeedbackStrength.off,
        );
    final cleared = selected.selectVoice('en', null);

    expect(selected.voiceIdByLanguage['en'], 'en-us::Local Voice');
    expect(selected.pitch, maximumNaturalVoicePitch);
    expect(selected.soundStrength, DeviceFeedbackStrength.strong);
    expect(selected.hapticStrength, DeviceFeedbackStrength.off);
    expect(cleared.voiceIdByLanguage, isNot(contains('en')));
  });
}
