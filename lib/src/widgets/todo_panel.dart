import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo_item.dart';
import '../models/todo_store.dart';
import '../widgets/todo_tile.dart';

/// The todo list, as a sliver suited to a [CustomScrollView].
///
/// Renders a [SliverList] of rows or a wrapped grid of cards depending on
/// [wide]. When [collapseDone] is set, completed entries are folded behind an
/// expandable header instead of trailing the list forever — on a narrow phone
/// the finished pile otherwise pushes everything you still have to do below
/// the fold, and it only ever grows.
class TodoPanel extends StatefulWidget {
  const TodoPanel({
    super.key,
    required this.wide,
    this.collapseDone = false,
    this.bottomInset,
  });

  /// Grid of cards when true, single-column rows when false.
  final bool wide;

  /// Folds completed entries behind a header. Only meaningful for the row
  /// layout; the grid layout always shows everything, because a card grid has
  /// no natural "below the fold" to hide behind.
  final bool collapseDone;

  /// Extra bottom padding to clear floating overlays (FAB / nav bar). When
  /// null the caller's scroll container provides its own placement.
  final double? bottomInset;

  @override
  State<TodoPanel> createState() => _TodoPanelState();
}

class _TodoPanelState extends State<TodoPanel> {
  /// Whether the completed entries are visible. Starts folded; the choice is
  /// deliberately not persisted, so the panel is in the same state every launch
  /// and a long-finished list never reappears expanded on its own.
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TodoStore>();
    final items = store.items;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.task_outlined,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  '还没有待办，点右下角 + 添加一个吧',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget tileFor(TodoItem item) => TodoTile(
          item: item,
          variant: widget.wide ? TodoTileVariant.card : TodoTileVariant.list,
          onToggle: () => store.toggle(item.id),
          onRemove: () => store.remove(item.id),
        );

    if (widget.wide) {
      return SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final item in items) tileFor(item)],
          ),
        ),
      );
    }

    final pending = items.where((item) => !item.done).toList();
    final done = items.where((item) => item.done).toList();
    final bottom = widget.bottomInset ?? 96;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      sliver: SliverList.list(
        children: [
          for (final item in pending) tileFor(item),
          if (widget.collapseDone && done.isNotEmpty) ...[
            _DoneHeader(
              count: done.length,
              expanded: _showDone,
              onToggle: () => setState(() => _showDone = !_showDone),
            ),
            // Kept in the tree while collapsed so the list keeps a stable
            // scroll extent instead of jumping when the section expands.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _showDone
                  ? Column(children: [for (final item in done) tileFor(item)])
                  : const SizedBox(width: double.infinity),
            ),
          ] else
            for (final item in done) tileFor(item),
        ],
      ),
    );
  }
}

/// Tappable header that folds the completed entries.
class _DoneHeader extends StatelessWidget {
  const _DoneHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onToggle,
      leading: Icon(Icons.check_circle_outline, color: scheme.onSurfaceVariant),
      title: Text(
        expanded ? '收起已完成' : '已完成 $count 项',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      trailing: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 200),
        child: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
      ),
    );
  }
}