import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

final reportDeliveryProvider = Provider<ReportDelivery>(
  (ref) => ReportDelivery(),
);

typedef SaveWorkbook = Future<Uri?> Function(String filename, Uint8List bytes);
typedef ShareWorkbook = Future<bool> Function(String filename, Uint8List bytes);

class ReportDelivery {
  ReportDelivery({SaveWorkbook? saveWorkbook, ShareWorkbook? shareWorkbook})
    : _saveWorkbook = saveWorkbook ?? _saveDefault,
      _shareWorkbook = shareWorkbook ?? _shareDefault;

  final SaveWorkbook _saveWorkbook;
  final ShareWorkbook _shareWorkbook;

  Future<bool> save(String filename, Uint8List bytes) async =>
      await _saveWorkbook(filename, bytes) != null;

  Future<bool> share(String filename, Uint8List bytes) =>
      _shareWorkbook(filename, bytes);

  static Future<Uri?> _saveDefault(String filename, Uint8List bytes) =>
      FilePicker.saveFile(
        fileName: filename,
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

  static Future<bool> _shareDefault(String filename, Uint8List bytes) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: [filename],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
