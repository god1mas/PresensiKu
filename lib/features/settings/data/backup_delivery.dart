import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupDeliveryProvider = Provider<BackupDelivery>(
  (ref) => BackupDelivery(),
);

typedef SaveBackup = Future<bool> Function(String filename, Uint8List bytes);
typedef PickBackup = Future<Uint8List?> Function();

class BackupDelivery {
  BackupDelivery({SaveBackup? saveBackup, PickBackup? pickBackup})
    : _saveBackup = saveBackup ?? _saveDefault,
      _pickBackup = pickBackup ?? _pickDefault;

  final SaveBackup _saveBackup;
  final PickBackup _pickBackup;

  Future<bool> save(String filename, Uint8List bytes) =>
      _saveBackup(filename, bytes);

  Future<Uint8List?> pick() => _pickBackup();

  static Future<bool> _saveDefault(String filename, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: filename,
        bytes: bytes,
        mimeType: 'application/json',
      ) !=
      null;

  static Future<Uint8List?> _pickDefault() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pkbackup'],
    );
    return result?.readAsBytes();
  }
}
