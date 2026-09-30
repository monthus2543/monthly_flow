import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import 'dashboard_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  final AppStore store;
  const HomeShell({super.key, required this.store});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(store: widget.store, onNavigate: _selectPage),
      TransactionsScreen(store: widget.store),
      StatisticsScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: SafeArea(child: IndexedStack(index: index, children: pages)),
      ),
      extendBody: true,
      floatingActionButton: SizedBox.square(
        dimension: 58,
        child: FloatingActionButton(
          onPressed: _openEntryForm,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: const CircleBorder(),
          elevation: 8,
          child: const Icon(Icons.add_rounded, size: 29),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 62,
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(children: [
          Expanded(
              child: _BottomNavItem(
            icon: LucideIcons.house,
            selectedIcon: LucideIcons.house600,
            label: context.l10n.t('dashboard'),
            selected: index == 0,
            onTap: () => _selectPage(0),
          )),
          Expanded(
              child: _BottomNavItem(
            icon: LucideIcons.receiptText,
            selectedIcon: LucideIcons.receiptText600,
            label: context.l10n.t('transactions'),
            selected: index == 1,
            onTap: () => _selectPage(1),
          )),
          const SizedBox(width: 68),
          Expanded(
              child: _BottomNavItem(
            icon: LucideIcons.chartNoAxesColumn,
            selectedIcon: LucideIcons.chartNoAxesColumn600,
            label: context.l10n.t('statistics'),
            selected: index == 2,
            onTap: () => _selectPage(2),
          )),
          Expanded(
              child: _BottomNavItem(
            icon: LucideIcons.settings,
            selectedIcon: LucideIcons.settings600,
            label: context.l10n.t('settings'),
            selected: index == 3,
            onTap: () => _selectPage(3),
          )),
        ]),
      ),
    );
  }

  void _selectPage(int value) {
    if (index != value) setState(() => index = value);
  }

  Future<void> _openEntryForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .42),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return FractionallySizedBox(
          heightFactor: .94,
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Theme(
                      data: theme.copyWith(
                        scaffoldBackgroundColor: Colors.transparent,
                        appBarTheme: theme.appBarTheme.copyWith(
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                        ),
                      ),
                      child: EntryFormScreen(store: widget.store),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem(
      {required this.icon,
      required this.selectedIcon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 20),
                const SizedBox(height: 1),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500)),
              ]),
        ),
      ),
    );
  }
}
