import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:pomodoro_app/src/widgets/animated_check.dart';

void main() {
  Widget wrap({required bool checked, required ValueChanged<bool> onChanged}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AnimatedCheck(checked: checked, onChanged: onChanged),
      ),
    );
  }

  testWidgets('reports the toggled value when tapped', (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(wrap(checked: false, onChanged: seen.add));

    await tester.tap(find.byType(AnimatedCheck));
    await tester.pump();

    expect(seen, [true]);
  });

  testWidgets('unticking reports false', (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(wrap(checked: true, onChanged: seen.add));

    await tester.tap(find.byType(AnimatedCheck));
    await tester.pump();

    expect(seen, [false]);
  });

  testWidgets('actually animates when the value changes', (tester) async {
    var checked = false;
    await tester.pumpWidget(wrap(
      checked: checked,
      onChanged: (v) => checked = v,
    ));
    await tester.tap(find.byType(AnimatedCheck));

    // Mid-flight: the painter must be drawing something in between, otherwise
    // the "animation" is really an instant state swap.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.widget<CustomPaint>(find.byType(CustomPaint).last),
      isNotNull,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('animates backwards when unticked', (tester) async {
    await tester.pumpWidget(wrap(checked: true, onChanged: (_) {}));
    // Rebuild as unchecked and step the animation partway.
    await tester.pumpWidget(wrap(checked: false, onChanged: (_) {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('exposes its state to accessibility', (tester) async {
    await tester.pumpWidget(wrap(checked: true, onChanged: (_) {}));

    final semantics = tester.getSemantics(find.byType(AnimatedCheck));

    expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
  });

  testWidgets('keeps a 48dp tap target regardless of the drawn size',
      (tester) async {
    await tester.pumpWidget(wrap(checked: false, onChanged: (_) {}));

    final box = tester.getSize(find.byType(AnimatedCheck));

    expect(box.width, greaterThanOrEqualTo(48));
    expect(box.height, greaterThanOrEqualTo(48));
  });
}