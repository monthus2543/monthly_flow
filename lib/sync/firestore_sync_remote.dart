import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sync_record.dart';

class FirestoreSyncRemote implements SyncRemote {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  FirestoreSyncRemote(this.firestore, this.auth);
  CollectionReference<Map<String, dynamic>> _records(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('Account changed');
    return firestore.collection('users').doc(uid).collection('finance');
  }

  SyncRecord _decode(DocumentSnapshot<Map<String, dynamic>> doc) {
    final value = doc.data()!;
    if (value['schema'] != 1 ||
        !syncTables.contains(value['table']) ||
        value['deleted'] is! bool ||
        value['token'] is! String ||
        value['data'] is! Map) {
      throw const FormatException('Unsupported cloud data');
    }
    return SyncRecord(
      id: doc.id,
      table: value['table'] as String,
      deleted: value['deleted'] as bool,
      token: value['token'] as String,
      data: Map<String, Object?>.from(value['data'] as Map),
    );
  }

  @override
  Stream<List<SyncRecord>> watch(String uid) => _records(uid)
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map((snapshot) => snapshot.docs.map(_decode).toList());
  @override
  Future<List<SyncRecord>> read(String uid) async => (await _records(
    uid,
  ).get(const GetOptions(source: Source.server))).docs.map(_decode).toList();
  @override
  Future<SyncRecord> write(String uid, SyncRecord record) async {
    final doc = _records(uid).doc(record.id);
    return firestore.runTransaction((txn) async {
      if (auth.currentUser?.uid != uid) throw StateError('Account changed');
      final previous = await txn.get(doc);
      if (previous.exists) {
        final old = _decode(previous);
        if (old.table != record.table)
          throw const FormatException('Entity type changed');
        // Tombstones are permanent; stale offline edits cannot resurrect deleted records.
        if (old.deleted || record.createOnly) return old;
      }
      txn.set(doc, {
        'schema': 1,
        'table': record.table,
        'data': record.data,
        'deleted': record.deleted,
        'token': record.token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return record;
    });
  }
}
