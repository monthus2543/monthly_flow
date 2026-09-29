import 'package:sqflite/sqflite.dart';

import '../models/finance_models.dart';

class FinanceRepository {
  final Database db;
  const FinanceRepository(this.db);

  Future<List<Category>> categories() async => (await db.query('categories',
          where: 'is_active = 1', orderBy: 'sort_order ASC, id ASC'))
      .map(Category.fromMap)
      .toList();

  Future<List<Entry>> entries() async => (await db.query('transactions',
          orderBy: 'transaction_date DESC, created_at DESC, id DESC'))
      .map(Entry.fromMap)
      .toList();

  Future<List<Account>> accounts() async =>
      (await db.query('accounts', where: 'is_active = 1', orderBy: 'id ASC'))
          .map(Account.fromMap)
          .toList();
  Future<List<Budget>> budgets() async =>
      (await db.query('budgets')).map(Budget.fromMap).toList();
  Future<List<RecurringRule>> recurringRules() async =>
      (await db.query('recurring_rules', orderBy: 'day_of_month ASC'))
          .map(RecurringRule.fromMap)
          .toList();
  Future<List<SavingGoal>> savingGoals() async =>
      (await db.query('saving_goals', orderBy: 'id DESC'))
          .map(SavingGoal.fromMap)
          .toList();
  Future<List<BillReminder>> billReminders() async =>
      (await db.query('bill_reminders', orderBy: 'day_of_month ASC'))
          .map(BillReminder.fromMap)
          .toList();

  Future<Map<String, String>> settings() async => {
        for (final row in await db.query('settings'))
          row['key'] as String: row['value'] as String,
      };

  Future<void> save(Entry entry) async {
    if (entry.id == null) {
      await db.insert('transactions', entry.toMap());
    } else {
      await db.update('transactions', entry.toMap(),
          where: 'id = ?', whereArgs: [entry.id]);
    }
  }

  Future<void> delete(int id) =>
      db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  Future<void> saveCategory(Category value) async {
    if (value.id <= 0) {
      await db.insert('categories', value.toMap());
    } else {
      await db.update('categories', value.toMap(),
          where: 'id = ?', whereArgs: [value.id]);
    }
  }

  Future<void> saveAccount(Account value) async {
    if (value.id == null)
      await db.insert('accounts', value.toMap());
    else
      await db.update('accounts', value.toMap(),
          where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> saveBudget(Budget value) async {
    if (value.id == null)
      await db.insert('budgets', value.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    else
      await db.update('budgets', value.toMap(),
          where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> saveRecurringRule(RecurringRule value) async {
    if (value.id == null)
      await db.insert('recurring_rules', value.toMap());
    else
      await db.update('recurring_rules', value.toMap(),
          where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> saveGoal(SavingGoal value) async {
    if (value.id == null)
      await db.insert('saving_goals', value.toMap());
    else
      await db.update('saving_goals', value.toMap(),
          where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> saveReminder(BillReminder value) async {
    if (value.id == null)
      await db.insert('bill_reminders', value.toMap());
    else
      await db.update('bill_reminders', value.toMap(),
          where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> removePlannerItem(String table, int id) =>
      db.delete(table, where: 'id = ?', whereArgs: [id]);
  Future<void> transaction(Future<void> Function(Transaction txn) action) =>
      db.transaction(action);
  Future<List<Map<String, Object?>>> table(String name) => db.query(name);
  Future<void> replaceBackup(
      Map<String, List<Map<String, Object?>>> backup) async {
    const insertOrder = [
      'categories',
      'accounts',
      'transactions',
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'settings'
    ];
    await db.transaction((txn) async {
      const deleteOrder = [
        'transactions',
        'budgets',
        'recurring_rules',
        'saving_goals',
        'bill_reminders',
        'categories',
        'accounts',
        'settings'
      ];
      for (final name in deleteOrder) {
        await txn.delete(name);
      }
      for (final name in insertOrder) {
        for (final row in backup[name] ?? const <Map<String, Object?>>[]) {
          await txn.insert(name, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> clearEntries() => db.delete('transactions');
  Future<void> setting(String key, String value) =>
      db.insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
}
