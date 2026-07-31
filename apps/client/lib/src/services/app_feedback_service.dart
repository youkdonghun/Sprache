import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/app_experience_preferences.dart';

enum AppFeedbackCue { success, error, selection }

typedef AppExperiencePreferencesReader = AppExperiencePreferences Function();
typedef AppFeedbackEmitter = Future<void> Function(AppFeedbackCue cue);

/// Delivers optional, best-effort interaction feedback.
///
/// Preferences are read for every cue so a long-lived service immediately
/// follows setting changes. Emitters are injectable to keep platform feedback
/// out of business logic and make behavior deterministic in tests.
class AppFeedbackService {
  const AppFeedbackService({
    required this.readPreferences,
    this.emitHaptic = _emitSystemHaptic,
    this.emitSound = _emitSystemSound,
  });

  final AppExperiencePreferencesReader readPreferences;
  final AppFeedbackEmitter emitHaptic;
  final AppFeedbackEmitter emitSound;

  Future<void> success() => emit(AppFeedbackCue.success);

  Future<void> error() => emit(AppFeedbackCue.error);

  Future<void> selection() => emit(AppFeedbackCue.selection);

  Future<void> emit(AppFeedbackCue cue) async {
    final preferences = readPreferences();
    await Future.wait([
      if (preferences.hapticsEnabled) _emitSafely('haptic', emitHaptic, cue),
      if (preferences.soundEffectsEnabled) _emitSafely('sound', emitSound, cue),
    ]);
  }
}

Future<void> _emitSafely(
  String channel,
  AppFeedbackEmitter emitter,
  AppFeedbackCue cue,
) async {
  try {
    await emitter(cue);
  } on Object catch (error) {
    debugPrint('App $channel feedback failed for ${cue.name}: $error');
  }
}

Future<void> _emitSystemHaptic(AppFeedbackCue cue) {
  return switch (cue) {
    AppFeedbackCue.success => HapticFeedback.mediumImpact(),
    AppFeedbackCue.error => HapticFeedback.heavyImpact(),
    AppFeedbackCue.selection => HapticFeedback.selectionClick(),
  };
}

Future<void> _emitSystemSound(AppFeedbackCue cue) {
  final sound = switch (cue) {
    AppFeedbackCue.success || AppFeedbackCue.selection => SystemSoundType.click,
    AppFeedbackCue.error => SystemSoundType.alert,
  };
  return SystemSound.play(sound);
}
