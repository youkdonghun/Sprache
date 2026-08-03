import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';

void main() {
  test('new theme controls preserve established defaults', () {
    const preferences = AppExperiencePreferences();

    expect(preferences.separateBrightnessAccents, isFalse);
    expect(preferences.lightAccentPalette, AppAccentPalette.sprache);
    expect(preferences.darkAccentPalette, AppAccentPalette.sprache);
    expect(preferences.themeScheduleMode, AppThemeScheduleMode.off);
    expect(preferences.themeDarkStartHour, 19);
    expect(preferences.themeLightStartHour, 7);
    expect(preferences.scheduledDarkUsesOled, isFalse);
    expect(preferences.customAccentEnabled, isFalse);
    expect(preferences.customAccentRgb, 0x3D8F40);
    expect(preferences.themeProfiles, isEmpty);
    expect(preferences.activeThemeProfileId, isNull);
    expect(preferences.fontFamily, AppFontFamily.notoSans);
    expect(preferences.studyTextScale, AppStudyTextScale.sameAsApp);
    expect(preferences.cardAlignment, AppCardAlignment.adaptive);
    expect(preferences.navigationIconStyle, AppNavigationIconStyle.adaptive);
    expect(preferences.decorationIntensity, AppDecorationIntensity.balanced);
  });

  test('expanded theme preferences and a profile survive JSON round trip', () {
    const configured = AppExperiencePreferences(
      colorMode: AppColorMode.dark,
      accentPalette: AppAccentPalette.violet,
      separateBrightnessAccents: true,
      lightAccentPalette: AppAccentPalette.sunrise,
      darkAccentPalette: AppAccentPalette.mint,
      themeScheduleMode: AppThemeScheduleMode.custom,
      themeDarkStartHour: 21,
      themeLightStartHour: 6,
      scheduledDarkUsesOled: true,
      customAccentEnabled: true,
      customAccentRgb: 0xA1B2C3,
      fontFamily: AppFontFamily.system,
      studyTextScale: AppStudyTextScale.extraLarge,
      cardAlignment: AppCardAlignment.leading,
      navigationIconStyle: AppNavigationIconStyle.outlined,
      decorationIntensity: AppDecorationIntensity.vivid,
    );
    final profile = AppThemeProfile.capture(
      id: 'night_focus',
      name: '야간 집중',
      preferences: configured,
    );
    final preferences = configured.copyWith(
      themeProfiles: [profile],
      activeThemeProfileId: profile.id,
    );

    final restored = AppExperiencePreferences.fromJson(preferences.toJson());

    expect(restored.toJson(), preferences.toJson());
    expect(restored.themeProfiles.single.name, '야간 집중');
    expect(restored.activeThemeProfileId, 'night_focus');
  });

  test('overnight theme schedules resolve modes and next boundaries', () {
    const preferences = AppExperiencePreferences(
      colorMode: AppColorMode.system,
      themeScheduleMode: AppThemeScheduleMode.custom,
      themeDarkStartHour: 20,
      themeLightStartHour: 6,
      scheduledDarkUsesOled: true,
    );

    expect(
      preferences.colorModeAt(DateTime(2026, 8, 3, 5, 30)),
      AppColorMode.oled,
    );
    expect(
      preferences.colorModeAt(DateTime(2026, 8, 3, 12)),
      AppColorMode.light,
    );
    expect(
      preferences.colorModeAt(DateTime(2026, 8, 3, 22)),
      AppColorMode.oled,
    );
    expect(
      preferences.nextThemeBoundaryAfter(DateTime(2026, 8, 3, 19, 30)),
      DateTime(2026, 8, 3, 20),
    );
    expect(
      preferences.nextThemeBoundaryAfter(DateTime(2026, 8, 3, 21)),
      DateTime(2026, 8, 4, 6),
    );
  });

  test('same-hour schedule safely falls back to manual mode', () {
    const preferences = AppExperiencePreferences(
      colorMode: AppColorMode.dark,
      themeScheduleMode: AppThemeScheduleMode.custom,
      themeDarkStartHour: 8,
      themeLightStartHour: 8,
    );

    expect(
      preferences.colorModeAt(DateTime(2026, 8, 3, 12)),
      AppColorMode.dark,
    );
    expect(preferences.nextThemeBoundaryAfter(DateTime(2026, 8, 3)), isNull);
  });

  test(
    'profile parser isolates corruption, duplicates, and excess entries',
    () {
      const base = AppExperiencePreferences();
      Map<String, Object?> profile(String id) => AppThemeProfile.capture(
        id: id,
        name: '테마 $id',
        preferences: base,
      ).toJson();

      final restored = AppExperiencePreferences.fromJson({
        'themeProfiles': [
          {...profile('broken'), 'customAccentRgb': 'red'},
          profile('safe_1'),
          profile('safe_1'),
          profile('safe_2'),
          profile('safe_3'),
          profile('safe_4'),
          profile('safe_5'),
          profile('ignored_6'),
        ],
        'activeThemeProfileId': 'broken',
      });

      expect(restored.themeProfiles.map((profile) => profile.id), [
        'safe_1',
        'safe_2',
        'safe_3',
        'safe_4',
        'safe_5',
      ]);
      expect(restored.activeThemeProfileId, isNull);
    },
  );

  test('malformed schedule and color ranges are bounded without throwing', () {
    final restored = AppExperiencePreferences.fromJson({
      'themeDarkStartHour': -100,
      'themeLightStartHour': 80,
      'customAccentRgb': double.infinity,
      'themeScheduleMode': 'solar-flare',
      'fontFamily': 'comic',
    });

    expect(restored.themeDarkStartHour, 0);
    expect(restored.themeLightStartHour, 23);
    expect(restored.customAccentRgb, 0x3D8F40);
    expect(restored.themeScheduleMode, AppThemeScheduleMode.off);
    expect(restored.fontFamily, AppFontFamily.notoSans);
  });

  test(
    'captured profile restores visual settings but preserves profile list',
    () {
      const source = AppExperiencePreferences(
        colorMode: AppColorMode.oled,
        accentPalette: AppAccentPalette.rose,
        fontFamily: AppFontFamily.system,
        studyTextScale: AppStudyTextScale.larger,
        decorationIntensity: AppDecorationIntensity.minimal,
      );
      final profile = AppThemeProfile.capture(
        id: 'saved',
        name: '저장됨',
        preferences: source,
      );
      final current = const AppExperiencePreferences(
        colorMode: AppColorMode.light,
        accentPalette: AppAccentPalette.ocean,
      ).copyWith(themeProfiles: [profile]);

      final applied = profile.applyTo(current);

      expect(applied.colorMode, AppColorMode.oled);
      expect(applied.accentPalette, AppAccentPalette.rose);
      expect(applied.fontFamily, AppFontFamily.system);
      expect(applied.studyTextScale, AppStudyTextScale.larger);
      expect(applied.themeProfiles.single.id, 'saved');
      expect(applied.activeThemeProfileId, 'saved');
    },
  );
}
