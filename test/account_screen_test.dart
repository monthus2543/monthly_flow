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
import 'package:monthly_flow/widgets/account_card.dart';
import 'package:monthly_flow/widgets/account_avatar.dart';
import 'support/fake_auth_repository.dart';

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
      await tester.tap(find.text('Monthly User'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
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
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
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
