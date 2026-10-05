import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/screens/entry_form_screen.dart';
import 'package:monthly_flow/screens/home_shell.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/widgets/common_widgets.dart';
import 'support/fake_auth_repository.dart';

class SheetStore extends AppStore {
  @override
  AppState build() => AppState(selectedMonth: DateTime(2026, 10));

  @override
  Future<void> changeMonth(DateTime date) async {
    state = state.copyWith(selectedMonth: DateTime(date.year, date.month));
  }
}

Widget testApp(ThemeData theme, Widget home) => MaterialApp(
  theme: theme,
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  for (final brightness in Brightness.values) {
    for (final accent in ['orange', 'rose']) {
      testWidgets('edit form uses $accent in $brightness', (tester) async {
        final theme = appTheme(brightness, accent);
        final scheme = theme.colorScheme;
        final container = ProviderContainer(
          overrides: [appStoreProvider.overrideWith(SheetStore.new)],
        );
        addTearDown(container.dispose);
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final entry = Entry(
          id: 1,
          title: 'Salary',
          amountMinor: 2400000,
          type: income,
          categoryId: 1,
          date: DateTime(2026, 10),
          createdAt: 1,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: testApp(theme, EntryFormScreen(existing: entry)),
          ),
        );
        await tester.pumpAndSettle();
        final formTheme = Theme.of(
          tester.element(find.byType(TextFormField).first),
        );
        expect(formTheme.scaffoldBackgroundColor, Colors.transparent);
        expect(formTheme.appBarTheme.backgroundColor, Colors.transparent);
        final background = tester.widget<DecoratedBox>(find.ancestor(
          of: find.byType(Scaffold), matching: find.byType(DecoratedBox)).first);
        expect((background.decoration as BoxDecoration).gradient,
          appBackgroundGradient(tester.element(find.byType(Scaffold))));
        expect(formTheme.appBarTheme.foregroundColor, scheme.onSurface);
        expect(
          formTheme.inputDecorationTheme.fillColor,
          scheme.surfaceContainerLowest,
        );
        expect(
          formTheme.inputDecorationTheme.enabledBorder!.borderSide.color,
          scheme.outlineVariant,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color,
          scheme.error,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('entry sheet follows $brightness theme and fits the keyboard', (
      tester,
    ) async {
      final base = appTheme(brightness, 'rose');
      final sheetColor = base.colorScheme.surfaceContainerHigh;
      final theme = base.copyWith(
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: sheetColor,
          modalBackgroundColor: sheetColor,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);
      final repository = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          appStoreProvider.overrideWith(SheetStore.new),
          authRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(theme, const HomeShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, sheetColor);
      expect(sheet.showDragHandle, isTrue);
      final sheetMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(sheetMaterial.shape, base.bottomSheetTheme.shape);
      final formContext = tester.element(find.byType(EntryFormScreen));
      expect(Theme.of(formContext).scaffoldBackgroundColor, sheetColor);
      expect(Theme.of(formContext).appBarTheme.backgroundColor, sheetColor);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(formContext).pop();
      await tester.pumpAndSettle();
      expect(find.byType(EntryFormScreen), findsNothing);
      expect(container.read(appStoreProvider).entries, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('month sheet uses $brightness theme and returns a selection', (
      tester,
    ) async {
      final base = appTheme(brightness, 'rose');
      final sheetColor = base.colorScheme.surfaceContainerHigh;
      final theme = base.copyWith(
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: sheetColor,
          modalBackgroundColor: sheetColor,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [appStoreProvider.overrideWith(SheetStore.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(theme, const Scaffold(body: MonthButton())),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, sheetColor);
      expect(sheet.showDragHandle, isTrue);
      await tester.tap(find.text('Feb'));
      await tester.tap(find.widgetWithText(FilledButton, 'Select'));
      await tester.pumpAndSettle();
      expect(container.read(appStoreProvider).selectedMonth, DateTime(2026, 2));
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
