import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format/date_formats.dart';
import '../models/focus_stats_store.dart';
import 'main_shell.dart' show kCompactBreakpoint;

/// 历史记录页面：展示每日/每周/每月的专注汇总。
/// 完全遵循 M3 规范：颜色来自 ColorScheme，排版使用 textTheme 角色。
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FocusStatsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('历史')),
      body: SafeArea(
        child: store.totalPomodoroCount == 0
            ? const _EmptyState()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= kCompactBreakpoint;
                  if (!wide) return _buildNarrow(context, store);
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
        _DailyHistorySection(store: store),
        const SizedBox(height: 24),
        _WeeklyHistorySection(store: store),
        const SizedBox(height: 24),
        _MonthlyHistorySection(store: store),
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
            _DailyHistorySection(store: store),
            const SizedBox(height: 32),
            _WeeklyHistorySection(store: store),
            const SizedBox(height: 32),
            _MonthlyHistorySection(store: store),
          ],
        ),
      ),
    );
  }
}

/// 空状态占位
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '还没有历史记录，先完成一个专注吧',
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

/// 每日历史区段
class _DailyHistorySection extends StatelessWidget {
  const _DailyHistorySection({required this.store});
  final FocusStatsStore store;

  @override
  Widget build(BuildContext context) {
    final dailyStats = store.dailyStats;
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每日记录', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dailyStats.length,
            separatorBuilder: _buildSeparator,
            itemBuilder: (context, index) {
              // 倒序显示：最近的在前
              final stat = dailyStats[dailyStats.length - 1 - index];
              return _DailyHistoryTile(stat: stat);
            },
          ),
        ),
      ],
    );
  }
}

Widget _buildSeparator(BuildContext context, int index) => const Divider(height: 1, indent: 16, endIndent: 16);

class _DailyHistoryTile extends StatelessWidget {
  const _DailyHistoryTile({required this.stat});
  final DailyStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          stat.pomodoroCount.toString(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
        ),
      ),
      title: Text(
        fullDateFormat.format(stat.date),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        weekdayFormat.format(stat.date),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: Text(
        '${stat.focusMinutes} 分钟',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
            ),
      ),
    );
  }
}

/// 每周历史区段
class _WeeklyHistorySection extends StatelessWidget {
  const _WeeklyHistorySection({required this.store});
  final FocusStatsStore store;

  @override
  Widget build(BuildContext context) {
    // 聚合由 FocusStatsStore 提供；空周在这里过滤，索引仍取自 store 的原始
    // 桶位，所以「本周」标记不会因为前面的空周被跳过而错标到更早的一周。
    final weeklySummaries = _labelledWeeks(store);
    if (weeklySummaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每周汇总', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weeklySummaries.length,
            separatorBuilder: _buildSeparator,
            itemBuilder: (context, index) {
              final summary = weeklySummaries[index];
              return _WeeklyHistoryTile(
                weekLabel: summary.label,
                summary: summary.summary,
                isCurrentWeek: summary.isCurrent,
              );
            },
          ),
        ),
      ],
    );
  }

  List<_LabelledPeriod> _labelledWeeks(FocusStatsStore store) {
    final buckets = store.weeklySummaries(count: 8);
    return [
      for (var i = 0; i < buckets.length; i++)
        if (_hasData(buckets[i].summary))
          _LabelledPeriod(
            label: i == 0 ? '本周' : '$i 周前',
            summary: buckets[i].summary,
            isCurrent: i == 0,
          ),
    ];
  }
}

/// A [PeriodSummary] with the display label the history screen shows and
/// whether it is the period the user is currently living in.
class _LabelledPeriod {
  const _LabelledPeriod({
    required this.label,
    required this.summary,
    required this.isCurrent,
  });

  final String label;
  final PeriodSummary summary;
  final bool isCurrent;
}

bool _hasData(PeriodSummary summary) =>
    summary.pomodoroCount > 0 || summary.focusMinutes > 0;

class _WeeklyHistoryTile extends StatelessWidget {
  const _WeeklyHistoryTile({
    required this.weekLabel,
    required this.summary,
    required this.isCurrentWeek,
  });

  final String weekLabel;
  final PeriodSummary summary;
  final bool isCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isCurrentWeek ? scheme.primaryContainer : scheme.secondaryContainer,
        child: Text(
          summary.pomodoroCount.toString(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isCurrentWeek ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
              ),
        ),
      ),
      title: Text(
        weekLabel,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${summary.focusMinutes} 分钟',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: Text(
        '${summary.pomodoroCount} 个番茄',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
            ),
      ),
    );
  }
}

/// 每月历史区段
class _MonthlyHistorySection extends StatelessWidget {
  const _MonthlyHistorySection({required this.store});
  final FocusStatsStore store;

  @override
  Widget build(BuildContext context) {
    final monthlySummaries = _labelledMonths(store);
    if (monthlySummaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每月汇总', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthlySummaries.length,
            separatorBuilder: _buildSeparator,
            itemBuilder: (context, index) {
              final summary = monthlySummaries[index];
              return _MonthlyHistoryTile(
                monthLabel: summary.label,
                summary: summary.summary,
                isCurrentMonth: summary.isCurrent,
              );
            },
          ),
        ),
      ],
    );
  }

  List<_LabelledPeriod> _labelledMonths(FocusStatsStore store) {
    final buckets = store.monthlySummaries(count: 12);
    return [
      for (var i = 0; i < buckets.length; i++)
        if (_hasData(buckets[i].summary))
          _LabelledPeriod(
            label: i == 0
                ? '本月'
                : '${buckets[i].start.year}年${buckets[i].start.month}月',
            summary: buckets[i].summary,
            isCurrent: i == 0,
          ),
    ];
  }
}

class _MonthlyHistoryTile extends StatelessWidget {
  const _MonthlyHistoryTile({
    required this.monthLabel,
    required this.summary,
    required this.isCurrentMonth,
  });

  final String monthLabel;
  final PeriodSummary summary;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isCurrentMonth ? scheme.primaryContainer : scheme.tertiaryContainer,
        child: Text(
          summary.pomodoroCount.toString(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isCurrentMonth ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
              ),
        ),
      ),
      title: Text(
        monthLabel,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${summary.focusMinutes} 分钟',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: Text(
        '${summary.pomodoroCount} 个番茄',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
            ),
      ),
    );
  }
}