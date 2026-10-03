import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/widgets/app_segmented_control.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('type selector works in a compact $brightness dialog',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var value = 'expense';
      await tester.pumpWidget(MaterialApp(
        theme: appTheme(brightness),
        home: StatefulBuilder(builder: (context, setState) {
          return Scaffold(
            body: AlertDialog(
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const TextField(),
                AppSegmentedControl(
                  width: 264,
                  value: value,
                  segments: const [
                    AppSegment('expense', 'รายจ่าย', Icons.north_east),
                    AppSegment('income', 'รายรับ', Icons.south_west),
                  ],
                  onChanged: (selected) => setState(() => value = selected),
                ),
              ]),
            ),
          );
        }),
      ));
      await tester.tap(find.byKey(const ValueKey('segment-income')));
      await tester.pumpAndSettle();
      expect(value, 'income');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('four filters scroll with enlarged text on a small screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var value = 'all';
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(Brightness.light),
      home: StatefulBuilder(builder: (context, setState) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: Scaffold(
              body: AppSegmentedControl(
            value: value,
            segments: const [
              AppSegment('all', 'ทั้งหมด', Icons.list),
              AppSegment('income', 'รายรับ', Icons.south_west),
              AppSegment('expense', 'รายจ่าย', Icons.north_east),
              AppSegment('favorite', 'รายการโปรด', Icons.star_outline),
            ],
            onChanged: (selected) => setState(() => value = selected),
          )),
        );
      }),
    ));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('segment-favorite')));
    await tester.pumpAndSettle();
    expect(value, 'favorite');
    expect(tester.takeException(), isNull);
  });
}
