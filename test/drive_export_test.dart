import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monthly_flow/export/drive_export.dart';

void main() {
  test(
    'upload uses reserved ID, app folders and acknowledged chunk progress',
    () async {
      final requests = <http.Request>[];
      final progress = <double>[];
      final bytes = Uint8List(300000);
      final client = MockClient((r) async {
        requests.add(r);
        expect(r.headers['Authorization'], 'Bearer test-token');
        if (r.url.path.endsWith('generateIds'))
          return http.Response('{"ids":["reserved"]}', 200);
        if (r.method == 'GET' && r.url.path.endsWith('/reserved'))
          return http.Response('', 404);
        if (r.method == 'GET') return http.Response('{"files":[]}', 200);
        if (r.method == 'POST' && !r.url.path.startsWith('/upload')) {
          return http.Response(
            jsonEncode({'id': jsonDecode(r.body)['name']}),
            200,
          );
        }
        if (r.method == 'POST') {
          expect(jsonDecode(r.body)['id'], 'reserved');
          expect(jsonDecode(r.body)['parents'], ['Reports']);
          return http.Response(
            '',
            200,
            headers: {'location': 'https://www.googleapis.com/upload/session'},
          );
        }
        return http.Response(
          '{}',
          r.headers['Content-Range']!.endsWith('299999/300000') ? 200 : 308,
        );
      });
      final drive = DriveExportService(client);
      final id = await drive.reserveId('test-token');
      final uri = await drive.upload(
        token: 'test-token',
        fileId: id,
        filename: 'report.xlsx',
        bytes: bytes,
        onProgress: progress.add,
        checkAccount: () {},
      );
      expect(uri.toString(), 'https://drive.google.com/file/d/reserved/view');
      expect(progress, [262144 / 300000, 1]);
      expect(
        requests.where((r) => r.method == 'PUT').map((r) => r.bodyBytes.length),
        [262144, 37856],
      );
    },
  );
  test(
    'retry recovers a completed upload without uploading a duplicate',
    () async {
      var calls = 0;
      final drive = DriveExportService(
        MockClient((r) async {
          calls++;
          expect(r.method, 'GET');
          return http.Response(
            '{"id":"reserved","size":"5","trashed":false}',
            200,
          );
        }),
      );
      await drive.upload(
        token: 'token',
        fileId: 'reserved',
        filename: 'same.xlsx',
        bytes: Uint8List(5),
        onProgress: (_) {},
        checkAccount: () {},
      );
      expect(calls, 1);
    },
  );
  test('quota and expired permission failures are actionable', () async {
    for (final pair in [
      (401, 'export_permission_expired'),
      (403, 'export_drive_full'),
    ]) {
      final drive = DriveExportService(
        MockClient(
          (r) async => http.Response(
            '{"error":{"errors":[{"reason":"storageQuotaExceeded"}]}}',
            pair.$1,
          ),
        ),
      );
      await expectLater(
        drive.reserveId('token'),
        throwsA(isA<ExportFailure>().having((e) => e.key, 'reason', pair.$2)),
      );
    }
  });
}
