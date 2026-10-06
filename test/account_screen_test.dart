import 'package:monthly_flow/sync/sync_providers.dart';
import 'support/disabled_sync_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/screens/account_screen.dart';
import 'package:monthly_flow/screens/edit_profile_screen.dart';
import 'package:monthly_flow/screens/settings_screen.dart';
import 'package:monthly_flow/widgets/sync_status_card.dart';
import 'package:monthly_flow/widgets/common_widgets.dart';
import 'package:monthly_flow/widgets/account_card.dart';
import 'package:monthly_flow/widgets/account_avatar.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'support/fake_auth_repository.dart';
import 'dart:async';
import 'dart:io';
import 'package:monthly_flow/auth/profile_photo_storage.dart';

class TestPhotoStorage implements ProfilePhotoStorage {
  final pending = Completer<void>();
  bool fail = false;
  int removed = 0;
  @override
  Future<UploadedProfilePhoto> upload(String uid, ProfilePhoto photo,
      {void Function(double)? onProgress}) async {
    onProgress?.call(.5);
    await pending.future;
    if (fail) throw const ProfilePhotoFailure('profile_photo_upload_failed');
    return UploadedProfilePhoto('users/$uid/profile/test.png', 'https://example.com/uploaded.png');
  }
  @override
  Future<void> remove(String uid, UploadedProfilePhoto photo) async { removed++; }
}

class OfflineProfileStore extends AppStore {
  bool linked = false;
  @override
  AppState build() => AppState(localName: 'Offline User', onboardingCompleted: true);
  @override
  Future<String?> localProfileNameForLink() async => linked ? null : state.localName;
  @override
  Future<void> completeLocalProfileLink() async { linked = true; }
  @override
  Future<void> completeOnboarding({String? localName}) async {
    state = state.copyWith(localName: localName, onboardingCompleted: true);
  }
}

Future<void> mount(WidgetTester tester, ProviderContainer container,
    Brightness brightness, {Widget home = const AccountScreen()}) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: appTheme(brightness),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('settings contains account, avatar edit and sync near clear in $brightness', (tester) async {
      int picks = 0;
      final repository = FakeAuthRepository(account: const AuthAccount(
          id: 'user', name: 'Monthly User', email: 'user@example.com'));
      final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        appStoreProvider.overrideWith(OfflineProfileStore.new),
        authRepositoryProvider.overrideWith((ref) async => repository),
        profilePhotoPickerProvider.overrideWithValue(() async { picks++; return null; }),
      ]);
      addTearDown(() async { container.dispose(); await repository.dispose(); });
      await mount(tester, container, brightness,
          home: const Scaffold(body: SettingsScreen()));
      expect(find.text('Monthly User'), findsOneWidget);
      await tester.tap(find.byType(AccountAvatar));
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Clear all data'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byType(SyncStatusCard), findsOneWidget);
      final syncSurface = find.ancestor(of: find.byType(SyncStatusCard), matching: find.byType(Surface)).first;
      final clearSurface = find.ancestor(of: find.text('Clear all data'), matching: find.byType(Surface)).first;
      expect(tester.widget(syncSurface), same(tester.widget(clearSurface)));
      await tester.ensureVisible(find.text('Sign out'));
      final logout = find.ancestor(of: find.text('Sign out'), matching: find.byType(FilledButton)).first;
      expect(find.ancestor(of: logout, matching: find.byType(Surface)), findsNothing);
      expect(tester.getTopLeft(logout).dy,
          greaterThan(tester.getTopLeft(find.text('Clear all data')).dy));
      final clear = find.ancestor(of: find.text('Clear all data'), matching: find.byType(OutlinedButton)).first;
      expect(tester.getSize(logout), tester.getSize(clear));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final failure in ['none', 'upload', 'profile']) {
    testWidgets('profile photo upload handles $failure', (tester) async {
      final bytes = File('assets/branding/monthly-flow-icon.png').readAsBytesSync();
      final storage = TestPhotoStorage()..fail = failure == 'upload';
      final repository = FakeAuthRepository(account: const AuthAccount(
          id: 'user', name: 'Old name', email: 'user@example.com', photoUrl: 'https://example.com/old.png'));
      final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authRepositoryProvider.overrideWith((ref) async => repository),
        profilePhotoStorageProvider.overrideWithValue(storage),
        profilePhotoPickerProvider.overrideWithValue(() async => ProfilePhoto(bytes,'image/png')),
      ]);
      addTearDown(() async { container.dispose(); await repository.dispose(); });
      await mount(tester, container, Brightness.light);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-profile-photo')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pump();
      expect(find.text('Uploading photo 50%'), findsOneWidget);
      expect(repository.profileUpdates, 0);
      if (failure == 'profile') repository.failure = const AuthFailure(AuthFailureReason.network);
      storage.pending.complete();
      await tester.pumpAndSettle();
      expect(repository.account!.photoUrl,
        failure == 'none' ? 'https://example.com/uploaded.png' : 'https://example.com/old.png');
      expect(storage.removed, failure == 'profile' ? 1 : 0);
      if (failure == 'upload') expect(repository.profileUpdates, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('offline profile can edit and connect Google in $brightness', (tester) async {
      final repository = FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        appStoreProvider.overrideWith(OfflineProfileStore.new),
        authRepositoryProvider.overrideWith((ref) async => repository),
      ]);
      addTearDown(() async { container.dispose(); await repository.dispose(); });
      await mount(tester, container, brightness);
      expect(find.text('Offline User'), findsOneWidget);
      expect(find.text('Offline profile'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'My local name');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(repository.signIns, 0);
      expect(find.text('My local name'), findsOneWidget);
      await tester.ensureVisible(find.text('Connect Google account'));
      await tester.tap(find.text('Connect Google account'));
      await tester.pumpAndSettle();
      expect(repository.linkedDefaultName, 'My local name');
      expect(find.text('My local name'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      final store = container.read(appStoreProvider.notifier) as OfflineProfileStore;
      expect(store.linked, isTrue);
      expect(await store.localProfileNameForLink(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('edit profile validates, retries and updates $brightness account',
        (tester) async {
      final repository = FakeAuthRepository(account: const AuthAccount(
          id: 'user', name: 'Monthly User', email: 'user@example.com'));
      final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authRepositoryProvider.overrideWith((ref) async => repository),
      ]);
      addTearDown(() async { container.dispose(); await repository.dispose(); });
      await mount(tester, container, brightness);
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      final nameField = find.byType(TextFormField).at(0);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(nameField, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(repository.profileUpdates, 0);
      expect(find.text('Enter a display name.'), findsOneWidget);
      await tester.enterText(nameField, '  New Name  ');
      FocusManager.instance.primaryFocus?.unfocus();
      repository.failure = const AuthFailure(AuthFailureReason.network);
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(repository.account!.name, 'Monthly User');
      expect(find.text('Check your internet connection and try again.'), findsOneWidget);
      repository.failure = null;
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('New Name'), findsOneWidget);
      expect(repository.account!.photoUrl, isNull);
      expect(repository.account!.email, 'user@example.com');
      expect(find.text('Edit profile'), findsOneWidget);
      // Back discards drafts rather than updating the account.
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Discard me');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repository.account!.name, 'New Name');
      expect(repository.profileUpdates, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('profile card stacks avatar, name and email in $brightness',
        (tester) async {
      final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authSessionProvider.overrideWith((ref) => Stream.value(
          const AuthAccount(id: 'user', name: 'Monthly User',
            email: 'user@example.com', photoUrl: 'https://example.com/avatar.png'))),
      ]);
      addTearDown(container.dispose);
      await mount(tester, container, brightness,
        home: const Scaffold(body: Padding(padding: EdgeInsets.all(24), child: AccountCard())));
      expect(tester.getBottomLeft(find.byType(AccountAvatar)).dy,
        lessThan(tester.getTopLeft(find.text('Monthly User')).dy));
      expect(tester.getBottomLeft(find.text('Monthly User')).dy,
        lessThan(tester.getTopLeft(find.text('user@example.com')).dy));
      expect(tester.widget<Image>(find.byType(Image)).image,
        const NetworkImage('https://example.com/avatar.png'));
      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
        'Google login and confirmed logout work on a small $brightness screen',
        (tester) async {
      final repository = FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authRepositoryProvider.overrideWith((ref) async => repository),
      ]);
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });
      await mount(tester, container, brightness);
      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('Monthly User'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.signOuts, 0);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Sign out')));
      await tester.pumpAndSettle();
      expect(repository.signOuts, 1);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('user@example.com'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('cancellation stays on login and network error allows retry',
      (tester) async {
    final repository = FakeAuthRepository()..failure = const AuthCancelled();
    final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
      authRepositoryProvider.overrideWith((ref) async => repository),
    ]);
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    await mount(tester, container, Brightness.light);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    repository.failure = const AuthFailure(AuthFailureReason.network);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Check your internet connection and try again.'),
        findsOneWidget);
    repository.failure = null;
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('user@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'missing Firebase configuration shows a retry instead of crashing',
      (tester) async {
    final container = ProviderContainer(overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
      authRepositoryProvider.overrideWith((ref) async =>
          throw const AuthFailure(AuthFailureReason.configuration)),
    ]);
    addTearDown(container.dispose);
    await mount(tester, container, Brightness.light);
    expect(
        find.text('Account services are unavailable. Please try again later.'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Continue offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
