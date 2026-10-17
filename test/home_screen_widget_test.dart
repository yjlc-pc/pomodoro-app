import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:pomodoro_app/src/screens/timer_screen.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:pomodoro_app/src/timer/pomodoro_timer.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  Widget wrap(PomodoroTimer timer, {TodoStore? todoStore}) {
    addTearDown(timer.dispose);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timer),
        ChangeNotifierProvider.value(value: todoStore ?? TodoStore()),
        ChangeNotifierProvider.value(
          value: AmbientPlayer(engine: _StubAmbientEngine()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: TimerScreen(onOpenSettings: () {}),
      ),
    );
  }

  setUp(() {
    now = DateTime(2024, 1, 1, 12, 0, 0);
  });

  testWidgets('skip button advances from focus to short break', (tester) async {
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25, shortBreakMinutes: 5),
      clock: clock,
    );
    await tester.pumpWidget(wrap(timer));
    await tester.pump();

    // Initial: focus, 25:00, button shows 开始.
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('保持专注'), findsOneWidget);

    // Tap the skip icon button.
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();

    expect(timer.phase, PomodoroPhase.shortBreak);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('休息一下'), findsOneWidget);
  });

  testWidgets('start opens the todo sheet; picking skip starts the timer',
      (tester) async {
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25),
      clock: clock,
    );
    await tester.pumpWidget(wrap(timer));
    await tester.pump();

    // Initial: not running.
    expect(find.text('开始'), findsOneWidget);

    // Tapping 开始 opens the link-todo sheet first.
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    expect(find.text('这次专注要关联哪个待办？'), findsOneWidget);

    // "跳过" starts without a linked todo.
    await tester.tap(find.text('跳过，不关联直接开始'));
    await tester.pumpAndSettle();

    expect(timer.running, isTrue);
    expect(timer.linkedTodoId, isNull);
    expect(find.text('暂停'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(timer.running, isFalse);
    expect(find.text('开始'), findsOneWidget);
  });

  testWidgets('picking a todo links it to the focus', (tester) async {
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25),
      clock: clock,
    );
    final store = TodoStore();
    store.add('写周报');
    await tester.pumpWidget(wrap(timer, todoStore: store));
    await tester.pump();

    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写周报'));
    await tester.pumpAndSettle();

    expect(timer.running, isTrue);
    expect(timer.linkedTodoId, store.items.first.id);
    expect(find.text('正在专注：写周报'), findsOneWidget);

    timer.pause(); // stop the periodic ticker before the test ends
  });

  testWidgets('reset button restores full duration', (tester) async {
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25),
      clock: clock,
    );
    await tester.pumpWidget(wrap(timer));
    await tester.pump();

    // Run 5 seconds then reset.
    timer.start();
    now = now.add(const Duration(seconds: 5));
    timer.tick();
    await tester.pump();
    expect(find.text('24:55'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();
    expect(timer.remaining, const Duration(minutes: 25));
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('UI switches to rest when focus completes', (tester) async {
    final timer = PomodoroTimer(
      const PomodoroSettings(focusMinutes: 25, shortBreakMinutes: 5),
      clock: clock,
    );
    await tester.pumpWidget(wrap(timer));
    await tester.pump();

    timer.start();
    // Drive the focus to completion by advancing the injected clock and the
    // widget-tree fake clock in lockstep (25 minutes in 5-second steps).
    for (var i = 0; i < 300; i++) {
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
    }

    expect(timer.phase, PomodoroPhase.shortBreak);
    // Regression: the UI must be notified of the phase change even though
    // autoStartBreaks is off, otherwise it stays frozen on the focus phase.
    expect(find.text('休息一下'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
  });
}

/// Silent engine stub so TimerScreen tests don't need an audio device.
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
