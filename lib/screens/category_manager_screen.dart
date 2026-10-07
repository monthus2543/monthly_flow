import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/category_color_picker.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});
  @override
  ConsumerState<CategoryManagerScreen> createState() =>
      _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  String get selectedType => tabs.index == 0 ? expense : income;
  Color get selectedColor => selectedType == expense
      ? AppColors.categoryExpense
      : AppColors.categoryIncome;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this)..addListener(_tabChanged);
  }

  void _tabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tabs.removeListener(_tabChanged);
    tabs.dispose();
    super.dispose();
  }

  AppStore get store => ref.read(appStoreProvider.notifier);
  @override
  Widget build(BuildContext context) {
    ref.watch(appStoreProvider);
    final selectorHeight = (MediaQuery.textScalerOf(context).scale(20) + 20)
        .clamp(45.0, double.infinity)
        .toDouble();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.t('manage_categories')),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(selectorHeight + 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selectedColor.withValues(alpha: .35)),
              ),
              child: AppSegmentedControl(
                width: MediaQuery.sizeOf(context).width - 44,
                value: selectedType,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.inputDark
                    : AppColors.scaffold,
                segments: [
                  AppSegment(
                    expense,
                    context.l10n.t(expense),
                    Icons.north_east,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.errorDark
                        : AppColors.categoryExpense,
                  ),
                  AppSegment(
                    income,
                    context.l10n.t(income),
                    Icons.south_west,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.tealDark
                        : AppColors.categoryIncome,
                  ),
                ],
                onChanged: (value) => tabs.animateTo(value == expense ? 0 : 1),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: selectedColor,
        foregroundColor: Colors.white,
        tooltip: context.l10n.t('add_category'),
        onPressed: () => _edit(context),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          for (final type in [expense, income])
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                for (final category in store.categories.where(
                  (category) => category.type == type,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        minTileHeight: 48,
                        minVerticalPadding: 0,
                        minLeadingWidth: 32,
                        horizontalTitleGap: 12,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              (type == expense
                                      ? AppColors.categoryExpense
                                      : AppColors.categoryIncome)
                                  .withValues(alpha: .12),
                          foregroundColor: type == expense
                              ? (Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.errorDark
                                    : AppColors.categoryExpense)
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.tealDark
                                    : AppColors.categoryIncome),
                          child: Icon(
                            category.type == income
                                ? Icons.south_west
                                : Icons.north_east,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          categoryLabel(context, category),
                          style: category.colorValue == null
                              ? null
                              : TextStyle(
                                  color: categoryTextColor(context, category),
                                ),
                        ),
                        trailing: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: type == expense
                              ? AppColors.categoryExpense
                              : AppColors.categoryIncome,
                        ),
                        onTap: () => _edit(context, category),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, [Category? existing]) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) =>
          _CategoryDialog(existing: existing, initialType: selectedType),
    );
    if (result?['action'] == 'save' && (result?['name'] ?? '').isNotEmpty) {
      await store.saveCategory(
        Category(
          existing?.id ?? 0,
          result!['name']!,
          result['type']!,
          existing?.icon ?? 'other',
          sortOrder: existing?.sortOrder ?? store.categories.length + 1,
          colorValue: int.tryParse(result['color_value'] ?? ''),
        ),
      );
    }
  }
}

class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  final String initialType;
  const _CategoryDialog({this.existing, required this.initialType});
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController controller;
  late String type;
  int? colorValue;
  final formKey = GlobalKey<FormState>();
  String initialLabel = '';
  bool initialized = false;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    type = widget.existing?.type ?? widget.initialType;
    colorValue = widget.existing?.colorValue;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialLabel = widget.existing == null
          ? ''
          : categoryLabel(context, widget.existing);
      controller.text = initialLabel;
      initialized = true;
    }
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final label = controller.text.trim();
    Navigator.pop(context, {
      'action': 'save',
      'name': widget.existing != null && label == initialLabel
          ? widget.existing!.name
          : label,
      'type': type,
      if (colorValue != null) 'color_value': colorValue.toString(),
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = type == expense
        ? AppColors.categoryExpense
        : AppColors.categoryIncome;
    final labelColor = theme.brightness == Brightness.dark
        ? (type == expense ? AppColors.errorDark : AppColors.tealDark)
        : color;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: BoxConstraints(
        minWidth: (MediaQuery.sizeOf(context).width - 48).clamp(0.0, 480.0),
        maxWidth: 480,
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(
              type == expense ? Icons.north_east : Icons.south_west,
              color: labelColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t(
                    widget.existing == null ? 'add_category' : 'edit_category',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.t(type),
                  style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.t('category'),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? context.l10n.t('category_name_required')
                    : null,
                onFieldSubmitted: (_) => save(),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: Icon(
                  Icons.circle,
                  color: colorValue == null ? labelColor : Color(colorValue!),
                  size: 22,
                ),
                label: Text(context.l10n.t('category_text_color')),
                onPressed: () async {
                  final selected = await showCategoryColorPicker(
                    context,
                    Color(colorValue ?? color.toARGB32()),
                  );
                  if (selected != null && mounted)
                    setState(() => colorValue = selected.toARGB32());
                },
              ),
              const SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPrimaryButton(
                        color: color,
                        foregroundColor: Colors.white,
                        onPressed: save,
                        child: Text(
                          context.l10n.t('save_category'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
