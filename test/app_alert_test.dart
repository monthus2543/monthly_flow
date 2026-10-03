import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/widgets/app_alert.dart';

void main() {
  testWidgets('top alert replaces the previous message and expires',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(Brightness.light),
      home: Scaffold(body: Builder(builder: (value) {
        context = value;
        return const Text('Page remains available');
      })),
    ));

    showAppAlert(context, 'Copied');
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        1);
    expect(tester.getTopLeft(find.text('Copied')).dy, lessThan(100));

    await tester.pump(const Duration(seconds: 1));
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(1 / 3, .01));
    showAppAlert(context, 'Imported');
    await tester.pump();
    expect(find.text('Copied'), findsNothing);
    expect(find.text('Imported'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Imported'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.text('Imported'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dark error alert counts down and cleans up when the app is removed',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(Brightness.dark),
      home: Scaffold(body: Builder(builder: (value) {
        context = value;
        return const SizedBox();
      })),
    ));
    showAppAlert(context, 'Save failed', isError: true);
    await tester.pump();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Save failed'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(.2, .01));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.text('Save failed'), findsNothing);

    showAppAlert(context, 'Another error', isError: true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
