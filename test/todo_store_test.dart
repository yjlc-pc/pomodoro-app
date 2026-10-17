import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/models/todo_item.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TodoItem backwards compatibility', () {
    test('loads a blob written before priority/description/subtasks existed', () {
      // Entries persisted by the previous schema must not throw; missing
      // fields fall back to defaults.
      final legacy = TodoItem.fromJson({
        'id': 'old-1',
        'title': '没有新字段的待办',
        'done': false,
        'createdAt': '2024-01-01T00:00:00.000',
      });

      expect(legacy.title, '没有新字段的待办');
      expect(legacy.priority, TodoPriority.normal);
      expect(legacy.description, isEmpty);
      expect(legacy.subtasks, isEmpty);
    });

    test('unknown priority name falls back to normal', () {
      final item = TodoItem.fromJson({
        'id': 'x',
        'title': 't',
        'done': false,
        'priority': 'urgent-ish',
        'createdAt': '2024-01-01T00:00:00.000',
      });
      expect(item.priority, TodoPriority.normal);
    });
  });

  group('TodoItem', () {
    test('copyWith toggles done', () {
      final item = TodoItem(
        id: '1',
        title: '写测试',
        done: false,
        createdAt: DateTime(2024, 1, 1),
      );
      final updated = item.copyWith(done: true);
      expect(updated.done, isTrue);
      expect(updated.id, item.id);
      expect(updated.title, item.title);
    });

    test('toJson/fromJson round-trip', () {
      final item = TodoItem(
        id: 'a1',
        title: '专注 25 分钟',
        done: true,
        createdAt: DateTime(2024, 6, 15, 10, 30),
      );
      final restored = TodoItem.fromJson(item.toJson());
      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.done, item.done);
      expect(restored.createdAt, item.createdAt);
    });
  });

  group('TodoStore', () {
    late TodoStore store;

    setUp(() {
      store = TodoStore();
    });

    test('add appends a pending item', () {
      store.add('任务一');
      expect(store.items, hasLength(1));
      expect(store.items.first.title, '任务一');
      expect(store.items.first.done, isFalse);
      expect(store.pendingCount, 1);
      expect(store.doneCount, 0);
    });

    test('add rejects empty / whitespace-only titles', () {
      store.add('');
      store.add('   ');
      expect(store.items, isEmpty);
    });

    test('toggle flips done state', () {
      store.add('任务一');
      final id = store.items.first.id;
      store.toggle(id);
      expect(store.items.first.done, isTrue);
      store.toggle(id);
      expect(store.items.first.done, isFalse);
    });

    test('remove deletes the item', () {
      store.add('任务一');
      store.add('任务二');
      final id = store.items.first.id;
      store.remove(id);
      expect(store.items, hasLength(1));
      expect(store.items.first.title, '任务二');
    });

    test('items sort pending first, done last, keeping insertion order', () {
      store.add('旧任务');
      store.add('新任务');
      store.toggle(store.items.first.id); // 完成「旧任务」
      store.add('第三个');

      final titles = store.items.map((e) => e.title).toList();
      // 未完成在前：新任务、第三个；已完成置底：旧任务
      expect(titles, ['新任务', '第三个', '旧任务']);
      expect(store.pendingCount, 2);
      expect(store.doneCount, 1);
    });

    test('save/load round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      store.add('写测试');
      store.add('跑测试');
      store.toggle(store.items.first.id);
      await store.save(prefs);

      final restored = TodoStore();
      await restored.load(prefs);
      expect(restored.items, hasLength(2));
      expect(restored.items.first.title, '跑测试');
      expect(restored.items.first.done, isFalse);
      expect(restored.items.last.title, '写测试');
      expect(restored.items.last.done, isTrue);
    });

    test('load tolerates corrupted / missing data', () async {
      SharedPreferences.setMockInitialValues({'todos_v1': 'not-json{{{'});
      final prefs = await SharedPreferences.getInstance();

      final restored = TodoStore();
      await restored.load(prefs);
      expect(restored.items, isEmpty);
    });
  });

  group('subtasks', () {
    late TodoStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = TodoStore();
      await store.load(await SharedPreferences.getInstance());
      store.add('重构设置模块');
    });

    String todoId() => store.items.single.id;

    test('adds and counts sub-steps', () {
      store.addSubtask(todoId(), '拆依赖');
      store.addSubtask(todoId(), '写测试');

      final item = store.items.single;
      expect(item.subtasks, hasLength(2));
      expect(item.subtasks.first.title, '拆依赖');
      expect(item.hasSubtasks, isTrue);
      expect(item.doneSubtaskCount, 0);
      expect(item.subtasksComplete, isFalse);
    });

    test('ignores blank sub-step titles', () {
      store.addSubtask(todoId(), '   ');
      expect(store.items.single.subtasks, isEmpty);
    });

    test('toggles a sub-step in place', () {
      store.addSubtask(todoId(), '第一步');
      store.addSubtask(todoId(), '第二步');
      final target = store.items.single.subtasks.first;

      store.toggleSubtask(todoId(), target.id);

      final item = store.items.single;
      expect(item.subtasks[0].done, isTrue);
      expect(item.subtasks[0].title, '第一步');
      expect(item.subtasks[1].done, isFalse);
      expect(item.doneSubtaskCount, 1);
    });

    test('reports completion once every sub-step is done', () {
      store.addSubtask(todoId(), '一');
      store.addSubtask(todoId(), '二');
      final ids = store.items.single.subtasks.map((s) => s.id).toList();
      store.toggleSubtask(todoId(), ids[0]);
      expect(store.items.single.subtasksComplete, isFalse);
      store.toggleSubtask(todoId(), ids[1]);
      expect(store.items.single.subtasksComplete, isTrue);
    });

    test('removes a sub-step and leaves the others in order', () {
      store.addSubtask(todoId(), '一');
      store.addSubtask(todoId(), '二');
      store.addSubtask(todoId(), '三');
      final target = store.items.single.subtasks[1];

      store.removeSubtask(todoId(), target.id);

      expect(
        store.items.single.subtasks.map((s) => s.title),
        ['一', '三'],
      );
    });

    test('unknown todo or sub-step ids are no-ops', () {
      store.addSubtask(todoId(), '一');
      final before = store.items.single.subtasks.length;
      store.addSubtask('no-such-todo', 'x');
      store.toggleSubtask('no-such-todo', 'x');
      store.toggleSubtask(todoId(), 'no-such-subtask');
      store.removeSubtask(todoId(), 'no-such-subtask');
      expect(store.items.single.subtasks, hasLength(before));
    });

    test('sub-steps survive a persistence round-trip', () async {
      store.addSubtask(todoId(), '拆依赖');
      store.toggleSubtask(todoId(), store.items.single.subtasks.first.id);
      await store.save();

      final reloaded = TodoStore();
      await reloaded.load(await SharedPreferences.getInstance());

      final item = reloaded.items.single;
      expect(item.subtasks.single.title, '拆依赖');
      expect(item.subtasks.single.done, isTrue);
    });
  });

  group('update', () {
    late TodoStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = TodoStore();
      await store.load(await SharedPreferences.getInstance());
      store.add('原始标题');
    });

    test('writes title, priority and description', () {
      final id = store.items.single.id;
      store.update(
        id,
        title: '新标题',
        priority: TodoPriority.high,
        description: '一些细节',
      );
      final item = store.items.single;
      expect(item.title, '新标题');
      expect(item.priority, TodoPriority.high);
      expect(item.description, '一些细节');
    });

    test('refuses to blank the title', () {
      final id = store.items.single.id;
      store.update(id, title: '   ', description: '只有描述变了');
      final item = store.items.single;
      expect(item.title, '原始标题');
      expect(item.description, '只有描述变了');
    });
  });
}
