import 'package:flutter/material.dart';

/// Material Design 3 theme for the Pomodoro app.
///
/// Relies entirely on Flutter's built-in M3 implementation:
/// [ColorScheme.fromSeed] generates the full role-based color system,
/// and `useMaterial3: true` activates the correct component defaults
/// (NavigationBar, NavigationRail, FAB, Card, etc.) with proper
/// typography, shapes, and elevation — no manual overrides needed.
abstract final class AppTheme {
  /// A tomato-red seed that matches the Pomodoro brand.
  static const Color _seed = Color(0xFFC62828);

  /// Curated tonal palettes so primary/secondary/tertiary stand apart.
  static const Color _secondarySeed = Color(0xFF006A6A);
  static const Color _tertiarySeed = Color(0xFF7D5260);

  /// The 15-role Material 3 type scale exactly as Flutter's built-in M3
  /// typography defines it (display 57/45/36, headline 32/28/24,
  /// title 22/16/14, body 16/14/12, label 14/12/11, per the M3 type scale
  /// tokens). Geometry lives in [Typography.englishLike]; color-only platform
  /// themes are merged in at `Theme.of` time. Exposed so callers can reference
  /// spec values without hand-rolling sizes or weights.
  ///
  /// This is the untouched token scale and is what `test/theme_test.dart`
  /// asserts against. The theme actually installed by [light] / [dark] layers
  /// one extra typographic feature on top — see [_tabularDigits].
  static TextTheme get typeScale => Typography.material2021().englishLike;

  /// Equal-width digits, applied to every role in the theme.
  ///
  /// The app is full of numbers that change while you look at them: the
  /// countdown ticks every second, the stats page re-renders totals, the
  /// session dots count up. With proportional figures those glyphs have
  /// differing advance widths, so the text visibly jitters sideways on each
  /// change — most obviously on `MM:SS`, where the colon makes every digit
  /// shift. `tabularFigures` fixes the advance width so only the glyphs
  /// change, never the layout.
  ///
  /// This is a font *feature*, not a size or weight override, so the M3 type
  /// scale itself is untouched.
  static const List<FontFeature> _tabularDigits = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The four-character OpenType tag that enables tabular figures.
  static const String _tabularTag = 'tnum';

  /// Applies [_tabularDigits] to every role of [base].
  ///
  /// `TextTheme.apply` has no `fontFeatures` parameter, so the roles are mapped
  /// by hand. Any features a role already carries are preserved; an existing
  /// `tnum` is replaced rather than duplicated.
  static TextTheme _withTabularDigits(TextTheme base) => TextTheme(
        displayLarge: _digits(base.displayLarge),
        displayMedium: _digits(base.displayMedium),
        displaySmall: _digits(base.displaySmall),
        headlineLarge: _digits(base.headlineLarge),
        headlineMedium: _digits(base.headlineMedium),
        headlineSmall: _digits(base.headlineSmall),
        titleLarge: _digits(base.titleLarge),
        titleMedium: _digits(base.titleMedium),
        titleSmall: _digits(base.titleSmall),
        bodyLarge: _digits(base.bodyLarge),
        bodyMedium: _digits(base.bodyMedium),
        bodySmall: _digits(base.bodySmall),
        labelLarge: _digits(base.labelLarge),
        labelMedium: _digits(base.labelMedium),
        labelSmall: _digits(base.labelSmall),
      );

  static TextStyle? _digits(TextStyle? style) {
    if (style == null) return null;
    final existing = style.fontFeatures ?? const <FontFeature>[];
    return style.copyWith(fontFeatures: <FontFeature>[
      ...existing.where((f) => f.feature != _tabularTag),
      ..._tabularDigits,
    ]);
  }

  /// Resolves every role's colour to its M3 colour role.
  ///
  /// `Typography.material2021().englishLike` carries geometry only — every
  /// colour comes back null — so text ends up inheriting whatever
  /// `DefaultTextStyle` happens to be in scope. That is fragile: it made the
  /// largest text in the app (the countdown, `displayLarge`) inherit a colour
  /// that is unreadable on the light surface, and it leaves dark mode resting
  /// on the same accident.
  ///
  /// M3 assigns `onSurface` to the display/headline/title/body roles and
  /// `onSurfaceVariant` to the label roles, so that mapping is applied here
  /// once instead of per widget.
  static TextTheme _withColors(TextTheme base, ColorScheme scheme) => TextTheme(
        displayLarge: _tinted(base.displayLarge, scheme.onSurface),
        displayMedium: _tinted(base.displayMedium, scheme.onSurface),
        displaySmall: _tinted(base.displaySmall, scheme.onSurface),
        headlineLarge: _tinted(base.headlineLarge, scheme.onSurface),
        headlineMedium: _tinted(base.headlineMedium, scheme.onSurface),
        headlineSmall: _tinted(base.headlineSmall, scheme.onSurface),
        titleLarge: _tinted(base.titleLarge, scheme.onSurface),
        titleMedium: _tinted(base.titleMedium, scheme.onSurface),
        titleSmall: _tinted(base.titleSmall, scheme.onSurface),
        bodyLarge: _tinted(base.bodyLarge, scheme.onSurface),
        bodyMedium: _tinted(base.bodyMedium, scheme.onSurface),
        bodySmall: _tinted(base.bodySmall, scheme.onSurface),
        labelLarge: _tinted(base.labelLarge, scheme.onSurfaceVariant),
        labelMedium: _tinted(base.labelMedium, scheme.onSurfaceVariant),
        labelSmall: _tinted(base.labelSmall, scheme.onSurfaceVariant),
      );

  static TextStyle? _tinted(TextStyle? style, Color color) =>
      style?.copyWith(color: color);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      textTheme: _withColors(_withTabularDigits(typeScale), scheme),
    );
  }
}
