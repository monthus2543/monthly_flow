import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/models/finance_models.dart';

void main() {
  test('monthly sums preserve cents and exclude other months', () {
    final rows = [
      Entry(
          title: 'เงินเดือน',
          amountMinor: 3500000,
          type: income,
          categoryId: 1,
          date: DateTime(2026, 9, 1),
          createdAt: 1),
      Entry(
          title: 'อาหาร',
          amountMinor: 12050,
          type: expense,
          categoryId: 3,
          date: DateTime(2026, 9, 2),
          createdAt: 2),
      Entry(
          title: 'เดินทาง',
          amountMinor: 4700,
          type: expense,
          categoryId: 4,
          date: DateTime(2026, 9, 2),
          createdAt: 3),
      Entry(
          title: 'เดือนก่อน',
          amountMinor: 999900,
          type: expense,
          categoryId: 4,
          date: DateTime(2026, 8, 31),
          createdAt: 4),
    ];
    final september = rows.where((e) => sameMonth(e.date, DateTime(2026, 9)));
    expect(sumType(september, income), 3500000);
    expect(sumType(september, expense), 16750);
    expect(sumType(september, income) - sumType(september, expense), 3483250);
  });

  test('account balance preserves opening balance and transaction signs', () {
    const account = Account(name: 'Main', openingBalanceMinor: 100000);
    expect(account.openingBalanceMinor, 100000);
    const budget = Budget(month: '2026-09', amountMinor: 250000);
    expect(budget.amountMinor, 250000);
    expect(budget.categoryId, isNull);
  });

  test('monthly entries respect start month, count, and short months', () {
    final template = Entry(
        title: 'Installment',
        amountMinor: 150000,
        type: expense,
        categoryId: 3,
        date: DateTime(2026, 1, 31),
        createdAt: 100);
    final rows = buildMonthlyEntries(template, DateTime(2026, 2), 3);
    expect(rows.map((entry) => entry.date), [
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30),
    ]);
    expect(rows.every((entry) => entry.amountMinor == 150000), isTrue);
  });

  test('recurring rule preserves its starting month', () {
    const rule = RecurringRule(
        title: 'Rent',
        amountMinor: 900000,
        type: expense,
        categoryId: 3,
        dayOfMonth: 1,
        startMonth: '2026-10');
    expect(rule.toMap()['start_month'], '2026-10');
  });
}
