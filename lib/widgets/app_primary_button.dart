import 'package:flutter/material.dart';

/// Shared styling for the main save and sign-out actions.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.foregroundColor,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.primary;
    final foreground = foregroundColor ?? scheme.onPrimary;
    // Saturated hues keep the gradient lively without mixing in dull black.
    final base = HSLColor.fromColor(background);
    final vivid = base
        .withSaturation((base.saturation + .2).clamp(0.0, 1.0))
        .withLightness((base.lightness + .035).clamp(0.0, 1.0));
    final start = _readableColor(vivid, foreground);
    final end = _readableColor(
      vivid
          .withHue((vivid.hue + 8) % 360)
          .withLightness(
            (vivid.lightness +
                    (foreground.computeLuminance() > .5 ? .035 : -.035))
                .clamp(0.0, 1.0),
          ),
      foreground,
    );

    return FilledButton(
      clipBehavior: Clip.antiAlias,
      onPressed: onPressed,
      style:
          FilledButton.styleFrom(
            backgroundColor: start,
            foregroundColor: foreground,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ).copyWith(
            backgroundBuilder: (context, states, child) {
              if (states.contains(WidgetState.disabled)) return child!;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [start, end],
                  ),
                ),
                child: child,
              );
            },
          ),
      child: child,
    );
  }

  Color _readableColor(HSLColor color, Color foreground) {
    var adjusted = color;
    final lightText = foreground.computeLuminance() > .5;
    for (var i = 0; i < 100; i++) {
      final a = adjusted.toColor().computeLuminance();
      final b = foreground.computeLuminance();
      final ratio = (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
      if (ratio >= 4.5) break;
      adjusted = adjusted.withLightness(
        (adjusted.lightness + (lightText ? -.01 : .01)).clamp(0.0, 1.0),
      );
    }
    return adjusted.toColor();
  }
}
