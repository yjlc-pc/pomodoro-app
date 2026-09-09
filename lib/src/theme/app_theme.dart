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
  static TextTheme get typeScale => Typography.material2021().englishLike;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
    );
  }
}
