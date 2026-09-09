import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';

void main() {
  group('M3 type scale', () {
    test('declares all 15 roles with exact spec values', () {
      final ts = AppTheme.typeScale;

      // display
      expect(ts.displayLarge?.fontSize, 57);
      expect(ts.displayLarge?.fontWeight, FontWeight.w400);
      expect(ts.displayLarge?.letterSpacing, -0.25);
      expect(ts.displayMedium?.fontSize, 45);
      expect(ts.displayMedium?.fontWeight, FontWeight.w400);
      expect(ts.displayMedium?.letterSpacing, 0);
      expect(ts.displaySmall?.fontSize, 36);
      expect(ts.displaySmall?.fontWeight, FontWeight.w400);
      expect(ts.displaySmall?.letterSpacing, 0);

      // headline
      expect(ts.headlineLarge?.fontSize, 32);
      expect(ts.headlineLarge?.fontWeight, FontWeight.w400);
      expect(ts.headlineMedium?.fontSize, 28);
      expect(ts.headlineMedium?.fontWeight, FontWeight.w400);
      expect(ts.headlineSmall?.fontSize, 24);
      expect(ts.headlineSmall?.fontWeight, FontWeight.w400);

      // title — per M3 type scale tokens only titleMedium/Small are Medium;
      // titleLarge stays Regular (w400), matching Flutter's englishLike2021.
      expect(ts.titleLarge?.fontSize, 22);
      expect(ts.titleLarge?.fontWeight, FontWeight.w400);
      expect(ts.titleMedium?.fontSize, 16);
      expect(ts.titleMedium?.fontWeight, FontWeight.w500);
      expect(ts.titleMedium?.letterSpacing, 0.15);
      expect(ts.titleSmall?.fontSize, 14);
      expect(ts.titleSmall?.fontWeight, FontWeight.w500);
      expect(ts.titleSmall?.letterSpacing, 0.1);

      // body
      expect(ts.bodyLarge?.fontSize, 16);
      expect(ts.bodyLarge?.fontWeight, FontWeight.w400);
      expect(ts.bodyMedium?.fontSize, 14);
      expect(ts.bodyMedium?.fontWeight, FontWeight.w400);
      expect(ts.bodySmall?.fontSize, 12);
      expect(ts.bodySmall?.fontWeight, FontWeight.w400);

      // label
      expect(ts.labelLarge?.fontSize, 14);
      expect(ts.labelLarge?.fontWeight, FontWeight.w500);
      expect(ts.labelMedium?.fontSize, 12);
      expect(ts.labelMedium?.fontWeight, FontWeight.w500);
      expect(ts.labelSmall?.fontSize, 11);
      expect(ts.labelSmall?.fontWeight, FontWeight.w500);
    });

    test('smallest size is not below 10sp', () {
      final ts = AppTheme.typeScale;
      expect(ts.labelSmall?.fontSize, greaterThanOrEqualTo(10));
    });
  });

  group('color scheme', () {
    test('light theme derives from seed and enables Material 3', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, isNotNull);
    });

    test('dark theme derives from seed and enables Material 3', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, isNotNull);
    });
  });
}
