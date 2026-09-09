import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_store.dart';

sealed class StartTodoChoice {
  const StartTodoChoice();
}

class StartWithTodo implements StartTodoChoice {
  const StartWithTodo(this.id);
  final String id;
}

class StartWithoutTodo implements StartTodoChoice {
  const StartWithoutTodo();
}

class StartTodoSheet extends StatelessWidget {
  const StartTodoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TodoStore>();
    final pending = store.items.where((item) => !item.done).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Text(
                '这次专注要关联哪个待办？',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  '没有未完成的待办，直接开始吧',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final item = pending[index];
                    return ListTile(
                      leading: Icon(
                        Icons.radio_button_unchecked,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(item.title),
                      onTap: () =>
                          Navigator.of(context).pop(StartWithTodo(item.id)),
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(
                '跳过，不关联直接开始',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              onTap: () =>
                  Navigator.of(context).pop(const StartWithoutTodo()),
            ),
          ],
        ),
      ),
    );
  }
}
