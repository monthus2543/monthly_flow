import 'dart:io';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monthly_flow/export/excel_report.dart';
import 'package:monthly_flow/models/finance_models.dart';

Entry entry(
  String title,
  int amount,
  String type,
  DateTime date, {
  int account = 1,
  int category = 1,
}) => Entry(
  title: title,
  amountMinor: amount,
  type: type,
  categoryId: category,
  accountId: account,
  date: date,
  createdAt: 0,
);

void main() {
  setUpAll(() => initializeDateFormatting('th'));
  test('export labels use the selected currency without converting amounts', () {
    final report = ExcelReportData(options: ReportOptions(years: [2026], currencyCode: 'USD', language: 'en'),
      entries: [entry('Income', 123456, income, DateTime(2026, 1, 1))], categoryNames: {}, accountNames: {});
    final wb = Excel.decodeBytes(buildExcelReport(report));
    for (final sheet in wb.tables.values) {
      expect(sheet.cell(CellIndex.indexByString('A2')).value.toString(), contains('Currency USD'));
    }
    expect(report.years.single.incomeMinor, 123456);
  });
  final entries = [
    entry('เงินเดือน', 2400050, income, DateTime(2024, 1, 1)),
    entry('อาหาร', 12345, expense, DateTime(2024, 2, 29)),
    entry('=SUM(A1:A3)', 50, expense, DateTime(2024, 12, 31)),
    entry(
      'Different wallet',
      9900,
      expense,
      DateTime(2024, 1, 1),
      account: 2,
      category: 2,
    ),
    entry('Outside year', 100, expense, DateTime(2023, 1, 1)),
  ];
  ExcelReportData data({bool charts = true, int? account}) => ExcelReportData(
    options: ReportOptions(
      years: [2025, 2024, 2024],
      includeCharts: charts,
      accountId: account,
    ),
    entries: entries,
    categoryNames: {1: 'อาหาร', 2: 'เดินทาง'},
    accountNames: {1: 'เงินสด', 2: 'ธนาคาร'},
  );

  test(
    'workbook round trips real numeric totals, leap dates, Thai and editable charts',
    () {
      final report = data(account: 1);
      final bytes = buildExcelReport(report);
      final wb = Excel.decodeBytes(bytes);
      expect(wb.tables.keys.toList(), ['ภาพรวม', '2024', '2025']);
      final year = wb['2024'];
      expect(
        year.cell(CellIndex.indexByString('B4')).value,
        DoubleCellValue(24000.5),
      );
      expect(
        year.cell(CellIndex.indexByString('B5')).value,
        DoubleCellValue(123.95),
      );
      expect(
        year.cell(CellIndex.indexByString('D10')).value,
        DoubleCellValue(-123.45),
      );
      expect(
        year.cell(CellIndex.indexByString('A20')).value,
        TextCellValue('ธันวาคม'),
      );
      expect(
        year.cell(CellIndex.indexByString('A55')).displayText,
        '2024-02-29',
      );
      expect(
        year.cell(CellIndex.indexByString('B56')).value,
        TextCellValue('=SUM(A1:A3)'),
      );
      expect(year.charts.length, 3);
      expect(year.charts.first.series.length, 2);
      expect(
        wb['2025'].cell(CellIndex.indexByString('B4')).value,
        IntCellValue(0),
      );
      expect(
        wb['2025'].cell(CellIndex.indexByString('A54')).value,
        TextCellValue('ไม่มีข้อมูล'),
      );
      final directory = Directory('build/export-preview')
        ..createSync(recursive: true);
      File(
        '${directory.path}/MonthlyFlow_2024-2025.xlsx',
      ).writeAsBytesSync(bytes);
    },
  );
  test('filters use the same totals and charts can be omitted', () {
    final report = data(charts: false, account: 2);
    expect(report.years.first.expenseMinor, 9900);
    final wb = Excel.decodeBytes(buildExcelReport(report));
    expect(wb['2024'].charts, isEmpty);
    expect(
      wb['2024'].cell(CellIndex.indexByString('B5')).value,
      IntCellValue(99),
    );
    final empty = ExcelReportData(
      options: ReportOptions(years: [2024], categoryId: 99),
      entries: entries,
      categoryNames: {},
      accountNames: {},
    );
    expect(empty.years.single.entries, isEmpty);
  });
  test('large exports contain every row and never include receipt paths', () {
    final report = ExcelReportData(
      options: ReportOptions(years: [2026], includeCharts: false),
      entries: List.generate(
        2000,
        (i) => entry('รายการ $i', 101, income, DateTime(2026, 1, 1)),
      ),
      categoryNames: {},
      accountNames: {},
    );
    final wb = Excel.decodeBytes(buildExcelReport(report));
    expect(report.years.single.incomeMinor, 202000);
    final titles = List.generate(2000, (i) => wb['2026'].cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 26 + i)).value.toString());
    expect(titles.toSet(), {for (var i = 0; i < 2000; i++) 'รายการ $i'});
  });
}
