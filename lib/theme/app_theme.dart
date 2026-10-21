import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'brutal_theme.dart';

const _yellow = Color(0xFFFFC91F);
const _purple = Color(0xFF7C5CFC);
const _pink = Color(0xFFE11D5A);
const _ink = Color(0xFF111111);
const _cream = Color(0xFFFBF8F3);

/// Fixed palette used for collection accents (independent of dynamic colour).
abstract final class CollectionPalette {
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
            surfaceContainerLow: Colors.white,
            surfaceContainer: const Color(0xFFF4EFE6),
            surfaceContainerHigh: const Color(0xFFEFE9DD),
            surfaceContainerHighest: const Color(0xFFE9E2D3),
            outline: _ink,
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
            primaryContainer: const Color(0xFF5A4500),
            onPrimaryContainer: const Color(0xFFFFE9A3),
            secondary: const Color(0xFFB7A4FF),
            onSecondary: _ink,
            tertiary: const Color(0xFFFF7BA1),
            onTertiary: _ink,
            surface: const Color(0xFF1C1B16),
            onSurface: const Color(0xFFF3EDDD),
            // Cards sit lighter than the page so the hard shadow stays visible.
            surfaceContainerLowest: const Color(0xFF2A2921),
            surfaceContainerLow: const Color(0xFF24231C),
            surfaceContainer: const Color(0xFF292820),
            surfaceContainerHigh: const Color(0xFF302F26),
            surfaceContainerHighest: const Color(0xFF38372D),
            outline: const Color(0xFFF3EDDD),
            outlineVariant: const Color(0xFF4A483C),
          ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final brutal = BrutalTheme(
      border: scheme.brightness == Brightness.light
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: .92),
      shadow: Colors.black,
    );
    final side = BorderSide(color: brutal.border, width: brutal.borderWidth);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: side,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );
    final text = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: text,
      extensions: [brutal],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.fuchsia: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.linux: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.macOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.windows: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          elevation: 0,
          textStyle: text.labelLarge,
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          side: side,
          textStyle: text.labelLarge,
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: text.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shape,
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: side,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: side,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: side.copyWith(width: brutal.borderWidth + 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.error,
            width: brutal.borderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.error,
            width: brutal.borderWidth + 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        hintStyle: text.bodyLarge?.copyWith(
          color: scheme.onSurface.withValues(alpha: .6),
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (s) => text.bodyLarge!.copyWith(
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.error)
                ? scheme.error
                : scheme.onSurface,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionColor: scheme.primary.withValues(alpha: .35),
        selectionHandleColor: scheme.onSurface,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        shape: WidgetStatePropertyAll(shape),
        side: WidgetStatePropertyAll(side),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: side,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: brutal.border,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: side,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: side,
        ),
        side: side,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: side,
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surfaceContainerLowest,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          textStyle: text.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(brutal.border),
        trackOutlineWidth: WidgetStatePropertyAll(brutal.borderWidth),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : brutal.border,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerLowest,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1.5,
        space: 1.5,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          headlineLarge: w(t.headlineLarge, FontWeight.w800, ls: -0.8),
          headlineMedium: w(t.headlineMedium, FontWeight.w800, ls: -0.5),
          headlineSmall: w(t.headlineSmall, FontWeight.w800, ls: -0.3),
          titleLarge: w(t.titleLarge, FontWeight.w800, ls: -0.2),
          titleMedium: w(t.titleMedium, FontWeight.w800, ls: 0),
          titleSmall: w(t.titleSmall, FontWeight.w700),
          labelLarge: w(t.labelLarge, FontWeight.w800),
          labelMedium: w(t.labelMedium, FontWeight.w700, ls: 0.2),
          labelSmall: w(t.labelSmall, FontWeight.w800, ls: 0.4),
          bodyLarge: w(t.bodyLarge, FontWeight.w500, ls: 0),
          bodyMedium: w(t.bodyMedium, FontWeight.w500, ls: 0),
          bodySmall: w(t.bodySmall, FontWeight.w500, ls: 0.1),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
