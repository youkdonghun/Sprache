import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_store.dart';
import '../domain/device_preferences.dart';
import '../services/study_notification_service.dart';
import '../services/tts_service.dart';
import 'app_state.dart';

class DevicePreferencesState {
  const DevicePreferencesState({
    this.preferences = const DevicePreferences(),
    this.isHydrated = false,
    this.error,
  });

  final DevicePreferences preferences;
  final bool isHydrated;
  final String? error;

  DevicePreferencesState copyWith({
    DevicePreferences? preferences,
    bool? isHydrated,
    String? error,
    bool clearError = false,
  }) => DevicePreferencesState(
    preferences: preferences ?? this.preferences,
    isHydrated: isHydrated ?? this.isHydrated,
    error: clearError ? null : error ?? this.error,
  );
}

class DevicePreferencesController
    extends StateNotifier<DevicePreferencesState> {
  DevicePreferencesController(
    this._store,
    this._notificationService,
    this._onNotificationPreferencesChanged,
  ) : super(const DevicePreferencesState()) {
    unawaited(_hydrate());
  }

  final StudyStore _store;
  final StudyNotificationService _notificationService;
  final Future<void> Function() _onNotificationPreferencesChanged;
  Future<void> _writeTail = Future.value();

  Future<void> _hydrate() async {
    try {
      final preferences = await _store.loadDevicePreferences();
      configureStudyNotificationPreferences(
        _notificationService,
        preferences.notifications,
      );
      if (!mounted) return;
      state = DevicePreferencesState(
        preferences: preferences,
        isHydrated: true,
      );
    } catch (_) {
      if (!mounted) return;
      state = const DevicePreferencesState(
        isHydrated: true,
        error: '이 기기의 설정을 읽지 못해 안전한 기본값을 사용합니다.',
      );
    }
  }

  Future<void> updateNotifications(
    DeviceNotificationPreferences notifications,
  ) async {
    configureStudyNotificationPreferences(_notificationService, notifications);
    await _save(state.preferences.copyWith(notifications: notifications));
    await _onNotificationPreferencesChanged();
  }

  Future<void> updatePrivacy(DevicePrivacyPreferences privacy) =>
      _save(state.preferences.copyWith(privacy: privacy));

  Future<void> updateVoice(DeviceVoicePreferences voice) =>
      _save(state.preferences.copyWith(voice: voice));

  Future<void> replace(DevicePreferences preferences) async {
    configureStudyNotificationPreferences(
      _notificationService,
      preferences.notifications,
    );
    await _save(preferences);
    await _onNotificationPreferencesChanged();
  }

  Future<void> reset() => replace(const DevicePreferences());

  Future<void> _save(DevicePreferences preferences) {
    state = state.copyWith(preferences: preferences, clearError: true);
    final completer = Completer<void>();
    _writeTail = _writeTail.catchError((_) {}).then((_) async {
      try {
        await _store.saveDevicePreferences(preferences);
        completer.complete();
      } catch (_) {
        if (mounted) {
          state = state.copyWith(error: '기기 설정을 저장하지 못했습니다.');
        }
        completer.completeError(StateError('Device preferences save failed'));
      }
    });
    _writeTail = _writeTail.catchError((_) {});
    return completer.future;
  }
}

final devicePreferencesControllerProvider =
    StateNotifierProvider<DevicePreferencesController, DevicePreferencesState>(
      (ref) => DevicePreferencesController(
        ref.watch(studyStoreProvider),
        ref.watch(studyNotificationServiceProvider),
        () async {
          await ref
              .read(appControllerProvider.notifier)
              .refreshStudyNotifications();
        },
      ),
    );

final deviceTtsServiceProvider = Provider<TtsService>(
  (ref) => TtsService.device(),
);
