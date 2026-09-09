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
