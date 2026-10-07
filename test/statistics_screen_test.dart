import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/screens/statistics_screen.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/widgets/common_widgets.dart';

class StatisticsStore extends AppStore {
  @override
  AppState build() => AppState(selectedMonth: DateTime(2026, 10));

  void setEntries(List<Entry> entries) {
    state = state.copyWith(entries: entries);
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('empty and populated statistics follow $brightness theme',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(overrides: [
        appStoreProvider.overrideWith(StatisticsStore.new),
      ]);
      addTearDown(container.dispose);
      final theme = appTheme(brightness, 'rose');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          locale: const Locale('th'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: StatisticsScreen()),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ไม่มีข้อมูล'));
      await tester.pumpAndSettle();
      expect(find.text('ไม่มีข้อมูล'), findsOneWidget);
      expect(find.byType(Table), findsNothing);
      expect(find.byType(PieChart), findsOneWidget);

      final store =
          container.read(appStoreProvider.notifier) as StatisticsStore;
      // Records in a different month must not suppress the empty state.
      store.setEntries([
        Entry(
            title: 'Previous month',
            amountMinor: 10000,
            type: income,
            categoryId: 1,
            date: DateTime(2026, 9, 1),
            createdAt: 0),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('ไม่มีข้อมูล'), findsOneWidget);

      // Balance is displayed in the summary, never counted as a pie slice.
      final salary = Entry(title: 'Salary', amountMinor: 2400000,
          type: income, categoryId: 1, date: DateTime(2026, 10, 1), createdAt: 0);
      store.setEntries([salary]);
      await tester.pumpAndSettle();
      var sections = tester.widget<PieChart>(find.byType(PieChart)).data.sections;
      expect(sections, hasLength(1));
      expect(sections.single.value, 2400000);
      expect(sections.single.title, '100%');

      store.setEntries([salary, Entry(title: 'Expense', amountMinor: 800000,
          type: expense, categoryId: 1, date: DateTime(2026, 10, 2), createdAt: 0)]);
      await tester.pumpAndSettle();
      sections = tester.widget<PieChart>(find.byType(PieChart)).data.sections;
      expect(sections.map((section) => section.value), [2400000, 800000]);
      expect(sections.map((section) => section.title), ['75%', '25%']);

      // A populated month with zero balance must still render its data.
      store.setEntries([
        Entry(
            title: 'Salary',
            amountMinor: 10000,
            type: income,
            categoryId: 1,
            date: DateTime(2026, 10, 1),
            createdAt: 0),
        Entry(
            title: 'Expense',
            amountMinor: 10000,
            type: expense,
            categoryId: 1,
            date: DateTime(2026, 10, 2),
            createdAt: 0),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('ไม่มีข้อมูล'), findsNothing);
      await tester.ensureVisible(find.byType(PieChart));
      await tester.pumpAndSettle();
      expect(find.byType(PieChart), findsOneWidget);
      await tester.ensureVisible(find.text('ตารางรายรับ / รายจ่าย'));
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      // Statistics read from oldest date to newest; same-day rows follow
      // insertion order even when edited later or supplied in reverse order.
      final unordered = [
        Entry(id: 4, title: 'Later day', amountMinor: 10000,
            type: expense, categoryId: 1, date: DateTime(2026, 10, 3), createdAt: 1),
        Entry(id: 3, title: 'Same timestamp later', amountMinor: 10000,
            type: expense, categoryId: 1, date: DateTime(2026, 10, 2), createdAt: 20),
        Entry(id: 2, title: 'Second added', amountMinor: 10000,
            type: expense, categoryId: 1, date: DateTime(2026, 10, 2), createdAt: 20),
        Entry(id: 1, title: 'First added', amountMinor: 10000,
            type: income, categoryId: 1, date: DateTime(2026, 10, 2, 12),
            createdAt: 10, updatedAt: 100),
      ];
      store.setEntries(unordered);
      await tester.pumpAndSettle();
      final table = tester.widget<Table>(find.byType(Table));
      final titles = table.children.skip(1).take(4).map((row) =>
          ((row.children.first as Padding).child as Text).data).toList();
      expect(titles, ['First added', 'Second added', 'Same timestamp later', 'Later day']);
      expect(store.entries.map((entry) => entry.title), unordered.map((entry) => entry.title));
      for (final surface in tester.widgetList<Surface>(find.byType(Surface))) {
        final box = tester.widget<Container>(find
            .descendant(
                of: find.byWidget(surface), matching: find.byType(Container))
            .first);
        expect((box.decoration as BoxDecoration).color, theme.cardColor);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
