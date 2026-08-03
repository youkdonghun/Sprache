import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/device_preferences.dart';
import 'package:sprache/src/services/app_feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'haptic and sound channels follow the latest settings independently',
    () async {
      var preferences = const AppExperiencePreferences();
      final haptics = <AppFeedbackCue>[];
      final sounds = <AppFeedbackCue>[];
      final service = AppFeedbackService(
        readPreferences: () => preferences,
        emitHaptic: (cue) async => haptics.add(cue),
        emitSound: (cue) async => sounds.add(cue),
      );

      await service.success();
      preferences = preferences.copyWith(hapticsEnabled: true);
      await service.success();
      preferences = preferences.copyWith(
        hapticsEnabled: false,
        soundEffectsEnabled: true,
      );
      await service.error();
      preferences = preferences.copyWith(hapticsEnabled: true);
      await service.selection();

      expect(haptics, [AppFeedbackCue.success, AppFeedbackCue.selection]);
      expect(sounds, [AppFeedbackCue.error, AppFeedbackCue.selection]);
    },
  );

  test(
    'success, error, and selection use their system feedback mappings',
    () async {
      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            platformCalls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final service = AppFeedbackService(
        readPreferences: () => const AppExperiencePreferences(
          hapticsEnabled: true,
          soundEffectsEnabled: true,
        ),
      );

      await service.success();
      await service.error();
      await service.selection();

      expect(
        platformCalls.map((call) => (call.method, call.arguments)),
        unorderedEquals([
          ('HapticFeedback.vibrate', 'HapticFeedbackType.mediumImpact'),
          ('SystemSound.play', 'SystemSoundType.click'),
          ('HapticFeedback.vibrate', 'HapticFeedbackType.heavyImpact'),
          ('SystemSound.play', 'SystemSoundType.alert'),
          ('HapticFeedback.vibrate', 'HapticFeedbackType.selectionClick'),
          ('SystemSound.play', 'SystemSoundType.click'),
        ]),
      );
    },
  );

  test('a failed feedback channel never interrupts the interaction', () async {
    final sounds = <AppFeedbackCue>[];
    final service = AppFeedbackService(
      readPreferences: () => const AppExperiencePreferences(
        hapticsEnabled: true,
        soundEffectsEnabled: true,
      ),
      emitHaptic: (_) => Future<void>.error(StateError('not available')),
      emitSound: (cue) async => sounds.add(cue),
    );

    await expectLater(service.error(), completes);
    expect(sounds, [AppFeedbackCue.error]);
  });

  test(
    'device strengths independently disable and scale feedback channels',
    () async {
      var device = const DeviceVoicePreferences(
        soundStrength: DeviceFeedbackStrength.off,
        hapticStrength: DeviceFeedbackStrength.light,
      );
      final haptics = <(AppFeedbackCue, DeviceFeedbackStrength)>[];
      final sounds = <(AppFeedbackCue, DeviceFeedbackStrength)>[];
      final service = AppFeedbackService(
        readPreferences: () => const AppExperiencePreferences(
          hapticsEnabled: true,
          soundEffectsEnabled: true,
        ),
        readDevicePreferences: () => device,
        emitHapticWithStrength: (cue, strength) async =>
            haptics.add((cue, strength)),
        emitSoundWithStrength: (cue, strength) async =>
            sounds.add((cue, strength)),
      );

      await service.success();
      device = device.copyWith(
        soundStrength: DeviceFeedbackStrength.strong,
        hapticStrength: DeviceFeedbackStrength.off,
      );
      await service.error();

      expect(haptics, [(AppFeedbackCue.success, DeviceFeedbackStrength.light)]);
      expect(sounds, [(AppFeedbackCue.error, DeviceFeedbackStrength.strong)]);
    },
  );
}
