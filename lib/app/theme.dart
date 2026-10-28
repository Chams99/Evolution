import 'package:flutter/material.dart';

import '../sim/genome.dart';

/// The colour system. Every colour in the app comes from here and has one job:
///
/// * Neutrals (ink, surface, cream, muted, faint) carry the interface.
/// * [gold] is the only accent: buttons, selection, trait data.
/// * [terracotta] is the only alert: deaths, crashes, the UV pulse.
/// * [food] is the only green: algae, on the slide and in the charts.
/// * Family stains (see microbes.dart) are data colours with equal lightness
///   and chroma, and none of them is green.
/// * [Slide] holds the microscope view, warm ivory to match the cream.
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

  /// Algae green, lifted slightly so it reads on the dark panels.
  static const food = Color(0xFF79A866);

  /// Overlay chips on the live view.
  static const hud = Color(0xBF09080E);

  /// Traits share the accent; they are told apart by icon and label.
  static Color trait(Trait trait) => gold;

  static IconData traitIcon(Trait trait) => switch (trait) {
    Trait.size => Icons.open_in_full,
    Trait.speed => Icons.speed,
    Trait.sense => Icons.visibility_outlined,
  };
}

/// Colours of the slide under the lamp. Warm ivory, the same family as the
/// interface's cream, so the live view and the panels belong together.
abstract final class Slide {
  static const bright = Color(0xFFF4F0E7);
  static const brightEdge = Color(0xFFD9D0C1);
  static const dim = Color(0xFFD4D0C8);
  static const dimEdge = Color(0xFFABA397);
  static const ink = Color(0xFF2D2421);
  static const eyespot = Color(0xFFD25030);
  static const algae = Color(0xFF5E904D);
  static const algaeRim = Color(0xFF3B612D);
  static const ghost = Color(0xFF8B867E);
  static const debris = Color(0xFF6E6457);
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
    error: Palette.terracotta,
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
