import 'package:flutter/foundation.dart' hide Category;
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../models/finance_models.dart';
import '../repositories/finance_repository.dart';

class AppStore extends ChangeNotifier {
  final AppDatabase database;
  FinanceRepository? _repository;
  AppStore({AppDatabase? database}) : database = database ?? AppDatabase();

  List<Entry> entries = [];
  List<Category> categories = [];
  List<Account> accounts = [];
  List<Budget> budgets = [];
  List<RecurringRule> recurringRules = [];
  List<SavingGoal> savingGoals = [];
  List<BillReminder> billReminders = [];
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool darkMode = false;
  String languageCode = 'th';
  String themeColor = 'teal';
  bool hideBalances = false;
  bool remindersEnabled = true;
  String pinHash = '';

  Future<void> open() async {
    _repository = FinanceRepository(await database.open());
    final values = await _repository!.settings();
    darkMode = values['theme_mode'] == 'dark' || values['dark_mode'] == '1';
    languageCode = values['language_code'] == 'en' ? 'en' : 'th';
    const themeColors = {'teal', 'blue', 'purple', 'orange', 'rose'};
    themeColor = themeColors.contains(values['theme_color'])
        ? values['theme_color']!
        : 'teal';
    hideBalances = values['hide_balances'] == '1';
    remindersEnabled = values['reminders_enabled'] != '0';
    pinHash = values['pin_hash'] ?? '';
    final parsed = DateTime.tryParse(values['selected_month'] ?? '');
    if (parsed != null) selectedMonth = DateTime(parsed.year, parsed.month);
    await refresh();
  }

  Future<void> refresh() async {
    final values = await Future.wait([
      _repository!.categories(),
      _repository!.entries(),
      _repository!.accounts(),
      _repository!.budgets(),
      _repository!.recurringRules(),
      _repository!.savingGoals(),
      _repository!.billReminders(),
    ]);
    categories = values[0] as List<Category>;
    entries = values[1] as List<Entry>;
    accounts = values[2] as List<Account>;
    budgets = values[3] as List<Budget>;
    recurringRules = values[4] as List<RecurringRule>;
    savingGoals = values[5] as List<SavingGoal>;
    billReminders = values[6] as List<BillReminder>;
    notifyListeners();
  }

  List<Entry> get monthlyEntries =>
      entries.where((e) => sameMonth(e.date, selectedMonth)).toList();
  int get monthlyIncome => sumType(monthlyEntries, income);
  int get monthlyExpense => sumType(monthlyEntries, expense);
  String get selectedMonthKey =>
      '${selectedMonth.year.toString().padLeft(4, '0')}-${selectedMonth.month.toString().padLeft(2, '0')}';
  List<Budget> get monthlyBudgets =>
      budgets.where((b) => b.month == selectedMonthKey).toList();
  int get monthlyBudget => monthlyBudgets
      .where((b) => b.categoryId == null)
      .fold(0, (sum, b) => sum + b.amountMinor);
  int spentForBudget(Budget budget) => monthlyEntries
      .where((e) =>
          e.type == expense &&
          (budget.categoryId == null || e.categoryId == budget.categoryId))
      .fold(0, (sum, e) => sum + e.amountMinor);
  Account? accountFor(int id) {
    for (final value in accounts) {
      if (value.id == id) return value;
    }
    return null;
  }

  int accountBalance(Account account) =>
      account.openingBalanceMinor +
      entries.where((e) => e.accountId == account.id).fold(
          0,
          (sum, e) =>
              sum + (e.type == income ? e.amountMinor : -e.amountMinor));
  Category? categoryFor(int id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> save(Entry entry) async {
    if (entry.amountMinor <= 0 ||
        entry.title.trim().isEmpty ||
        !categories
            .any((c) => c.id == entry.categoryId && c.type == entry.type)) {
      throw ArgumentError('Invalid transaction');
    }
    await _repository!.save(entry);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repository!.delete(id);
    await refresh();
  }

  Future<void> changeMonth(DateTime date) async {
    selectedMonth = DateTime(date.year, date.month);
    await _repository!
        .setting('selected_month', selectedMonth.toIso8601String());
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await _repository!.setting('theme_mode', value ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setThemeColor(String value) async {
    const supported = {'teal', 'blue', 'purple', 'orange', 'rose'};
    if (!supported.contains(value)) return;
    themeColor = value;
    await _repository!.setting('theme_color', value);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    languageCode = code == 'en' ? 'en' : 'th';
    await _repository!.setting('language_code', languageCode);
    notifyListeners();
  }

  Future<void> setHideBalances(bool value) async {
    hideBalances = value;
    await _repository!.setting('hide_balances', value ? '1' : '0');
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool value) async {
    remindersEnabled = value;
    await _repository!.setting('reminders_enabled', value ? '1' : '0');
    notifyListeners();
  }

  bool verifyPin(String value) =>
      pinHash.isNotEmpty &&
      sha256.convert(utf8.encode(value)).toString() == pinHash;

  Future<void> setPin(String value) async {
    pinHash =
        value.isEmpty ? '' : sha256.convert(utf8.encode(value)).toString();
    await _repository!.setting('pin_hash', pinHash);
    notifyListeners();
  }

  Future<void> saveCategory(Category value) async {
    await _repository!.saveCategory(value);
    await refresh();
  }

  Future<void> saveAccount(Account value) async {
    await _repository!.saveAccount(value);
    await refresh();
  }

  Future<void> saveBudget(Budget value) async {
    await _repository!.saveBudget(value);
    await refresh();
  }

  Future<void> saveRecurringRule(RecurringRule value) async {
    await _repository!.saveRecurringRule(value);
    await refresh();
  }

  Future<void> saveGoal(SavingGoal value) async {
    await _repository!.saveGoal(value);
    await refresh();
  }

  Future<void> saveReminder(BillReminder value) async {
    await _repository!.saveReminder(value);
    await refresh();
  }

  Future<void> removePlannerItem(String table, int id) async {
    await _repository!.removePlannerItem(table, id);
    await refresh();
  }

  Future<void> generateRecurringForMonth(DateTime month) async {
    final key =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    for (final rule in recurringRules
        .where((r) => r.isActive && r.lastGeneratedMonth != key)) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final now = DateTime.now().microsecondsSinceEpoch;
      await _repository!.save(Entry(
          title: rule.title,
          amountMinor: rule.amountMinor,
          type: rule.type,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          date: DateTime(
              month.year, month.month, rule.dayOfMonth.clamp(1, lastDay)),
          note: rule.note,
          createdAt: now));
      await _repository!.saveRecurringRule(RecurringRule(
          id: rule.id,
          title: rule.title,
          amountMinor: rule.amountMinor,
          type: rule.type,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          dayOfMonth: rule.dayOfMonth,
          note: rule.note,
          isActive: rule.isActive,
          lastGeneratedMonth: key));
    }
    await refresh();
  }

  Future<void> transfer(
      {required int fromAccountId,
      required int toAccountId,
      required int amountMinor,
      required DateTime date,
      String note = ''}) async {
    if (fromAccountId == toAccountId || amountMinor <= 0)
      throw ArgumentError('Invalid transfer');
    final expenseCategory = categories.firstWhere((c) => c.type == expense);
    final incomeCategory = categories.firstWhere((c) => c.type == income);
    final now = DateTime.now().microsecondsSinceEpoch;
    await _repository!.save(Entry(
        title: 'Transfer out',
        amountMinor: amountMinor,
        type: expense,
        categoryId: expenseCategory.id,
        accountId: fromAccountId,
        date: date,
        note: note,
        createdAt: now));
    await _repository!.save(Entry(
        title: 'Transfer in',
        amountMinor: amountMinor,
        type: income,
        categoryId: incomeCategory.id,
        accountId: toAccountId,
        date: date,
        note: note,
        createdAt: now + 1));
    await refresh();
  }

  Future<void> clearEntries() async {
    await _repository!.clearEntries();
    await refresh();
  }

  String exportCsv() {
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    return [
      'date,type,category,title,amount_thb,note',
      for (final entry in entries)
        [
          entry.date.toIso8601String().substring(0, 10),
          entry.type,
          categoryFor(entry.categoryId)?.name ?? '',
          entry.title,
          (entry.amountMinor / 100).toStringAsFixed(2),
          entry.note
        ].map(quote).join(','),
    ].join('\r\n');
  }

  Future<String> exportBackupJson() async {
    const tables = [
      'transactions',
      'categories',
      'accounts',
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'settings'
    ];
    final payload = <String, Object?>{
      'format': 'monthly-flow-backup',
      'version': 1,
      'created_at': DateTime.now().toIso8601String()
    };
    for (final table in tables) {
      payload[table] = await _repository!.table(table);
    }
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importBackupJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['format'] != 'monthly-flow-backup') {
      throw const FormatException('Invalid backup');
    }
    const tables = [
      'transactions',
      'categories',
      'accounts',
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'settings'
    ];
    final backup = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      backup[table] = ((decoded[table] as List?) ?? const [])
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList();
    }
    await _repository!.replaceBackup(backup);
    await open();
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }
}
