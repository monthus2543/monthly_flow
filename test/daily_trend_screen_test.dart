import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/screens/daily_trend_screen.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/widgets/common_widgets.dart';

class TrendStore extends AppStore {
  @override
  AppState build() => AppState(selectedMonth: DateTime(2026, 10), entries: [
    Entry(title: 'Income', amountMinor: 2400000, type: income, categoryId: 1,
      date: DateTime(2026, 10, 1), createdAt: 1),
    Entry(title: 'Expense', amountMinor: 500000, type: expense, categoryId: 3,
      date: DateTime(2026, 10, 1), createdAt: 2),
  ]);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('daily charts use themed surfaces and readable labels $brightness', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final theme = appTheme(brightness, 'orange');
      await tester.pumpWidget(ProviderScope(overrides: [appStoreProvider.overrideWith(TrendStore.new)],
        child: MaterialApp(theme: theme, locale: const Locale('th'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate(), GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const DailyTrendScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      for (final surface in tester.widgetList<Surface>(find.byType(Surface))) {
        final container = tester.widget<Container>(find.descendant(of: find.byWidget(surface), matching: find.byType(Container)).first);
        expect((container.decoration as BoxDecoration).color, theme.cardColor);
      }
      expect(tester.widget<Text>(find.text('สัปดาห์ที่ 1 · วันที่ 1–7')).style!.color, theme.colorScheme.onSurface);
      final data = tester.widget<BarChart>(find.byType(BarChart).first).data;
      expect(data.barGroups.first.barRods.map((rod) => rod.toY), [2400000, 500000]);
      expect(data.barGroups.first.barRods.map((rod) => rod.color), brightness == Brightness.dark
        ? [AppColors.tealDark, AppColors.errorDark] : [brandGreen, expenseRed]);
      final grid = data.gridData.getDrawingHorizontalLine(0);
      expect(grid.color, theme.dividerColor.withValues(alpha: .6));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
