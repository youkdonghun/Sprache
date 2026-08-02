import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  group('AppTheme preference compatibility', () {
    test('system defaults retain the existing Sprache palette', () {
      const preferences = AppExperiencePreferences();

      expect(preferences.colorMode, AppColorMode.system);
      expect(preferences.accentPalette, AppAccentPalette.sprache);

      final mobileLight = AppTheme.mobileFor(
        preferences,
        brightness: Brightness.light,
      );
      final mobileDark = AppTheme.mobileFor(
        preferences,
        brightness: Brightness.dark,
      );
      final desktopLight = AppTheme.desktopFor(
        preferences,
        brightness: Brightness.light,
      );
      final desktopDark = AppTheme.desktopFor(
        preferences,
        brightness: Brightness.dark,
      );

      expect(mobileLight.colorScheme.primary, AppTheme.mobilePrimary);
      expect(desktopLight.colorScheme.primary, AppTheme.desktopPrimary);
      expect(mobileLight.colorScheme, AppTheme.mobile.colorScheme);
      expect(mobileDark.colorScheme, AppTheme.mobileDark.colorScheme);
      expect(desktopLight.colorScheme, AppTheme.desktop.colorScheme);
      expect(desktopDark.colorScheme, AppTheme.desktopDark.colorScheme);
    });

    test('all ten accent palettes remain visually distinct', () {
      expect(AppAccentPalette.values, hasLength(10));

      final previews = {
        for (final palette in AppAccentPalette.values)
          AppTheme.palettePreview(palette),
      };
      final mobilePrimaries = {
        for (final palette in AppAccentPalette.values)
          AppTheme.mobileFor(
            AppExperiencePreferences(accentPalette: palette),
            brightness: Brightness.light,
          ).colorScheme.primary,
      };
      final desktopPrimaries = {
        for (final palette in AppAccentPalette.values)
          AppTheme.desktopFor(
            AppExperiencePreferences(accentPalette: palette),
            brightness: Brightness.light,
          ).colorScheme.primary,
      };

      expect(previews, hasLength(10));
      expect(mobilePrimaries, hasLength(10));
      expect(desktopPrimaries, hasLength(10));
    });

    test('mobile and desktop builders honor light and dark brightness', () {
      for (final palette in AppAccentPalette.values) {
        final preferences = AppExperiencePreferences(accentPalette: palette);
        for (final builder in [AppTheme.mobileFor, AppTheme.desktopFor]) {
          final light = builder(preferences, brightness: Brightness.light);
          final dark = builder(preferences, brightness: Brightness.dark);

          expect(light.brightness, Brightness.light);
          expect(light.colorScheme.brightness, Brightness.light);
          expect(dark.brightness, Brightness.dark);
          expect(dark.colorScheme.brightness, Brightness.dark);
          expect(
            dark.scaffoldBackgroundColor,
            isNot(light.scaffoldBackgroundColor),
          );
          expect(dark.colorScheme.primary, isNot(light.colorScheme.primary));
        }
      }
    });

    test('density preferences map consistently on each platform layout', () {
      const expected = <AppDensity, (VisualDensity, VisualDensity)>{
        AppDensity.platform: (VisualDensity.standard, VisualDensity.compact),
        AppDensity.comfortable: (
          VisualDensity.comfortable,
          VisualDensity.comfortable,
        ),
        AppDensity.compact: (VisualDensity.compact, VisualDensity.compact),
      };

      for (final entry in expected.entries) {
        final preferences = AppExperiencePreferences(density: entry.key);
        final mobile = AppTheme.mobileFor(
          preferences,
          brightness: Brightness.light,
        );
        final desktop = AppTheme.desktopFor(
          preferences,
          brightness: Brightness.light,
        );

        expect(mobile.visualDensity, entry.value.$1);
        expect(desktop.visualDensity, entry.value.$2);
      }
    });

    test('surface, card, contrast, and typography choices reach the theme', () {
      const preferences = AppExperiencePreferences(
        colorMode: AppColorMode.oled,
        surfaceTone: AppSurfaceTone.warm,
        cornerStyle: AppCornerStyle.square,
        cardStyle: AppCardStyle.elevated,
        fontEmphasis: AppFontEmphasis.strong,
        readingLineHeight: AppReadingLineHeight.relaxed,
        highContrast: true,
      );
      final theme = AppTheme.desktopFor(
        preferences,
        brightness: Brightness.dark,
      );

      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.surface, const Color(0xFF000000));
      expect(theme.cardTheme.color, const Color(0xFF000000));
      expect(theme.cardTheme.elevation, 1);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.bodyMedium?.height, 1.65);
      expect(
        theme.colorScheme.outline,
        isNot(theme.colorScheme.outlineVariant),
      );
    });

    test('content width profiles expose stable desktop limits', () {
      expect(AppTheme.contentMaxWidth(AppContentWidth.focused), 880);
      expect(AppTheme.contentMaxWidth(AppContentWidth.balanced), 1120);
      expect(AppTheme.contentMaxWidth(AppContentWidth.wide), 1360);
    });

    testWidgets('motion levels select full, subtle, and immediate navigation', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );
      const child = SizedBox(key: Key('transition-child'));

      PageTransitionsBuilder builderFor(AppMotionLevel level) =>
          AppTheme.mobileFor(
            AppExperiencePreferences(motionLevel: level),
            brightness: Brightness.light,
          ).pageTransitionsTheme.builders[TargetPlatform.android]!;

      final full = builderFor(AppMotionLevel.full);
      final subtle = builderFor(AppMotionLevel.reduced);
      final off = builderFor(AppMotionLevel.off);
      expect(subtle.runtimeType, isNot(full.runtimeType));
      expect(off.runtimeType, isNot(subtle.runtimeType));
      expect(
        subtle.buildTransitions<void>(
          route,
          context,
          const AlwaysStoppedAnimation<double>(0.5),
          const AlwaysStoppedAnimation<double>(0),
          child,
        ),
        isA<FadeTransition>(),
      );
      expect(
        off.buildTransitions<void>(
          route,
          context,
          const AlwaysStoppedAnimation<double>(0.5),
          const AlwaysStoppedAnimation<double>(0),
          child,
        ),
        same(child),
      );
    });
  });
}
