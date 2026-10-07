import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../auth/profile_photo_storage.dart';
import '../auth/auth_providers.dart';
import '../sync/sync_record.dart' show newSyncId;

const receiptCloudPrefix = 'firebase-storage://';
// Keep local receipt saving available until Firebase Storage is configured.
const receiptCloudEnabled = bool.fromEnvironment('ENABLE_RECEIPT_CLOUD', defaultValue: false);
bool isCloudReceipt(String value) => value.startsWith(receiptCloudPrefix);

class ReceiptCloudFailure implements Exception {
  const ReceiptCloudFailure(this.key);
  final String key;
}

abstract interface class ReceiptCloud {
  Future<String> upload(
    String uid,
    String localPath, {
    void Function(double)? onProgress,
  });
  Future<Uint8List> read(String reference);
}

final receiptCloudProvider = Provider<ReceiptCloud>(
  (ref) => FirebaseReceiptCloud(),
);
final receiptImageProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, reference) {
      ref.watch(
        authSessionProvider.select((account) => account.asData?.value?.id),
      );
      return ref.watch(receiptCloudProvider).read(reference);
    });

class FirebaseReceiptCloud implements ReceiptCloud {
  void _owner(String uid) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const ReceiptCloudFailure('auth_unavailable');
    }
  }

  Future<File> _cache(String uid, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/receipts/$uid');
    await folder.create(recursive: true);
    return File('${folder.path}/$filename');
  }

  @override
  Future<String> upload(
    String uid,
    String localPath, {
    void Function(double)? onProgress,
  }) async {
    _owner(uid);
    final local = File(localPath);
    if (await local.length() > maxProfilePhotoBytes) {
      throw const ReceiptCloudFailure('receipt_too_large');
    }
    final bytes = await local.readAsBytes();
    String type;
    try {
      type = photoContentType(bytes);
    } catch (_) {
      throw const ReceiptCloudFailure('receipt_format');
    }
    final extension = type == 'image/jpeg' ? 'jpg' : type.split('/').last;
    final filename = '${newSyncId()}.$extension';
    final path = 'users/$uid/receipts/$filename';
    _owner(uid);
    final task = FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: type));
    final subscription = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    }, onError: (Object _) {});
    try {
      await task.timeout(
        const Duration(seconds: 60),
        onTimeout: () async {
          await task.cancel();
          throw const ReceiptCloudFailure('receipt_upload_failed');
        },
      );
      _owner(uid);
      // Cache failures must not discard a successfully uploaded receipt.
      try {
        await (await _cache(uid, filename)).writeAsBytes(bytes, flush: true);
      } catch (_) {}
      return '$receiptCloudPrefix$path';
    } on FirebaseException catch (e) {
      throw ReceiptCloudFailure(
        [
              'unauthorized',
              'bucket-not-found',
              'no-default-bucket',
              'project-not-found',
            ].contains(e.code)
            ? 'receipt_storage_setup'
            : 'receipt_upload_failed',
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<Uint8List> read(String reference) async {
    if (!isCloudReceipt(reference)) {
      throw const ReceiptCloudFailure('receipt_unavailable');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const ReceiptCloudFailure('auth_unavailable');
    final path = reference.substring(receiptCloudPrefix.length);
    if (!RegExp(
      '^users/${RegExp.escape(uid)}/receipts/[a-f0-9]{32}\\.(jpg|png|webp)\$',
    ).hasMatch(path)) {
      throw const ReceiptCloudFailure('receipt_unavailable');
    }
    final cache = await _cache(uid, path.split('/').last);
    _owner(uid);
    if (await cache.exists()) {
      final bytes = await cache.readAsBytes();
      _owner(uid);
      return bytes;
    }
    final bytes = await FirebaseStorage.instance
        .ref(path)
        .getData(maxProfilePhotoBytes)
        .timeout(const Duration(seconds: 30));
    _owner(uid);
    if (bytes == null) throw const ReceiptCloudFailure('receipt_unavailable');
    try {
      await cache.writeAsBytes(bytes, flush: true);
    } catch (_) {}
    return bytes;
  }
}
