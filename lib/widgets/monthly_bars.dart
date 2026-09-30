import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import 'common_widgets.dart';

class MonthlyBars extends StatelessWidget {
  final AppStore store;
  final VoidCallback? onTap;
  const MonthlyBars({super.key, required this.store, this.onTap});
  @override
  Widget build(BuildContext context) {
    final points = List.generate(6, (i) {
      final date =
          DateTime(store.selectedMonth.year, store.selectedMonth.month - 5 + i);
      final rows = store.entries.where((e) => sameMonth(e.date, date));
      return (date, sumType(rows, income), sumType(rows, expense));
    });
    final maximum = math.max(
        1, points.fold<int>(0, (m, p) => math.max(m, math.max(p.$2, p.$3))));
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 168,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maximum.toDouble() * 1.16,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(1, maximum / 3),
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.dividerColor.withValues(alpha: .55),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 27,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text('${points[index].$1.month}',
                          style: const TextStyle(fontSize: 10, color: muted)),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              enabled: false,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                  money(context, rod.toY.round()),
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 3,
                  barRods: [
                    _rod(points[i].$2, brandGreen),
                    _rod(points[i].$3, expenseRed),
                  ],
                ),
            ],
          ),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  BarChartRodData _rod(int value, Color color) => BarChartRodData(
        toY: value.toDouble(),
        width: 9,
        color: value == 0 ? color.withValues(alpha: .25) : color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      );
}
