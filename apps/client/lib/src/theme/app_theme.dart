import 'package:flutter/foundation.dart';
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
    final surfaces = _surfaceColors(
      preferences,
      brightness: brightness,
      isDesktop: false,
    );
    final palette = _palette(
      preferences.accentPaletteForBrightness(
        isDark: brightness == Brightness.dark,
      ),
      brightness: brightness,
      isDesktop: false,
    );
    return _build(
      seed: preferences.customAccentEnabled
          ? safeCustomAccentColor(
              preferences.customAccentRgb,
              brightness: brightness,
              background: surfaces.scaffold,
            )
          : palette.primary,
      accent: palette.secondary,
      scaffold: surfaces.scaffold,
      surface: surfaces.surface,
      brightness: brightness,
      isDesktop: false,
      preferences: preferences,
      accessibilityProfile: accessibilityProfile,
    );
  }

  static ThemeData desktopFor(
    AppExperiencePreferences preferences, {
    required Brightness brightness,
    AccessibilityInputProfile accessibilityProfile =
        const AccessibilityInputProfile(),
  }) {
    final surfaces = _surfaceColors(
      preferences,
      brightness: brightness,
      isDesktop: true,
    );
    final palette = _palette(
      preferences.accentPaletteForBrightness(
        isDark: brightness == Brightness.dark,
      ),
      brightness: brightness,
      isDesktop: true,
    );
    return _build(
      seed: preferences.customAccentEnabled
          ? safeCustomAccentColor(
              preferences.customAccentRgb,
              brightness: brightness,
              background: surfaces.scaffold,
            )
          : palette.primary,
      accent: palette.secondary,
      scaffold: surfaces.scaffold,
      surface: surfaces.surface,
      brightness: brightness,
      isDesktop: true,
      preferences: preferences,
      accessibilityProfile: accessibilityProfile,
    );
  }

  static Color palettePreview(AppAccentPalette palette) =>
      _palette(palette, brightness: Brightness.light, isDesktop: false).primary;

  static Color safeCustomAccentColor(
    int rgb, {
    required Brightness brightness,
    Color? background,
  }) {
    final raw = Color(0xFF000000 | (rgb & 0xFFFFFF));
    final surface =
        background ??
        (brightness == Brightness.dark
            ? const Color(0xFF101512)
            : Colors.white);
    if (_contrastRatio(raw, surface) >= 3) return raw;
    final target = brightness == Brightness.dark ? Colors.white : Colors.black;
    for (var step = 1; step <= 20; step++) {
      final candidate = Color.lerp(raw, target, step / 20)!;
      if (_contrastRatio(candidate, surface) >= 3) return candidate;
    }
    return target;
  }

  static double contentMaxWidth(AppContentWidth width) => switch (width) {
    AppContentWidth.focused => 880,
    AppContentWidth.balanced => 1120,
    AppContentWidth.wide => 1360,
  };

  static ThemeData _build({
    required Color seed,
    required Color accent,
    required Color scaffold,
    required Color surface,
    required Brightness brightness,
    required bool isDesktop,
    required AppExperiencePreferences preferences,
    required AccessibilityInputProfile accessibilityProfile,
  }) {
    final radius = _cornerRadius(preferences.cornerStyle, isDesktop);
    final controlRadius = _controlRadius(preferences.cornerStyle, isDesktop);
    final fontFamily = _fontFamilyName(
      preferences.fontFamily,
      defaultTargetPlatform,
    );
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
    final highContrast =
        accessibilityProfile.highContrast || preferences.highContrast;
    final reduceTransparency = accessibilityProfile.reduceTransparency;
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
      fontFamily: fontFamily,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: preferences.showFocusRing
          ? reduceTransparency
                ? colors.primaryContainer
                : seed.withValues(alpha: highContrast ? 0.34 : 0.2)
          : Colors.transparent,
    );
    final bodyWeight = preferences.fontEmphasis == AppFontEmphasis.strong
        ? FontWeight.w600
        : null;
    final bodyHeight = _readingLineHeight(
      preferences.readingLineHeight,
      isDesktop,
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
        height: bodyHeight,
        fontWeight: bodyWeight,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: bodyHeight,
        fontWeight: bodyWeight,
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
        elevation: reduceTransparency
            ? 0
            : _cardElevation(preferences, brightness),
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: reduceTransparency
            ? Colors.transparent
            : preferences.decorationIntensity == AppDecorationIntensity.vivid
            ? seed.withValues(alpha: 0.28)
            : null,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: preferences.cardStyle == AppCardStyle.flat && !highContrast
              ? BorderSide.none
              : BorderSide(
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
      dialogTheme: DialogThemeData(
        elevation: reduceTransparency ? 0 : 6,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: reduceTransparency ? Colors.transparent : colors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: reduceTransparency ? 0 : 8,
        modalElevation: reduceTransparency ? 0 : 12,
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: reduceTransparency ? Colors.transparent : colors.shadow,
        shape: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, isDesktop ? 46 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 18,
            vertical: isDesktop ? 12 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
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
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
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
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(
            color: colors.outline,
            width: highContrast ? 1.6 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(
            color: highContrast ? colors.outline : colors.outlineVariant,
            width: highContrast ? 1.6 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
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
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            preferences.cornerStyle == AppCornerStyle.square ? 4 : 10,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: highContrast ? colors.outline : colors.outlineVariant,
        thickness: highContrast ? 1.6 : 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: reduceTransparency
            ? SnackBarBehavior.fixed
            : SnackBarBehavior.floating,
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
      visualDensity: switch (preferences.density) {
        AppDensity.platform =>
          isDesktop ? VisualDensity.compact : VisualDensity.standard,
        AppDensity.comfortable => VisualDensity.comfortable,
        AppDensity.compact => VisualDensity.compact,
      },
      pageTransitionsTheme: _pageTransitionsTheme(preferences.motionLevel),
      extensions: [StudyAccessibilityTheme.fromProfile(accessibilityProfile)],
    );
  }

  static PageTransitionsTheme _pageTransitionsTheme(AppMotionLevel level) {
    if (level == AppMotionLevel.full) return const PageTransitionsTheme();
    final builder = level == AppMotionLevel.off
        ? const _NoMotionPageTransitionsBuilder()
        : const _SubtlePageTransitionsBuilder();
    return PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values) platform: builder,
      },
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
      AppAccentPalette.sunrise => _AppPalette(
        primary: dark ? const Color(0xFFFFB36B) : const Color(0xFFB85C18),
        secondary: dark ? const Color(0xFF8FB7E8) : const Color(0xFF315F91),
      ),
      AppAccentPalette.mint => _AppPalette(
        primary: dark ? const Color(0xFF83D7B0) : const Color(0xFF277A59),
        secondary: dark ? const Color(0xFF8EC8D0) : const Color(0xFF367681),
      ),
      AppAccentPalette.rose => _AppPalette(
        primary: dark ? const Color(0xFFF3A0B5) : const Color(0xFFA83E5C),
        secondary: dark ? const Color(0xFFD5A3E8) : const Color(0xFF744A9B),
      ),
      AppAccentPalette.mono => _AppPalette(
        primary: dark ? const Color(0xFFE4E8EA) : const Color(0xFF3F4A50),
        secondary: dark ? const Color(0xFFAEC5CD) : const Color(0xFF596F78),
      ),
    };
  }

  static _SurfaceColors _surfaceColors(
    AppExperiencePreferences preferences, {
    required Brightness brightness,
    required bool isDesktop,
  }) {
    if (brightness == Brightness.dark &&
        preferences.colorMode == AppColorMode.oled) {
      return const _SurfaceColors(
        scaffold: Color(0xFF000000),
        surface: Color(0xFF000000),
      );
    }
    final dark = brightness == Brightness.dark;
    return switch (preferences.surfaceTone) {
      AppSurfaceTone.neutral => _SurfaceColors(
        scaffold: dark
            ? isDesktop
                  ? const Color(0xFF11171B)
                  : const Color(0xFF101512)
            : isDesktop
            ? const Color(0xFFF3F5F7)
            : const Color(0xFFF7F8F4),
        surface: dark
            ? isDesktop
                  ? const Color(0xFF192126)
                  : const Color(0xFF181E1A)
            : const Color(0xFFFFFFFF),
      ),
      AppSurfaceTone.warm => _SurfaceColors(
        scaffold: dark ? const Color(0xFF17130F) : const Color(0xFFF8F3E9),
        surface: dark ? const Color(0xFF211B16) : const Color(0xFFFFFCF5),
      ),
      AppSurfaceTone.cool => _SurfaceColors(
        scaffold: dark ? const Color(0xFF0F1519) : const Color(0xFFF1F6F8),
        surface: dark ? const Color(0xFF171F24) : const Color(0xFFFBFDFF),
      ),
    };
  }

  static double _cornerRadius(AppCornerStyle style, bool isDesktop) =>
      switch (style) {
        AppCornerStyle.rounded => isDesktop ? 16 : 20,
        AppCornerStyle.balanced => isDesktop ? 12 : 14,
        AppCornerStyle.square => 4,
      };

  static double _controlRadius(AppCornerStyle style, bool isDesktop) =>
      switch (style) {
        AppCornerStyle.rounded => isDesktop ? 13 : 18,
        AppCornerStyle.balanced => isDesktop ? 9 : 15,
        AppCornerStyle.square => 4,
      };

  static double _readingLineHeight(
    AppReadingLineHeight value,
    bool isDesktop,
  ) => switch (value) {
    AppReadingLineHeight.compact => isDesktop ? 1.32 : 1.25,
    AppReadingLineHeight.comfortable => isDesktop ? 1.45 : 1.35,
    AppReadingLineHeight.relaxed => isDesktop ? 1.65 : 1.55,
  };

  static double _cardElevation(
    AppExperiencePreferences preferences,
    Brightness brightness,
  ) {
    if (preferences.decorationIntensity == AppDecorationIntensity.minimal) {
      return 0;
    }
    final base = switch (preferences.cardStyle) {
      AppCardStyle.flat => 0.0,
      AppCardStyle.outlined => brightness == Brightness.light ? 0.4 : 0.0,
      AppCardStyle.elevated => brightness == Brightness.light ? 3.0 : 1.0,
    };
    return preferences.decorationIntensity == AppDecorationIntensity.vivid
        ? base + 2
        : base;
  }

  static String? _fontFamilyName(
    AppFontFamily family,
    TargetPlatform platform,
  ) => switch (family) {
    AppFontFamily.notoSans => 'NotoSansKR',
    AppFontFamily.system => null,
    AppFontFamily.serif => switch (platform) {
      TargetPlatform.windows => 'Georgia',
      TargetPlatform.iOS || TargetPlatform.macOS => 'New York',
      TargetPlatform.android ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => 'serif',
    },
    AppFontFamily.monospace => switch (platform) {
      TargetPlatform.windows => 'Consolas',
      TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
      TargetPlatform.android ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => 'monospace',
    },
  };

  static double _contrastRatio(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// Keeps navigation legible while replacing spatial movement with a short,
/// low-stimulation fade. The route still owns the transition duration, so
/// interrupted navigation and back gestures retain Flutter's normal lifecycle.
class _SubtlePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SubtlePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    child: child,
  );
}

/// Presents the destination immediately for learners who disable motion.
class _NoMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoMotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _AppPalette {
  const _AppPalette({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;
}

class _SurfaceColors {
  const _SurfaceColors({required this.scaffold, required this.surface});

  final Color scaffold;
  final Color surface;
}
