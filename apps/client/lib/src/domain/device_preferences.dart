enum NotificationLockScreenContent { hidden, generic, detailed }

enum DeviceFeedbackStrength { off, light, normal, strong }

class DeviceNotificationPreferences {
  const DeviceNotificationPreferences({
    this.enabled = true,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
    this.lockScreenContent = NotificationLockScreenContent.generic,
  });

  factory DeviceNotificationPreferences.fromJson(Map<String, Object?> json) {
    final start = _safeMinute(json['quietStartMinutes'], 22 * 60);
    final end = _safeMinute(json['quietEndMinutes'], 7 * 60);
    return DeviceNotificationPreferences(
      enabled: json['enabled'] is bool ? json['enabled']! as bool : true,
      quietStartMinutes: start,
      quietEndMinutes: end,
      lockScreenContent: _safeEnum(
        NotificationLockScreenContent.values,
        json['lockScreenContent'],
        NotificationLockScreenContent.generic,
      ),
    );
  }

  final bool enabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final NotificationLockScreenContent lockScreenContent;

  bool isQuietAt(DateTime localTime) {
    final minute = localTime.hour * 60 + localTime.minute;
    if (quietStartMinutes == quietEndMinutes) return false;
    if (quietStartMinutes < quietEndMinutes) {
      return minute >= quietStartMinutes && minute < quietEndMinutes;
    }
    return minute >= quietStartMinutes || minute < quietEndMinutes;
  }

  DateTime nextAllowedAt(DateTime scheduledAt) {
    final local = scheduledAt.toLocal();
    if (!isQuietAt(local)) return scheduledAt;
    var allowed = DateTime(
      local.year,
      local.month,
      local.day,
      quietEndMinutes ~/ 60,
      quietEndMinutes % 60,
    );
    if (!allowed.isAfter(local)) {
      allowed = DateTime(
        local.year,
        local.month,
        local.day + 1,
        quietEndMinutes ~/ 60,
        quietEndMinutes % 60,
      );
    }
    return scheduledAt.isUtc ? allowed.toUtc() : allowed;
  }

  ({String title, String body}) visibleNotification({
    required String title,
    required String body,
  }) => switch (lockScreenContent) {
    NotificationLockScreenContent.hidden => (
      title: 'Sprache',
      body: '학습 알림이 도착했습니다.',
    ),
    NotificationLockScreenContent.generic => (
      title: '학습할 시간이에요',
      body: '앱을 열어 오늘 계획을 확인하세요.',
    ),
    NotificationLockScreenContent.detailed => (title: title, body: body),
  };

  DeviceNotificationPreferences copyWith({
    bool? enabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    NotificationLockScreenContent? lockScreenContent,
  }) => DeviceNotificationPreferences(
    enabled: enabled ?? this.enabled,
    quietStartMinutes: _safeMinute(quietStartMinutes, this.quietStartMinutes),
    quietEndMinutes: _safeMinute(quietEndMinutes, this.quietEndMinutes),
    lockScreenContent: lockScreenContent ?? this.lockScreenContent,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
    'lockScreenContent': lockScreenContent.name,
  };
}

class DevicePrivacyPreferences {
  const DevicePrivacyPreferences({this.privacyMode = false});

  factory DevicePrivacyPreferences.fromJson(Map<String, Object?> json) =>
      DevicePrivacyPreferences(privacyMode: json['privacyMode'] == true);

  final bool privacyMode;

  DevicePrivacyPreferences copyWith({bool? privacyMode}) =>
      DevicePrivacyPreferences(privacyMode: privacyMode ?? this.privacyMode);

  Map<String, Object?> toJson() => {'privacyMode': privacyMode};
}

const minimumNaturalVoicePitch = 0.8;
const maximumNaturalVoicePitch = 1.2;
const defaultNaturalVoicePitch = 1.0;

double normalizeNaturalVoicePitch(Object? value) {
  if (value is! num || !value.isFinite) return defaultNaturalVoicePitch;
  return value
      .toDouble()
      .clamp(minimumNaturalVoicePitch, maximumNaturalVoicePitch)
      .toDouble();
}

class DeviceVoicePreferences {
  const DeviceVoicePreferences({
    this.voiceIdByLanguage = const {},
    this.pitch = defaultNaturalVoicePitch,
    this.soundStrength = DeviceFeedbackStrength.normal,
    this.hapticStrength = DeviceFeedbackStrength.normal,
  });

  factory DeviceVoicePreferences.fromJson(Map<String, Object?> json) {
    final voices = <String, String>{};
    if (json['voiceIdByLanguage'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(20)) {
        if (entry.key is! String || entry.value is! String) continue;
        final language = (entry.key! as String).trim();
        final voice = (entry.value! as String).trim();
        if (language.isEmpty ||
            language.runes.length > 24 ||
            voice.isEmpty ||
            voice.runes.length > 160) {
          continue;
        }
        voices[language] = voice;
      }
    }
    final pitch = normalizeNaturalVoicePitch(json['pitch']);
    return DeviceVoicePreferences(
      voiceIdByLanguage: Map.unmodifiable(voices),
      pitch: pitch,
      soundStrength: _safeEnum(
        DeviceFeedbackStrength.values,
        json['soundStrength'],
        DeviceFeedbackStrength.normal,
      ),
      hapticStrength: _safeEnum(
        DeviceFeedbackStrength.values,
        json['hapticStrength'],
        DeviceFeedbackStrength.normal,
      ),
    );
  }

  final Map<String, String> voiceIdByLanguage;
  final double pitch;
  final DeviceFeedbackStrength soundStrength;
  final DeviceFeedbackStrength hapticStrength;

  DeviceVoicePreferences copyWith({
    Map<String, String>? voiceIdByLanguage,
    double? pitch,
    DeviceFeedbackStrength? soundStrength,
    DeviceFeedbackStrength? hapticStrength,
  }) => DeviceVoicePreferences(
    voiceIdByLanguage: Map.unmodifiable(
      voiceIdByLanguage ?? this.voiceIdByLanguage,
    ),
    pitch: normalizeNaturalVoicePitch(pitch ?? this.pitch),
    soundStrength: soundStrength ?? this.soundStrength,
    hapticStrength: hapticStrength ?? this.hapticStrength,
  );

  DeviceVoicePreferences selectVoice(String language, String? voiceId) {
    final next = Map<String, String>.from(voiceIdByLanguage);
    final normalizedLanguage = language.trim();
    final normalizedVoice = voiceId?.trim();
    if (normalizedLanguage.isEmpty || normalizedLanguage.runes.length > 24) {
      return this;
    }
    if (normalizedVoice == null || normalizedVoice.isEmpty) {
      next.remove(normalizedLanguage);
    } else if (normalizedVoice.runes.length <= 160) {
      next[normalizedLanguage] = normalizedVoice;
    }
    return copyWith(voiceIdByLanguage: next);
  }

  Map<String, Object?> toJson() => {
    'voiceIdByLanguage': voiceIdByLanguage,
    'pitch': pitch,
    'soundStrength': soundStrength.name,
    'hapticStrength': hapticStrength.name,
  };
}

class DevicePreferences {
  const DevicePreferences({
    this.notifications = const DeviceNotificationPreferences(),
    this.privacy = const DevicePrivacyPreferences(),
    this.voice = const DeviceVoicePreferences(),
  });

  factory DevicePreferences.fromJson(Map<String, Object?> json) =>
      DevicePreferences(
        notifications: json['notifications'] is Map
            ? DeviceNotificationPreferences.fromJson(
                Map<String, Object?>.from(json['notifications']! as Map),
              )
            : const DeviceNotificationPreferences(),
        privacy: json['privacy'] is Map
            ? DevicePrivacyPreferences.fromJson(
                Map<String, Object?>.from(json['privacy']! as Map),
              )
            : const DevicePrivacyPreferences(),
        voice: json['voice'] is Map
            ? DeviceVoicePreferences.fromJson(
                Map<String, Object?>.from(json['voice']! as Map),
              )
            : const DeviceVoicePreferences(),
      );

  final DeviceNotificationPreferences notifications;
  final DevicePrivacyPreferences privacy;
  final DeviceVoicePreferences voice;

  DevicePreferences copyWith({
    DeviceNotificationPreferences? notifications,
    DevicePrivacyPreferences? privacy,
    DeviceVoicePreferences? voice,
  }) => DevicePreferences(
    notifications: notifications ?? this.notifications,
    privacy: privacy ?? this.privacy,
    voice: voice ?? this.voice,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'notifications': notifications.toJson(),
    'privacy': privacy.toJson(),
    'voice': voice.toJson(),
  };
}

int _safeMinute(Object? raw, int fallback) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return fallback;
  return raw.toInt().clamp(0, 1439).toInt();
}

T _safeEnum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
