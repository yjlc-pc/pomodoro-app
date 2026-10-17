import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'todo_item.dart';

/// In-memory todo list with SharedPreferences persistence.
///
/// Notifies listeners on every mutation so the UI can rebuild. Items are
/// always exposed sorted: pending first (insertion order), done last.
class TodoStore extends ChangeNotifier {
  static const _kStorageKey = 'todos_v1';

  final List<TodoItem> _items = [];
  int _idCounter = 0;

  /// Attached once [load] runs; mutations persist through it afterwards.
  SharedPreferences? _prefs;

  /// Pending-first snapshot of all items.
  List<TodoItem> get items {
    final pending = <TodoItem>[];
    final done = <TodoItem>[];
    for (final item in _items) {
      (item.done ? done : pending).add(item);
    }
    return [...pending, ...done];
  }

  int get pendingCount => _items.where((e) => !e.done).length;
  int get doneCount => _items.length - pendingCount;

  /// Adds a todo with [title]. Blank / whitespace-only titles are ignored.
  void add(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    _items.add(TodoItem(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      title: trimmed,
      done: false,
      createdAt: now,
    ));
    notifyListeners();
    _persist();
  }

  void remove(String id) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _items.removeAt(index);
    notifyListeners();
    _persist();
  }

  void toggle(String id) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(done: !_items[index].done);
    notifyListeners();
    _persist();
  }

  /// Rewrites the editable fields of a todo. Blank [title] is ignored so an
  /// empty text field can never wipe a todo's name.
  void update(
    String id, {
    String? title,
    TodoPriority? priority,
    String? description,
  }) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final trimmed = title?.trim();
    _items[index] = _items[index].copyWith(
      title: (trimmed?.isNotEmpty ?? false) ? trimmed : null,
      priority: priority,
      description: description,
    );
    notifyListeners();
    _persist();
  }

  /// Appends a sub-step to the todo. Blank titles are ignored.
  void addSubtask(String todoId, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final index = _items.indexWhere((e) => e.id == todoId);
    if (index == -1) return;
    final sub = SubTask(id: _newSubtaskId(), title: trimmed);
    _items[index] = _items[index]
        .copyWith(subtasks: [..._items[index].subtasks, sub]);
    notifyListeners();
    _persist();
  }

  void toggleSubtask(String todoId, String subtaskId) {
    _mapSubtask(todoId, subtaskId, (s) => s.copyWith(done: !s.done));
  }

  void removeSubtask(String todoId, String subtaskId) {
    final index = _items.indexWhere((e) => e.id == todoId);
    if (index == -1) return;
    final next = _items[index].subtasks
        .where((s) => s.id != subtaskId)
        .toList(growable: false);
    if (next.length == _items[index].subtasks.length) return;
    _items[index] = _items[index].copyWith(subtasks: next);
    notifyListeners();
    _persist();
  }

  /// Replaces one sub-step in place, keeping its position. No-op when the todo
  /// or the sub-step does not exist.
  void _mapSubtask(
    String todoId,
    String subtaskId,
    SubTask Function(SubTask) transform,
  ) {
    final index = _items.indexWhere((e) => e.id == todoId);
    if (index == -1) return;
    final next = <SubTask>[];
    var changed = false;
    for (final sub in _items[index].subtasks) {
      if (sub.id == subtaskId) {
        next.add(transform(sub));
        changed = true;
      } else {
        next.add(sub);
      }
    }
    if (!changed) return;
    _items[index] = _items[index].copyWith(subtasks: next);
    notifyListeners();
    _persist();
  }

  String _newSubtaskId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  /// Replaces the current list with the persisted snapshot. Tolerates
  /// corrupted data by falling back to an empty list.
  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_kStorageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(decoded
            .map((e) => TodoItem.fromJson(e as Map<String, Object?>))
            .whereType<TodoItem>());
      _idCounter = _items.length;
      notifyListeners();
    } catch (_) {
      // Corrupted storage: keep current in-memory state.
    }
  }

  /// Persists the whole list under a single JSON key. Failures are swallowed
  /// so the app keeps working in-memory.
  Future<void> save([SharedPreferences? prefs]) async {
    try {
      final target = prefs ?? _prefs;
      if (target == null) return;
      final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
      await target.setString(_kStorageKey, raw);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs != null) save(prefs);
  }
}
