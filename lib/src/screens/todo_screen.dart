import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_store.dart';
import '../widgets/todo_panel.dart';
import 'main_shell.dart' show kCompactBreakpoint;

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          Consumer<TodoStore>(
            builder: (context, store, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${store.pendingCount} 项未完成',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _promptAddTodo(context),
        tooltip: '新增待办',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Medium window and up: center the grid in a 720dp content column.
            final wide = constraints.maxWidth >= kCompactBreakpoint;
            if (wide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: CustomScrollView(slivers: [TodoPanel(wide: true)]),
                ),
              );
            }
            return CustomScrollView(slivers: [TodoPanel(wide: false)]);
          },
        ),
      ),
    );
  }

  Future<void> _promptAddTodo(BuildContext context) async {
    final store = context.read<TodoStore>();
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新增待办'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: '要做点什么？',
          ),
          onSubmitted: (value) {
            if (value.trim().isEmpty) return;
            Navigator.of(dialogContext).pop(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) store.add(title);
  }
}
