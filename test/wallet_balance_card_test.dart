import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/widgets/wallet_balance_card.dart';
import 'package:monthly_flow/main.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Prompt');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Prompt-$weight.ttf'));
    }
    await fonts.load();
  });
  for (final brightness in Brightness.values) {
    testWidgets('wallet recolors when selecting each app theme $brightness', (
      tester,
    ) async {
      final gradients = <String>{};
      for (final themeColor in ['teal', 'blue', 'purple', 'orange', 'rose']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(brightness, themeColor),
            locale: const Locale('th'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 320,
                  child: WalletBalanceCard(
                    incomeMinor: 2400000,
                    expenseMinor: 0,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final gradient =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(WalletBalanceCard),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        gradients.add(gradient.gradient.toString());
        expect(tester.takeException(), isNull);
      }
      expect(gradients.length, 5);
    });
    for (final hidden in [false, true]) {
      testWidgets(
        'wallet fits small screen and protects hidden amounts $brightness hidden=$hidden',
        (tester) async {
          tester.view.physicalSize = const Size(320, 400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness, fontFamily: 'Prompt'),
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
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: WalletBalanceCard(
                        incomeMinor: 0,
                        expenseMinor: 123456789,
                        hideBalances: hidden,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (hidden) {
            expect(find.text('******'), findsNWidgets(3));
            expect(find.textContaining('1,234,567'), findsNothing);
          } else {
            expect(find.textContaining('1,234,567'), findsNWidgets(2));
            expect(find.textContaining('-'), findsOneWidget);
          }
          if (!hidden && Platform.environment['WALLET_SCREENSHOTS'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('build/wallet-preview')
                ..createSync(recursive: true);
              File(
                '${dir.path}/${brightness.name}.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}
