import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/models/focus_stats_store.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:pomodoro_app/src/screens/main_shell.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:pomodoro_app/src/timer/pomodoro_timer.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:pomodoro_app/src/widgets/active_timer_capsule.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() {
    now = DateTime(2024, 1, 1, 12, 0, 0);
  });

  PomodoroTimer makeTimer() {
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25),
      clock: clock,
    );
    addTearDown(timer.dispose);
    return timer;
  }

  Widget wrap(PomodoroTimer timer, {required VoidCallback onTap}) {
    return ChangeNotifierProvider.value(
      value: timer,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ActiveTimerCapsule(onTap: onTap),
        ),
      ),
    );
  }

  testWidgets('hidden when the timer is not running', (tester) async {
    final timer = makeTimer();
    await tester.pumpWidget(wrap(timer, onTap: () {}));
    expect(find.byType(ActiveTimerCapsule), findsOneWidget);
    expect(find.textContaining('专注'), findsNothing);
  });

  testWidgets('shows phase + remaining time while running', (tester) async {
    final timer = makeTimer();
    await tester.pumpWidget(wrap(timer, onTap: () {}));

    timer.start();
    await tester.pump();
    expect(find.text('专注 25:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 5));
    timer.tick();
    await tester.pump();
    expect(find.text('专注 20:00'), findsOneWidget);

    timer.pause(); // stop the periodic ticker before the test ends
  });

  testWidgets('tap jumps back to the timer page via onTap', (tester) async {
    final timer = makeTimer();
    var tapped = false;
    await tester.pumpWidget(wrap(timer, onTap: () => tapped = true));

    timer.start();
    await tester.pump();
    await tester.tap(find.byType(ActiveTimerCapsule));
    expect(tapped, isTrue);

    timer.pause(); // stop the periodic ticker before the test ends
  });

  testWidgets('hidden again after pausing', (tester) async {
    final timer = makeTimer();
    await tester.pumpWidget(wrap(timer, onTap: () {}));
    timer.start();
    await tester.pump();
    expect(find.text('专注 25:00'), findsOneWidget);

    timer.pause();
    await tester.pump();
    expect(find.textContaining('专注'), findsNothing);
  });

  Widget shell(PomodoroTimer timer) {
    SharedPreferences.setMockInitialValues({});
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timer),
        ChangeNotifierProvider.value(value: TodoStore()),
        ChangeNotifierProvider.value(value: FocusStatsStore()),
        ChangeNotifierProvider.value(
          value: AmbientPlayer(engine: _StubAmbientEngine()),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const MainShell()),
    );
  }

  testWidgets('MainShell uses NavigationBar narrow / NavigationRail wide',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final timer = makeTimer();

    // Narrow (< 840): bottom NavigationBar.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpWidget(shell(timer));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Wide (>= 840): left NavigationRail.
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpWidget(shell(timer));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('MainShell shows the capsule on another tab while running',
      (tester) async {
    final timer = makeTimer();
    await tester.pumpWidget(shell(timer));

    // Switch to the todo tab (scoped to the NavigationBar to avoid matching the
    // TodoScreen app-bar title inside the IndexedStack).
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('待办'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_navIndex(tester), 1);
    expect(find.textContaining('专注'), findsNothing);

    // Start the timer while on the todo tab: the capsule floats above.
    timer.start();
    await tester.pump();
    expect(find.text('专注 25:00'), findsOneWidget);

    // Tapping it jumps back to the timer page (index 0).
    await tester.tap(find.text('专注 25:00'));
    await tester.pump();
    expect(_navIndex(tester), 0);

    timer.pause(); // stop the periodic ticker before the test ends
  });
}

int _navIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

/// Silent engine stub so tests don't need an audio device.
class _StubAmbientEngine implements AmbientEngine {
  @override
  Future<void> init() async {}

  @override
  Future<void> loadTrack(AmbientTrack track) async {}

  @override
  void pause() {}

  @override
  void play() {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> playChime() async {}

  @override
  Future<void> dispose() async {}
}
