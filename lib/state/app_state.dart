import '../models/finance_models.dart';

/// Immutable snapshot of the persisted application data.
class AppState {
  final List<Entry> entries;
  final List<Category> categories;
  final List<Account> accounts;
  final List<Budget> budgets;
  final List<RecurringRule> recurringRules;
  final List<SavingGoal> savingGoals;
  final List<BillReminder> billReminders;
  final DateTime selectedMonth;
  final bool darkMode;
  final String languageCode;
  final String themeColor;
  final bool hideBalances;
  final bool remindersEnabled;
  final String pinHash;
  final bool onboardingCompleted;
  final String localName;

  AppState({
    List<Entry>? entries,
    List<Category>? categories,
    List<Account>? accounts,
    List<Budget>? budgets,
    List<RecurringRule>? recurringRules,
    List<SavingGoal>? savingGoals,
    List<BillReminder>? billReminders,
    DateTime? selectedMonth,
    this.darkMode = false,
    this.languageCode = 'th',
    this.themeColor = 'teal',
    this.hideBalances = false,
    this.remindersEnabled = true,
    this.pinHash = '',
    this.onboardingCompleted = false,
    this.localName = '',
  })  : entries = List.unmodifiable(entries ?? const []),
        categories = List.unmodifiable(categories ?? const []),
        accounts = List.unmodifiable(accounts ?? const []),
        budgets = List.unmodifiable(budgets ?? const []),
        recurringRules = List.unmodifiable(recurringRules ?? const []),
        savingGoals = List.unmodifiable(savingGoals ?? const []),
        billReminders = List.unmodifiable(billReminders ?? const []),
        selectedMonth = selectedMonth ??
            DateTime(DateTime.now().year, DateTime.now().month);

  AppState copyWith({
    List<Entry>? entries,
    List<Category>? categories,
    List<Account>? accounts,
    List<Budget>? budgets,
    List<RecurringRule>? recurringRules,
    List<SavingGoal>? savingGoals,
    List<BillReminder>? billReminders,
    DateTime? selectedMonth,
    bool? darkMode,
    String? languageCode,
    String? themeColor,
    bool? hideBalances,
    bool? remindersEnabled,
    String? pinHash,
    bool? onboardingCompleted,
    String? localName,
  }) =>
      AppState(
        entries: entries ?? this.entries,
        categories: categories ?? this.categories,
        accounts: accounts ?? this.accounts,
        budgets: budgets ?? this.budgets,
        recurringRules: recurringRules ?? this.recurringRules,
        savingGoals: savingGoals ?? this.savingGoals,
        billReminders: billReminders ?? this.billReminders,
        selectedMonth: selectedMonth ?? this.selectedMonth,
        darkMode: darkMode ?? this.darkMode,
        languageCode: languageCode ?? this.languageCode,
        themeColor: themeColor ?? this.themeColor,
        hideBalances: hideBalances ?? this.hideBalances,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        pinHash: pinHash ?? this.pinHash,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        localName: localName ?? this.localName,
      );
}
