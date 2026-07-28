import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const mobilePrimary = Color(0xFF3D8F40);
  static const mobileAccent = Color(0xFFF59E0B);
  static const desktopPrimary = Color(0xFF365F7B);
  static const desktopAccent = Color(0xFF2E7D78);
  static const success = Color(0xFF238B57);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFC2414B);

  static ThemeData get mobile => _build(
    seed: mobilePrimary,
    accent: mobileAccent,
    scaffold: const Color(0xFFF7F8F4),
    surface: const Color(0xFFFFFFFF),
    brightness: Brightness.light,
    radius: 18,
    isDesktop: false,
  );

  static ThemeData get mobileDark => _build(
    seed: const Color(0xFF6FC276),
    accent: const Color(0xFFF8B84E),
    scaffold: const Color(0xFF101512),
    surface: const Color(0xFF181E1A),
    brightness: Brightness.dark,
    radius: 18,
    isDesktop: false,
  );

  static ThemeData get desktop => _build(
    seed: desktopPrimary,
    accent: desktopAccent,
    scaffold: const Color(0xFFF3F5F7),
    surface: const Color(0xFFFFFFFF),
    brightness: Brightness.light,
    radius: 12,
    isDesktop: true,
  );

  static ThemeData get desktopDark => _build(
    seed: const Color(0xFF78A9C7),
    accent: const Color(0xFF65B8AF),
    scaffold: const Color(0xFF11171B),
    surface: const Color(0xFF192126),
    brightness: Brightness.dark,
    radius: 12,
    isDesktop: true,
  );

  static ThemeData _build({
    required Color seed,
    required Color accent,
    required Color scaffold,
    required Color surface,
    required Brightness brightness,
    required double radius,
    required bool isDesktop,
  }) {
    final colors =
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

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: scaffold,
      brightness: brightness,
      fontFamily: 'NotoSansKR',
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
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.45,
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
          side: BorderSide(color: colors.outlineVariant),
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
          minimumSize: Size(0, isDesktop ? 46 : 54),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 22,
            vertical: 12,
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
          minimumSize: Size(0, isDesktop ? 44 : 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 9 : 15),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: isDesktop ? 62 : 70,
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
        color: colors.outlineVariant,
        thickness: 1,
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
      visualDensity: isDesktop ? VisualDensity.compact : VisualDensity.standard,
    );
  }
}
