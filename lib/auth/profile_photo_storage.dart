import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

const maxProfilePhotoBytes = 5 * 1024 * 1024;

class ProfilePhotoFailure implements Exception {
  final String messageKey;
  const ProfilePhotoFailure(this.messageKey);
}

class ProfilePhoto {
  final Uint8List bytes;
  final String contentType;
  const ProfilePhoto(this.bytes, this.contentType);
}

String photoContentType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10)
    return 'image/png';
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255)
    return 'image/jpeg';
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')
    return 'image/webp';
  throw const ProfilePhotoFailure('profile_photo_format');
}

final profilePhotoPickerProvider = Provider<Future<ProfilePhoto?> Function()>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    if (await file.length() > maxProfilePhotoBytes) {
      throw const ProfilePhotoFailure('profile_photo_too_large');
    }
    final bytes = await file.readAsBytes();
    return ProfilePhoto(bytes, photoContentType(bytes));
  },
);

class UploadedProfilePhoto {
  final String path;
  final String url;
  const UploadedProfilePhoto(this.path, this.url);
}

abstract interface class ProfilePhotoStorage {
  Future<UploadedProfilePhoto> upload(
    String uid,
    ProfilePhoto photo, {
    void Function(double)? onProgress,
  });
  Future<void> remove(String uid, UploadedProfilePhoto photo);
}

final profilePhotoStorageProvider = Provider<ProfilePhotoStorage>(
  (ref) => FirebaseProfilePhotoStorage(
    FirebaseStorage.instance,
    FirebaseAuth.instance,
  ),
);

class FirebaseProfilePhotoStorage implements ProfilePhotoStorage {
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  FirebaseProfilePhotoStorage(this.storage, this.auth);

  @override
  Future<UploadedProfilePhoto> upload(
    String uid,
    ProfilePhoto photo, {
    void Function(double)? onProgress,
  }) async {
    if (auth.currentUser?.uid != uid)
      throw const ProfilePhotoFailure('auth_unavailable');
    if (photo.bytes.isEmpty || photo.bytes.length > maxProfilePhotoBytes) {
      throw const ProfilePhotoFailure('profile_photo_too_large');
    }
    final type = photoContentType(photo.bytes);
    final extension = type.split('/').last == 'jpeg'
        ? 'jpg'
        : type.split('/').last;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final file = storage.ref('users/$uid/profile/$id.$extension');
    final task = file.putData(photo.bytes, SettableMetadata(contentType: type));
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0)
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
    }, onError: (Object _) {});
    bool uploaded = false;
    try {
      await task.timeout(
        const Duration(seconds: 45),
        onTimeout: () async {
          await task.cancel();
          throw const ProfilePhotoFailure('profile_photo_upload_failed');
        },
      );
      uploaded = true;
      final url = await file.getDownloadURL().timeout(
        const Duration(seconds: 15),
      );
      if (auth.currentUser?.uid != uid) {
        throw const ProfilePhotoFailure('auth_unavailable');
      }
      return UploadedProfilePhoto(file.fullPath, url);
    } catch (error) {
      if (uploaded && auth.currentUser?.uid == uid) {
        try {
          await file.delete().timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      if (error is ProfilePhotoFailure) rethrow;
      throw ProfilePhotoFailure(
        error is FirebaseException &&
                [
                  'bucket-not-found',
                  'project-not-found',
                  'no-default-bucket',
                  'unauthorized',
                ].contains(error.code)
            ? 'profile_storage_setup'
            : 'profile_photo_upload_failed',
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> remove(String uid, UploadedProfilePhoto photo) async {
    if (auth.currentUser?.uid != uid ||
        !photo.path.startsWith('users/$uid/profile/'))
      return;
    await storage.ref(photo.path).delete();
  }
}
