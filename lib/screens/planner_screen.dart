import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';

class PlannerScreen extends StatelessWidget {
  final AppStore store;
  const PlannerScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.t('planner'))),
        body: DefaultTabController(
            length: 5,
            child: Column(children: [
              TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.zero,
                  tabs: [
                    Tab(text: context.l10n.t('budgets')),
                    Tab(text: context.l10n.t('accounts')),
                    Tab(text: context.l10n.t('recurring')),
                    Tab(text: context.l10n.t('goals')),
                    Tab(text: context.l10n.t('bills')),
                  ]),
              Expanded(
                  child: TabBarView(children: [
                _Budgets(store),
                _Accounts(store),
                _Recurring(store),
                _Goals(store),
                _Bills(store),
              ])),
            ])),
      );
}

class _Budgets extends StatelessWidget {
  final AppStore store;
  const _Budgets(this.store);
  @override
  Widget build(BuildContext context) =>
      _Page(onAdd: () => _budgetDialog(context, store), children: [
        MonthButton(store: store),
        for (final budget in store.monthlyBudgets)
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _DeleteRow(
                    title: budget.categoryId == null
                        ? context.l10n.t('total_budget')
                        : categoryLabel(
                            context, store.categoryFor(budget.categoryId!)),
                    onDelete: () =>
                        store.removePlannerItem('budgets', budget.id!)),
                Text(
                    '${money(context, store.spentForBudget(budget))} / ${money(context, budget.amountMinor)}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: (store.spentForBudget(budget) / budget.amountMinor)
                        .clamp(0, 1),
                    color: store.spentForBudget(budget) > budget.amountMinor
                        ? expenseRed
                        : Theme.of(context).colorScheme.primary),
              ])),
        if (store.monthlyBudgets.isEmpty) _Empty(context.l10n.t('no_budgets')),
      ]);
}

class _Accounts extends StatelessWidget {
  final AppStore store;
  const _Accounts(this.store);
  @override
  Widget build(BuildContext context) => _Page(
          onAdd: () => _accountDialog(context, store),
          secondaryAction: store.accounts.length > 1
              ? () => _transferDialog(context, store)
              : null,
          secondaryLabel: context.l10n.t('transfer'),
          children: [
            for (final account in store.accounts)
              Surface(
                  child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    child: Icon(Icons.account_balance_wallet_outlined)),
                title: Text(account.name == 'cash'
                    ? context.l10n.t('cash')
                    : account.name),
                subtitle: Text(account.kind),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money(context, store.accountBalance(account)),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (account.id != 1)
                    IconButton(
                        onPressed: () => _confirmPlannerDelete(
                            context, () => store.removeAccount(account.id!)),
                        icon: const Icon(Icons.delete_outline,
                            color: expenseRed)),
                ]),
              ))
          ]);
}

class _Recurring extends StatelessWidget {
  final AppStore store;
  const _Recurring(this.store);
  @override
  Widget build(BuildContext context) => _Page(
          onAdd: () => _recurringDialog(context, store),
          secondaryAction: store.recurringRules.isEmpty
              ? null
              : () => store.generateRecurringForMonth(store.selectedMonth),
          secondaryLabel: context.l10n.t('generate_now'),
          children: [
            for (final rule in store.recurringRules)
              Surface(
                  child: _DeleteRow(
                      title:
                          '${rule.title} · ${money(context, rule.amountMinor)} · ${context.l10n.t('day')} ${rule.dayOfMonth}',
                      onDelete: () => store.removePlannerItem(
                          'recurring_rules', rule.id!))),
            if (store.recurringRules.isEmpty)
              _Empty(context.l10n.t('no_recurring')),
          ]);
}

class _Goals extends StatelessWidget {
  final AppStore store;
  const _Goals(this.store);
  @override
  Widget build(BuildContext context) =>
      _Page(onAdd: () => _goalDialog(context, store), children: [
        for (final goal in store.savingGoals)
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _DeleteRow(
                    title: goal.name,
                    onDelete: () =>
                        store.removePlannerItem('saving_goals', goal.id!)),
                Text(
                    '${money(context, goal.savedMinor)} / ${money(context, goal.targetMinor)}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: (goal.savedMinor / goal.targetMinor).clamp(0, 1)),
              ])),
        if (store.savingGoals.isEmpty) _Empty(context.l10n.t('no_goals')),
      ]);
}

class _Bills extends StatelessWidget {
  final AppStore store;
  const _Bills(this.store);
  @override
  Widget build(BuildContext context) =>
      _Page(onAdd: () => _billDialog(context, store), children: [
        for (final bill in store.billReminders)
          Surface(
              child: _DeleteRow(
                  title:
                      '${bill.title} · ${context.l10n.t('day')} ${bill.dayOfMonth}${bill.amountMinor > 0 ? ' · ${money(context, bill.amountMinor)}' : ''}',
                  onDelete: () =>
                      store.removePlannerItem('bill_reminders', bill.id!))),
        if (store.billReminders.isEmpty) _Empty(context.l10n.t('no_bills')),
      ]);
}

class _Page extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback onAdd;
  final VoidCallback? secondaryAction;
  final String? secondaryLabel;
  const _Page(
      {required this.children,
      required this.onAdd,
      this.secondaryAction,
      this.secondaryLabel});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.t('add')))),
          if (secondaryAction != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: secondaryAction, child: Text(secondaryLabel!))
          ]
        ]),
        const SizedBox(height: 14),
        ...children.map((e) =>
            Padding(padding: const EdgeInsets.only(bottom: 12), child: e)),
      ]);
}

class _DeleteRow extends StatelessWidget {
  final String title;
  final Future<void> Function() onDelete;
  const _DeleteRow({required this.title, required this.onDelete});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
            onPressed: () => _confirmPlannerDelete(context, onDelete),
            icon: const Icon(Icons.delete_outline, color: expenseRed))
      ]);
}

Future<void> _confirmPlannerDelete(
    BuildContext context, Future<void> Function() onDelete) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.t('delete_planner_title')),
            content: Text(dialogContext.l10n.t('delete_planner_body')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(dialogContext.l10n.t('cancel'))),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(dialogContext.l10n.t('delete'))),
            ],
          ));
  if (confirmed != true || !context.mounted) return;
  try {
    await onDelete();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('delete_failed'))));
    }
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) =>
      Surface(child: Text(text, style: const TextStyle(color: muted)));
}

int? _minor(String value) {
  final parsed = double.tryParse(value.replaceAll(',', '').trim());
  return parsed == null || parsed <= 0 ? null : (parsed * 100).round();
}

Future<Map<String, String>?> _formDialog(BuildContext context, String title,
        List<(String, String, TextInputType)> fields) =>
    showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _PlannerFormDialog(title: title, fields: fields),
    );

class _PlannerFormDialog extends StatefulWidget {
  final String title;
  final List<(String, String, TextInputType)> fields;
  const _PlannerFormDialog({required this.title, required this.fields});
  @override
  State<_PlannerFormDialog> createState() => _PlannerFormDialogState();
}

class _PlannerFormDialogState extends State<_PlannerFormDialog> {
  late final Map<String, TextEditingController> controllers;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in widget.fields)
        field.$1: TextEditingController(text: field.$2)
    };
  }

  @override
  void dispose() {
    for (final value in controllers.values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final field in widget.fields)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                    controller: controllers[field.$1],
                    keyboardType: field.$3,
                    decoration:
                        InputDecoration(labelText: context.l10n.t(field.$1)))),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, {
                    for (final item in controllers.entries)
                      item.key: item.value.text.trim()
                  }),
              child: Text(context.l10n.t('save'))),
        ],
      );
}

Future<void> _budgetDialog(BuildContext context, AppStore store) async {
  final value = await _formDialog(context, context.l10n.t('budgets'),
      [('amount', '', TextInputType.number)]);
  final amount = _minor(value?['amount'] ?? '');
  if (amount != null)
    await store
        .saveBudget(Budget(month: store.selectedMonthKey, amountMinor: amount));
}

Future<void> _accountDialog(BuildContext context, AppStore store) async {
  final value = await _formDialog(context, context.l10n.t('accounts'), [
    ('name', '', TextInputType.text),
    ('opening_balance', '0', TextInputType.number)
  ]);
  if ((value?['name'] ?? '').isNotEmpty)
    await store.saveAccount(Account(
        name: value!['name']!,
        openingBalanceMinor: _minor(value['opening_balance'] ?? '') ?? 0));
}

Future<void> _goalDialog(BuildContext context, AppStore store) async {
  final value = await _formDialog(context, context.l10n.t('goals'), [
    ('name', '', TextInputType.text),
    ('target', '', TextInputType.number),
    ('saved', '0', TextInputType.number)
  ]);
  final target = _minor(value?['target'] ?? '');
  if ((value?['name'] ?? '').isNotEmpty && target != null)
    await store.saveGoal(SavingGoal(
        name: value!['name']!,
        targetMinor: target,
        savedMinor: _minor(value['saved'] ?? '') ?? 0));
}

Future<void> _billDialog(BuildContext context, AppStore store) async {
  final value = await _formDialog(context, context.l10n.t('bills'), [
    ('name', '', TextInputType.text),
    ('amount', '0', TextInputType.number),
    ('day', '1', TextInputType.number)
  ]);
  final day = int.tryParse(value?['day'] ?? '');
  if ((value?['name'] ?? '').isNotEmpty && day != null)
    await store.saveReminder(BillReminder(
        title: value!['name']!,
        amountMinor: _minor(value['amount'] ?? '') ?? 0,
        dayOfMonth: day.clamp(1, 31)));
}

Future<void> _recurringDialog(BuildContext context, AppStore store) async {
  final value = await _formDialog(context, context.l10n.t('recurring'), [
    ('name', '', TextInputType.text),
    ('amount', '', TextInputType.number),
    ('day', '1', TextInputType.number)
  ]);
  final amount = _minor(value?['amount'] ?? '');
  final day = int.tryParse(value?['day'] ?? '');
  final category = store.categories.where((c) => c.type == expense).firstOrNull;
  if ((value?['name'] ?? '').isNotEmpty &&
      amount != null &&
      day != null &&
      category != null)
    await store.saveRecurringRule(RecurringRule(
        title: value!['name']!,
        amountMinor: amount,
        type: expense,
        categoryId: category.id,
        accountId: store.accounts.first.id ?? 1,
        dayOfMonth: day.clamp(1, 31)));
}

Future<void> _transferDialog(BuildContext context, AppStore store) async {
  final value = await _formDialog(context, context.l10n.t('transfer'),
      [('amount', '', TextInputType.number), ('note', '', TextInputType.text)]);
  final amount = _minor(value?['amount'] ?? '');
  if (amount != null)
    await store.transfer(
        fromAccountId: store.accounts[0].id!,
        toAccountId: store.accounts[1].id!,
        amountMinor: amount,
        date: DateTime.now(),
        note: value?['note'] ?? '');
}
