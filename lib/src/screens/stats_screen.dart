import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/focus_stats_store.dart';
import '../widgets/focus_chart.dart';
import '../widgets/stats_summary.dart';
import '../layout/breakpoints.dart';

const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FocusStatsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: SafeArea(
        child: store.totalPomodoroCount == 0
            ? const _EmptyState()
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Medium window and up: 24 margins in a 720dp column.
                  final wide = constraints.maxWidth >= kCompactBreakpoint;
                  if (!wide) {
                    return _buildNarrow(context, store);
                  }
                  return _buildWide(context, store);
                },
              ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context, FocusStatsStore store) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StreakHeader(store: store),
        const SizedBox(height: 24),
        Text('本周专注', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: FocusChart(
              values: _last7DaysMinutes(store, store.today),
              labels: _last7DaysLabels(store.today),
            ),
          ),
        ),
        const SizedBox(height: 24),
        StatsSummary(store: store),
      ],
    );
  }

  Widget _buildWide(BuildContext context, FocusStatsStore store) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _StreakHeader(store: store),
            const SizedBox(height: 32),
            Text('本周专注', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: FocusChart(
                  values: _last7DaysMinutes(store, store.today),
                  labels: _last7DaysLabels(store.today),
                ),
              ),
            ),
            const SizedBox(height: 32),
            StatsSummary(store: store),
          ],
        ),
      ),
    );
  }

  static List<int> _last7DaysMinutes(FocusStatsStore store, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final byDay = {for (final s in store.dailyStats) s.date: s};
    return [
      for (var i = 6; i >= 0; i--)
        byDay[today.subtract(Duration(days: i))]?.focusMinutes ?? 0,
    ];
  }

  static List<String> _last7DaysLabels(DateTime now) {
    return [
      for (var i = 6; i >= 0; i--)
        _weekdayLabels[now.subtract(Duration(days: i)).weekday - 1],
    ];
  }
}

class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.store});

  final FocusStatsStore store;

  /// Diameter of the flame. Large enough to be the page's focal point — the
  /// streak is the reason to open this screen, so it should not be a line of
  /// body text.
  static const double _flameSize = 96;

  @override
  Widget build(BuildContext context) {
    final todayStat = store.statForDate(store.today);
    final todayCount = todayStat?.pomodoroCount ?? 0;
    final todayMinutes = todayStat?.focusMinutes ?? 0;

    final streak = store.currentStreak;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // A broken streak is de-emphasised rather than hidden: the number still has
    // to stay legible, it just should not shout while it reads zero.
    final accent = streak > 0 ? scheme.primary : scheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$streak',
                style: theme.textTheme.displayLarge?.copyWith(color: accent),
              ),
              Text(
                '天连胜',
                style: theme.textTheme.titleMedium?.copyWith(color: accent),
              ),
              const SizedBox(height: 8),
              Text(
                '今天 $todayCount 个番茄 · $todayMinutes 分钟',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.local_fire_department,
          size: _flameSize,
          color: accent,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '还没有统计，先完成一个专注吧',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
