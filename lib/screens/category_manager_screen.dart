import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';

class CategoryManagerScreen extends StatelessWidget {
  final AppStore store;
  const CategoryManagerScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.t('manage_categories'))),
        floatingActionButton: FloatingActionButton(
            onPressed: () => _edit(context), child: const Icon(Icons.add)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          for (final category in store.categories)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Surface(
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                            child: Icon(category.type == income
                                ? Icons.south_west
                                : Icons.north_east)),
                        title: Text(categoryLabel(context, category)),
                        subtitle: Text(context.l10n.t(category.type)),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _edit(context, category)))),
        ]),
      );

  Future<void> _edit(BuildContext context, [Category? existing]) async {
    final result = await showDialog<Map<String, String>>(
        context: context, builder: (_) => _CategoryDialog(existing: existing));
    if (result?['action'] == 'hide' && existing != null) {
      await store.saveCategory(Category(
          existing.id, existing.name, existing.type, existing.icon,
          sortOrder: existing.sortOrder, isActive: false));
    } else if (result?['action'] == 'save' &&
        (result?['name'] ?? '').isNotEmpty) {
      await store.saveCategory(Category(existing?.id ?? 0, result!['name']!,
          result['type']!, existing?.icon ?? 'other',
          sortOrder: existing?.sortOrder ?? store.categories.length + 1));
    }
  }
}

class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  const _CategoryDialog({this.existing});
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController controller;
  late String type;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.existing?.name ?? '');
    type = widget.existing?.type ?? expense;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.l10n.t('manage_categories')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: controller,
              decoration:
                  InputDecoration(labelText: context.l10n.t('category'))),
          const SizedBox(height: 12),
          SegmentedButton<String>(segments: [
            ButtonSegment(
                value: expense, label: Text(context.l10n.t('expense'))),
            ButtonSegment(value: income, label: Text(context.l10n.t('income'))),
          ], selected: {
            type
          }, onSelectionChanged: (value) => setState(() => type = value.first)),
        ]),
        actions: [
          if (widget.existing != null)
            TextButton(
                onPressed: () => Navigator.pop(context, {'action': 'hide'}),
                child: Text(context.l10n.t('hide'))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, {
                    'action': 'save',
                    'name': controller.text.trim(),
                    'type': type
                  }),
              child: Text(context.l10n.t('save'))),
        ],
      );
}
