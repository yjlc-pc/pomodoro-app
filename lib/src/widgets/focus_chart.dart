import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FocusChart extends StatelessWidget {
  const FocusChart({super.key, required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    assert(values.isNotEmpty && values.length == labels.length);
    final scheme = Theme.of(context).colorScheme;

    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxValue == 0) {
      // An empty axis frame reads as "the chart is broken". Say what is
      // actually true instead.
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            '本周还没有专注记录',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final top = maxValue * 1.2;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: 16,
                    // Today's bar uses primary; past days drop to the neutral
                    // role instead of a hand-tuned alpha of primary.
                    color: i == values.length - 1
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
