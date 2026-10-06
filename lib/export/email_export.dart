import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'drive_export.dart' show ExportFailure;

abstract interface class ReportEmailService {
  Future<void> send({
    required String uid,
    required String filename,
    required Uint8List bytes,
  });
}

class FirebaseReportEmailService implements ReportEmailService {
  @override
  Future<void> send({
    required String uid,
    required String filename,
    required Uint8List bytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != uid || user?.email == null) {
      throw const ExportFailure('export_account_changed');
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw const ExportFailure('export_email_too_large');
    }
    final requestId = sha256.convert([
      ...utf8.encode(filename),
      ...bytes,
    ]).toString();
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
            'emailExcelReport',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Map<String, dynamic>>({
            'filename': filename,
            'contentBase64': base64Encode(bytes),
            'requestId': requestId,
          });
      if (result.data['status'] != 'sent') {
        throw const ExportFailure('export_email_pending');
      }
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      const allowed = {
        'export_email_setup',
        'export_email_too_large',
        'export_email_pending',
        'export_email_limit',
        'export_email_failed',
        'export_email_verified_required',
      };
      final key = details is Map ? details['key'] : null;
      throw ExportFailure(
        allowed.contains(key)
            ? key as String
            : e.code == 'not-found'
            ? 'export_email_setup'
            : e.code == 'unauthenticated'
            ? 'export_account_changed'
            : e.code == 'deadline-exceeded'
            ? 'export_email_pending'
            : 'export_email_failed',
      );
    }
  }
}
