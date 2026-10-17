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
              values: _last7DaysMinutes(store, DateTime.now()),
              labels: _last7DaysLabels(DateTime.now()),
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
                  values: _last7DaysMinutes(store, DateTime.now()),
                  labels: _last7DaysLabels(DateTime.now()),
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final todayStat = store.statForDate(day);
    final todayCount = todayStat?.pomodoroCount ?? 0;
    final todayMinutes = todayStat?.focusMinutes ?? 0;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔥 连续 ${store.currentStreak} 天',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '今天 $todayCount 个番茄 · $todayMinutes 分钟',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: onSurfaceVariant),
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
