import 'package:monthly_flow/sync/sync_providers.dart';

// Screen tests isolate sync I/O; coordinator integration has its own suite.
class DisabledSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => const SyncState(SyncPhase.local);
}
