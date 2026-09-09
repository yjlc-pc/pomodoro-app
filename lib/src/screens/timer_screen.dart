import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_store.dart';
import '../timer/pomodoro_timer.dart';
import '../widgets/audio_control_bar.dart';
import '../widgets/start_todo_sheet.dart';
import '../widgets/timer_ring.dart';
import '../widgets/todo_panel.dart';
import 'main_shell.dart' show kCompactBreakpoint, kExpandedBreakpoint;

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  Future<void> _handleStartPressed(BuildContext context) async {
    final timer = context.read<PomodoroTimer>();
    if (timer.running) {
      timer.pause();
      return;
    }

    String? linkedTodoId;
    if (timer.phase == PomodoroPhase.focus) {
      final choice = await showModalBottomSheet<StartTodoChoice>(
        context: context,
        showDragHandle: true,
        builder: (_) => const StartTodoSheet(),
      );
      if (choice == null) return;
      if (choice is StartWithTodo) linkedTodoId = choice.id;
    }
    timer.start(linkedTodoId: linkedTodoId);
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<PomodoroTimer>();
    final todoStore = context.watch<TodoStore>();
    final linked = timer.linkedTodoId;
    String? linkedTitle;
    if (linked != null) {
      for (final item in todoStore.items) {
        if (item.id == linked) {
          linkedTitle = item.title;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟'),
        actions: [
          if (timer.phase == PomodoroPhase.focus) const AudioMiniPlayer(),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: onOpenSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width >= kExpandedBreakpoint) {
              return _buildWide(context, timer, todoStore, linkedTitle);
            }
            return _buildCentered(
              context,
              timer,
              linkedTitle,
              medium: width >= kCompactBreakpoint,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCentered(
    BuildContext context,
    PomodoroTimer timer,
    String? linkedTitle, {
    required bool medium,
  }) {
    return SingleChildScrollView(
      padding: medium
          ? const EdgeInsets.all(24)
          : const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (linkedTitle != null) ...[
                _LinkedTodoBanner(title: linkedTitle),
                const SizedBox(height: 24),
              ],
              TimerRing(
                size: medium ? 320 : 260,
                progress: timer.progress,
                durationLabel: timer.formattedTime,
                phaseLabel: timer.phase.title,
              ),
              const SizedBox(height: 32),
              _SessionDots(
                completed: timer.completedFocusSessions,
                total: timer.settings.sessionsBeforeLongBreak,
              ),
              const SizedBox(height: 32),
              _Controls(
                timer: timer,
                onStart: () => _handleStartPressed(context),
              ),
              if (timer.phase != PomodoroPhase.focus) ...[
                const SizedBox(height: 24),
                const AudioControlBar(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWide(
    BuildContext context,
    PomodoroTimer timer,
    TodoStore todoStore,
    String? linkedTitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (linkedTitle != null) ...[
                      _LinkedTodoBanner(title: linkedTitle),
                      const SizedBox(height: 24),
                    ],
                    TimerRing(
                      size: 320,
                      progress: timer.progress,
                      durationLabel: timer.formattedTime,
                      phaseLabel: timer.phase.title,
                    ),
                    const SizedBox(height: 32),
                    _SessionDots(
                      completed: timer.completedFocusSessions,
                      total: timer.settings.sessionsBeforeLongBreak,
                    ),
                    const SizedBox(height: 32),
                    _Controls(
                      timer: timer,
                      onStart: () => _handleStartPressed(context),
                    ),
                    if (timer.phase != PomodoroPhase.focus) ...[
                      const SizedBox(height: 24),
                      const AudioControlBar(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _TodoSidebar(),
        ),
      ],
    );
  }
}

class _TodoSidebar extends StatelessWidget {
  const _TodoSidebar();

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                Text(
                  '待办',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: '新增待办',
                  icon: const Icon(Icons.add),
                  onPressed: () => _promptAddTodo(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: const [TodoPanel(wide: false, bottomInset: 0)],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedTodoBanner extends StatelessWidget {
  const _LinkedTodoBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '正在专注：$title',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.timer, required this.onStart});

  final PomodoroTimer timer;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: onStart,
          icon: Icon(timer.running ? Icons.pause : Icons.play_arrow),
          label: Text(timer.running ? '暂停' : '开始'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 56),
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: '重置',
              icon: const Icon(Icons.replay),
              onPressed: timer.reset,
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(
              tooltip: '跳过',
              icon: const Icon(Icons.skip_next),
              onPressed: timer.skip,
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < completed % total;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? scheme.primary : scheme.surfaceContainerHighest,
          ),
        );
      }),
    );
  }
}
