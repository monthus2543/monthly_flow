import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/monthly_bars.dart';

class StatisticsScreen extends StatelessWidget {
  final AppStore store;
  const StatisticsScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final grouped = <int, int>{};
    for (final entry in store.monthlyEntries.where((e) => e.type == expense)) {
      grouped[entry.categoryId] =
          (grouped[entry.categoryId] ?? 0) + entry.amountMinor;
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = store.monthlyExpense;
    final now = DateTime.now();
    final days = sameMonth(now, store.selectedMonth)
        ? now.day
        : DateTime(store.selectedMonth.year, store.selectedMonth.month + 1, 0)
            .day;
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
        children: [
          PageTitle(
              context.l10n.t('statistics'), context.l10n.t('stats_subtitle')),
          MonthButton(store: store),
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(monthLabel(context, store.selectedMonth),
                    style: const TextStyle(color: muted)),
                Text('${context.l10n.t('spending')} ${money(context, total)}',
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.bold)),
              ])),
          const SizedBox(height: 13),
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(context.l10n.t('trend'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                MonthlyBars(store: store),
              ])),
          const SizedBox(height: 13),
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(context.l10n.t('expense_by_category'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (sorted.isEmpty)
                  Text(context.l10n.t('no_expense'),
                      style: const TextStyle(color: muted))
                else
                  for (var i = 0; i < sorted.length; i++) ...[
                    Row(children: [
                      Expanded(
                          child: Text(categoryLabel(
                              context, store.categoryFor(sorted[i].key)))),
                      Text(
                          '${(sorted[i].value * 100 / math.max(1, total)).round()}%  ${money(context, sorted[i].value)}',
                          style: const TextStyle(color: muted, fontSize: 12))
                    ]),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                        value: sorted[i].value / total,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(8),
                        color: brandGreen),
                    const SizedBox(height: 12),
                  ],
              ])),
          const SizedBox(height: 13),
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    '${context.l10n.t('daily_average')}  ${money(context, (total / days).round())}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    sorted.isEmpty
                        ? context.l10n.t('no_top_category')
                        : '${context.l10n.t('top_category')}: ${categoryLabel(context, store.categoryFor(sorted.first.key))}',
                    style: const TextStyle(color: muted, fontSize: 12)),
              ])),
        ]);
  }
}
