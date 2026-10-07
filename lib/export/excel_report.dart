import 'dart:typed_data';
import 'package:excel_plus/excel_plus.dart';
import '../models/finance_models.dart';

const excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class ReportOptions {
  ReportOptions({
    required Iterable<int> years,
    this.accountId,
    this.categoryId,
    this.includeCharts = true,
    this.language = 'th',
    this.currencyCode = 'THB',
  }) : years = (years.toSet().toList()..sort());
  final List<int> years;
  final int? accountId;
  final int? categoryId;
  final bool includeCharts;
  final String language;
  final String currencyCode;
}

class YearReport {
  YearReport(this.year, this.entries);
  final int year;
  final List<Entry> entries;
  int get incomeMinor => sumType(entries, income);
  int get expenseMinor => sumType(entries, expense);
  int get netMinor => incomeMinor - expenseMinor;
  int monthTotal(int month, String type) =>
      sumType(entries.where((e) => e.date.month == month).toList(), type);
}

class ExcelReportData {
  ExcelReportData({
    this.ownerId,
    required this.options,
    required Iterable<Entry> entries,
    required this.categoryNames,
    required this.accountNames,
  }) : years = options.years
           .map(
             (year) => YearReport(
               year,
               entries
                   .where(
                     (e) =>
                         e.date.year == year &&
                         (options.accountId == null ||
                             e.accountId == options.accountId) &&
                         (options.categoryId == null ||
                             e.categoryId == options.categoryId),
                   )
                   .toList()
                 ..sort((a, b) => a.date.compareTo(b.date)),
             ),
           )
           .toList();
  final ReportOptions options;
  final String? ownerId;
  final List<YearReport> years;
  final Map<int, String> categoryNames;
  final Map<int, String> accountNames;
}

/// Pure Dart: builds off the UI thread through compute in the export controller.
Uint8List buildExcelReport(ExcelReportData data) {
  if (data.years.isEmpty) throw ArgumentError('Select at least one year');
  final th = data.options.language == 'th';
  String label(String thai, String english) => th ? thai : english;
  const thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  const englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final wb = Excel.createExcel();
  final overviewName = label('ภาพรวม', 'Overview');
  final overview = wb[overviewName];
  wb.delete('Sheet1');
  wb.setDefaultSheet(overviewName);
  final titleStyle = CellStyle(
    bold: true,
    fontSize: 20,
    fontColorHex: ExcelColor.fromHexString('#007F65'),
  );
  final headerStyle = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#D9FAF1'),
    fontColorHex: ExcelColor.fromHexString('#123C39'),
  );
  final moneyStyle = CellStyle(
    numberFormat: NumFormat.custom(formatCode: '#,##0.00;[Red]-#,##0.00'),
    fontFamily: 'Calibri',
  );
  void row(
    Sheet sheet,
    int index,
    List<CellValue?> values, {
    bool header = false,
  }) {
    for (var c = 0; c < values.length; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: index),
        values[c],
        cellStyle: header
            ? headerStyle
            : values[c] is DoubleCellValue
            ? moneyStyle
            : values[c] is DateCellValue
            ? CellStyle(
                numberFormat: NumFormat.custom(formatCode: 'yyyy-mm-dd'),
              )
            : CellStyle(textWrapping: TextWrapping.WrapText),
      );
    }
    sheet.setRowHeight(index, header ? 28 : 22);
  }

  TextCellValue text(String s) => TextCellValue(s);
  DoubleCellValue amount(int minor) => DoubleCellValue(minor / 100);
  void setup(Sheet sheet, String title) {
    sheet.updateCell(
      CellIndex.indexByString('A1'),
      text(title),
      cellStyle: titleStyle,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
    sheet.setRowHeight(0, 34);
    for (var c = 0; c < 8; c++)
      sheet.setColumnWidth(c, c == 1 || c == 7 ? 28 : 18);
    sheet.freezePanes(rows: 3);
    row(sheet, 1, [
      text(
        label(
          'สกุลเงิน ${data.options.currencyCode} · ยอดจากรายการที่เลือก',
          'Currency ${data.options.currencyCode} · totals from selected transactions',
        ),
      ),
    ]);
  }

  setup(overview, 'Monthly Flow · $overviewName');
  row(overview, 3, [
    text(label('ปี', 'Year')),
    text(label('รายรับ', 'Income')),
    text(label('รายจ่าย', 'Expenses')),
    text(label('สุทธิ', 'Net')),
    text(label('รายการ', 'Transactions')),
  ], header: true);
  for (var i = 0; i < data.years.length; i++) {
    final y = data.years[i];
    row(overview, 4 + i, [
      IntCellValue(y.year),
      amount(y.incomeMinor),
      amount(y.expenseMinor),
      amount(y.netMinor),
      IntCellValue(y.entries.length),
    ]);
  }
  row(overview, 4 + data.years.length, [
    text(label('รวม', 'Total')),
    amount(data.years.fold(0, (a, y) => a + y.incomeMinor)),
    amount(data.years.fold(0, (a, y) => a + y.expenseMinor)),
    amount(data.years.fold(0, (a, y) => a + y.netMinor)),
  ], header: true);
  row(overview, 7 + data.years.length, [
    text(label('บัญชี/กระเป๋าเงิน', 'Account')),
    text(data.accountNames[data.options.accountId] ?? label('ทั้งหมด', 'All')),
  ]);
  row(overview, 8 + data.years.length, [
    text(label('หมวดหมู่', 'Category')),
    text(
      data.categoryNames[data.options.categoryId] ?? label('ทั้งหมด', 'All'),
    ),
  ]);

  for (final y in data.years) {
    final sheet = wb['${y.year}'];
    setup(sheet, 'Monthly Flow · ${y.year}');
    row(sheet, 3, [text(label('รายรับ', 'Income')), amount(y.incomeMinor)]);
    row(sheet, 4, [text(label('รายจ่าย', 'Expenses')), amount(y.expenseMinor)]);
    row(sheet, 5, [text(label('สุทธิ', 'Net')), amount(y.netMinor)]);
    row(sheet, 7, [
      text(label('เดือน', 'Month')),
      text(label('รายรับ', 'Income')),
      text(label('รายจ่าย', 'Expenses')),
      text(label('สุทธิ', 'Net')),
    ], header: true);
    for (var month = 1; month <= 12; month++) {
      final incoming = y.monthTotal(month, income);
      final outgoing = y.monthTotal(month, expense);
      row(sheet, 7 + month, [
        text((th ? thaiMonths : englishMonths)[month - 1]),
        amount(incoming),
        amount(outgoing),
        amount(incoming - outgoing),
      ]);
    }
    final categoryTotals = <int, int>{};
    for (final e in y.entries.where((e) => e.type == expense)) {
      categoryTotals.update(
        e.categoryId,
        (n) => n + e.amountMinor,
        ifAbsent: () => e.amountMinor,
      );
    }
    final categories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    row(sheet, 22, [
      text(label('หมวดรายจ่าย', 'Expense category')),
      text(label('จำนวนเงิน', 'Amount')),
    ], header: true);
    for (var i = 0; i < categories.length; i++) {
      row(sheet, 23 + i, [
        text(data.categoryNames[categories[i].key] ?? label('อื่น ๆ', 'Other')),
        amount(categories[i].value),
      ]);
    }
    if (data.options.includeCharts) {
      final green = ChartSeriesStyle(fill: ExcelColor.fromHexString('#008E7B'));
      final red = ChartSeriesStyle(fill: ExcelColor.fromHexString('#FF5F52'));
      sheet.addChart(
        Chart.column(
          anchor: CellIndex.indexByString('F3'),
          title: label('รายรับ / รายจ่ายรายเดือน', 'Monthly income / expenses'),
          categories: 'A9:A20',
          series: [
            ChartSeries(
              name: label('รายรับ', 'Income'),
              values: 'B9:B20',
              style: green,
            ),
            ChartSeries(
              name: label('รายจ่าย', 'Expenses'),
              values: 'C9:C20',
              style: red,
            ),
          ],
        ),
      );
      sheet.addChart(
        Chart.line(
          anchor: CellIndex.indexByString('F19'),
          title: label('เงินสุทธิรายเดือน', 'Monthly net'),
          categories: 'A9:A20',
          series: [
            ChartSeries(
              name: label('สุทธิ', 'Net'),
              values: 'D9:D20',
              style: green,
            ),
          ],
        ),
      );
      if (categories.isNotEmpty)
        sheet.addChart(
          Chart.doughnut(
            anchor: CellIndex.indexByString('F35'),
            title: label('สัดส่วนรายจ่ายตามหมวดหมู่', 'Expenses by category'),
            categories: 'A24:A${23 + categories.length}',
            series: ChartSeries(
              name: label('รายจ่าย', 'Expenses'),
              values: 'B24:B${23 + categories.length}',
            ),
          ),
        );
    }
    final detailRow = data.options.includeCharts
        ? (categories.length + 25 > 52 ? categories.length + 25 : 52)
        : categories.length + 25;
    row(sheet, detailRow, [
      text(label('วันที่', 'Date')),
      text(label('ชื่อรายการ', 'Title')),
      text(label('ประเภท', 'Type')),
      text(label('หมวดหมู่', 'Category')),
      text(label('บัญชี/กระเป๋าเงิน', 'Account')),
      text(label('รายรับ', 'Income')),
      text(label('รายจ่าย', 'Expenses')),
      text(label('หมายเหตุ', 'Note')),
    ], header: true);
    for (var i = 0; i < y.entries.length; i++) {
      final e = y.entries[i];
      row(sheet, detailRow + i + 1, [
        DateCellValue(year: e.date.year, month: e.date.month, day: e.date.day),
        text(e.title),
        text(
          e.type == income
              ? label('รายรับ', 'Income')
              : label('รายจ่าย', 'Expenses'),
        ),
        text(data.categoryNames[e.categoryId] ?? label('อื่น ๆ', 'Other')),
        text(data.accountNames[e.accountId] ?? label('ไม่ระบุ', 'Unknown')),
        amount(e.type == income ? e.amountMinor : 0),
        amount(e.type == expense ? e.amountMinor : 0),
        text(e.note),
      ]);
    }
    if (y.entries.isEmpty)
      row(sheet, detailRow + 1, [text(label('ไม่มีข้อมูล', 'No data'))]);
    sheet.setAutoFilter(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: detailRow),
      CellIndex.indexByColumnRow(
        columnIndex: 7,
        rowIndex: detailRow + y.entries.length,
      ),
    );
  }
  return Uint8List.fromList(wb.save()!);
}
