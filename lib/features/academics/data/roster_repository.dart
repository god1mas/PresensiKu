import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../dashboard/data/dashboard_repository.dart';

final rosterRepositoryProvider = Provider<RosterRepository>((ref) {
  return RosterRepository(ref.watch(appDatabaseProvider).database);
});

class Student {
  const Student({
    required this.id,
    required this.classId,
    required this.name,
    required this.attendanceNumber,
    this.nis,
  });
  final int id;
  final int classId;
  final String name;
  final int attendanceNumber;
  final String? nis;
}

class Subject {
  const Subject({required this.id, required this.name});
  final int id;
  final String name;
}

class RosterRepository {
  const RosterRepository(this.database);
  final Database database;

  Future<List<Student>> students(int classId, {String search = ''}) async {
    final term = search.trim().toLowerCase();
    final rows = await database.rawQuery(
      '''
      SELECT s.id, s.class_id, s.name, s.attendance_number, s.nis
      FROM student s JOIN school_class c ON c.id = s.class_id
      WHERE s.class_id = ? AND s.archived_at IS NULL AND c.archived_at IS NULL
        AND (? = '' OR lower(s.name) LIKE ? OR CAST(s.attendance_number AS TEXT) LIKE ?)
      ORDER BY s.attendance_number, lower(s.name)
    ''',
      [classId, term, '%$term%', '%$term%'],
    );
    return rows
        .map(
          (row) => Student(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            name: row['name'] as String,
            attendanceNumber: row['attendance_number'] as int,
            nis: row['nis'] as String?,
          ),
        )
        .toList();
  }

  Future<int> addStudent({
    required int classId,
    required String name,
    required int attendanceNumber,
    String? nis,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('Nama siswa wajib diisi.');
    if (attendanceNumber <= 0) {
      throw const FormatException('Nomor absen harus lebih dari nol.');
    }
    final now = DateTime.now().toIso8601String();
    return database.insert('student', {
      'class_id': classId,
      'name': trimmed,
      'attendance_number': attendanceNumber,
      'nis': nis?.trim().isEmpty == true ? null : nis?.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateStudent({
    required int id,
    required String name,
    required int attendanceNumber,
    String? nis,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('Nama siswa wajib diisi.');
    if (attendanceNumber <= 0) {
      throw const FormatException('Nomor absen harus lebih dari nol.');
    }
    final changed = await database.update(
      'student',
      {
        'name': trimmed,
        'attendance_number': attendanceNumber,
        'nis': nis?.trim().isEmpty == true ? null : nis?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Siswa tidak ditemukan.');
  }

  Future<void> archiveStudent(int id) async {
    final now = DateTime.now().toIso8601String();
    final changed = await database.update(
      'student',
      {'archived_at': now, 'updated_at': now},
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Siswa tidak ditemukan.');
  }

  Future<List<Subject>> subjects({bool includeArchived = false}) async {
    final rows = await database.query(
      'subject',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => Subject(id: row['id'] as int, name: row['name'] as String),
        )
        .toList();
  }

  Future<List<Subject>> subjectsForClass(int classId) async {
    final rows = await database.rawQuery(
      '''
      SELECT s.id, s.name FROM subject s
      JOIN class_subject cs ON cs.subject_id = s.id
      JOIN school_class c ON c.id = cs.class_id
      WHERE cs.class_id = ? AND cs.archived_at IS NULL
        AND s.archived_at IS NULL AND c.archived_at IS NULL
      ORDER BY s.name COLLATE NOCASE
    ''',
      [classId],
    );
    return rows
        .map(
          (row) => Subject(id: row['id'] as int, name: row['name'] as String),
        )
        .toList();
  }

  Future<int> addSubject(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Nama mata pelajaran wajib diisi.');
    }
    final now = DateTime.now().toIso8601String();
    return database.insert('subject', {
      'name': trimmed,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> renameSubject(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Nama mata pelajaran wajib diisi.');
    }
    final changed = await database.update(
      'subject',
      {'name': trimmed, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Mata pelajaran tidak ditemukan.');
  }

  Future<void> archiveSubject(int id) async {
    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      final changed = await txn.update(
        'subject',
        {'archived_at': now, 'updated_at': now},
        where: 'id = ? AND archived_at IS NULL',
        whereArgs: [id],
      );
      if (changed == 0) throw StateError('Mata pelajaran tidak ditemukan.');
      await txn.update(
        'class_subject',
        {'archived_at': now},
        where: 'subject_id = ? AND archived_at IS NULL',
        whereArgs: [id],
      );
    });
  }

  Future<void> assignSubject({
    required int classId,
    required int subjectId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      final classes = await txn.query(
        'school_class',
        columns: ['id'],
        where: 'id = ? AND archived_at IS NULL',
        whereArgs: [classId],
        limit: 1,
      );
      final subjects = await txn.query(
        'subject',
        columns: ['id'],
        where: 'id = ? AND archived_at IS NULL',
        whereArgs: [subjectId],
        limit: 1,
      );
      if (classes.isEmpty || subjects.isEmpty) {
        throw StateError('Kelas atau mata pelajaran tidak aktif.');
      }
      await txn.insert('class_subject', {
        'class_id': classId,
        'subject_id': subjectId,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<void> unassignSubject({
    required int classId,
    required int subjectId,
  }) async {
    await database.update(
      'class_subject',
      {
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'class_id = ? AND subject_id = ? AND archived_at IS NULL',
      whereArgs: [classId, subjectId],
    );
  }

  void refreshDashboard(WidgetRef ref) =>
      ref.invalidate(dashboardSummaryProvider);
}
