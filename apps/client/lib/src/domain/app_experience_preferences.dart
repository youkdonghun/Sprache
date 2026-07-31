enum AppColorMode { system, light, dark }

enum AppAccentPalette { sprache, forest, ocean, violet, coral, slate }

enum AppDensity { platform, comfortable, compact }

enum AppTextScale { system, small, medium, large }

const _experienceTimestampNotProvided = Object();

class AppExperiencePreferences {
  const AppExperiencePreferences({
    this.colorMode = AppColorMode.system,
    this.accentPalette = AppAccentPalette.sprache,
    this.density = AppDensity.platform,
    this.textScale = AppTextScale.system,
    this.reduceMotion = false,
    this.hapticsEnabled = false,
    this.soundEffectsEnabled = false,
    this.updatedAt,
  });

  final AppColorMode colorMode;
  final AppAccentPalette accentPalette;
  final AppDensity density;
  final AppTextScale textScale;
  final bool reduceMotion;
  final bool hapticsEnabled;
  final bool soundEffectsEnabled;
  final DateTime? updatedAt;

  AppExperiencePreferences copyWith({
    AppColorMode? colorMode,
    AppAccentPalette? accentPalette,
    AppDensity? density,
    AppTextScale? textScale,
    bool? reduceMotion,
    bool? hapticsEnabled,
    bool? soundEffectsEnabled,
    Object? updatedAt = _experienceTimestampNotProvided,
  }) {
    return AppExperiencePreferences(
      colorMode: colorMode ?? this.colorMode,
      accentPalette: accentPalette ?? this.accentPalette,
      density: density ?? this.density,
      textScale: textScale ?? this.textScale,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      updatedAt: identical(updatedAt, _experienceTimestampNotProvided)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'colorMode': colorMode.name,
    'accentPalette': accentPalette.name,
    'density': density.name,
    'textScale': textScale.name,
    'reduceMotion': reduceMotion,
    'hapticsEnabled': hapticsEnabled,
    'soundEffectsEnabled': soundEffectsEnabled,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  factory AppExperiencePreferences.fromJson(Map<String, Object?> json) {
    return AppExperiencePreferences(
      colorMode: _enumByName(
        AppColorMode.values,
        json['colorMode'],
        AppColorMode.system,
      ),
      accentPalette: _enumByName(
        AppAccentPalette.values,
        json['accentPalette'],
        AppAccentPalette.sprache,
      ),
      density: _enumByName(
        AppDensity.values,
        json['density'],
        AppDensity.platform,
      ),
      textScale: _enumByName(
        AppTextScale.values,
        json['textScale'],
        AppTextScale.system,
      ),
      reduceMotion: _boolOr(json['reduceMotion'], false),
      hapticsEnabled: _boolOr(json['hapticsEnabled'], false),
      soundEffectsEnabled: _boolOr(json['soundEffectsEnabled'], false),
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }
}

bool _boolOr(Object? raw, bool fallback) => raw is bool ? raw : fallback;

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
