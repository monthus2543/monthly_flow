import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Picker files may be temporary. Keep a separate copy in app documents.
Future<String> storeReceipt(XFile picked, Directory documents) async {
  final directory = Directory('${documents.path}/receipts');
  await directory.create(recursive: true);
  final extension = picked.name.split('.').last.toLowerCase();
  final suffix =
      ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'].contains(extension)
      ? extension
      : 'jpg';
  final file = File(
    '${directory.path}/receipt-${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );
  await picked.saveTo(file.path);
  return file.path;
}
