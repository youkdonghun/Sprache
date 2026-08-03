import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  test('light and dark accent palettes are resolved independently', () {
    const preferences = AppExperiencePreferences(
      separateBrightnessAccents: true,
      lightAccentPalette: AppAccentPalette.sunrise,
      darkAccentPalette: AppAccentPalette.mint,
    );

    final light = AppTheme.mobileFor(preferences, brightness: Brightness.light);
    final dark = AppTheme.mobileFor(preferences, brightness: Brightness.dark);
    final expectedLight = AppTheme.mobileFor(
      const AppExperiencePreferences(accentPalette: AppAccentPalette.sunrise),
      brightness: Brightness.light,
    );
    final expectedDark = AppTheme.mobileFor(
      const AppExperiencePreferences(accentPalette: AppAccentPalette.mint),
      brightness: Brightness.dark,
    );

    expect(light.colorScheme.primary, expectedLight.colorScheme.primary);
    expect(dark.colorScheme.primary, expectedDark.colorScheme.primary);
  });

  test('custom accent is adjusted to at least non-text contrast safety', () {
    const white = Color(0xFFFFFFFF);
    const nearBlack = Color(0xFF101512);
    final lightSafe = AppTheme.safeCustomAccentColor(
      0xFFFFFF,
      brightness: Brightness.light,
      background: white,
    );
    final darkSafe = AppTheme.safeCustomAccentColor(
      0x000000,
      brightness: Brightness.dark,
      background: nearBlack,
    );

    expect(_contrastRatio(lightSafe, white), greaterThanOrEqualTo(3));
    expect(_contrastRatio(darkSafe, nearBlack), greaterThanOrEqualTo(3));

    final theme = AppTheme.mobileFor(
      const AppExperiencePreferences(
        customAccentEnabled: true,
        customAccentRgb: 0xFFFFFF,
      ),
      brightness: Brightness.light,
    );
    expect(
      _contrastRatio(theme.colorScheme.primary, white),
      greaterThanOrEqualTo(3),
    );
  });

  test('font family preference supports sans, serif, and monospace', () {
    final bundled = AppTheme.desktopFor(
      const AppExperiencePreferences(fontFamily: AppFontFamily.notoSans),
      brightness: Brightness.light,
    );
    final system = AppTheme.desktopFor(
      const AppExperiencePreferences(fontFamily: AppFontFamily.system),
      brightness: Brightness.light,
    );
    final serif = AppTheme.desktopFor(
      const AppExperiencePreferences(fontFamily: AppFontFamily.serif),
      brightness: Brightness.light,
    );
    final monospace = AppTheme.desktopFor(
      const AppExperiencePreferences(fontFamily: AppFontFamily.monospace),
      brightness: Brightness.light,
    );

    expect(bundled.textTheme.bodyLarge?.fontFamily, 'NotoSansKR');
    expect(system.textTheme.bodyLarge?.fontFamily, isNot('NotoSansKR'));
    expect(
      serif.textTheme.bodyLarge?.fontFamily,
      switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Georgia',
        TargetPlatform.iOS || TargetPlatform.macOS => 'New York',
        _ => 'serif',
      },
    );
    expect(
      monospace.textTheme.bodyLarge?.fontFamily,
      switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Consolas',
        TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
        _ => 'monospace',
      },
    );
  });

  test(
    'decoration intensity scales card depth without changing card choice',
    () {
      final minimal = AppTheme.desktopFor(
        const AppExperiencePreferences(
          cardStyle: AppCardStyle.elevated,
          decorationIntensity: AppDecorationIntensity.minimal,
        ),
        brightness: Brightness.light,
      );
      final balanced = AppTheme.desktopFor(
        const AppExperiencePreferences(
          cardStyle: AppCardStyle.elevated,
          decorationIntensity: AppDecorationIntensity.balanced,
        ),
        brightness: Brightness.light,
      );
      final vivid = AppTheme.desktopFor(
        const AppExperiencePreferences(
          cardStyle: AppCardStyle.elevated,
          decorationIntensity: AppDecorationIntensity.vivid,
        ),
        brightness: Brightness.light,
      );

      expect(minimal.cardTheme.elevation, 0);
      expect(balanced.cardTheme.elevation, 3);
      expect(vivid.cardTheme.elevation, 5);
      expect(vivid.cardTheme.shadowColor, isNotNull);
    },
  );
}

double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
