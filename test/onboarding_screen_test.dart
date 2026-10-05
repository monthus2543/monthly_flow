import 'package:monthly_flow/sync/sync_providers.dart';
import 'support/disabled_sync_coordinator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/screens/home_shell.dart';
import 'package:monthly_flow/screens/onboarding_screen.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'support/fake_auth_repository.dart';

class OnboardingStore extends AppStore {
  OnboardingStore(this.initial);
  final AppState initial;
  bool failSave = false;
  @override
  AppState build() => initial;
  @override
  Future<void> completeOnboarding({String? localName}) async {
    if (failSave) throw StateError('Disk full');
    state = state.copyWith(
      onboardingCompleted: true,
      localName: localName?.trim() ?? '',
    );
  }
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  FakeAuthRepository auth, {
  bool dark = false,
  String language = 'en',
  bool completed = false,
  OnboardingStore? store,
  String pinHash = '',
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
      appStoreProvider.overrideWith(
        () =>
            store ??
            OnboardingStore(
              AppState(
                darkMode: dark,
                languageCode: language,
                onboardingCompleted: completed,
                pinHash: pinHash,
              ),
            ),
      ),
      appStartupProvider.overrideWith((ref) async {}),
      authRepositoryProvider.overrideWith((ref) async => auth),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await auth.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MonthlyFlowApp(),
    ),
  );
  if (pinHash.isEmpty) {
    await tester.pumpAndSettle();
  } else {
    // PIN autofocus keeps the caret animating indefinitely.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return container;
}

void main() {
  for (final dark in [false, true]) {
    for (final language in ['en', 'th']) {
      testWidgets(
        'local name works offline on small $language dark=$dark screen',
        (tester) async {
          final auth = FakeAuthRepository();
          final container = await mount(
            tester,
            auth,
            dark: dark,
            language: language,
          );
          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(auth.signIns, 0);
          final start = language == 'th' ? 'เริ่มใช้งาน' : 'Get started';
          await tester.ensureVisible(find.text(start));
          await tester.tap(find.text(start));
          await tester.pumpAndSettle();
          expect(
            find.text(
              language == 'th'
                  ? 'กรุณาใส่ชื่อก่อนเริ่มใช้งาน'
                  : 'Enter your name to get started',
            ),
            findsOneWidget,
          );
          await tester.enterText(find.byType(TextFormField), '   ');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.byType(OnboardingScreen), findsOneWidget);
          // Simulate the keyboard reducing available height with larger text.
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.enterText(find.byType(TextFormField), '  อิ้งค์  ');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.byType(HomeShell), findsOneWidget);
          expect(container.read(appStoreProvider).localName, 'อิ้งค์');
          expect(container.read(appStoreProvider).onboardingCompleted, isTrue);
          expect(auth.signIns, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('successful Google login opens home without requiring a name', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final container = await mount(tester, auth);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(auth.signIns, 1);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(container.read(appStoreProvider).onboardingCompleted, isTrue);
    expect(auth.account?.id, 'verified-firebase-uid');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google cancellation, network failure and offline fallback', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..failure = const AuthCancelled();
    final container = await mount(tester, auth);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(container.read(appStoreProvider).onboardingCompleted, isFalse);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    auth.failure = const AuthFailure(AuthFailureReason.network);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'Offline User');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(container.read(appStoreProvider).localName, 'Offline User');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending sign in prevents duplicate actions', (tester) async {
    final auth = FakeAuthRepository()..pending = Completer<void>();
    final container = await mount(tester, auth);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(container.read(appStoreProvider).onboardingCompleted, isFalse);
    auth.pending!.complete();
    await tester.pumpAndSettle();
    expect(auth.signIns, 1);
    expect(find.byType(HomeShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('save failure remains on welcome and permits retry', (
    tester,
  ) async {
    final store = OnboardingStore(AppState(languageCode: 'en'))
      ..failSave = true;
    await mount(tester, FakeAuthRepository(), store: store);
    await tester.enterText(find.byType(TextFormField), 'Name');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your setup. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    store.failSave = false;
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('completed setup skips welcome on a subsequent launch', (
    tester,
  ) async {
    await mount(tester, FakeAuthRepository(), completed: true);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('existing PIN is required before welcome', (tester) async {
    await mount(
      tester,
      FakeAuthRepository(),
      pinHash: sha256.convert(utf8.encode('123456')).toString(),
    );
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '123456');
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
