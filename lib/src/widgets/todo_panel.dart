import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_item.dart';
import '../models/todo_store.dart';
import '../widgets/todo_tile.dart';

class TodoPanel extends StatelessWidget {
  const TodoPanel({super.key, required this.wide, this.bottomInset});

  final bool wide;

  /// Extra bottom padding to clear floating overlays (FAB / nav bar). When
  /// null the caller's scroll container provides its own placement.
  final double? bottomInset;

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
          variant: wide ? TodoTileVariant.card : TodoTileVariant.list,
          onToggle: () => store.toggle(item.id),
          onRemove: () => store.remove(item.id),
        );

    if (wide) {
      return SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 72,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => tileFor(items[index]),
            childCount: items.length,
          ),
        ),
      );
    }

    final bottom = bottomInset ?? (wide ? 0 : 96);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => tileFor(items[index]),
      ),
    );
  }
}
