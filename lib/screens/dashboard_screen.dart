import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/monthly_bars.dart';
import 'planner_screen.dart';
import 'daily_trend_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppStore store;
  final ValueChanged<int>? onNavigate;
  const DashboardScreen({super.key, required this.store, this.onNavigate});
  @override
  Widget build(BuildContext context) {
    final rows = store.monthlyEntries;
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
        children: [
          PageTitle(
              context.l10n.t('dashboard'), context.l10n.t('overview_subtitle')),
          MonthButton(store: store),
          Surface(
                  gradient: brandGradient(context),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.t('balance'),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .82))),
                        const SizedBox(height: 4),
                        Text(
                            store.hideBalances
                                ? '••••••'
                                : money(context,
                                    store.monthlyIncome - store.monthlyExpense),
                            style: const TextStyle(
                                fontSize: 31,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: _metric(context, context.l10n.t('income'),
                                  store.monthlyIncome)),
                          Expanded(
                              child: _metric(context, context.l10n.t('expense'),
                                  store.monthlyExpense)),
                        ]),
                      ]))
              .animate()
              .fadeIn(duration: 420.ms)
              .slideY(begin: .08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          if (store.monthlyBudget > 0) ...[
            Surface(
                child: InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => PlannerScreen(store: store))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(context.l10n.t('monthly_budget'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600))),
                            Text(
                                '${(store.monthlyExpense * 100 / store.monthlyBudget).round()}%')
                          ]),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                              value:
                                  (store.monthlyExpense / store.monthlyBudget)
                                      .clamp(0, 1),
                              color: store.monthlyExpense > store.monthlyBudget
                                  ? expenseRed
                                  : Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 6),
                          Text(
                              '${money(context, store.monthlyExpense)} / ${money(context, store.monthlyBudget)}',
                              style: const TextStyle(color: muted)),
                        ]))),
            const SizedBox(height: 14),
          ],
          Surface(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => DailyTrendScreen(store: store))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.t('trend'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 15),
                        MonthlyBars(store: store),
                      ]))
              .animate(delay: 100.ms)
              .fadeIn(duration: 420.ms)
              .slideY(begin: .06, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          Surface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Row(children: [
                  Expanded(
                      child: Text(context.l10n.t('latest'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600))),
                  IconButton(
                      onPressed: () => onNavigate?.call(1),
                      icon: const Icon(Icons.chevron_right))
                ]),
                if (rows.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(context.l10n.t('no_entries'),
                          style: const TextStyle(color: muted)))
                else
                  for (final entry in rows.take(3))
                    TransactionTile(store: store, entry: entry),
              ]))
              .animate(delay: 170.ms)
              .fadeIn(duration: 420.ms)
              .slideY(begin: .06, end: 0, curve: Curves.easeOutCubic),
        ]);
  }

  Widget _metric(BuildContext context, String label, int amount) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: .82))),
        Text(store.hideBalances ? '••••••' : money(context, amount),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
      ]);
}
