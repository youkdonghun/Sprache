import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';

void main() {
  test('experience preferences survive a JSON round trip', () {
    final preferences = AppExperiencePreferences(
      colorMode: AppColorMode.dark,
      accentPalette: AppAccentPalette.violet,
      density: AppDensity.compact,
      textScale: AppTextScale.large,
      reduceMotion: true,
      hapticsEnabled: true,
      soundEffectsEnabled: true,
      updatedAt: DateTime.utc(2026, 7, 31, 9, 30),
    );

    final restored = AppExperiencePreferences.fromJson(preferences.toJson());

    expect(restored.colorMode, AppColorMode.dark);
    expect(restored.accentPalette, AppAccentPalette.violet);
    expect(restored.density, AppDensity.compact);
    expect(restored.textScale, AppTextScale.large);
    expect(restored.reduceMotion, isTrue);
    expect(restored.hapticsEnabled, isTrue);
    expect(restored.soundEffectsEnabled, isTrue);
    expect(restored.updatedAt, DateTime.utc(2026, 7, 31, 9, 30));
  });

  test('legacy and malformed values fall back without throwing', () {
    final legacy = AppExperiencePreferences.fromJson(const {});
    final malformed = AppExperiencePreferences.fromJson({
      'colorMode': 'midnight',
      'accentPalette': 12,
      'density': 'tiny',
      'textScale': 'huge',
      'reduceMotion': 'yes',
      'hapticsEnabled': 1,
      'soundEffectsEnabled': null,
      'updatedAt': 'not-a-date',
    });

    expect(legacy.colorMode, AppColorMode.system);
    expect(legacy.accentPalette, AppAccentPalette.sprache);
    expect(legacy.density, AppDensity.platform);
    expect(legacy.textScale, AppTextScale.system);
    expect(malformed.colorMode, AppColorMode.system);
    expect(malformed.accentPalette, AppAccentPalette.sprache);
    expect(malformed.density, AppDensity.platform);
    expect(malformed.textScale, AppTextScale.system);
    expect(malformed.reduceMotion, isFalse);
    expect(malformed.hapticsEnabled, isFalse);
    expect(malformed.soundEffectsEnabled, isFalse);
    expect(malformed.updatedAt, isNull);
  });
}
