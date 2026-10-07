import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/screens/settings_screen.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';

class PinSettingsStore extends AppStore {
  final saved = <String>[];
  @override
  AppState build() => AppState(localName: 'User', onboardingCompleted: true);
  @override
  Future<void> setPin(String value) async { saved.add(value); }
}

void main() {
  testWidgets('PIN dialog survives settings removal and localization rebuild', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = PinSettingsStore();
    final visible = ValueNotifier(true);
    final language = ValueNotifier('th');
    addTearDown(visible.dispose);
    addTearDown(language.dispose);
    final container = ProviderContainer(overrides: [
      appStoreProvider.overrideWith(() => store),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: ValueListenableBuilder<String>(valueListenable: language,
        builder: (context, code, _) => MaterialApp(
          theme: appTheme(Brightness.light), locale: Locale(code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate(), GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: Scaffold(body: ValueListenableBuilder<bool>(valueListenable: visible,
            builder: (context, show, _) => show ? const SettingsScreen() : const SizedBox.shrink())),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ล็อกแอปด้วย PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ล็อกแอปด้วย PIN'));
    await tester.pump(const Duration(milliseconds: 300));
    visible.value = false;
    await tester.pump();
    language.value = 'en';
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(Pinput), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(EditableText), '123456');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(store.saved, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final brightness in Brightness.values) {
    testWidgets('settings PIN dialog stays compact above keyboard $brightness', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = PinSettingsStore();
      final container = ProviderContainer(overrides: [
        appStoreProvider.overrideWith(() => store),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(UncontrolledProviderScope(container: container,
        child: MaterialApp(theme: appTheme(brightness, 'orange'),
          locale: const Locale('th'), supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home: const Scaffold(body: SettingsScreen()),
        ),
      ));
      await tester.pumpAndSettle();
      for (final code in ['1234', '123456']) {
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.ensureVisible(find.text('ล็อกแอปด้วย PIN'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('ล็อกแอปด้วย PIN'));
        await tester.pump(const Duration(milliseconds: 300));
        final dialog = find.byType(AlertDialog);
        final surface = find.descendant(of: dialog, matching: find.byType(Material)).first;
        expect(tester.getSize(surface).height, lessThan(320));
        tester.view.viewInsets = FakeViewPadding(bottom: 280 * tester.view.devicePixelRatio);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.getSize(surface).height, lessThan(320));
        expect(tester.getSize(find.byType(Pinput)).height, lessThanOrEqualTo(56));
        final save = find.descendant(of: dialog, matching: find.byType(FilledButton));
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(360));
        await tester.enterText(find.byType(EditableText), code);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(store.saved.last, code);
        expect(dialog, findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
