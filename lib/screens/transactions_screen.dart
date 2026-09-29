import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import 'entry_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final AppStore store;
  const TransactionsScreen({super.key, required this.store});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String filter = 'all';
  String search = '';
  @override
  Widget build(BuildContext context) {
    final query = search.trim().toLowerCase();
    final rows = widget.store.monthlyEntries.where((entry) {
      if (filter == 'favorite' && !entry.isFavorite) return false;
      if (filter != 'all' && filter != 'favorite' && entry.type != filter)
        return false;
      final category =
          categoryLabel(context, widget.store.categoryFor(entry.categoryId));
      return query.isEmpty ||
          '${entry.title} ${entry.note} $category'
              .toLowerCase()
              .contains(query);
    }).toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
        children: [
          PageTitle(context.l10n.t('transactions'),
              context.l10n.t('search_subtitle')),
          const SizedBox(height: 16),
          TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.search),
                  hintText: context.l10n.t('search'))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _chip(context.l10n.t('all'), 'all'),
            _chip(context.l10n.t('income'), income),
            _chip(context.l10n.t('expense'), expense),
            _chip(context.l10n.t('favorite'), 'favorite'),
          ]),
          MonthButton(store: widget.store),
          if (rows.isEmpty)
            Surface(
                child: Text(context.l10n.t('not_found'),
                    style: const TextStyle(color: muted)))
          else
            Surface(
                child: Column(children: [
              for (final entry in rows)
                TransactionTile(
                  store: widget.store,
                  entry: entry,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => EntryFormScreen(
                              store: widget.store, existing: entry))),
                  onDuplicate: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => EntryFormScreen(
                              store: widget.store, initial: entry))),
                )
            ])),
        ]);
  }

  Widget _chip(String label, String value) => ChoiceChip(
      label: Text(label),
      selected: filter == value,
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(color: filter == value ? Colors.white : null),
      showCheckmark: false,
      onSelected: (_) => setState(() => filter = value));
}
