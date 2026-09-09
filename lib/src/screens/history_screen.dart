import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
    final dateFormat = DateFormat('yyyy年M月d日', 'zh_CN');
    final weekdayFormat = DateFormat('EEEE', 'zh_CN');

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
        dateFormat.format(stat.date),
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
    // 生成最近 8 周（含当周）的周汇总
    final weeklySummaries = _buildWeeklySummaries(store);
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
                isCurrentWeek: index == 0,
              );
            },
          ),
        ),
      ],
    );
  }

  List<_WeeklySummaryWithLabel> _buildWeeklySummaries(FocusStatsStore store) {
    final result = <_WeeklySummaryWithLabel>[];
    final now = DateTime.now();
    for (var i = 0; i < 8; i++) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      var count = 0;
      var minutes = 0;
      for (final s in store.dailyStats) {
        if (!s.date.isBefore(weekStart) && !s.date.isAfter(weekEnd)) {
          count += s.pomodoroCount;
          minutes += s.focusMinutes;
        }
      }
      if (count == 0 && minutes == 0) continue;
      result.add(_WeeklySummaryWithLabel(
        label: i == 0 ? '本周' : '$i 周前',
        summary: PeriodSummary(pomodoroCount: count, focusMinutes: minutes),
      ));
    }
    return result;
  }
}

class _WeeklySummaryWithLabel {
  const _WeeklySummaryWithLabel({required this.label, required this.summary});
  final String label;
  final PeriodSummary summary;
}

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
    final monthlySummaries = _buildMonthlySummaries(store);
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
                isCurrentMonth: index == 0,
              );
            },
          ),
        ),
      ],
    );
  }

  List<_MonthlySummaryWithLabel> _buildMonthlySummaries(FocusStatsStore store) {
    final result = <_MonthlySummaryWithLabel>[];
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      var count = 0;
      var minutes = 0;
      for (final s in store.dailyStats) {
        if (!s.date.isBefore(monthStart) && !s.date.isAfter(monthEnd)) {
          count += s.pomodoroCount;
          minutes += s.focusMinutes;
        }
      }
      if (count == 0 && minutes == 0) continue;
      final label = i == 0 ? '本月' : '${monthStart.year}年${monthStart.month}月';
      result.add(_MonthlySummaryWithLabel(
        label: label,
        summary: PeriodSummary(pomodoroCount: count, focusMinutes: minutes),
      ));
    }
    return result;
  }
}

class _MonthlySummaryWithLabel {
  const _MonthlySummaryWithLabel({required this.label, required this.summary});
  final String label;
  final PeriodSummary summary;
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