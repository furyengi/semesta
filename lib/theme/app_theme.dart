import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'brutal_theme.dart';

const _yellow = Color(0xFFFFC91F);
const _purple = Color(0xFF7C5CFC);
const _pink = Color(0xFFE11D5A);
const _ink = Color(0xFF111111);
const _cream = Color(0xFFFBF8F3);

/// Accent colours for categories and (later) courses. Fixed, so they stay
/// recognisable regardless of dynamic colour.
abstract final class AccentPalette {
  static const colors = <Color>[
    Color(0xFF9E9E9E), // gray
    Color(0xFF3DC23D), // green
    Color(0xFFFCD98A), // sand
    Color(0xFFA8DB2C), // lime
    Color(0xFFFF4F81), // pink
    Color(0xFF7C5CFC), // purple
    Color(0xFFFF8A3D), // orange
    Color(0xFF4FC3F7), // sky
    Color(0xFF26C6A6), // teal
  ];

  /// Picks black or white content for legibility on [background].
  static Color on(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : _ink;
}

/// The app is dark-first: a calm Material 3 dark theme with the brand yellow
/// as the single accent. The light theme keeps the same structure.
abstract final class AppTheme {
  /// [dynamicSeed] is the system accent colour (Android 12+ wallpaper colour);
  /// when given, the scheme is derived from it instead of the brand palette.
  static ThemeData light([Color? dynamicSeed]) => _build(
    dynamicSeed != null
        ? ColorScheme.fromSeed(seedColor: dynamicSeed)
        : ColorScheme.fromSeed(seedColor: _yellow).copyWith(
            primary: _yellow,
            onPrimary: _ink,
            primaryContainer: const Color(0xFFFFE9A3),
            onPrimaryContainer: _ink,
            secondary: _purple,
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFE4DCFF),
            onSecondaryContainer: _ink,
            tertiary: _pink,
            onTertiary: Colors.white,
            surface: _cream,
            onSurface: _ink,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFF7F3EB),
            surfaceContainer: const Color(0xFFF1ECE2),
            surfaceContainerHigh: const Color(0xFFEBE5D9),
            surfaceContainerHighest: const Color(0xFFE5DECF),
            outline: const Color(0xFF7A7567),
            outlineVariant: const Color(0xFFD6CFBF),
          ),
  );

  static ThemeData dark([Color? dynamicSeed]) => _build(
    dynamicSeed != null
        ? ColorScheme.fromSeed(
            seedColor: dynamicSeed,
            brightness: Brightness.dark,
          )
        : ColorScheme.fromSeed(
            seedColor: _yellow,
            brightness: Brightness.dark,
          ).copyWith(
            primary: _yellow,
            onPrimary: _ink,
            primaryContainer: const Color(0xFF4F3E00),
            onPrimaryContainer: const Color(0xFFFFE9A3),
            secondary: const Color(0xFFB7A4FF),
            onSecondary: _ink,
            tertiary: const Color(0xFFFF7BA1),
            onTertiary: _ink,
            surface: const Color(0xFF121210),
            onSurface: const Color(0xFFEAE6DA),
            onSurfaceVariant: const Color(0xFFB4AFA0),
            surfaceContainerLowest: const Color(0xFF0D0D0B),
            surfaceContainerLow: const Color(0xFF181815),
            surfaceContainer: const Color(0xFF1D1D19),
            surfaceContainerHigh: const Color(0xFF272723),
            surfaceContainerHighest: const Color(0xFF32322D),
            outline: const Color(0xFF8A8678),
            outlineVariant: const Color(0xFF3E3D36),
          ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final brutal = BrutalTheme(
      border: dark ? scheme.onSurface.withValues(alpha: .92) : scheme.onSurface,
      shadow: Colors.black,
      card: dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
    final text = _textTheme(base.textTheme, scheme);
    const slide = SharedAxisPageTransitionsBuilder(
      transitionType: SharedAxisTransitionType.horizontal,
    );

    return base.copyWith(
      textTheme: text,
      extensions: [brutal],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final p in TargetPlatform.values) p: slide},
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: text.labelLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
      popupMenuTheme: const PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme t, ColorScheme scheme) {
    TextStyle? w(TextStyle? s, FontWeight weight, {double? ls, double? h}) =>
        s?.copyWith(fontWeight: weight, letterSpacing: ls, height: h);
    return t
        .copyWith(
          displayMedium: w(t.displayMedium, FontWeight.w800, ls: -1.5, h: 1.05),
          displaySmall: w(t.displaySmall, FontWeight.w800, ls: -1, h: 1.08),
          headlineLarge: w(t.headlineLarge, FontWeight.w700, ls: -0.8),
          headlineMedium: w(t.headlineMedium, FontWeight.w700, ls: -0.5),
          headlineSmall: w(t.headlineSmall, FontWeight.w700, ls: -0.3),
          titleLarge: w(t.titleLarge, FontWeight.w700, ls: -0.2),
          titleMedium: w(t.titleMedium, FontWeight.w700, ls: 0),
          titleSmall: w(t.titleSmall, FontWeight.w600),
          labelLarge: w(t.labelLarge, FontWeight.w700),
          labelMedium: w(t.labelMedium, FontWeight.w600, ls: 0.2),
          labelSmall: w(t.labelSmall, FontWeight.w700, ls: 0.4),
          bodyLarge: w(t.bodyLarge, FontWeight.w500, ls: 0),
          bodyMedium: w(t.bodyMedium, FontWeight.w500, ls: 0),
          bodySmall: w(t.bodySmall, FontWeight.w500, ls: 0.1),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
