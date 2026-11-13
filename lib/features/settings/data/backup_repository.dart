import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(appDatabaseProvider).database);
});

class BackupPreview {
  const BackupPreview(this.data);
  final Map<String, List<Map<String, Object?>>> data;

  int count(String table) => data[table]?.length ?? 0;
  String get teacherName => data['teacher_profile']!.single['name'] as String;
}

class BackupRepository {
  const BackupRepository(this.database);
  final Database database;

  static const format = 'PresensiKu SQLite backup';
  static const legacyTables = <String>[
    'teacher_profile',
    'academic_period',
    'school_class',
    'student',
    'subject',
    'class_subject',
    'attendance_session',
    'attendance_record',
  ];
  static const tables = <String>[
    ...legacyTables,
    'assessment_category',
    'assessment',
    'assessment_grade',
    'grading_weight_set',
    'grading_weight_item',
    'grading_audit_log',
  ];

  Future<Uint8List> create() async {
    final data = await database.transaction((txn) async {
      final result = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        result[table] = await txn.query(table, orderBy: 'id');
      }
      return result;
    });
    final payload = jsonEncode(data);
    final envelope = {
      'format': format,
      'schemaVersion': AppDatabase.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'data': data,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  BackupPreview inspect(Uint8List bytes) {
    try {
      if (bytes.isEmpty || bytes.length > 100 * 1024 * 1024) {
        throw const FormatException('Ukuran file cadangan tidak valid.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
        throw const FormatException('Format file cadangan tidak dikenal.');
      }
      final version = decoded['schemaVersion'];
      if (version != 1 && version != AppDatabase.schemaVersion) {
        throw const FormatException('Versi database cadangan tidak cocok.');
      }
      final expectedTables = version == 1 ? legacyTables : tables;
      final raw = decoded['data'];
      if (raw is! Map<String, dynamic> ||
          raw.length != expectedTables.length ||
          !expectedTables.every(raw.containsKey)) {
        throw const FormatException('Isi file cadangan tidak lengkap.');
      }
      final digest = sha256.convert(utf8.encode(jsonEncode(raw))).toString();
      if (decoded['sha256'] != digest) {
        throw const FormatException('File cadangan rusak atau berubah.');
      }
      final data = <String, List<Map<String, Object?>>>{};
      for (final table in expectedTables) {
        final rows = raw[table];
        if (rows is! List) {
          throw const FormatException('Isi file cadangan tidak valid.');
        }
        data[table] = rows.map((row) {
          if (row is! Map<String, dynamic> ||
              row.values.any(
                (value) => value != null && value is! String && value is! num,
              )) {
            throw const FormatException('Baris file cadangan tidak valid.');
          }
          return Map<String, Object?>.from(row);
        }).toList();
      }
      if (data['teacher_profile']!.length != 1 ||
          data['teacher_profile']!.single['name'] is! String) {
        throw const FormatException('Profil guru tidak valid.');
      }
      for (final table in tables) {
        data.putIfAbsent(table, () => []);
      }
      return BackupPreview(data);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'File cadangan rusak atau tidak dapat dibaca.',
      );
    }
  }

  Future<void> restore(Uint8List bytes) async {
    final backup = inspect(bytes);
    await database.transaction((txn) async {
      for (final table in tables.reversed) {
        await txn.delete(table);
      }
      for (final table in tables) {
        final columns = (await txn.rawQuery('PRAGMA table_info($table)'))
            .map((row) => row['name'] as String)
            .toSet();
        for (final row in backup.data[table]!) {
          if (!columns.containsAll(row.keys)) {
            throw const FormatException('Skema file cadangan tidak cocok.');
          }
          await txn.insert(table, row);
        }
      }
      if (backup.data['assessment_category']!.isEmpty) {
        final now = DateTime.now().toUtc().toIso8601String();
        for (final name in ['Tugas', 'Ulangan', 'UTS', 'UAS', 'Sikap']) {
          await txn.insert('assessment_category', {
            'name': name,
            'is_default': 1,
            'created_at': now,
            'updated_at': now,
          });
        }
      }
      final invalidRelations = await txn.rawQuery('PRAGMA foreign_key_check');
      if (invalidRelations.isNotEmpty) {
        throw const FormatException('Relasi dalam file cadangan tidak valid.');
      }
      final integrity = await txn.rawQuery('PRAGMA integrity_check');
      if (integrity.single.values.single != 'ok') {
        throw const FormatException('Integritas database cadangan gagal.');
      }
    });
  }
}
