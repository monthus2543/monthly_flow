import 'dart:math' as math;

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

class AppSegment {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const AppSegment(this.value, this.label, this.icon, {this.color});
}

class AppSegmentedControl extends StatelessWidget {
  final String value;
  final List<AppSegment> segments;
  final ValueChanged<String> onChanged;
  final double? width;
  final Color? backgroundColor;

  const AppSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.width,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableWidth = width ?? MediaQuery.sizeOf(context).width - 48;
    final textStyle = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w500,
    );
    var segmentWidth = (availableWidth - 8) / segments.length;
    for (final segment in segments) {
      final painter = TextPainter(
        text: TextSpan(text: segment.label, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      segmentWidth = math.max(segmentWidth, painter.width + 56);
      painter.dispose();
    }
    if (segments.length == 2) segmentWidth = (availableWidth - 8) / 2;
    return SizedBox(
      width: availableWidth,
      height: math.max(45, MediaQuery.textScalerOf(context).scale(20) + 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: AnimatedToggleSwitch<String>.size(
                  current: value,
                  values: segments.map((s) => s.value).toList(),
                  indicatorSize: Size.fromWidth(segmentWidth),
                  height: math.max(
                    56,
                    MediaQuery.textScalerOf(context).scale(20) + 28,
                  ),
                  borderWidth: 4,
                  selectedIconScale: 1,
                  iconOpacity: 1,
                  loading: false,
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  animationCurve: Curves.easeOutCubic,
                  style: ToggleStyle(
                    backgroundColor:
                        backgroundColor ??
                        theme.colorScheme.surfaceContainerLow,
                    borderColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    indicatorBorderRadius: BorderRadius.circular(14),
                  ),
                  styleBuilder: (selected) {
                    final segment = segments.firstWhere(
                      (s) => s.value == selected,
                    );
                    return ToggleStyle(
                      indicatorColor:
                          (segment.color ?? theme.colorScheme.primary)
                              .withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? .22
                                    : .13,
                              ),
                    );
                  },
                  iconBuilder: (selected) {
                    final segment = segments.firstWhere(
                      (s) => s.value == selected,
                    );
                    final selectedColor =
                        segment.color ?? theme.colorScheme.primary;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              segment.icon,
                              size: 20,
                              color: value == selected
                                  ? selectedColor
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              segment.label,
                              style: textStyle.copyWith(
                                color: value == selected
                                    ? selectedColor
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onChanged: onChanged,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (final segment in segments)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: value == segment.value,
                          label: segment.label,
                          child: InkWell(
                            key: ValueKey('segment-${segment.value}'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => onChanged(segment.value),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
