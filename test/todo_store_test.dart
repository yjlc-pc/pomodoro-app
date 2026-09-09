import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/models/todo_item.dart';
import 'package:pomodoro_app/src/models/todo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
}
