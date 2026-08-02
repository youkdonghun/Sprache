import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/app_experience_preferences.dart';
import '../domain/device_preferences.dart';

enum AppFeedbackCue { success, error, selection }

typedef AppExperiencePreferencesReader = AppExperiencePreferences Function();
typedef AppFeedbackEmitter = Future<void> Function(AppFeedbackCue cue);
typedef DeviceVoicePreferencesReader = DeviceVoicePreferences Function();
typedef AppFeedbackStrengthEmitter =
    Future<void> Function(AppFeedbackCue cue, DeviceFeedbackStrength strength);

/// Delivers optional, best-effort interaction feedback.
///
/// Preferences are read for every cue so a long-lived service immediately
/// follows setting changes. Emitters are injectable to keep platform feedback
/// out of business logic and make behavior deterministic in tests.
class AppFeedbackService {
  const AppFeedbackService({
    required this.readPreferences,
    this.readDevicePreferences,
    this.emitHaptic,
    this.emitSound,
    this.emitHapticWithStrength,
    this.emitSoundWithStrength,
  });

  final AppExperiencePreferencesReader readPreferences;
  final DeviceVoicePreferencesReader? readDevicePreferences;
  final AppFeedbackEmitter? emitHaptic;
  final AppFeedbackEmitter? emitSound;
  final AppFeedbackStrengthEmitter? emitHapticWithStrength;
  final AppFeedbackStrengthEmitter? emitSoundWithStrength;

  Future<void> success() => emit(AppFeedbackCue.success);

  Future<void> error() => emit(AppFeedbackCue.error);

  Future<void> selection() => emit(AppFeedbackCue.selection);

  Future<void> emit(AppFeedbackCue cue) async {
    final preferences = readPreferences();
    final devicePreferences =
        readDevicePreferences?.call() ?? const DeviceVoicePreferences();
    final hapticStrength = devicePreferences.hapticStrength;
    final soundStrength = devicePreferences.soundStrength;
    await Future.wait([
      if (preferences.hapticsEnabled &&
          hapticStrength != DeviceFeedbackStrength.off)
        _emitSafely(
          'haptic',
          () => emitHapticWithStrength != null
              ? emitHapticWithStrength!(cue, hapticStrength)
              : emitHaptic != null
              ? emitHaptic!(cue)
              : _emitSystemHaptic(cue, hapticStrength),
        ),
      if (preferences.soundEffectsEnabled &&
          soundStrength != DeviceFeedbackStrength.off)
        _emitSafely(
          'sound',
          () => emitSoundWithStrength != null
              ? emitSoundWithStrength!(cue, soundStrength)
              : emitSound != null
              ? emitSound!(cue)
              : _emitSystemSound(cue, soundStrength),
        ),
    ]);
  }
}

Future<void> _emitSafely(String channel, Future<void> Function() emit) async {
  try {
    await emit();
  } on Object catch (error) {
    debugPrint('App $channel feedback failed: $error');
  }
}

Future<void> _emitSystemHaptic(
  AppFeedbackCue cue,
  DeviceFeedbackStrength strength,
) {
  return switch ((cue, strength)) {
    (_, DeviceFeedbackStrength.off) => Future.value(),
    (_, DeviceFeedbackStrength.light) => HapticFeedback.selectionClick(),
    (AppFeedbackCue.selection, DeviceFeedbackStrength.normal) =>
      HapticFeedback.selectionClick(),
    (AppFeedbackCue.success, DeviceFeedbackStrength.normal) =>
      HapticFeedback.mediumImpact(),
    (AppFeedbackCue.error, DeviceFeedbackStrength.normal) =>
      HapticFeedback.heavyImpact(),
    (AppFeedbackCue.selection, DeviceFeedbackStrength.strong) =>
      HapticFeedback.mediumImpact(),
    (_, DeviceFeedbackStrength.strong) => HapticFeedback.heavyImpact(),
  };
}

Future<void> _emitSystemSound(
  AppFeedbackCue cue,
  DeviceFeedbackStrength strength,
) {
  if (strength == DeviceFeedbackStrength.off) return Future.value();
  final sound = switch (cue) {
    AppFeedbackCue.success || AppFeedbackCue.selection => SystemSoundType.click,
    AppFeedbackCue.error => SystemSoundType.alert,
  };
  return SystemSound.play(sound);
}
