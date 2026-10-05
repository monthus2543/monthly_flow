import 'package:monthly_flow/auth/auth_providers.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/database/app_database.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RetryDatabase extends AppDatabase {
  int attempts = 0;
  int closes = 0;
  @override
  Future<Database> open() {
    if (++attempts == 1) throw StateError('Temporary startup failure');
    return super.open();
  }

  @override
  Future<void> close() async {
    closes++;
    await super.close();
  }
}

void main() {
  late Directory directory;
  late ProviderContainer container;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('monthly-flow-riverpod-');
    await databaseFactory.setDatabasesPath(directory.path);
    container = ProviderContainer(overrides: [authSessionProvider.overrideWith((ref) => Stream.value(null))]);
    container.listen(appStartupProvider, (_, __) {});
  });
  tearDown(() async {
    final database = container.read(appDatabaseProvider);
    container.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('first-run completion and local name survive a new scope', () async {
    await container.read(appStartupProvider.future);
    final store = container.read(appStoreProvider.notifier);
    expect(container.read(appStoreProvider).onboardingCompleted, isFalse);
    await expectLater(
      store.completeOnboarding(localName: '   '),
      throwsArgumentError,
    );
    expect(container.read(appStoreProvider).onboardingCompleted, isFalse);
    await store.completeOnboarding(localName: '  อิ้งค์  ');
    expect(container.read(appStoreProvider).localName, 'อิ้งค์');
    final restored = ProviderContainer(overrides: [authSessionProvider.overrideWith((ref) => Stream.value(null))]);
    restored.listen(appStartupProvider, (_, __) {});
    await restored.read(appStartupProvider.future);
    expect(restored.read(appStoreProvider).onboardingCompleted, isTrue);
    expect(restored.read(appStoreProvider).localName, 'อิ้งค์');
    restored.dispose();
  });

  test('Google onboarding persists completion without a local name', () async {
    await container.read(appStartupProvider.future);
    await container.read(appStoreProvider.notifier).completeOnboarding();
    final restored = ProviderContainer(overrides: [authSessionProvider.overrideWith((ref) => Stream.value(null))]);
    restored.listen(appStartupProvider, (_, __) {});
    await restored.read(appStartupProvider.future);
    expect(restored.read(appStoreProvider).onboardingCompleted, isTrue);
    expect(restored.read(appStoreProvider).localName, isEmpty);
    restored.dispose();
  });

  test(
    'CRUD, month totals and persisted settings survive a new scope',
    () async {
      await container.read(appStartupProvider.future);
      final store = container.read(appStoreProvider.notifier);
      final initial = container.read(appStoreProvider);
      final month = DateTime(2026, 8);
      await store.changeMonth(month);
      final category = store.categories.firstWhere((c) => c.type == expense);
      await store.save(
        Entry(
          title: 'Lunch',
          amountMinor: 12500,
          type: expense,
          categoryId: category.id,
          date: DateTime(2026, 8, 10),
          createdAt: 1,
        ),
      );
      expect(initial.entries, isEmpty);
      expect(
        () => container.read(appStoreProvider).entries.clear(),
        throwsUnsupportedError,
      );
      expect(store.monthlyExpense, 12500);
      await store.changeMonth(DateTime(2026, 9));
      expect(store.monthlyExpense, 0);
      await store.changeMonth(month);
      await store.setDarkMode(true);
      await store.setThemeColor('purple');
      await store.setLanguage('en');
      await store.setHideBalances(true);
      await store.setRemindersEnabled(false);
      await store.setPin('123456');
      expect(store.verifyPin('123456'), isTrue);
      expect(store.verifyPin('000000'), isFalse);
      await store.setThemeColor('invalid');
      expect(store.themeColor, 'purple');

      final restored = ProviderContainer(overrides: [authSessionProvider.overrideWith((ref) => Stream.value(null))]);
    restored.listen(appStartupProvider, (_, __) {});
      await restored.read(appStartupProvider.future);
      final next = restored.read(appStoreProvider.notifier);
      expect(next.monthlyExpense, 12500);
      expect(next.selectedMonth, month);
      expect(next.darkMode, isTrue);
      expect(next.languageCode, 'en');
      expect(next.themeColor, 'purple');
      expect(next.hideBalances, isTrue);
      expect(next.remindersEnabled, isFalse);
      expect(next.verifyPin('123456'), isTrue);
      await next.delete(next.entries.single.id!);
      expect(next.monthlyExpense, 0);
      restored.dispose();
    },
  );

  test(
    'budget, recurring entries and backup import publish fresh state',
    () async {
      await container.read(appStartupProvider.future);
      final store = container.read(appStoreProvider.notifier);
      final month = DateTime(2026, 8);
      await store.changeMonth(month);
      await store.saveBudget(Budget(month: '2026-08', amountMinor: 50000));
      final category = store.categories.firstWhere((c) => c.type == expense);
      await store.saveMonthlyEntries(
        Entry(
          title: 'Rent',
          amountMinor: 10000,
          type: expense,
          categoryId: category.id,
          date: DateTime(2026, 8, 31),
          createdAt: 1,
        ),
        month,
        2,
      );
      expect(store.entries.length, 2);
      expect(store.monthlyBudget, 50000);
      expect(store.monthlyExpense, 10000);
      final backup = await store.exportBackupJson();
      await store.clearEntries();
      expect(store.entries, isEmpty);
      await store.importBackupJson(backup);
      expect(store.entries.length, 2);
      expect(store.monthlyExpense, 10000);
      expect(store.monthlyBudget, 50000);
    },
  );

  test('startup error is retryable and scope owns database disposal', () async {
    final database = RetryDatabase();
    final retryContainer = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    retryContainer.listen(appStartupProvider, (_, __) {});
    await expectLater(
      retryContainer.read(appStartupProvider.future),
      throwsStateError,
    );
    expect(retryContainer.read(appStartupProvider).hasError, isTrue);
    expect(database.attempts, 1);
    retryContainer.invalidate(appStartupProvider);
    await retryContainer.read(appStartupProvider.future);
    expect(database.attempts, 2);
    expect(retryContainer.read(appStoreProvider).categories, isNotEmpty);
    retryContainer.dispose();
    expect(database.closes, 1);
    await database.close();
  });
}
