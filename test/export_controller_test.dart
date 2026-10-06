import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/export/export_controller.dart';
import 'package:monthly_flow/export/excel_report.dart';
import 'package:monthly_flow/export/email_export.dart';
import 'package:monthly_flow/export/drive_export.dart';

class FakeEmailService implements ReportEmailService {
  int sends = 0;
  bool fail = true;
  Completer<void>? pending;
  @override
  Future<void> send({
    required String uid,
    required String filename,
    required Uint8List bytes,
  }) async {
    sends++;
    expect(uid, 'first');
    if (pending != null) return pending!.future;
    if (fail) throw const ExportFailure('export_email_failed');
  }
}

void main() {
  test(
    'email failures retain file and successful retries cannot send again',
    () async {
      final service = FakeEmailService();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AuthAccount(id: 'first', email: 'user@example.com'),
            ),
          ),
          reportEmailServiceProvider.overrideWithValue(service),
        ],
      );
      final sub = container.listen(exportControllerProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });
      await container.read(authSessionProvider.future);
      final controller = container.read(exportControllerProvider.notifier);
      await controller.generate(
        ExcelReportData(
          ownerId: 'first',
          options: ReportOptions(years: [2026], language: 'en'),
          entries: [],
          categoryNames: {},
          accountNames: {},
        ),
      );
      final bytes = container.read(exportControllerProvider).bytes;
      expect(await controller.sendEmail(), isFalse);
      expect(container.read(exportControllerProvider).bytes, same(bytes));
      expect(
        container.read(exportControllerProvider).error,
        'export_email_failed',
      );
      service.fail = false;
      expect(await controller.sendEmail(), isTrue);
      expect(await controller.sendEmail(), isTrue);
      expect(service.sends, 2);
    },
  );
  test('guest export does not invoke the email service', () async {
    final service = FakeEmailService();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
        reportEmailServiceProvider.overrideWithValue(service),
      ],
    );
    final sub = container.listen(exportControllerProvider, (_, __) {});
    addTearDown(() {
      sub.close();
      container.dispose();
    });
    await container.read(authSessionProvider.future);
    final controller = container.read(exportControllerProvider.notifier);
    await controller.generate(
      ExcelReportData(
        options: ReportOptions(years: [2026], language: 'en'),
        entries: [],
        categoryNames: {},
        accountNames: {},
      ),
    );
    expect(await controller.sendEmail(), isFalse);
    expect(service.sends, 0);
  });
  test(
    'changing accounts while email is pending discards the report',
    () async {
      final sessions = StreamController<AuthAccount?>();
      final service = FakeEmailService()..pending = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith((ref) => sessions.stream),
          reportEmailServiceProvider.overrideWithValue(service),
        ],
      );
      final subscription = container.listen(
        exportControllerProvider,
        (_, __) {},
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await sessions.close();
      });
      sessions.add(const AuthAccount(id: 'first', email: 'user@example.com'));
      await container.read(authSessionProvider.future);
      final controller = container.read(exportControllerProvider.notifier);
      expect(
        await controller.generate(
          ExcelReportData(
            ownerId: 'first',
            options: ReportOptions(years: [2026], language: 'en'),
            entries: [],
            categoryNames: {},
            accountNames: {},
          ),
        ),
        isTrue,
      );
      final upload = controller.sendEmail();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(exportControllerProvider).busy, isTrue);
      sessions.add(const AuthAccount(id: 'second'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.pending!.complete();
      expect(await upload, isFalse);
      expect(container.read(exportControllerProvider).bytes, isNull);
      expect(container.read(exportControllerProvider).busy, isFalse);
      expect(
        await controller.generate(
          ExcelReportData(
            ownerId: 'first',
            options: ReportOptions(years: [2026], language: 'en'),
            entries: [],
            categoryNames: {},
            accountNames: {},
          ),
        ),
        isFalse,
      );
    },
  );
}
