import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../auth/firebase_auth_repository.dart';
import 'excel_report.dart';

class ExportFailure implements Exception {
  const ExportFailure(this.key);
  final String key;
}

Future<String> authorizeReportDrive(String uid) async {
  await FirebaseAuthRepository.initializeGoogle();
  final google = await GoogleSignIn.instance.authenticate();
  final user = FirebaseAuth.instance.currentUser;
  if (user?.uid != uid ||
      !user!.providerData.any(
        (provider) =>
            provider.providerId == 'google.com' && provider.uid == google.id,
      )) {
    throw const ExportFailure('export_wrong_account');
  }
  const scopes = ['https://www.googleapis.com/auth/drive.file'];
  final grant =
      await google.authorizationClient.authorizationForScopes(scopes) ??
      await google.authorizationClient.authorizeScopes(scopes);
  return grant.accessToken;
}

/// Uses a preallocated ID to recover an ambiguous response without creating duplicates.
class DriveExportService {
  DriveExportService(this.client);
  final http.Client client;
  static const _base = 'www.googleapis.com';

  Future<http.Response> _request(
    String method,
    Uri uri,
    String token, {
    Map<String, String>? headers,
    List<int>? bytes,
    Object? json,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll({'Authorization': 'Bearer $token', ...?headers});
    if (json != null) {
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
      request.body = jsonEncode(json);
    } else if (bytes != null)
      request.bodyBytes = bytes;
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 60)),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode >= 400 && response.statusCode != 404) {
      String reason = '';
      try {
        reason = '${jsonDecode(response.body)['error']['errors'][0]['reason']}';
      } catch (_) {}
      throw ExportFailure(
        response.statusCode == 401
            ? 'export_permission_expired'
            : reason == 'storageQuotaExceeded'
            ? 'export_drive_full'
            : reason == 'accessNotConfigured' || reason == 'serviceDisabled'
            ? 'export_drive_setup'
            : response.statusCode == 403
            ? 'export_permission_denied'
            : 'export_upload_failed',
      );
    }
    return response;
  }

  Future<String> reserveId(String token) async {
    final response = await _request(
      'GET',
      Uri.https(_base, '/drive/v3/files/generateIds', {
        'count': '1',
        'space': 'drive',
      }),
      token,
    );
    return jsonDecode(response.body)['ids'][0] as String;
  }

  Future<String> _folder(String token, String name, String parent) async {
    final response = await _request(
      'GET',
      Uri.https(_base, '/drive/v3/files', {
        'q':
            "trashed = false and mimeType = 'application/vnd.google-apps.folder' "
            "and name = '$name' and '$parent' in parents",
        'fields': 'files(id)',
        'spaces': 'drive',
      }),
      token,
    );
    final files = jsonDecode(response.body)['files'] as List;
    if (files.isNotEmpty) return files.first['id'] as String;
    final created = await _request(
      'POST',
      Uri.https(_base, '/drive/v3/files', {'fields': 'id'}),
      token,
      json: {
        'name': name,
        'parents': [parent],
        'mimeType': 'application/vnd.google-apps.folder',
      },
    );
    return jsonDecode(created.body)['id'] as String;
  }

  Future<Uri> upload({
    required String token,
    required String fileId,
    required String filename,
    required Uint8List bytes,
    required void Function(double) onProgress,
    required void Function() checkAccount,
  }) async {
    checkAccount();
    final existing = await _request(
      'GET',
      Uri.https(_base, '/drive/v3/files/$fileId', {
        'fields': 'id,size,trashed',
      }),
      token,
    );
    if (existing.statusCode == 200) {
      final file = jsonDecode(existing.body);
      if (file['trashed'] != true && file['size'] == '${bytes.length}') {
        onProgress(1);
        return Uri.https('drive.google.com', '/file/d/$fileId/view');
      }
      throw const ExportFailure('export_upload_failed');
    }
    final root = await _folder(token, 'Monthly Flow', 'root');
    final reports = await _folder(token, 'Reports', root);
    checkAccount();
    final session = await _request(
      'POST',
      Uri.https(_base, '/upload/drive/v3/files', {
        'uploadType': 'resumable',
        'fields': 'id',
      }),
      token,
      headers: {
        'X-Upload-Content-Type': excelMimeType,
        'X-Upload-Content-Length': '${bytes.length}',
      },
      json: {
        'id': fileId,
        'name': filename,
        'parents': [reports],
        'mimeType': excelMimeType,
      },
    );
    final location = session.headers['location'];
    if (location == null) throw const ExportFailure('export_upload_failed');
    final uri = Uri.parse(location);
    if (uri.scheme != 'https' || uri.host != _base) {
      throw const ExportFailure('export_upload_failed');
    }
    const chunkSize = 256 * 1024;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      checkAccount();
      final end = (offset + chunkSize).clamp(0, bytes.length);
      final response = await _request(
        'PUT',
        uri,
        token,
        bytes: bytes.sublist(offset, end),
        headers: {
          'Content-Type': excelMimeType,
          'Content-Range': 'bytes $offset-${end - 1}/${bytes.length}',
        },
      );
      if (end < bytes.length && response.statusCode != 308 ||
          end == bytes.length &&
              response.statusCode != 200 &&
              response.statusCode != 201) {
        throw const ExportFailure('export_upload_failed');
      }
      onProgress(end / bytes.length);
    }
    checkAccount();
    return Uri.https('drive.google.com', '/file/d/$fileId/view');
  }
}
