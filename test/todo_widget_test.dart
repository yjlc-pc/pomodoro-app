import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:pomodoro_app/src/screens/todo_screen.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:pomodoro_app/src/timer/pomodoro_timer.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  Future<Widget> wrap({
    TodoStore? todoStore,
    double width = 800,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = todoStore ?? TodoStore();
    await store.load(prefs);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(
          value: PomodoroTimer(
            const PomodoroSettings(focusMinutes: 25),
            clock: clock,
          ),
        ),
        ChangeNotifierProvider.value(
          value: AmbientPlayer(engine: _StubAmbientEngine()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const TodoScreen(),
      ),
    );
  }

  setUp(() {
    now = DateTime(2024, 1, 1, 12, 0, 0);
  });

  Future<void> setSurfaceSize(WidgetTester tester, double width,
      [double height = 800]) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows empty state when there are no todos', (tester) async {
    // Tall viewport so the todo section is inside the lazily-built slivers
    // (timer + audio bar occupy the top of the page).
    await setSurfaceSize(tester, 400, 1200);
    await tester.pumpWidget(await wrap());
    await tester.pump();
    expect(find.text('还没有待办，点右下角 + 添加一个吧'), findsOneWidget);
  });

  testWidgets('adds a todo via the FAB dialog', (tester) async {
    await setSurfaceSize(tester, 400, 1200);
    await tester.pumpWidget(await wrap());
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('新增待办'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '完成报告');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('完成报告'), findsOneWidget);
    expect(find.text('还没有待办，点右下角 + 添加一个吧'), findsNothing);
  });

  testWidgets('toggle marks the todo done and moves it below pending ones',
      (tester) async {
    final store = TodoStore();
    store.add('任务A');
    store.add('任务B');
    // Tall narrow viewport so both list items are built (lazy slivers).
    await setSurfaceSize(tester, 400, 1200);
    await tester.pumpWidget(await wrap(todoStore: store));
    await tester.pump();

    // Both pending initially.
    expect(find.text('任务A'), findsOneWidget);
    expect(find.text('任务B'), findsOneWidget);

    // Toggle the first (A) via its checkbox.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(store.items.first.title, '任务B');
    expect(store.items.last.title, '任务A');
    expect(store.items.last.done, isTrue);
  });

  testWidgets('swipe deletes a todo', (tester) async {
    final store = TodoStore();
    store.add('临时任务');
    await setSurfaceSize(tester, 400, 1200);
    await tester.pumpWidget(await wrap(todoStore: store));
    await tester.pump();

    expect(find.text('临时任务'), findsOneWidget);
    await tester.drag(find.text('临时任务'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(store.items, isEmpty);
    expect(find.text('临时任务'), findsNothing);
    expect(find.text('还没有待办，点右下角 + 添加一个吧'), findsOneWidget);
  });

  testWidgets('narrow layout renders list tiles, wide layout renders grid',
      (tester) async {
    final store = TodoStore();
    for (var i = 0; i < 8; i++) {
      store.add('任务$i');
    }

    // Narrow: single-column list.
    await setSurfaceSize(tester, 400);
    await tester.pumpWidget(await wrap(todoStore: store));
    await tester.pump();
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.byType(Card), findsNothing);

    // Wide: multi-column grid.
    await setSurfaceSize(tester, 1200);
    await tester.pumpWidget(await wrap(todoStore: store));
    await tester.pump();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Card), findsWidgets);
  });
}

/// Silent engine stub so todo tests don't need an audio device.
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
