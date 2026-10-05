import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/sync/sync_providers.dart';
import 'support/disabled_sync_coordinator.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'onboarding_screen_test.dart' show OnboardingStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Widget tests require explicit font loading for representative screenshots.
    final prompt = FontLoader('Prompt');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      prompt.addFont(rootBundle.load('assets/fonts/Prompt-$weight.ttf'));
    }
    await prompt.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  for (final dark in [false, true]) {
    testWidgets('welcome preview matches phone proportions dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
        syncCoordinatorProvider.overrideWith(DisabledSyncCoordinator.new),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
          appStoreProvider.overrideWith(
            () => OnboardingStore(AppState(darkMode: dark)),
          ),
          appStartupProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: key, child: const MonthlyFlowApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final previewDir = Platform.environment['MONTHLY_FLOW_PREVIEW_DIR'];
      if (previewDir != null) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(previewDir).create(recursive: true);
          await File(
            '$previewDir/welcome-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
