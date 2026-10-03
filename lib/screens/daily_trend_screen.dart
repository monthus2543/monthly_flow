import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';

class DailyTrendScreen extends StatelessWidget {
  final AppStore store;
  const DailyTrendScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final days =
        DateTime(store.selectedMonth.year, store.selectedMonth.month + 1, 0)
            .day;
    final values = List.generate(days, (index) {
      final day = index + 1;
      final rows = store.monthlyEntries.where((entry) => entry.date.day == day);
      return (day, sumType(rows, income), sumType(rows, expense));
    });
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('daily_trend'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          MonthButton(store: store),
          Text(monthLabel(context, store.selectedMonth),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _Legend(color: brandGreen, label: context.l10n.t('income')),
            const SizedBox(width: 18),
            _Legend(color: expenseRed, label: context.l10n.t('expense')),
          ]),
          const SizedBox(height: 16),
          for (var start = 0; start < values.length; start += 7) ...[
            Surface(
                color: Colors.white,
                child: _WeekChart(
                    weekNumber: start ~/ 7 + 1,
                    values: values.sublist(
                        start, math.min(start + 7, values.length)))),
            if (start + 7 < values.length) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final int weekNumber;
  final List<(int, int, int)> values;
  const _WeekChart({required this.weekNumber, required this.values});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximum = math.max(
        1,
        values.fold<int>(
            0, (value, day) => math.max(value, math.max(day.$2, day.$3))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          '${context.l10n.t('week')} $weekNumber · ${context.l10n.t('day')} ${values.first.$1}–${values.last.$1}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maximum * 1.18,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(1, maximum / 3),
              getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.dividerColor.withValues(alpha: .6),
                  strokeWidth: 1,
                  dashArray: [4, 4]),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: math.max(1, maximum / 3),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(_shortAmount(value),
                        style: const TextStyle(fontSize: 9, color: muted))),
              )),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= values.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                      meta: meta,
                      child: Text('${values[index].$1}',
                          style: const TextStyle(fontSize: 10, color: muted)));
                },
              )),
            ),
            barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                    '${context.l10n.t(rodIndex == 0 ? 'income' : 'expense')}\n${money(context, rod.toY.round())}',
                    TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                )),
            barGroups: [
              for (var index = 0; index < values.length; index++)
                BarChartGroupData(x: index, barsSpace: 3, barRods: [
                  _rod(values[index].$2, brandGreen),
                  _rod(values[index].$3, expenseRed),
                ])
            ],
          ),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        ),
      ),
    ]);
  }

  BarChartRodData _rod(int value, Color color) => BarChartRodData(
        toY: value.toDouble(),
        width: 10,
        color: value == 0 ? color.withValues(alpha: .18) : color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      );

  String _shortAmount(double minor) {
    final amount = minor / 100;
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}
