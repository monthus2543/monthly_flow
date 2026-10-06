import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/screens/export_screen.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/export/export_controller.dart';
import 'package:monthly_flow/export/excel_report.dart';

class ExportTestStore extends AppStore {
  @override
  AppState build() => AppState(
    selectedMonth: DateTime(2026, 10),
    accounts: const [Account(id: 1, name: 'เงินสด')],
    categories: const [Category(1, 'salary', income, 'other')],
    entries: [
      Entry(
        title: 'เงินเดือน',
        amountMinor: 2400000,
        type: income,
        categoryId: 1,
        date: DateTime(2026, 10, 1),
        createdAt: 0,
      ),
    ],
  );
}

class DestinationTestController extends ExportController {
  int generated = 0;
  int saved = 0;
  int emailed = 0;
  @override
  ExportState build() => const ExportState();
  @override
  Future<bool> generate(ExcelReportData data) async {
    generated++;
    state = ExportState(bytes: Uint8List(4), filename: 'test.xlsx');
    return true;
  }

  @override
  Future<bool> save() async {
    saved++;
    return false;
  }

  @override
  Future<bool> sendEmail() async {
    emailed++;
    return false;
  }
}

void main() {
  for (final brightness in Brightness.values) {
    for (final signedIn in [false, true]) {
      testWidgets(
        'export destinations and preview fit Thai small screen $brightness signedIn=$signedIn',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = DestinationTestController();
          final container = ProviderContainer(
            overrides: [
              exportControllerProvider.overrideWith(() => controller),
              appStoreProvider.overrideWith(
                () =>
                    ExportTestStore()
                      ..activeAccountId = signedIn ? 'first' : null,
              ),
              authSessionProvider.overrideWith(
                (ref) => Stream.value(
                  signedIn
                      ? const AuthAccount(
                          id: 'first',
                          email: 'user@example.com',
                        )
                      : null,
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  theme: appTheme(brightness, 'teal'),
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
                  home: const ExportScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('2026'), findsWidgets);
          expect(find.text('2569 (2026)'), findsNothing);
          expect(find.text('บันทึกไฟล์ที่'), findsNothing);
          expect(find.text('อีเมลที่ Login'), findsNothing);
          expect(find.text('Google Drive'), findsNothing);
          await tester.scrollUntilVisible(find.text('ดูตัวอย่างรายงาน'), 300);
          await tester.pumpAndSettle();
          await tester.tap(find.text('ดูตัวอย่างรายงาน'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ChoiceChip, '2026'));
          await tester.pumpAndSettle();
          expect(find.text('สรุป 12 เดือน'), findsOneWidget);
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(ExcelPreviewScreen))).pop();
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('สร้างไฟล์ Excel'), 200);
          await tester.pumpAndSettle();
          await tester.tap(find.text('สร้างไฟล์ Excel'));
          await tester.pumpAndSettle();
          if (signedIn) {
            expect(find.text('บันทึกไฟล์ที่'), findsOneWidget);
            expect(find.text('user@example.com'), findsOneWidget);
            expect(controller.generated, 0);
            await tester.tap(find.text('ยกเลิก'));
            await tester.pumpAndSettle();
            expect(controller.generated, 0);
            await tester.tap(find.text('สร้างไฟล์ Excel'));
            await tester.pumpAndSettle();
            await tester.tap(
              find.text(
                brightness == Brightness.dark
                    ? 'ส่งไปอีเมลที่ Login'
                    : 'บันทึกลงอุปกรณ์',
              ),
            );
            await tester.pumpAndSettle();
            expect(controller.emailed, brightness == Brightness.dark ? 1 : 0);
            expect(controller.saved, brightness == Brightness.light ? 1 : 0);
          } else {
            expect(find.text('บันทึกไฟล์ที่'), findsNothing);
            expect(controller.saved, 1);
            expect(controller.emailed, 0);
          }
          expect(controller.generated, 1);
          expect(tester.takeException(), isNull);
          if (Platform.environment['EXPORT_SCREENSHOTS'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('build/export-preview')
                ..createSync(recursive: true);
              File(
                '${dir.path}/preview-${brightness.name}.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}
