import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../auth/auth_providers.dart';
import 'excel_report.dart';
import 'drive_export.dart';
import 'email_export.dart';

final reportEmailServiceProvider = Provider<ReportEmailService>(
  (ref) => FirebaseReportEmailService(),
);

final driveAuthorizationProvider = Provider<Future<String> Function(String)>(
  (ref) => authorizeReportDrive,
);
final driveExportServiceProvider = Provider<DriveExportService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return DriveExportService(client);
});

class ExportState {
  const ExportState({
    this.busy = false,
    this.phase = '',
    this.progress,
    this.bytes,
    this.filename,
    this.fileId,
    this.driveUrl,
    this.error,
    this.emailSent = false,
  });
  final bool busy;
  final String phase;
  final double? progress;
  final Uint8List? bytes;
  final String? filename;
  final String? fileId;
  final Uri? driveUrl;
  final String? error;
  final bool emailSent;
}

final exportControllerProvider =
    NotifierProvider.autoDispose<ExportController, ExportState>(
      ExportController.new,
    );

class ExportController extends Notifier<ExportState> {
  String? _owner;
  bool _started = false;
  int _generation = 0;
  @override
  ExportState build() {
    ref.listen(authSessionProvider.select((s) => s.asData?.value?.id), (
      _,
      uid,
    ) {
      if (_started && uid != _owner) {
        _started = false;
        _generation++;
        state = const ExportState();
      }
    });
    return const ExportState();
  }

  void _checkAccount(int generation) {
    if (!ref.mounted ||
        !_started ||
        generation != _generation ||
        ref.read(authSessionProvider).asData?.value?.id != _owner) {
      throw const ExportFailure('export_account_changed');
    }
  }

  Future<bool> generate(ExcelReportData data) async {
    if (state.busy) return false;
    _owner = ref.read(authSessionProvider).asData?.value?.id;
    if (data.ownerId != _owner) {
      state = const ExportState(error: 'export_account_changed');
      return false;
    }
    final generation = ++_generation;
    _started = true;
    state = const ExportState(busy: true, phase: 'export_generating');
    try {
      final bytes = await compute(buildExcelReport, data);
      _checkAccount(generation);
      final years = data.options.years;
      final period = years.length == 1
          ? '${years.first}'
          : '${years.first}-${years.last}';
      state = ExportState(
        bytes: bytes,
        filename:
            'MonthlyFlow_${period}_${DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now())}.xlsx',
      );
      return true;
    } catch (e) {
      if (ref.mounted && _started && generation == _generation)
        state = ExportState(
          error: e is ExportFailure ? e.key : 'export_failed',
        );
      return false;
    }
  }

  Future<bool> save() async => _localAction(false);
  Future<bool> share() async => _localAction(true);
  Future<bool> _localAction(bool sharing) async {
    if (state.busy || state.bytes == null) return false;
    final previous = state;
    final generation = _generation;
    state = ExportState(
      busy: true,
      phase: 'export_saving',
      bytes: previous.bytes,
      filename: previous.filename,
      fileId: previous.fileId,
      driveUrl: previous.driveUrl,
      emailSent: previous.emailSent,
    );
    try {
      _checkAccount(generation);
      bool saved;
      if (sharing) {
        final dir = await getTemporaryDirectory();
        _checkAccount(generation);
        final file = File('${dir.path}/${previous.filename}');
        await file.writeAsBytes(previous.bytes!, flush: true);
        _checkAccount(generation);
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: excelMimeType)],
            title: 'Monthly Flow',
          ),
        );
        saved = result.status == ShareResultStatus.success;
      } else {
        saved =
            await FilePicker.saveFile(
              fileName: previous.filename!,
              bytes: previous.bytes!,
              mimeType: excelMimeType,
            ) !=
            null;
      }
      _checkAccount(generation);
      state = previous;
      return saved;
    } catch (e) {
      if (ref.mounted && _started && generation == _generation)
        state = ExportState(
          bytes: previous.bytes,
          filename: previous.filename,
          fileId: previous.fileId,
          driveUrl: previous.driveUrl,
          emailSent: previous.emailSent,
          error: e is ExportFailure ? e.key : 'export_save_failed',
        );
      return false;
    }
  }

  Future<bool> upload() async {
    if (state.busy || state.bytes == null || _owner == null) return false;
    final previous = state;
    final generation = _generation;
    var fileId = previous.fileId;
    state = ExportState(
      busy: true,
      phase: 'export_authorizing',
      bytes: previous.bytes,
      filename: previous.filename,
      fileId: fileId,
    );
    try {
      final token = await ref.read(driveAuthorizationProvider)(_owner!);
      _checkAccount(generation);
      final drive = ref.read(driveExportServiceProvider);
      fileId ??= await drive.reserveId(token);
      _checkAccount(generation);
      final url = await drive.upload(
        token: token,
        fileId: fileId,
        filename: previous.filename!,
        bytes: previous.bytes!,
        checkAccount: () => _checkAccount(generation),
        onProgress: (p) {
          _checkAccount(generation);
          state = ExportState(
            busy: true,
            phase: 'export_uploading',
            progress: p,
            bytes: previous.bytes,
            filename: previous.filename,
            fileId: fileId,
          );
        },
      );
      _checkAccount(generation);
      state = ExportState(
        bytes: previous.bytes,
        filename: previous.filename,
        fileId: fileId,
        driveUrl: url,
      );
      return true;
    } catch (e) {
      if (ref.mounted && _started && generation == _generation)
        state = ExportState(
          bytes: previous.bytes,
          filename: previous.filename,
          fileId: fileId,
          error:
              e is GoogleSignInException &&
                  e.code == GoogleSignInExceptionCode.canceled
              ? null
              : e is ExportFailure
              ? e.key
              : 'export_upload_failed',
        );
      return false;
    }
  }

  Future<bool> sendEmail() async {
    if (state.busy || state.bytes == null || _owner == null) return false;
    if (state.emailSent) return true;
    final previous = state;
    final generation = _generation;
    state = ExportState(
      busy: true,
      phase: 'export_email_sending',
      bytes: previous.bytes,
      filename: previous.filename,
    );
    try {
      _checkAccount(generation);
      await ref
          .read(reportEmailServiceProvider)
          .send(
            uid: _owner!,
            filename: previous.filename!,
            bytes: previous.bytes!,
          );
      _checkAccount(generation);
      state = ExportState(
        bytes: previous.bytes,
        filename: previous.filename,
        emailSent: true,
      );
      return true;
    } catch (e) {
      if (ref.mounted && _started && generation == _generation) {
        state = ExportState(
          bytes: previous.bytes,
          filename: previous.filename,
          error: e is ExportFailure ? e.key : 'export_email_failed',
        );
      }
      return false;
    }
  }
}
