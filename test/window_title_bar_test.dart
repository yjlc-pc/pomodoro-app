import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomodoro_app/src/widgets/window_title_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the window title and control buttons', (tester) async {
    await tester.pumpWidget(wrap(const WindowTitleBar(title: '番茄钟')));

    expect(find.text('番茄钟'), findsOneWidget);
    // Three control buttons: minimize, maximize, close.
    final buttons = find.byType(InkWell);
    expect(buttons, findsNWidgets(3));

    // Default (no injected callbacks) is a no-op in tests — icon still shown.
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('window control buttons fire injected callbacks',
      (tester) async {
    var minimized = 0;
    var maximized = 0;
    var closed = 0;

    await tester.pumpWidget(wrap(WindowTitleBar(
      onMinimize: () => minimized++,
      onMaximize: () => maximized++,
      onClose: () => closed++,
    )));

    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.crop_square));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(minimized, 1);
    expect(maximized, 1);
    expect(closed, 1);
  });

  testWidgets('bar tracks window height for layout', (tester) async {
    expect(kWindowTitleBarHeight, greaterThan(0));

    await tester.pumpWidget(wrap(const WindowTitleBar()));
    final bar = tester.getSize(find.byType(WindowTitleBar));
    expect(bar.height, kWindowTitleBarHeight);
  });
}
