// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/screens/splash_screen.dart';

void main() {
  test('app can be constructed', () {
    expect(const MonthlyFlowApp(), isA<StatefulWidget>());
  });

  testWidgets('splash skeleton fits a compact phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
