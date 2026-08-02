import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef LifecycleAction = FutureOr<void> Function();

final mediaLifecycleRegistryProvider = Provider<MediaLifecycleRegistry>(
  (ref) => MediaLifecycleRegistry(),
);

class MediaLifecycleRegistration {
  const MediaLifecycleRegistration({
    this.persistCheckpoint,
    this.stopTextToSpeech,
    this.stopSpeechRecognition,
    this.stopRecording,
    this.stopEffects,
  });

  final LifecycleAction? persistCheckpoint;
  final LifecycleAction? stopTextToSpeech;
  final LifecycleAction? stopSpeechRecognition;
  final LifecycleAction? stopRecording;
  final LifecycleAction? stopEffects;
}

class MediaLifecycleRegistry {
  final Map<Object, MediaLifecycleRegistration> _registrations = {};

  void register(Object owner, MediaLifecycleRegistration registration) {
    _registrations[owner] = registration;
  }

  void unregister(Object owner) => _registrations.remove(owner);

  Future<void> persistCheckpoints() =>
      _run((registration) => registration.persistCheckpoint);

  Future<void> stopTextToSpeech() =>
      _run((registration) => registration.stopTextToSpeech);

  Future<void> stopSpeechRecognition() =>
      _run((registration) => registration.stopSpeechRecognition);

  Future<void> stopRecording() =>
      _run((registration) => registration.stopRecording);

  Future<void> stopEffects() =>
      _run((registration) => registration.stopEffects);

  Future<void> _run(
    LifecycleAction? Function(MediaLifecycleRegistration registration) select,
  ) async {
    final actions = [
      for (final registration in List.of(_registrations.values))
        ?select(registration),
    ];
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final action in actions) {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

class MediaLifecycleResult {
  const MediaLifecycleResult({
    required this.checkpointSaved,
    required this.failedActions,
  });

  final bool checkpointSaved;
  final List<String> failedActions;
}

class MediaLifecycleCoordinator {
  MediaLifecycleCoordinator({
    required this.persistCheckpoint,
    required this.stopTextToSpeech,
    required this.stopSpeechRecognition,
    required this.stopRecording,
    required this.stopEffects,
  });

  final LifecycleAction persistCheckpoint;
  final LifecycleAction stopTextToSpeech;
  final LifecycleAction stopSpeechRecognition;
  final LifecycleAction stopRecording;
  final LifecycleAction stopEffects;
  Future<MediaLifecycleResult>? _backgroundOperation;

  Future<MediaLifecycleResult> enterBackground() =>
      _backgroundOperation ??= _runBackground();

  void resume() => _backgroundOperation = null;

  Future<MediaLifecycleResult> _runBackground() async {
    var checkpointSaved = true;
    final failures = <String>[];
    try {
      await persistCheckpoint();
    } catch (_) {
      checkpointSaved = false;
      failures.add('checkpoint');
    }
    for (final entry in <(String, LifecycleAction)>[
      ('tts', stopTextToSpeech),
      ('speech', stopSpeechRecognition),
      ('recording', stopRecording),
      ('effects', stopEffects),
    ]) {
      try {
        await entry.$2();
      } catch (_) {
        failures.add(entry.$1);
      }
    }
    return MediaLifecycleResult(
      checkpointSaved: checkpointSaved,
      failedActions: List.unmodifiable(failures),
    );
  }
}
