// Generates reference screenshots for visual review.
//
// This file deliberately contains NO `expect(..., matchesGoldenFile(...))`
// assertions. PNG rendering differs between machines (font rasterisation,
// GPU/skia build), so a golden assertion turns every Flutter upgrade into a
// wall of false failures. The PNGs are here as *reference images to look at*,
// regenerated on demand —
//
//   GOLDEN_WRITE=1 flutter test test/golden_shots_test.dart
//
// and reviewed side by side, not as an automatic gate.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/models/focus_stats_store.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:pomodoro_app/src/screens/main_shell.dart';
import 'package:pomodoro_app/src/settings/settings_controller.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:pomodoro_app/src/timer/pomodoro_timer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether to write PNGs. Read from the environment rather than a
/// `--dart-define`, which does not reach the test isolate.
final bool _write = Platform.environment['GOLDEN_WRITE'] == '1';

/// Widths that exercise compact, medium and expanded layouts.
const List<double> _widths = <double>[390, 840, 1440];

const double _height = 900;

/// Destinations in [MainShell] order.
const List<String> _destinations = <String>['计时', '待办', '统计', '历史'];

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() {
    now = DateTime(2024, 1, 1, 12, 0, 0);
    SharedPreferences.setMockInitialValues({});
  });

  /// Deterministic state so the screenshots are comparable run to run: a
  /// timer partway through a focus session, a mix of done and pending todos,
  /// and three weeks of history.
  Future<List<Widget>> buildApp() async {
    final prefs = await SharedPreferences.getInstance();

    final timer = PomodoroTimer(
      const PomodoroSettings(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        sessionsBeforeLongBreak: 4,
      ),
      clock: clock,
    );
    timer.start();
    now = now.add(const Duration(minutes: 6, seconds: 24));
    timer.tick();
    // Pause again right away: the screenshot only needs the remaining time to
    // read as part-way through a session, and a live periodic ticker would be
    // still pending when the widget tree is torn down.
    timer.pause();
    addTearDown(timer.dispose);

    final todoStore = TodoStore();
    await todoStore.load(prefs);
    todoStore
      ..add('重构设置模块')
      ..add('写周报')
      ..add('给妈回电话')
      ..add('买咖啡豆');
    todoStore.toggle(todoStore.items[3].id);
    addTearDown(todoStore.dispose);

    final stats = FocusStatsStore(clock: clock);
    await stats.load(prefs);
    for (var day = 1; day <= 21; day++) {
      await stats.record(
        DateTime(2023, 12, 11 + day),
        day.isEven ? 50 : 100,
      );
    }
    addTearDown(stats.dispose);

    final settings = SettingsController();
    await settings.load(prefs);
    addTearDown(settings.dispose);

    final ambient = AmbientPlayer(engine: _SilentEngine());
    await ambient.init();

    Widget app({required Brightness brightness}) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: timer),
            ChangeNotifierProvider.value(value: todoStore),
            ChangeNotifierProvider.value(value: stats),
            ChangeNotifierProvider.value(value: ambient),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode:
                brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            home: const MainShell(),
          ),
        );

    return [
      for (final brightness in Brightness.values) app(brightness: brightness),
    ];
  }

  testWidgets('capture every screen at every width, in both brightnesses',
      (tester) async {
    final apps = await buildApp();

    for (final brightness in Brightness.values) {
      for (final width in _widths) {
        tester.view.physicalSize = Size(width, _height);
        tester.view.devicePixelRatio = 1.0;

        for (var index = 0; index < _destinations.length; index++) {
          final label = _destinations[index];
          await tester.pumpWidget(apps[brightness.index]);
          await tester.pumpAndSettle();

          // Tap the destination label in whichever navigation affordance this
          // width renders.
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();

          final tone = brightness == Brightness.dark ? 'dark' : 'light';
          final name =
              'shots/${label}_${width.round()}w_$tone.png';

          if (_write) {
            await expectLater(
              find.byType(MainShell),
              matchesGoldenFile(name),
            );
          }
        }
      }
    }
    tester.view.reset();
  });
}

/// Audio engine stub: the screenshots must not need a sound device.
class _SilentEngine implements AmbientEngine {
  @override
  Future<void> init() async {}

  @override
  Future<void> loadTrack(AmbientTrack track) async {}

  @override
  void play() {}

  @override
  void pause() {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> playChime() async {}

  @override
  Future<void> dispose() async {}
}