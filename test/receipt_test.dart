import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/receipts/receipt_storage.dart';
import 'package:monthly_flow/receipts/receipt_cloud.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/widgets/receipt_preview.dart';

class FakeReceiptCloud implements ReceiptCloud {
  FakeReceiptCloud(this.bytes);
  final Uint8List bytes;
  final List<String> reads = [];
  @override
  Future<Uint8List> read(String reference) async {
    reads.add(reference);
    return bytes;
  }

  @override
  Future<String> upload(
    String uid,
    String localPath, {
    void Function(double)? onProgress,
  }) => throw UnimplementedError();
}

void main() {
  test('receipt copy survives deletion of the picker temporary file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'monthly-flow-receipt-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/picked.png');
    await source.writeAsBytes([1, 2, 3, 4]);
    final saved = await storeReceipt(XFile(source.path), directory);
    await source.delete();
    expect(saved, contains('${directory.path}/receipts/'));
    expect(await File(saved).readAsBytes(), [1, 2, 3, 4]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('receipt preview opens zoom viewer $brightness', (
      tester,
    ) async {
      late Uint8List payload;
      final receiptFile = await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'monthly-flow-preview-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 20, 20),
          Paint()..color = Colors.teal,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(20, 20);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        payload = bytes!.buffer.asUint8List();
        final file = File('${directory.path}/receipt.png');
        await file.writeAsBytes(payload);
        image.dispose();
        picture.dispose();
        return file.path;
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          locale: const Locale('th'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: ReceiptPreview(path: receiptFile!)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReceiptPreview));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('ดูรูปใบเสร็จ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final cloud = FakeReceiptCloud(payload);
      const reference =
          'firebase-storage://users/user/receipts/0123456789abcdef0123456789abcdef.png';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCloudProvider.overrideWithValue(cloud),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(const AuthAccount(id: 'user')),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            locale: const Locale('th'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: ReceiptPreview(path: reference)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cloud.reads, contains(reference));
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      await tester.tap(find.byType(ReceiptPreview));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
