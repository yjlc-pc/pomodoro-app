import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/screens/settings_screen.dart';
import 'package:pomodoro_app/src/settings/settings_controller.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:pomodoro_app/src/timer/pomodoro_timer.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() {
    now = DateTime(2024, 1, 1, 12, 0, 0);
  });

  Future<Widget> wrap(PomodoroTimer timer, SharedPreferences prefs) async {
    addTearDown(timer.dispose);
    final settingsController = SettingsController();
    addTearDown(settingsController.dispose);
    await settingsController.load(prefs);
    // Mirror main()'s wiring: the controller drives the timer, so the page has
    // no direct handle on the timer at all.
    settingsController
        .addListener(() => timer.applySettings(settingsController.settings));
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timer),
        ChangeNotifierProvider.value(value: settingsController),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const SettingsScreen(),
      ),
    );
  }

  testWidgets('changing the focus slider stays on the page and applies',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25),
      clock: clock,
    );
    await tester.pumpWidget(await wrap(timer, prefs));
    await tester.pump();

    // The focus-duration slider is the first one on the page.
    final slider = find.byType(Slider).first;
    final before = tester.widget<Slider>(slider).value;
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle();

    // Regression: saving used to Navigator.pop() the screen away on every
    // change, closing settings after a single slider touch.
    expect(find.text('设置'), findsOneWidget);
    expect(find.byType(Slider), findsWidgets);
    expect(timer.settings.focusMinutes, greaterThan(before.round()));
    expect(prefs.getInt('focus_minutes'),
        timer.settings.focusMinutes);
  });

  testWidgets('toggling a switch stays on the page and persists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25, soundEnabled: true),
      clock: clock,
    );
    await tester.pumpWidget(await wrap(timer, prefs));
    await tester.pump();

    // Scroll to the "提示音" switch which is below the fold.
    await tester.scrollUntilVisible(find.text('提示音'), 100);
    await tester.tap(find.text('提示音'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(timer.settings.soundEnabled, isFalse);
    expect(prefs.getBool('sound_enabled'), isFalse);
  });
}
