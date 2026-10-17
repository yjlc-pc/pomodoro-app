import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo_item.dart';
import '../models/todo_store.dart';

/// Opens the full-detail sheet for the todo with [todoId].
///
/// The sheet sizes itself to its content: a todo with nothing but a title opens
/// a short strip, while one with sub-steps grows (and scrolls) naturally. That
/// keeps the common case from covering half the screen for nothing.
///
/// Every field writes straight through to the store, so there is no save button
/// and nothing to lose by closing the sheet.
Future<void> showTodoDetailSheet(BuildContext context, String todoId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        // Clear the keyboard so the last field stays reachable.
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _TodoDetailSheet(todoId: todoId),
    ),
  );
}

class _TodoDetailSheet extends StatefulWidget {
  const _TodoDetailSheet({required this.todoId});

  final String todoId;

  @override
  State<_TodoDetailSheet> createState() => _TodoDetailSheetState();
}

class _TodoDetailSheetState extends State<_TodoDetailSheet> {
  TextEditingController? _title;
  TextEditingController? _description;

  @override
  void dispose() {
    _title?.dispose();
    _description?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TodoStore>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // The todo can disappear underneath us (deleted here, or from the list
    // behind the sheet) — render nothing rather than throw.
    TodoItem? todo;
    for (final candidate in store.items) {
      if (candidate.id == widget.todoId) {
        todo = candidate;
        break;
      }
    }
    if (todo == null) return const SizedBox.shrink();

    _title ??= TextEditingController(text: todo.title);
    _description ??= TextEditingController(text: todo.description);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete on the left, dismiss on the right: the destructive and the
            // navigational exit are kept visually apart.
            Row(
              children: [
                IconButton(
                  tooltip: '删除待办',
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.error,
                  onPressed: () => _confirmDelete(context, store),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            TextField(
              controller: _title,
              onChanged: (value) => store.update(widget.todoId, title: value),
              textInputAction: TextInputAction.next,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                hintText: '待办标题',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TodoPriority>(
              segments: [
                for (final priority in TodoPriority.values)
                  ButtonSegment(value: priority, label: Text(priority.label)),
              ],
              selected: {todo.priority},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  store.update(widget.todoId, priority: selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              onChanged: (value) =>
                  store.update(widget.todoId, description: value),
              maxLines: null,
              minLines: 2,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                hintText: '补充描述（可留空）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('子任务', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (todo.hasSubtasks)
                  Text(
                    '${todo.doneSubtaskCount}/${todo.subtasks.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (todo.subtasks.isEmpty)
              Text(
                '还没有子任务',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              for (final sub in todo.subtasks)
                CheckboxListTile(
                  key: ValueKey('detail-sub-${sub.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: sub.done,
                  onChanged: (_) =>
                      store.toggleSubtask(widget.todoId, sub.id),
                  title: Text(
                    sub.title,
                    style: sub.done
                        ? theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: scheme.onSurfaceVariant,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _promptSubtask(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加子任务'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TodoStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个待办？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.remove(widget.todoId);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Reuses the same dialog style as adding a todo, so there is one way to type
  /// a title in this app.
  Future<void> _promptSubtask(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新增子任务'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: '这一步要做什么？'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.trim().isNotEmpty) {
      if (!context.mounted) return;
      context.read<TodoStore>().addSubtask(widget.todoId, title);
    }
  }
}