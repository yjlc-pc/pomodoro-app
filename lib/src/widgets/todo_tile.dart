import 'package:flutter/material.dart';

import '../models/todo_item.dart';

/// One todo row, plus its sub-steps when expanded.
///
/// Two visual variants: a dense [TodoTileVariant.list] row for narrow layouts
/// and a [TodoTileVariant.card] for wide grids. Both render the same
/// information — priority bar, title, priority/description sub-line, sub-step
/// progress — so a todo looks the same wherever it appears.
class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.item,
    required this.variant,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onOpenDetail,
    required this.onToggleSubtask,
    required this.onRemoveSubtask,
  });

  final TodoItem item;
  final TodoTileVariant variant;

  /// Whether the sub-step list is showing.
  final bool expanded;

  final VoidCallback onExpandedChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  /// Opens the full detail sheet. Tapping the row body routes here so the row
  /// is never a dead zone.
  final VoidCallback onOpenDetail;

  final ValueChanged<String> onToggleSubtask;
  final ValueChanged<String> onRemoveSubtask;

  @override
  Widget build(BuildContext context) {
    final subtasks = Column(
      children: [
        for (final sub in item.subtasks)
          _SubTaskRow(
            key: ValueKey('sub-${item.id}-${sub.id}'),
            subtask: sub,
            onToggle: () => onToggleSubtask(sub.id),
            onRemove: () => onRemoveSubtask(sub.id),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.horizontal,
          // Two nested horizontal dismissables fight over the same drag, so the
          // parent gives up its swipe while its sub-steps are on screen. The
          // delete button stays available in that state.
          dismissThresholds: const {},
          confirmDismiss: (_) async => !expanded,
          background: _deleteBackground(context, Alignment.centerLeft),
          secondaryBackground: _deleteBackground(context, Alignment.centerRight),
          onDismissed: (_) => onRemove(),
          child: switch (variant) {
            TodoTileVariant.list => _ListTile(item: item, onToggle: onToggle, onExpandedChanged: onExpandedChanged, onOpenDetail: onOpenDetail),
            TodoTileVariant.card => _CardTile(item: item, onToggle: onToggle, onExpandedChanged: onExpandedChanged, onOpenDetail: onOpenDetail),
          },
        ),
        if (expanded && item.hasSubtasks) subtasks,
      ],
    );
  }

  Widget _deleteBackground(BuildContext context, Alignment alignment) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: scheme.errorContainer,
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

enum TodoTileVariant { list, card }

/// Colour of the priority bar. `low` deliberately gets no bar at all: absence
/// is the signal, so an unremarkable todo stays visually quiet.
Color? priorityBarColor(ColorScheme scheme, TodoItem item) {
  if (item.done) return null;
  return switch (item.priority) {
    TodoPriority.high => scheme.error,
    TodoPriority.normal => scheme.primary,
    TodoPriority.low => null,
  };
}

/// Completed items drop to reduced emphasis: struck-through text on
/// onSurfaceVariant, per the M3 emphasis hierarchy.
TextStyle _titleStyle(BuildContext context, bool done) {
  final textTheme = Theme.of(context).textTheme;
  final base = textTheme.bodyLarge ?? const TextStyle();
  if (!done) return base;
  return base.copyWith(
    decoration: TextDecoration.lineThrough,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// The secondary line under the title: the priority label, then the
/// description. Returns null when there is nothing worth saying, so quiet
/// todos stay a single line tall.
Widget? _subLine(BuildContext context, TodoItem item) {
  if (item.done) return null;
  final scheme = Theme.of(context).colorScheme;
  final style = Theme.of(context)
      .textTheme
      .bodySmall
      ?.copyWith(color: scheme.onSurfaceVariant);

  final parts = <String>[
    if (item.priority != TodoPriority.low) item.priority.label,
    if (item.description.isNotEmpty) item.description,
  ];
  if (parts.isEmpty) return null;
  return Text(
    parts.join(' · '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

/// Trailing sub-step progress: a count plus a thin bar. Also the expand
/// affordance — the whole group is tappable.
Widget? _progress(BuildContext context, TodoItem item, VoidCallback onTap) {
  if (!item.hasSubtasks) return null;
  final scheme = Theme.of(context).colorScheme;
  final done = item.doneSubtaskCount;
  final total = item.subtasks.length;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$done/$total',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 40,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                item.subtasksComplete ? scheme.primary : scheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.item,
    required this.onToggle,
    required this.onExpandedChanged,
    required this.onOpenDetail,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onExpandedChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = priorityBarColor(scheme, item);
    final subLine = _subLine(context, item);
    final progress = _progress(context, item, onExpandedChanged);
    return Container(
      // Completed rows tighten up: less vertical padding, and the sub-line and
      // priority bar are gone, so the archived pile stays short.
      padding: EdgeInsets.only(
        left: barColor == null ? 0 : 12,
        right: 4,
        top: item.done ? 2 : 8,
        bottom: item.done ? 2 : 8,
      ),
      child: Row(
        children: [
          if (barColor != null)
            Container(
              width: 3,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Checkbox(value: item.done, onChanged: (_) => onToggle()),
          Expanded(
            child: InkWell(
              onTap: onOpenDetail,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context, item.done),
                    ),
                    if (subLine != null) ...[
                      const SizedBox(height: 2),
                      subLine,
                    ],
                  ],
                ),
              ),
            ),
          ),
          ?progress,
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.item,
    required this.onToggle,
    required this.onExpandedChanged,
    required this.onOpenDetail,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onExpandedChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = priorityBarColor(scheme, item);
    final subLine = _subLine(context, item);
    final progress = _progress(context, item, onExpandedChanged);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (barColor != null)
                Container(
                  width: 3,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Checkbox(
                value: item.done,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context, item.done),
                    ),
                    if (subLine != null) ...[
                      const SizedBox(height: 2),
                      subLine,
                    ],
                  ],
                ),
              ),
              ?progress,
            ],
          ),
        ),
      ),
    );
  }
}

/// One sub-step: checkbox plus title, swipe to delete.
class _SubTaskRow extends StatelessWidget {
  const _SubTaskRow({
    super.key,
    required this.subtask,
    required this.onToggle,
    required this.onRemove,
  });

  final SubTask subtask;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Indents the steps under their parent so the relationship is visible.
      padding: const EdgeInsets.only(left: 32),
      child: Dismissible(
        key: ValueKey('dismiss-${subtask.id}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: scheme.errorContainer,
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        child: Row(
          children: [
            Checkbox(value: subtask.done, onChanged: (_) => onToggle()),
            Expanded(
              child: Text(
                subtask.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(context, subtask.done),
              ),
            ),
          ],
        ),
      ),
    );
  }
}