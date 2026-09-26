import 'package:flutter/material.dart';

/// Colour tokens shared with the Bubble Tea TUI (internal/tui/model.go) and
/// the design canvas. Every screen reads from here, never from literals.
class PvColors {
  const PvColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline,
    required this.outlineSubtle,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceSubtle,
    required this.primary,
    required this.onPrimary,
    required this.tertiary,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.terminal,
  });

  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color outline;
  final Color outlineSubtle;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSurfaceSubtle;
  final Color primary; // warm accent: brow, active states, primary button
  final Color onPrimary;
  final Color tertiary; // cool accent: grille, section labels, links
  final Color error;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color terminal; // background of code/terminal blocks

  static const dark = PvColors(
    surface: Color(0xFF120F0D),
    surfaceContainer: Color(0xFF1B1613),
    surfaceContainerHigh: Color(0xFF2A211C),
    outline: Color(0xFF3A2F28),
    outlineSubtle: Color(0xFF2E2520),
    onSurface: Color(0xFFF7EFE4),
    onSurfaceMuted: Color(0xFFC9B8A9),
    onSurfaceSubtle: Color(0xFFA89A8E),
    primary: Color(0xFFF2A36E),
    onPrimary: Color(0xFF1B120C),
    tertiary: Color(0xFF7AD7C7),
    error: Color(0xFFFF8A70),
    errorContainer: Color(0xFF2A1512),
    onErrorContainer: Color(0xFFFF8A70),
    terminal: Color(0xFF0B0908),
  );

  static const light = PvColors(
    surface: Color(0xFFFAF6EF),
    surfaceContainer: Color(0xFFFFFDF8),
    surfaceContainerHigh: Color(0xFFE6D8C7),
    outline: Color(0xFFE2D3C4),
    outlineSubtle: Color(0xFFEDE2D6),
    onSurface: Color(0xFF2D211A),
    onSurfaceMuted: Color(0xFF5F5046),
    onSurfaceSubtle: Color(0xFF6B5B4F),
    primary: Color(0xFFB4531F),
    onPrimary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF0F6B64),
    error: Color(0xFFB42318),
    errorContainer: Color(0xFFFDECEA),
    onErrorContainer: Color(0xFF9A1C12),
    terminal: Color(0xFF1C1917),
  );
}

/// Spacing and radius scale from the canvas.
abstract final class PvSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double page = 40;
}

abstract final class PvRadius {
  static const double control = 10;
  static const double card = 14;
  static const double panel = 16;
}

/// Minimum hit target for every button and row.
const double pvTouchTarget = 44;

/// Window geometry: the "inspector" is a utility window beside a terminal.
const Size pvDefaultWindowSize = Size(640, 760);
const Size pvMinWindowSize = Size(520, 600);
