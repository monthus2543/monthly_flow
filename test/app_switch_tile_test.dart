import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/widgets/app_switch_tile.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('switch responds to its label and thumb in $brightness',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var value = false;
      await tester.pumpWidget(MaterialApp(
        theme: appTheme(brightness),
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppSwitchTile(
                      title: 'ซ่อนยอดเงิน',
                      value: value,
                      onChanged: (selected) => setState(() => value = selected),
                    ),
                  ),
                )),
      ));
      await tester.tap(find.text('ซ่อนยอดเงิน'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(
          tester
              .widget<AnimatedToggleSwitch<bool>>(
                  find.byType(AnimatedToggleSwitch<bool>))
              .current,
          isTrue);
      await tester
          .tapAt(tester.getCenter(find.byType(AnimatedToggleSwitch<bool>)));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
