import 'package:flutter/material.dart';

import '../sim/genome.dart';

/// Colours and type. Warm ink and cream, with one accent per trait.
abstract final class Palette {
  static const ink = Color(0xFF09080E);
  static const surface = Color(0xFF120F14);
  static const raised = Color(0xFF1B161B);
  static const line = Color(0x1AF5ECE0);
  static const lineStrong = Color(0x33F5ECE0);
  static const cream = Color(0xFFF5ECE0);
  static const muted = Color(0xFFB8ADA4);
  static const faint = Color(0xFF7A716B);
  static const gold = Color(0xFFC9A453);
  static const terracotta = Color(0xFFD37B59);
  static const rust = Color(0xFFAA4838);
  static const food = Color(0xFF8FB996);
  static const steel = Color(0xFF86A8C8);

  static Color trait(Trait trait) => switch (trait) {
    Trait.size => terracotta,
    Trait.speed => gold,
    Trait.sense => steel,
  };
}

abstract final class Styles {
  static const mono = 'Space Mono';
  static const display = 'Space Grotesk';
  static const body = 'DM Sans';

  /// Small uppercase label, used for section headings and readouts.
  static const label = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: Palette.muted,
  );

  static const readout = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    color: Palette.cream,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.gold,
    onPrimary: Palette.surface,
    secondary: Palette.terracotta,
    onSecondary: Palette.surface,
    surface: Palette.surface,
    onSurface: Palette.cream,
    outline: Palette.lineStrong,
    outlineVariant: Palette.line,
    error: Palette.rust,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: Styles.body);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.ink,
    dividerColor: Palette.line,
    textTheme: base.textTheme
        .apply(bodyColor: Palette.cream, displayColor: Palette.cream)
        .copyWith(
          titleLarge: const TextStyle(
            fontFamily: Styles.display,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: -0.6,
            color: Palette.cream,
          ),
          titleMedium: const TextStyle(
            fontFamily: Styles.display,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.3,
            color: Palette.cream,
          ),
          bodyMedium: const TextStyle(fontFamily: Styles.body, fontSize: 14, height: 1.45, color: Palette.cream),
          bodySmall: const TextStyle(fontFamily: Styles.body, fontSize: 12.5, height: 1.4, color: Palette.muted),
          labelLarge: const TextStyle(fontFamily: Styles.body, fontSize: 14, fontWeight: FontWeight.w600),
        ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.gold,
      inactiveTrackColor: Palette.lineStrong,
      thumbColor: Palette.gold,
      overlayColor: Color(0x22C9A453),
      trackHeight: 2,
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.surface : Palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.gold : Palette.raised,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Palette.lineStrong),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Palette.raised, borderRadius: BorderRadius.all(Radius.circular(4))),
      textStyle: TextStyle(fontSize: 12, color: Palette.cream),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.raised,
      contentTextStyle: TextStyle(color: Palette.cream, fontFamily: Styles.body),
      behavior: SnackBarBehavior.floating,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Palette.cream,
      unselectedLabelColor: Palette.faint,
      indicatorColor: Palette.gold,
      dividerColor: Palette.line,
      labelStyle: Styles.label,
      unselectedLabelStyle: Styles.label,
    ),
  );
}
