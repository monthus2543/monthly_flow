import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/screens/category_manager_screen.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/color/color.dart';

class CategoryStore extends AppStore {
  CategoryStore({this.initial});
  final AppState? initial;
  final saved = <Category>[];
  @override
  AppState build() =>
      initial ??
      AppState(
        categories: const [
          Category(1, 'Expense category', expense, 'other'),
          Category(2, 'Income category', income, 'other'),
        ],
      );
  @override
  Future<void> saveCategory(Category value) async {
    saved.add(value);
    final category = Category(
      value.id == 0 ? state.categories.length + 1 : value.id,
      value.name,
      value.type,
      value.icon,
      isActive: value.isActive,
      colorValue: value.colorValue,
    );
    state = state.copyWith(
      categories: [
        ...state.categories.where((item) => item.id != category.id),
        if (category.isActive) category,
      ],
    );
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Thai category dialog localizes default name and fits enlarged text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            appStoreProvider.overrideWith(
              () => CategoryStore(
                initial: AppState(
                  categories: const [Category(1, 'food', expense, 'other')],
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final label = const AppLocalizations(Locale('th')).category('food');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: appTheme(brightness, 'orange'),
              locale: const Locale('th'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const CategoryManagerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          label,
        );
        await tester.enterText(find.byType(TextFormField), '');
        await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
        await tester.pumpAndSettle();
        expect(find.text('กรุณาใส่ชื่อหมวดหมู่'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), label);
        await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
        await tester.pumpAndSettle();
        final store =
            container.read(appStoreProvider.notifier) as CategoryStore;
        expect(store.saved.single.name, 'food');
        expect(store.saved.single.type, expense);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final brightness in Brightness.values) {
    for (final accent in ['blue', 'orange']) {
      testWidgets(
        'category tabs and additions follow type in $brightness $accent',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = ProviderContainer(
            overrides: [appStoreProvider.overrideWith(CategoryStore.new)],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: appTheme(brightness, accent),
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const CategoryManagerScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final store =
              container.read(appStoreProvider.notifier) as CategoryStore;
          expect(find.text('Expense category').hitTestable(), findsOneWidget);
          expect(find.text('Income category').hitTestable(), findsNothing);
          expect(
            tester
                .widget<FloatingActionButton>(find.byType(FloatingActionButton))
                .backgroundColor,
            AppColors.categoryExpense,
          );
          for (final type in [expense, income]) {
            if (type == income) {
              await tester.tap(find.byKey(const ValueKey('segment-income')));
              await tester.pumpAndSettle();
              expect(
                find.text('Income category').hitTestable(),
                findsOneWidget,
              );
            }
            final color = type == expense
                ? AppColors.categoryExpense
                : AppColors.categoryIncome;
            expect(
              tester
                  .widget<FloatingActionButton>(
                    find.byType(FloatingActionButton),
                  )
                  .backgroundColor,
              color,
            );
            await tester.tap(find.byType(FloatingActionButton));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'New $type');
            await tester.tap(find.text('Text color'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('category-color-#2563EB')));
            await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
            await tester.pumpAndSettle();
            await tester.tap(
              find.widgetWithText(FilledButton, 'Save'),
            );
            await tester.pumpAndSettle();
            expect(store.saved.last.type, type);
            expect(store.saved.last.colorValue, AppColors.blue.toARGB32());
            expect(find.text('New $type').hitTestable(), findsOneWidget);
          }
          await tester.drag(find.byType(TabBarView), const Offset(330, 0));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FloatingActionButton>(find.byType(FloatingActionButton))
                .backgroundColor,
            AppColors.categoryExpense,
          );
          await tester.tap(find.text('Expense category'));
          await tester.pumpAndSettle();
          expect(find.text('Hide category'), findsNothing);
          await tester.enterText(find.byType(TextFormField), 'Renamed expense');
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await tester.pumpAndSettle();
          expect(store.saved.last.id, 1);
          expect(store.saved.last.type, expense);
          expect(store.saved.last.isActive, isTrue);
          expect(store.saved.last.name, 'Renamed expense');
          await tester.tap(find.text('New expense'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Text color'));
          await tester.pumpAndSettle();
          final hexField = find.widgetWithText(TextFormField, 'Color code (#RRGGBB)');
          expect(tester.widget<TextFormField>(hexField).controller!.text, '#2563EB');
          await tester.enterText(hexField, 'invalid');
          await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
          await tester.pumpAndSettle();
          expect(find.text('Enter a six-digit color code, such as #2563EB.'), findsOneWidget);
          await tester.enterText(hexField, '#123456');
          await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await tester.pumpAndSettle();
          expect(store.saved.last.colorValue, 0xff123456);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
