import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/sync/sync_providers.dart';
import 'package:monthly_flow/widgets/sync_status_card.dart';

class StatusCoordinator extends SyncCoordinator {
  StatusCoordinator(this.initial);
  final SyncState initial;
  @override
  SyncState build() => initial;
  @override
  Future<void> synchronize() async {
    state = const SyncState(SyncPhase.synced);
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('sync status and retry fit small Thai screen dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWith(
            () => StatusCoordinator(
              SyncState(
                SyncPhase.error,
                pending: 12,
                lastSync: DateTime(2026, 10, 6, 1, 30),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(dark ? Brightness.dark : Brightness.light),
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
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: SyncStatusCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('รายการที่รอส่ง: 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('ซิงค์ตอนนี้'));
      await tester.tap(find.text('ซิงค์ตอนนี้'));
      await tester.pumpAndSettle();
      expect(find.text('ซิงค์ข้อมูลแล้ว'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
