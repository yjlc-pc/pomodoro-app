import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:pomodoro_app/src/widgets/start_todo_sheet.dart';

void main() {
  /// Opens the sheet by tapping a host button and captures the returned choice.
  Future<void> pumpSheet(
    WidgetTester tester,
    TodoStore store,
    _Result result,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    result.value = await showModalBottomSheet<StartTodoChoice>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => const StartTodoSheet(),
                    );
                  },
                  child: const Text('开始'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists unfinished todos but not done ones', (tester) async {
    final store = TodoStore();
    store.add('写周报');
    store.add('修复登录 bug');
    store.add('已完成任务');
    store.toggle(store.items.last.id);

    final result = _Result();
    await pumpSheet(tester, store, result);
    expect(find.text('这次专注要关联哪个待办？'), findsOneWidget);
    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('修复登录 bug'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);

    // Dismiss by tapping the barrier -> null (do not start).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result.value, isNull);
  });

  testWidgets('selecting a todo returns StartWithTodo with its id',
      (tester) async {
    final store = TodoStore();
    store.add('写周报');
    store.add('修复登录 bug');

    final result = _Result();
    await pumpSheet(tester, store, result);
    await tester.tap(find.text('写周报'));
    await tester.pumpAndSettle();

    expect(result.value, isA<StartWithTodo>());
    expect((result.value! as StartWithTodo).id, store.items.first.id);
  });

  testWidgets('skip returns StartWithoutTodo', (tester) async {
    final store = TodoStore();
    store.add('写周报');

    final result = _Result();
    await pumpSheet(tester, store, result);
    await tester.tap(find.text('跳过，不关联直接开始'));
    await tester.pumpAndSettle();

    expect(result.value, isA<StartWithoutTodo>());
  });

  testWidgets('shows empty hint when there are no unfinished todos',
      (tester) async {
    final store = TodoStore();
    final result = _Result();
    await pumpSheet(tester, store, result);
    expect(find.text('没有未完成的待办，直接开始吧'), findsOneWidget);
    expect(find.text('跳过，不关联直接开始'), findsOneWidget);
  });
}

class _Result {
  StartTodoChoice? value;
}
