import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colours that Material's [ColorScheme] has no slot for.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.sheet,
    required this.ink,
    required this.inkSoft,
    required this.highlighter,
    required this.onHighlighter,
    required this.rule,
    required this.error,
  });

  final Color paper;
  final Color sheet;
  final Color ink;
  final Color inkSoft;
  final Color highlighter;
  final Color onHighlighter;
  final Color rule;
  final Color error;

  static const light = Palette(
    paper: Color(0xFFF4F6F9),
    sheet: Color(0xFFFFFFFF),
    ink: Color(0xFF1D2B4F),
    inkSoft: Color(0xFF566079),
    highlighter: Color(0xFFFFE45C),
    onHighlighter: Color(0xFF1D2B4F),
    rule: Color(0xFFD5DCE6),
    error: Color(0xFFB4322A),
  );

  static const dark = Palette(
    paper: Color(0xFF161E2E),
    sheet: Color(0xFF1F293C),
    ink: Color(0xFFE7EBF3),
    inkSoft: Color(0xFFA3AEC4),
    highlighter: Color(0xFFF2DC57),
    onHighlighter: Color(0xFF161E2E),
    rule: Color(0xFF33405A),
    error: Color(0xFFFF9C8F),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    return Palette(
      paper: Color.lerp(paper, other.paper, t)!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      highlighter: Color.lerp(highlighter, other.highlighter, t)!,
      onHighlighter: Color.lerp(onHighlighter, other.onHighlighter, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// Spacing on a 4/8 rhythm.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const huge = 48.0;

  /// Horizontal page gutter for the given width.
  static double gutter(double width) => width >= 840
      ? 48
      : width >= 600
      ? 32
      : 20;

  /// Comfortable reading measure.
  static const measure = 640.0;
}

/// Recursive, set in two voices.
///
/// Recursive's weight axis defaults to 300, so every style sets `wght`
/// explicitly along with `CASL` (0 = linear, 1 = casual).
abstract final class TypeScale {
  static const family = 'Recursive';

  static TextStyle _style({
    required double size,
    required double weight,
    required double casual,
    required double height,
    double tracking = 0,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    letterSpacing: tracking,
    fontWeight: _nearestWeight(weight),
    fontVariations: [
      FontVariation('wght', weight),
      FontVariation('CASL', casual),
      const FontVariation('MONO', 0),
      const FontVariation('CRSV', 0.5),
    ],
  );

  static FontWeight _nearestWeight(double w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

  /// Marker voice: screen titles, note titles, the revisit quote.
  static TextStyle casual(
    double size, {
    double weight = 680,
    double height = 1.18,
  }) => _style(
    size: size,
    weight: weight,
    casual: 1,
    height: height,
    tracking: -0.2,
  );

  /// Reading voice.
  static TextStyle linear(
    double size, {
    double weight = 400,
    double height = 1.45,
  }) => _style(size: size, weight: weight, casual: 0, height: height);

  static TextTheme textTheme(Color ink, Color inkSoft) => TextTheme(
    displaySmall: casual(34, weight: 720).copyWith(color: ink),
    headlineMedium: casual(26).copyWith(color: ink),
    headlineSmall: casual(22).copyWith(color: ink),
    titleLarge: linear(20, weight: 600, height: 1.3).copyWith(color: ink),
    titleMedium: linear(17, weight: 580, height: 1.35).copyWith(color: ink),
    titleSmall: linear(15, weight: 580, height: 1.35).copyWith(color: ink),
    bodyLarge: linear(17, height: 1.55).copyWith(color: ink),
    bodyMedium: linear(15, height: 1.45).copyWith(color: ink),
    bodySmall: linear(13, height: 1.4).copyWith(color: inkSoft),
    labelLarge: linear(15, weight: 600, height: 1.2).copyWith(color: ink),
    labelMedium: linear(13, weight: 560, height: 1.2).copyWith(color: ink),
    labelSmall: linear(12, weight: 520, height: 1.2).copyWith(color: inkSoft),
  );
}

/// Shared motion tokens.
abstract final class Motion {
  static const quick = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const highlightStroke = Duration(milliseconds: 380);
  static const highlightStagger = Duration(milliseconds: 140);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.ink,
    onPrimary: c.paper,
    secondary: c.highlighter,
    onSecondary: c.onHighlighter,
    error: c.error,
    onError: c.paper,
    surface: c.paper,
    onSurface: c.ink,
    onSurfaceVariant: c.inkSoft,
    surfaceContainerLowest: c.paper,
    surfaceContainerLow: c.sheet,
    surfaceContainer: c.sheet,
    surfaceContainerHigh: c.sheet,
    surfaceContainerHighest: c.sheet,
    outline: c.inkSoft,
    outlineVariant: c.rule,
    inverseSurface: c.ink,
    onInverseSurface: c.paper,
    primaryContainer: c.highlighter,
    onPrimaryContainer: c.onHighlighter,
    surfaceTint: Colors.transparent,
  );
  final text = TypeScale.textTheme(c.ink, c.inkSoft);
  final overlay = brightness == Brightness.light
      ? SystemUiOverlayStyle.dark
      : SystemUiOverlayStyle.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    fontFamily: TypeScale.family,
    textTheme: text,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    dividerTheme: DividerThemeData(color: c.rule, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.paper,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    ),
    iconTheme: IconThemeData(color: c.ink, size: 24),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.ink,
        foregroundColor: c.paper,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: text.labelLarge,
        side: BorderSide(color: c.inkSoft.withValues(alpha: 0.55)),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.ink,
      foregroundColor: c.paper,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 4,
      extendedTextStyle: text.labelLarge,
      shape: const StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: c.ink,
      labelStyle: text.labelLarge!.copyWith(color: c.ink),
      secondaryLabelStyle: text.labelLarge!.copyWith(color: c.paper),
      side: BorderSide(color: c.rule),
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.sheet,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.rule,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.sheet,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: c.paper),
      actionTextColor: c.highlighter,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.sheet,
      hintStyle: text.bodyLarge!.copyWith(color: c.inkSoft),
      labelStyle: text.bodyMedium!.copyWith(color: c.inkSoft),
      floatingLabelStyle: text.bodyMedium!.copyWith(color: c.ink),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.ink, width: 1.5),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: c.inkSoft, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.paper),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.paper : c.inkSoft,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.ink : c.rule,
      ),
      trackOutlineColor: WidgetStatePropertyAll(c.rule),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.ink,
      linearTrackColor: c.rule,
      circularTrackColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.ink,
      textColor: c.ink,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minVerticalPadding: 12,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.sheet,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: c.ink,
      collapsedIconColor: c.inkSoft,
      textColor: c.ink,
      collapsedTextColor: c.ink,
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
  );
}
