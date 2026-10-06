import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../sync/sync_providers.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class SyncStatusCard extends ConsumerStatefulWidget {
  const SyncStatusCard({super.key});
  @override
  ConsumerState<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends ConsumerState<SyncStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController rotation;

  @override
  void initState() {
    super.initState();
    rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncCoordinatorProvider);
    final syncTime = sync.lastSync == null
        ? null
        : DateFormat('HH:mm:ss').format(sync.lastSync!.toLocal());
    final busy =
        sync.phase == SyncPhase.syncing || sync.phase == SyncPhase.preparing;
    if (busy && !MediaQuery.disableAnimationsOf(context)) {
      if (!rotation.isAnimating) rotation.repeat();
    } else {
      rotation.stop();
      rotation.value = 0;
    }
    final key = switch (sync.phase) {
      SyncPhase.local => 'sync_local',
      SyncPhase.preparing => 'sync_preparing',
      SyncPhase.syncing => 'sync_working',
      SyncPhase.synced => 'sync_done',
      SyncPhase.pending => 'sync_pending',
      SyncPhase.error => 'sync_error',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          key: const ValueKey('sync-status-row'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: const ValueKey('sync-icon-boundary'),
              child: SizedBox.square(
                dimension: 24,
                child: sync.phase == SyncPhase.error
                    ? Icon(
                        Icons.cloud_off_outlined,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(left: 10, bottom: 2,
                            child: Icon(Icons.cloud_outlined,
                              key: const ValueKey('sync-cloud-icon'),
                              size: 14, color: Theme.of(context).colorScheme.primary)),
                          RotationTransition(
                            key: const ValueKey('sync-status-icon'),
                            turns: rotation,
                            child: CustomPaint(
                              size: const Size(11, 11),
                              painter: _SyncRingPainter(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.t(key),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (syncTime != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${context.l10n.t('sync_latest_short')} $syncTime',
                      key: const ValueKey('sync-last-time'),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (sync.pending > 0) ...[
          const SizedBox(height: 6),
          Text('${context.l10n.t('sync_pending_count')}: ${sync.pending}'),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => ref.read(syncCoordinatorProvider.notifier).synchronize(),
          child: Text(context.l10n.t('sync_now')),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.t('sync_account_note'),
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SyncRingPainter extends CustomPainter {
  final Color color;
  const _SyncRingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    for (final start in [.3, .3 + math.pi]) {
      const sweep = 2.2;
      canvas.drawArc(bounds, start, sweep, false, paint);
      final end = start + sweep;
      final radial = Offset(math.cos(end), math.sin(end));
      final tangent = Offset(-math.sin(end), math.cos(end));
      final tip = center + radial * radius;
      final back = tip - tangent * 3;
      final arrow = Path()
        ..moveTo((back + radial * 2).dx, (back + radial * 2).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((back - radial * 2).dx, (back - radial * 2).dy);
      canvas.drawPath(arrow, paint);
    }
  }

  @override
  bool shouldRepaint(_SyncRingPainter oldDelegate) =>
      color != oldDelegate.color;
}
