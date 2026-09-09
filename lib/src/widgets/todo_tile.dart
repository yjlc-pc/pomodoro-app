import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.item,
    required this.variant,
    required this.onToggle,
    required this.onRemove,
  });

  final TodoItem item;
  final TodoTileVariant variant;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onRemove(),
      background: _deleteBackground(context, Alignment.centerLeft),
      secondaryBackground: _deleteBackground(context, Alignment.centerRight),
      child: switch (variant) {
        TodoTileVariant.list => _ListTile(item: item, onToggle: onToggle, onRemove: onRemove),
        TodoTileVariant.card =>
          _CardTile(item: item, onToggle: onToggle, onRemove: onRemove),
      },
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

/// Completed items drop to reduced emphasis: strikethrough on
/// onSurfaceVariant, per the M3 emphasis hierarchy.
TextStyle _titleStyle(BuildContext context, bool done) {
  final textTheme = Theme.of(context).textTheme;
  if (!done) return textTheme.bodyLarge ?? const TextStyle();
  return (textTheme.bodyLarge ?? const TextStyle()).copyWith(
    decoration: TextDecoration.lineThrough,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.item, required this.onToggle, required this.onRemove});

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Checkbox(
          value: item.done,
          onChanged: (_) => onToggle(),
        ),
        Expanded(
          child: Text(item.title, style: _titleStyle(context, item.done)),
        ),
        IconButton(
          tooltip: '删除',
          icon: const Icon(Icons.delete_outline, size: 20),
          color: scheme.onSurfaceVariant,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.item,
    required this.onToggle,
    required this.onRemove,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.done
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 24,
                color: item.done ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle(context, item.done),
                ),
              ),
              // Pointer-device affordance: swipe-delete only exists on touch.
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: scheme.onSurfaceVariant,
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
