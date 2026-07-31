import 'package:flutter/material.dart';

import '../domain/accessibility_input_profile.dart';
import '../domain/app_experience_preferences.dart';
import 'study_accessibility_theme.dart';

abstract final class AppTheme {
  static const mobilePrimary = Color(0xFF3D8F40);
  static const mobileAccent = Color(0xFFF59E0B);
  static const desktopPrimary = Color(0xFF365F7B);
  static const desktopAccent = Color(0xFF2E7D78);
  static const success = Color(0xFF238B57);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFC2414B);

  static ThemeData get mobile =>
      mobileFor(const AppExperiencePreferences(), brightness: Brightness.light);

  static ThemeData get mobileDark =>
      mobileFor(const AppExperiencePreferences(), brightness: Brightness.dark);

  static ThemeData get desktop => desktopFor(
    const AppExperiencePreferences(),
    brightness: Brightness.light,
  );

  static ThemeData get desktopDark =>
      desktopFor(const AppExperiencePreferences(), brightness: Brightness.dark);

  static ThemeData mobileFor(
    AppExperiencePreferences preferences, {
    required Brightness brightness,
    AccessibilityInputProfile accessibilityProfile =
        const AccessibilityInputProfile(),
  }) {
    final palette = _palette(
      preferences.accentPalette,
      brightness: brightness,
      isDesktop: false,
    );
    return _build(
      seed: palette.primary,
      accent: palette.secondary,
      scaffold: brightness == Brightness.light
          ? const Color(0xFFF7F8F4)
          : const Color(0xFF101512),
      surface: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF181E1A),
      brightness: brightness,
      radius: 14,
      isDesktop: false,
      density: preferences.density,
      accessibilityProfile: accessibilityProfile,
    );
  }

  static ThemeData desktopFor(
    AppExperiencePreferences preferences, {
    required Brightness brightness,
    AccessibilityInputProfile accessibilityProfile =
        const AccessibilityInputProfile(),
  }) {
    final palette = _palette(
      preferences.accentPalette,
      brightness: brightness,
      isDesktop: true,
    );
    return _build(
      seed: palette.primary,
      accent: palette.secondary,
      scaffold: brightness == Brightness.light
          ? const Color(0xFFF3F5F7)
          : const Color(0xFF11171B),
      surface: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF192126),
      brightness: brightness,
      radius: 12,
      isDesktop: true,
      density: preferences.density,
      accessibilityProfile: accessibilityProfile,
    );
  }

  static Color palettePreview(AppAccentPalette palette) =>
      _palette(palette, brightness: Brightness.light, isDesktop: false).primary;

  static ThemeData _build({
    required Color seed,
    required Color accent,
    required Color scaffold,
    required Color surface,
    required Brightness brightness,
    required double radius,
    required bool isDesktop,
    required AppDensity density,
    required AccessibilityInputProfile accessibilityProfile,
  }) {
    final generatedColors =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: seed,
          secondary: accent,
          outline: brightness == Brightness.dark
              ? const Color(0xFF536168)
              : isDesktop
              ? const Color(0xFFCBD5DC)
              : const Color(0xFFD5DDD2),
          outlineVariant: brightness == Brightness.dark
              ? const Color(0xFF2D383D)
              : isDesktop
              ? const Color(0xFFE2E7EB)
              : const Color(0xFFE4E9E1),
        );
    final highContrast = accessibilityProfile.highContrast;
    final colors = highContrast
        ? generatedColors.copyWith(
            outline: brightness == Brightness.dark
                ? const Color(0xFFF2F7F9)
                : const Color(0xFF182126),
            outlineVariant: brightness == Brightness.dark
                ? const Color(0xFFAEBBC1)
                : const Color(0xFF4B5960),
          )
        : generatedColors;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: scaffold,
      brightness: brightness,
      fontFamily: 'NotoSansKR',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: seed.withValues(alpha: highContrast ? 0.34 : 0.2),
    );
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        height: 1.12,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: isDesktop ? null : 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        height: 1.22,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: isDesktop ? null : 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        height: 1.28,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        height: isDesktop ? 1.45 : 1.35,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: isDesktop ? 1.45 : 1.35,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.light ? 0.4 : 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: highContrast ? colors.outline : colors.outlineVariant,
            width: highContrast ? 1.6 : 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffold,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, isDesktop ? 46 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 18,
            vertical: isDesktop ? 12 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 9 : 16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, isDesktop ? 44 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: isDesktop ? 12 : 10,
          ),
          side: BorderSide(color: colors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isDesktop ? 15 : 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          borderSide: BorderSide(
            color: colors.outline,
            width: highContrast ? 1.6 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          borderSide: BorderSide(
            color: highContrast ? colors.outline : colors.outlineVariant,
            width: highContrast ? 1.6 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: isDesktop ? 62 : 64,
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainerLow,
        side: BorderSide(color: colors.outlineVariant),
        labelStyle: TextStyle(
          fontFamily: 'NotoSansKR',
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: highContrast ? colors.outline : colors.outlineVariant,
        thickness: highContrast ? 1.6 : 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFFE3E9EC)
            : const Color(0xFF27343C),
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark
              ? const Color(0xFF182126)
              : Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: const Color(0xFF27343C),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.outline,
        ),
      ),
      visualDensity: switch (density) {
        AppDensity.platform =>
          isDesktop ? VisualDensity.compact : VisualDensity.standard,
        AppDensity.comfortable => VisualDensity.comfortable,
        AppDensity.compact => VisualDensity.compact,
      },
      extensions: [StudyAccessibilityTheme.fromProfile(accessibilityProfile)],
    );
  }

  static _AppPalette _palette(
    AppAccentPalette palette, {
    required Brightness brightness,
    required bool isDesktop,
  }) {
    final dark = brightness == Brightness.dark;
    return switch (palette) {
      AppAccentPalette.sprache => _AppPalette(
        primary: isDesktop
            ? dark
                  ? const Color(0xFF78A9C7)
                  : desktopPrimary
            : dark
            ? const Color(0xFF6FC276)
            : mobilePrimary,
        secondary: isDesktop
            ? dark
                  ? const Color(0xFF65B8AF)
                  : desktopAccent
            : dark
            ? const Color(0xFFF8B84E)
            : mobileAccent,
      ),
      AppAccentPalette.forest => _AppPalette(
        primary: dark ? const Color(0xFF72C990) : const Color(0xFF28734A),
        secondary: dark ? const Color(0xFFE5B65B) : const Color(0xFFB87318),
      ),
      AppAccentPalette.ocean => _AppPalette(
        primary: dark ? const Color(0xFF73B9E8) : const Color(0xFF256B98),
        secondary: dark ? const Color(0xFF60C9C1) : const Color(0xFF147E79),
      ),
      AppAccentPalette.violet => _AppPalette(
        primary: dark ? const Color(0xFFB9A2F2) : const Color(0xFF6E55B5),
        secondary: dark ? const Color(0xFFE08BC0) : const Color(0xFFA33E7C),
      ),
      AppAccentPalette.coral => _AppPalette(
        primary: dark ? const Color(0xFFFF9A8F) : const Color(0xFFB84C42),
        secondary: dark ? const Color(0xFFFFC36B) : const Color(0xFFA96814),
      ),
      AppAccentPalette.slate => _AppPalette(
        primary: dark ? const Color(0xFFA8B5C2) : const Color(0xFF506273),
        secondary: dark ? const Color(0xFF8DC4CB) : const Color(0xFF3D747C),
      ),
    };
  }
}

class _AppPalette {
  const _AppPalette({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;
}
