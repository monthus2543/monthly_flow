import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';

const brandGreen = Color(0xFF008E7B);
const expenseRed = Color(0xFFFF6B5E);
const accentBlue = Color(0xFF4D7CFE);
const accentOrange = Color(0xFFFFA63D);
const muted = Color(0xFF66777A);

LinearGradient brandGradient(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(primary, Colors.white, .28)!,
      primary,
      Color.lerp(primary, Colors.black, .22)!
    ],
  );
}

LinearGradient appBackgroundGradient(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF000000), Color(0xFF080808), Color(0xFF000000)]
        : const [Color(0xFFE3F3F4), Color(0xFFF9FAF6), Color(0xFFFFF4E8)],
  );
}

String money(BuildContext context, int minor) => NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: '฿',
      decimalDigits: 2,
    ).format(minor / 100);

String monthLabel(BuildContext context, DateTime date) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
        .format(date);

String dateLabel(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);

String categoryLabel(BuildContext context, Category? category) {
  if (category == null) return context.l10n.category('other');
  const legacy = <String, String>{
    'เงินเดือน': 'salary',
    'รายรับอื่น ๆ': 'other_income',
    'อาหารและเครื่องดื่ม': 'food',
    'เดินทาง': 'travel',
    'ที่พัก': 'housing',
    'ช้อปปิ้ง': 'shopping',
    'บันเทิง': 'entertainment',
    'อื่น ๆ': 'other',
  };
  final key = legacy[category.name] ?? category.name;
  return context.l10n.category(key);
}

class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageTitle(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: muted)),
      ]);
}

class Surface extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  const Surface({super.key, required this.child, this.gradient});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: gradient == null ? Theme.of(context).cardColor : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .08)),
            boxShadow: [
              BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .09),
                  blurRadius: 22,
                  offset: const Offset(0, 8))
            ]),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
}

class MonthButton extends StatelessWidget {
  final AppStore store;
  const MonthButton({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          IconButton(
              onPressed: () => store.changeMonth(DateTime(
                  store.selectedMonth.year, store.selectedMonth.month - 1)),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: Text(monthLabel(context, store.selectedMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(
              onPressed: () => store.changeMonth(DateTime(
                  store.selectedMonth.year, store.selectedMonth.month + 1)),
              icon: const Icon(Icons.chevron_right)),
        ]),
      );
}

class TransactionTile extends StatelessWidget {
  final AppStore store;
  final Entry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDuplicate;
  const TransactionTile(
      {super.key,
      required this.store,
      required this.entry,
      this.onTap,
      this.onDuplicate});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            backgroundColor: entry.type == income
                ? const Color(0xFFD9FAF1)
                : const Color(0xFFFFE4DF),
            child: Icon(
                entry.type == income
                    ? LucideIcons.arrowDownLeft
                    : LucideIcons.arrowUpRight,
                color: entry.type == income ? brandGreen : expenseRed)),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${categoryLabel(context, store.categoryFor(entry.categoryId))} · ${dateLabel(context, entry.date)}'),
        trailing: Text(
            '${entry.type == income ? '+' : '−'}${money(context, entry.amountMinor)}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.type == income ? brandGreen : expenseRed)),
        onTap: onTap,
        onLongPress: onDuplicate,
      );
}
