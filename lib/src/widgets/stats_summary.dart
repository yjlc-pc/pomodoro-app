import 'package:flutter/material.dart';
import '../models/focus_stats_store.dart';

class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key, required this.store});

  final FocusStatsStore store;

  static const _previousLabels = {'本周': '上周', '本月': '上月'};

  @override
  Widget build(BuildContext context) {
    final week = store.weekSummary();
    final month = store.monthSummary();

    // Two cards reading "0 番茄 · 0 分钟" side by side is worse than no cards:
    // it looks like a report about nothing. With no activity in either period
    /// there is nothing to compare, so render nothing.
    if (week.pomodoroCount == 0 &&
        week.focusMinutes == 0 &&
        month.pomodoroCount == 0 &&
        month.focusMinutes == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PeriodCard(
            title: '本周',
            previousLabel: _previousLabels['本周']!,
            current: week,
            previous: store.previousWeekSummary(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _PeriodCard(
            title: '本月',
            previousLabel: _previousLabels['本月']!,
            current: month,
            previous: store.previousMonthSummary(),
          ),
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.title,
    required this.previousLabel,
    required this.current,
    required this.previous,
  });

  final String title;
  final String previousLabel;
  final PeriodSummary current;
  final PeriodSummary previous;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final change = FocusStatsStore.changePercent(current, previous);
    final countDiff = current.pomodoroCount - previous.pomodoroCount;

    final String trendLabel;
    if (change == null) {
      trendLabel = '$previousLabel无专注';
    } else {
      final sign = countDiff >= 0 ? '+' : '';
      trendLabel = '较$previousLabel $sign$countDiff 番茄';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${current.pomodoroCount} 番茄 · ${current.focusMinutes} 分钟',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              trendLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: change == null
                        ? scheme.onSurfaceVariant
                        : countDiff >= 0
                            ? scheme.primary
                            : scheme.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
