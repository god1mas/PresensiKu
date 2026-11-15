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
  const Subject({required this.id, required this.name, this.archivedAt});
  final int id;
  final String name;
  final String? archivedAt;
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
        AND (? = '' OR lower(s.name) LIKE ? OR CAST(s.attendance_number AS TEXT) LIKE ? OR (length(?) >= 3 AND s.nis LIKE ?))
      ORDER BY s.attendance_number, lower(s.name)
    ''',
      [classId, term, '%$term%', '%$term%', term, '%$term%'],
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
    return database.transaction((txn) async {
      final identity = await _identity(txn, classId, trimmed, nis);
      return txn.insert('student', {
        'identity_id': identity,
        'class_id': classId,
        'name': trimmed,
        'attendance_number': attendanceNumber,
        'nis': nis?.trim().isEmpty == true ? null : nis?.trim(),
        'created_at': now,
        'updated_at': now,
      });
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
    await database.transaction((txn) async {
      final rows = await txn.query(
        'student',
        where: 'id = ? AND archived_at IS NULL',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw StateError('Siswa tidak ditemukan.');
      final row = rows.single;
      final identity = await _identity(
        txn,
        row['class_id'] as int,
        trimmed,
        nis,
        existing: row,
      );
      await txn.update(
        'student',
        {
          'name': trimmed,
          'attendance_number': attendanceNumber,
          'nis': nis?.trim().isEmpty == true ? null : nis?.trim(),
          'identity_id': identity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> _identity(
    DatabaseExecutor txn,
    int classId,
    String name,
    String? identifier, {
    Map<String, Object?>? existing,
  }) async {
    final classes = await txn.query(
      'school_class',
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [classId],
    );
    if (classes.isEmpty) throw const FormatException('Kelas tidak aktif.');
    final university = classes.single['education_level'] == 'university';
    final nim = identifier?.trim() ?? '';
    if (!university) {
      return existing?['identity_id'] as int? ??
          await txn.insert('student_identity', {
            'name': name,
            'created_at': DateTime.now().toIso8601String(),
          });
    }
    // Existing imported enrollment without NIM can still be corrected; new
    // enrollment always requires it. Historical snapshots are never rewritten.
    if (nim.isEmpty &&
        existing != null &&
        (existing['nis'] == null || existing['nis'] == '')) {
      return existing['identity_id'] as int;
    }
    if (nim.isEmpty) throw const FormatException('NIM wajib diisi.');
    final duplicates = await txn.query(
      'student',
      where: 'class_id = ? AND nis = ? AND archived_at IS NULL AND id != ?',
      whereArgs: [classId, nim, existing?['id'] ?? -1],
    );
    if (duplicates.isNotEmpty) {
      throw const FormatException('NIM sudah terdaftar di kelas ini.');
    }
    // Institution is frozen on identity creation. Reuse an existing enrollment's
    // institution so a profile edit cannot silently move its identity.
    final profiles = await txn.query('teacher_profile');
    var institution = profiles.isEmpty
        ? ''
        : (profiles.single['school_name'] as String? ?? '')
              .trim()
              .toLowerCase();
    if (existing?['identity_id'] != null) {
      final old = await txn.query(
        'student_identity',
        where: 'id = ?',
        whereArgs: [existing!['identity_id']],
      );
      if (old.isNotEmpty && old.single['nim'] != null) {
        institution = old.single['institution'] as String;
      }
    }
    final identities = await txn.query(
      'student_identity',
      where: 'institution = ? AND nim = ?',
      whereArgs: [institution, nim],
    );
    if (identities.isNotEmpty) {
      final identity = identities.single;
      if ((identity['name'] as String).trim().toLowerCase() !=
              name.toLowerCase() &&
          identity['id'] != existing?['identity_id']) {
        throw const FormatException(
          'NIM sudah terkait dengan nama lain. Periksa identitas mahasiswa.',
        );
      }
      return identity['id'] as int;
    }
    return txn.insert('student_identity', {
      'name': name,
      'institution': institution,
      'nim': nim,
      'created_at': DateTime.now().toIso8601String(),
    });
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
          (row) => Subject(
            id: row['id'] as int,
            name: row['name'] as String,
            archivedAt: row['archived_at'] as String?,
          ),
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

  Future<void> restoreSubject(int id) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'subject',
        where: 'id = ? AND archived_at IS NOT NULL',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        throw const FormatException('Mata pelajaran tidak ada di arsip.');
      }
      final subject = rows.single;
      final conflict = await txn.rawQuery(
        'SELECT id FROM subject WHERE archived_at IS NULL AND lower(trim(name)) = lower(trim(?)) AND id != ? LIMIT 1',
        [subject['name'], id],
      );
      if (conflict.isNotEmpty) {
        throw const FormatException(
          'Nama ini sudah digunakan mata pelajaran aktif. Ubah nama yang aktif terlebih dahulu, lalu pulihkan arsip.',
        );
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'subject',
        {'archived_at': null, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      // Only associations archived in the same operation are recovered.
      // Older unlinks keep their distinct archive timestamps.
      await txn.rawUpdate(
        '''
        UPDATE class_subject SET archived_at = NULL, updated_at = ?
        WHERE subject_id = ? AND archived_at = ?
          AND class_id IN (SELECT id FROM school_class WHERE archived_at IS NULL)
          AND NOT EXISTS (SELECT 1 FROM class_subject active
            WHERE active.class_id = class_subject.class_id AND active.subject_id = ?
              AND active.archived_at IS NULL)
      ''',
        [now, id, subject['archived_at'], id],
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
