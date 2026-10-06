import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/widgets/app_primary_button.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('main action gradient stays scoped in $brightness', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: Column(
              children: [
                AppPrimaryButton(
                  onPressed: () => presses++,
                  child: const Text('Save'),
                ),
                FilledButton(onPressed: () {}, child: const Text('Other')),
                const AppPrimaryButton(onPressed: null, child: Text('Busy')),
              ],
            ),
          ),
        ),
      );
      final gradient = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient != null,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(AppPrimaryButton, 'Save'),
          matching: gradient,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, 'Other'),
          matching: gradient,
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(AppPrimaryButton, 'Busy'),
          matching: gradient,
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Save')).height,
        48,
      );
      await tester.tap(find.text('Save'));
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
