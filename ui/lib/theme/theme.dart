import 'package:flutter/material.dart';

import 'tokens.dart';

/// Family names declared in pubspec.yaml (bundled under assets/fonts/).
const String pvSansFamily = 'IBM Plex Sans';
const String pvMonoFamily = 'IBM Plex Mono';

/// How long a confirmation SnackBar ("Copied") stays up.
const Duration pvSnackBarDuration = Duration(milliseconds: 1600);

/// Outline of secondary buttons: a touch stronger than [PvColors.outline].
const Color _buttonOutlineDark = Color(0xFF5A493F);
const Color _buttonOutlineLight = Color(0xFFD8C6B4);

/// Carries [PvColors] through [ThemeData.extensions] so a subtree can
/// override the tokens with a nested [Theme].
@immutable
class PvColorsExtension extends ThemeExtension<PvColorsExtension> {
  const PvColorsExtension(this.colors);

  final PvColors colors;

  @override
  PvColorsExtension copyWith({PvColors? colors}) =>
      PvColorsExtension(colors ?? this.colors);

  @override
  PvColorsExtension lerp(PvColorsExtension? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// `context.pv` gives the colour tokens for the current brightness.
extension PvColorsX on BuildContext {
  PvColors get pv {
    final theme = Theme.of(this);
    return theme.extension<PvColorsExtension>()?.colors ??
        (theme.brightness == Brightness.dark ? PvColors.dark : PvColors.light);
  }
}

/// IBM Plex Mono at [size], for every path, command and code sample.
TextStyle pvMono(
  BuildContext context, {
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontFamily: pvMonoFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color ?? context.pv.onSurface,
  );
}

/// The app theme for [brightness], built from [PvColors].
ThemeData pvTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? PvColors.dark : PvColors.light;
  final buttonOutline = dark ? _buttonOutlineDark : _buttonOutlineLight;
  final fieldFill = dark ? c.surfaceContainer : Colors.white;

  final scheme = ColorScheme(
    brightness: brightness,
    surface: c.surface,
    onSurface: c.onSurface,
    onSurfaceVariant: c.onSurfaceMuted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surfaceContainer,
    surfaceContainer: c.surfaceContainer,
    surfaceContainerHigh: c.surfaceContainerHigh,
    surfaceContainerHighest: c.surfaceContainerHigh,
    outline: c.outline,
    outlineVariant: c.outlineSubtle,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    tertiary: c.tertiary,
    onTertiary: c.surface,
    error: c.error,
    onError: c.surface,
    errorContainer: c.errorContainer,
    onErrorContainer: c.onErrorContainer,
    inverseSurface: c.onSurface,
    onInverseSurface: c.surface,
  );

  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: pvSansFamily,
    useMaterial3: true,
  );

  final text = base.textTheme
      .copyWith(
        headlineSmall: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.28,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 15, height: 1.45),
        bodySmall: const TextStyle(fontSize: 13, height: 1.4),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
        labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      )
      .apply(
        fontFamily: pvSansFamily,
        bodyColor: c.onSurface,
        displayColor: c.onSurface,
      );

  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(PvRadius.control)),
  );
  const buttonSize = Size(64, pvTouchTarget);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18);
  const buttonText = TextStyle(
    fontFamily: pvSansFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(PvRadius.control),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.surface,
    canvasColor: c.surface,
    dividerColor: c.outlineSubtle,
    textTheme: text,
    extensions: [PvColorsExtension(c)],
    dividerTheme: DividerThemeData(color: c.outlineSubtle, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleMedium,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.onSurface,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: controlShape,
        side: BorderSide(color: buttonOutline),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.tertiary,
        minimumSize: const Size(48, pvTouchTarget),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      isDense: false,
      constraints: const BoxConstraints(minHeight: 44, maxHeight: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.onSurfaceSubtle),
      border: field(c.outline, 1),
      enabledBorder: field(c.outline, 1),
      focusedBorder: field(c.tertiary, 2),
      errorBorder: field(c.error, 2),
      focusedErrorBorder: field(c.error, 2),
      errorStyle: TextStyle(color: c.error),
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PvRadius.card),
        side: BorderSide(color: c.outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.onSurface,
      contentTextStyle: TextStyle(
        fontFamily: pvSansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: c.surface,
      ),
      shape: const StadiumBorder(),
      elevation: 2,
      insetPadding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? c.onPrimary : c.onSurfaceMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.primary
            : c.surfaceContainerHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? c.primary : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.onPrimary),
      side: BorderSide(color: buttonOutline, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: c.surfaceContainerHigh,
        selectedForegroundColor: c.onSurface,
        foregroundColor: c.onSurfaceMuted,
        side: BorderSide(color: c.outline),
        minimumSize: const Size(0, pvTouchTarget),
        textStyle: buttonText,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.onSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: c.surface, fontSize: 12),
    ),
  );
}

/// Shows a floating pill SnackBar with [message]; replaces any current one.
void showPvSnackBar(
  BuildContext context,
  String message, {
  Duration duration = pvSnackBarDuration,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message), duration: duration));
}
