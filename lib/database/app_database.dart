import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../sync/sync_local.dart';

import '../models/finance_models.dart';

class AppDatabase {
  Database? _database;
  final String? accountId;
  AppDatabase({this.accountId});

  Future<Database> open() async {
    if (_database != null) return _database!;
    final base = await getDatabasesPath();
    final name = accountId == null ? 'monthly_flow' : 'monthly_flow_${sha256.convert(utf8.encode(accountId!))}';
    _database = await openDatabase('$base/$name.db',
        version: 6,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA recursive_triggers = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          type TEXT NOT NULL, icon_key TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1)''');
          await db.execute('''CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
          amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
          type TEXT NOT NULL CHECK(type IN ('income','expense')),
          category_id INTEGER NOT NULL, transaction_date TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          account_id INTEGER NOT NULL DEFAULT 1, receipt_path TEXT NOT NULL DEFAULT '',
          is_favorite INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(category_id) REFERENCES categories(id))''');
          await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          await _seedCategories(db);
          await _createPlannerTables(db);
          await initializeSyncSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
            await db.execute(
                'ALTER TABLE categories ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
            await db.execute(
                'ALTER TABLE transactions ADD COLUMN updated_at INTEGER');
            await db.execute(
                'UPDATE transactions SET updated_at = created_at WHERE updated_at IS NULL');
          }
          if (oldVersion < 3) {
            await db.execute(
                "ALTER TABLE transactions ADD COLUMN account_id INTEGER NOT NULL DEFAULT 1");
            await db.execute(
                "ALTER TABLE transactions ADD COLUMN receipt_path TEXT NOT NULL DEFAULT ''");
            await db.execute(
                "ALTER TABLE transactions ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0");
            await _createPlannerTables(db);
          }
          if (oldVersion >= 3 && oldVersion < 5) {
            await db.execute(
                "ALTER TABLE recurring_rules ADD COLUMN start_month TEXT NOT NULL DEFAULT ''");
          }
          if (oldVersion < 6) await initializeSyncSchema(db);
        });
    return _database!;
  }

  Future<void> _createPlannerTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'cash', opening_balance_minor INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1)''');
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM accounts')) ??
        0;
    if (count == 0) {
      await db.insert('accounts', {
        'id': 1,
        'name': 'cash',
        'kind': 'cash',
        'opening_balance_minor': 0,
        'is_active': 1
      });
    }
    await db.execute('''CREATE TABLE IF NOT EXISTS budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT, month TEXT NOT NULL,
      category_id INTEGER, amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      UNIQUE(month, category_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS recurring_rules (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
      amount_minor INTEGER NOT NULL, type TEXT NOT NULL, category_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL DEFAULT 1, day_of_month INTEGER NOT NULL,
      note TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
      last_generated_month TEXT NOT NULL DEFAULT '',
      start_month TEXT NOT NULL DEFAULT '')''');
    await db.execute('''CREATE TABLE IF NOT EXISTS saving_goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      target_minor INTEGER NOT NULL, saved_minor INTEGER NOT NULL DEFAULT 0,
      due_date TEXT NOT NULL DEFAULT '')''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bill_reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
      amount_minor INTEGER NOT NULL DEFAULT 0, day_of_month INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1)''');
  }

  Future<void> _seedCategories(Database db) async {
    final rows = <List<Object>>[
      ['salary', income, 'work', 1],
      ['other_income', income, 'wallet', 2],
      ['food', expense, 'food', 1],
      ['travel', expense, 'travel', 2],
      ['housing', expense, 'home', 3],
      ['shopping', expense, 'shopping', 4],
      ['entertainment', expense, 'fun', 5],
      ['other', expense, 'other', 6],
    ];
    for (final row in rows) {
      await db.insert('categories', {
        'name': row[0],
        'type': row[1],
        'icon_key': row[2],
        'sort_order': row[3],
        'is_active': 1
      });
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
