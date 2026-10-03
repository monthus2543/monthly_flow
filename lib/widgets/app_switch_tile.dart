import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

class AppSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: title,
      toggled: value,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        onTap: () => onChanged(!value),
        trailing: IgnorePointer(
          child: AnimatedToggleSwitch<bool>.size(
            current: value,
            values: const [false, true],
            height: 32,
            indicatorSize: const Size.fromWidth(28),
            borderWidth: 4,
            selectedIconScale: 1,
            iconBuilder: (_) => const SizedBox.shrink(),
            loading: false,
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            animationCurve: Curves.easeOutCubic,
            style: ToggleStyle(
              borderColor: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              indicatorBorderRadius: BorderRadius.circular(14),
              indicatorColor: Colors.white,
            ),
            styleBuilder: (enabled) => ToggleStyle(
              backgroundColor: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              indicatorColor: enabled
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
