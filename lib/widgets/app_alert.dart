import 'package:flutter/material.dart';

OverlayEntry? _activeAlert;

void showAppAlert(BuildContext context, String message,
    {bool isError = false}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  _activeAlert?.remove();
  _activeAlert?.dispose();

  late final OverlayEntry entry;
  void dismiss() {
    if (_activeAlert != entry) return;
    _activeAlert = null;
    entry.remove();
    entry.dispose();
  }

  entry = OverlayEntry(
    builder: (_) => themes.wrap(
      _AppAlert(
        message: message,
        isError: isError,
        onDismiss: dismiss,
        onDisposed: () {
          if (_activeAlert == entry) _activeAlert = null;
        },
      ),
    ),
  );
  _activeAlert = entry;
  overlay.insert(entry);
}

class _AppAlert extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  final VoidCallback onDisposed;

  const _AppAlert({
    required this.message,
    required this.isError,
    required this.onDismiss,
    required this.onDisposed,
  });

  @override
  State<_AppAlert> createState() => _AppAlertState();
}

class _AppAlertState extends State<_AppAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController countdown;

  @override
  void initState() {
    super.initState();
    countdown = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isError ? 5000 : 1500),
      animationBehavior: AnimationBehavior.preserve,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDismiss();
      })
      ..forward();
  }

  @override
  void dispose() {
    countdown.dispose();
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        widget.isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent.withValues(alpha: .18)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .09),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Icon(
                            widget.isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(widget.message)),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: countdown,
                            builder: (_, __) => LinearProgressIndicator(
                              value: 1 - countdown.value,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(3),
                              color: accent,
                              backgroundColor: accent.withValues(alpha: .12),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
