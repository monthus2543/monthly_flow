import 'dart:async';
import 'package:monthly_flow/sync/sync_record.dart';

class MemorySyncRemote implements SyncRemote {
  final Map<String, Map<String, SyncRecord>> accounts = {};
  final changes = StreamController<void>.broadcast();
  bool offline = false;
  Completer<void>? pauseWrite;
  String? Function()? currentUid;
  void check(String uid) {
    if (offline) throw StateError('Offline');
    if (currentUid != null && currentUid!() != uid)
      throw StateError('Account changed');
  }

  @override
  Future<List<SyncRecord>> read(String uid) async {
    check(uid);
    return accounts[uid]?.values.toList() ?? [];
  }

  @override
  Stream<List<SyncRecord>> watch(String uid) async* {
    yield await read(uid);
    await for (final _ in changes.stream) {
      yield await read(uid);
    }
  }

  @override
  Future<SyncRecord> write(String uid, SyncRecord record) async {
    await pauseWrite?.future;
    check(uid);
    final rows = accounts.putIfAbsent(uid, () => {});
    final old = rows[record.id];
    if (old != null && (old.deleted || record.createOnly)) return old;
    rows[record.id] = record;
    changes.add(null);
    return record;
  }

  Future<void> dispose() => changes.close();
}
