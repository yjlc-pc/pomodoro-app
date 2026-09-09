import 'package:flutter/material.dart';
import '../models/focus_stats_store.dart';

class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key, required this.store});

  final FocusStatsStore store;

  static const _previousLabels = {'本周': '上周', '本月': '上月'};

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PeriodCard(
            title: '本周',
            previousLabel: _previousLabels['本周']!,
            current: store.weekSummary(),
            previous: store.previousWeekSummary(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _PeriodCard(
            title: '本月',
            previousLabel: _previousLabels['本月']!,
            current: store.monthSummary(),
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
