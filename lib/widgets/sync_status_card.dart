import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../sync/sync_providers.dart';

class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncCoordinatorProvider);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              sync.phase == SyncPhase.error
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_sync_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(context.l10n.t(key))),
          ],
        ),
        if (sync.pending > 0) ...[
          const SizedBox(height: 6),
          Text('${context.l10n.t('sync_pending_count')}: ${sync.pending}'),
        ],
        if (sync.lastSync != null) ...[
          const SizedBox(height: 6),
          Text(
            '${context.l10n.t('sync_last')}: ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(sync.lastSync!.toLocal()))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed:
              sync.phase == SyncPhase.syncing ||
                  sync.phase == SyncPhase.preparing
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
