import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/monthly_bars.dart';
import '../widgets/wallet_balance_card.dart';
import 'planner_screen.dart';
import 'daily_trend_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  AppStore get store => ref.read(appStoreProvider.notifier);
  @override
  Widget build(BuildContext context) {
    ref.watch(appStoreProvider);
    final rows = store.monthlyEntries;
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
        children: [
          PageTitle(
              context.l10n.t('dashboard'), context.l10n.t('overview_subtitle')),
          MonthButton(),
          WalletBalanceCard(
              incomeMinor: store.monthlyIncome,
              expenseMinor: store.monthlyExpense,
              hideBalances: store.hideBalances)
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
                            builder: (_) => PlannerScreen())),
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
                  onTap: () =>
                      Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => DailyTrendScreen())),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.t('trend'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 15),
                        MonthlyBars(),
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
                      onPressed: () => widget.onNavigate?.call(1),
                      icon: const Icon(Icons.chevron_right))
                ]),
                if (rows.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(context.l10n.t('no_entries'),
                          style: const TextStyle(color: muted)))
                else
                  for (final entry in rows.take(3))
                    TransactionTile(entry: entry),
              ]))
              .animate(delay: 170.ms)
              .fadeIn(duration: 420.ms)
              .slideY(begin: .06, end: 0, curve: Curves.easeOutCubic),
        ]);
  }

}
