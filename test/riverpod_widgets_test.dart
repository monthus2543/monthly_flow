import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/sync/sync_providers.dart';
import 'support/disabled_sync_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/screens/category_manager_screen.dart';
import 'package:monthly_flow/screens/home_shell.dart';
import 'package:monthly_flow/screens/splash_screen.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';

class MemoryStore extends AppStore {
  @override
  AppState build() => AppState(languageCode: 'en', onboardingCompleted: true);

  @override
  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(darkMode: value);
  }

  @override
  Future<void> saveCategory(Category category) async {
    state = state.copyWith(categories: [...state.categories, category]);
  }
}

void main() {
  testWidgets('startup shows loading, error, retry and applies live theme', (
    tester,
  ) async {
    final loading = Completer<void>();
    var attempts = 0;
    final container = ProviderContainer(
      overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
        appStoreProvider.overrideWith(MemoryStore.new),
        appStartupProvider.overrideWith((ref) {
          attempts++;
          return attempts == 1 ? loading.future : Future<void>.value();
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MonthlyFlowApp(),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    loading.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(HomeShell), findsOneWidget);
    await container.read(appStoreProvider.notifier).setDarkMode(true);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a pushed screen observes provider updates independently', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),appStoreProvider.overrideWith(MemoryStore.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoryManagerScreen(),
                  ),
                ),
                child: const Text('Open categories'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryManagerScreen), findsOneWidget);
    await container
        .read(appStoreProvider.notifier)
        .saveCategory(const Category(1, 'New category', expense, 'other'));
    await tester.pumpAndSettle();
    expect(find.text('category_New category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
