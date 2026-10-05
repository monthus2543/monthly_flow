import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/sync/sync_providers.dart';
import 'package:monthly_flow/sync/sync_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/fake_auth_repository.dart';
import 'support/memory_sync_remote.dart';

void main() {
  late Directory directory;
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late MemorySyncRemote cloud;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'monthly-coordinator-test-',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    auth = FakeAuthRepository();
    cloud = MemorySyncRemote()..currentUid = () => auth.account?.id;
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) async => auth),
        syncRemoteProvider.overrideWithValue(cloud),
      ],
    );
    container.listen(syncCoordinatorProvider, (_, __) {});
    await container.read(appStartupProvider.future);
  });
  tearDown(() async {
    final guest = container.read(appDatabaseProvider);
    final account = container.read(
      accountDatabaseProvider('verified-firebase-uid'),
    );
    final second = container.read(accountDatabaseProvider('second'));
    container.dispose();
    await guest.close();
    await account.close();
    await second.close();
    await auth.dispose();
    await cloud.dispose();
    await directory.delete(recursive: true);
  });
  Future<void> guestEntry() async => container
      .read(appStoreProvider.notifier)
      .save(
        Entry(
          title: 'Guest expense',
          amountMinor: 10000,
          type: expense,
          categoryId: 3,
          date: DateTime(2026, 10, 6),
          createdAt: 1,
        ),
      );
  Future<void> waitStartup() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(appStartupProvider.future);
  }

  test(
    'login automatically imports guest data, syncs, and logout returns to local profile',
    () async {
      await guestEntry();
      await container.read(authActionProvider.notifier).signIn();
      await waitStartup();
      final store = container.read(appStoreProvider.notifier);
      expect(store.activeAccountId, 'verified-firebase-uid');
      await container.read(syncCoordinatorProvider.notifier).synchronize();
      expect(container.read(syncCoordinatorProvider).phase, SyncPhase.synced);
      expect(
        cloud.accounts['verified-firebase-uid']!.values
            .where((r) => r.table == 'transactions')
            .length,
        1,
      );
      await container.read(authActionProvider.notifier).signOut();
      await waitStartup();
      expect(store.activeAccountId, isNull);
      expect(store.entries.single.title, 'Guest expense');
      expect(container.read(syncCoordinatorProvider).phase, SyncPhase.local);
    },
  );
  test('offline finance remains pending and manual retry recovers', () async {
    await guestEntry();
    await container.read(authActionProvider.notifier).signIn();
    await waitStartup();
    cloud.offline = true;
    await container.read(syncCoordinatorProvider.notifier).synchronize();
    expect(container.read(syncCoordinatorProvider).phase, SyncPhase.error);
    expect(container.read(appStoreProvider).entries.length, 1);
    cloud.offline = false;
    await container.read(syncCoordinatorProvider.notifier).synchronize();
    expect(container.read(syncCoordinatorProvider).phase, SyncPhase.synced);
  });
  test(
    'switching accounts during upload never acknowledges or imports data to the new account',
    () async {
      await guestEntry();
      await container.read(authActionProvider.notifier).signIn();
      await waitStartup();
      cloud.pauseWrite = Completer<void>();
      final running = container
          .read(syncCoordinatorProvider.notifier)
          .synchronize();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      auth.account = const AuthAccount(id: 'second', name: 'Second');
      auth.changes.add(auth.account);
      await waitStartup();
      expect(
        container.read(appStoreProvider.notifier).activeAccountId,
        'second',
      );
      expect(container.read(appStoreProvider).entries, isEmpty);
      cloud.pauseWrite!.complete();
      await running;
      final oldDb = await container
          .read(accountDatabaseProvider('verified-firebase-uid'))
          .open();
      expect(await SyncLocal(oldDb).pendingCount(), greaterThan(0));
      expect(
        cloud.accounts['second']?.values.where(
              (r) => r.table == 'transactions',
            ) ??
            [],
        isEmpty,
      );
    },
  );
}
