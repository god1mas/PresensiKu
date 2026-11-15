import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../dashboard/data/dashboard_repository.dart';

final classRepositoryProvider = Provider<ClassRepository>((ref) {
  return ClassRepository(ref.watch(appDatabaseProvider).database);
});

class AcademicPeriod {
  const AcademicPeriod({
    required this.id,
    required this.yearLabel,
    required this.semester,
    required this.isActive,
  });

  final int id;
  final String yearLabel;
  final String semester;
  final bool isActive;

  String get label => '$yearLabel ${semester == 'ganjil' ? 'Ganjil' : 'Genap'}';
}

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.periodId,
    required this.name,
    required this.studentCount,
    required this.colorIndex,
  });

  final int id;
  final int periodId;
  final String name;
  final int studentCount;
  final int colorIndex;
}

class ClassRepository {
  const ClassRepository(this.database);

  final Database database;

  Future<List<AcademicPeriod>> periods() async {
    final rows = await database.query(
      'academic_period',
      where: 'archived_at IS NULL',
      orderBy: 'is_active DESC, year_label DESC, semester',
    );
    return rows
        .map(
          (row) => AcademicPeriod(
            id: row['id'] as int,
            yearLabel: row['year_label'] as String,
            semester: row['semester'] as String,
            isActive: row['is_active'] == 1,
          ),
        )
        .toList();
  }

  Future<int> createPeriod({
    required String yearLabel,
    required String semester,
  }) async {
    final year = yearLabel.trim();
    if (year.isEmpty || !RegExp(r'^\d{4}/\d{4}$').hasMatch(year)) {
      throw const FormatException('Tahun ajaran harus seperti 2026/2027.');
    }
    if (semester != 'ganjil' && semester != 'genap') {
      throw const FormatException('Semester tidak valid.');
    }
    final now = DateTime.now().toIso8601String();
    return database.transaction((txn) async {
      final existing = await txn.query(
        'academic_period',
        columns: ['id'],
        limit: 1,
      );
      await txn.insert('academic_year', {
        'label': year,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final academicYear = (await txn.query(
        'academic_year',
        where: 'label = ?',
        whereArgs: [year],
      )).single['id'];
      return txn.insert('academic_period', {
        'year_id': academicYear,
        'year_label': year,
        'semester': semester,
        'is_active': existing.isEmpty ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<void> activatePeriod(int id) async {
    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      final target = await txn.query(
        'academic_period',
        where: 'id = ? AND archived_at IS NULL',
        whereArgs: [id],
        limit: 1,
      );
      if (target.isEmpty) throw StateError('Periode tidak ditemukan.');
      await txn.update('academic_period', {
        'is_active': 0,
        'updated_at': now,
      }, where: 'is_active = 1');
      await txn.update(
        'academic_period',
        {'is_active': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<SchoolClass>> classes(int periodId, {String search = ''}) async {
    final term = search.trim().toLowerCase();
    final rows = await database.rawQuery(
      '''
      SELECT c.id, c.period_id, c.name, c.color_index, COUNT(s.id) AS student_count
      FROM school_class c
      LEFT JOIN student s ON s.class_id = c.id AND s.archived_at IS NULL
      WHERE c.id IN (SELECT class_id FROM class_period WHERE period_id = ?) AND c.archived_at IS NULL
        AND (? = '' OR lower(c.name) LIKE ?)
      GROUP BY c.id
      ORDER BY lower(c.name)
    ''',
      [periodId, term, '%$term%'],
    );
    return rows
        .map(
          (row) => SchoolClass(
            id: row['id'] as int,
            periodId: row['period_id'] as int,
            name: row['name'] as String,
            studentCount: row['student_count'] as int,
            colorIndex: row['color_index'] as int,
          ),
        )
        .toList();
  }

  Future<SchoolClass?> classById(int id) async {
    final rows = await database.rawQuery(
      '''
      SELECT c.id, c.period_id, c.name, c.color_index, COUNT(s.id) AS student_count
      FROM school_class c
      LEFT JOIN student s ON s.class_id = c.id AND s.archived_at IS NULL
      WHERE c.id = ? AND c.archived_at IS NULL
      GROUP BY c.id
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return SchoolClass(
      id: row['id'] as int,
      periodId: row['period_id'] as int,
      name: row['name'] as String,
      studentCount: row['student_count'] as int,
      colorIndex: row['color_index'] as int,
    );
  }

  Future<int> createClass({
    required int periodId,
    required String name,
    int? colorIndex,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('Nama kelas wajib diisi.');
    final selectedColor = colorIndex ?? await nextColorIndex();
    if (selectedColor < 0 || selectedColor > 8) {
      throw const FormatException('Warna kelas tidak valid.');
    }
    final now = DateTime.now().toIso8601String();
    final profiles = await database.query('teacher_profile');
    final level = profiles.isEmpty
        ? 'legacy_school'
        : profiles.single['education_level'] ?? 'legacy_school';
    return database.transaction((txn) async {
      await _checkName(txn, periodId, trimmed);
      return txn.insert('school_class', {
        'education_level': level,
        'period_id': periodId,
        'name': trimmed,
        'color_index': selectedColor,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<void> _checkName(
    DatabaseExecutor txn,
    int periodId,
    String name, {
    int exclude = -1,
  }) async {
    final rows = await txn.rawQuery(
      '''SELECT c.id FROM school_class c JOIN class_period cp ON cp.class_id = c.id
      WHERE cp.period_id = ? AND c.archived_at IS NULL AND c.id != ? AND lower(trim(c.name)) = lower(trim(?))''',
      [periodId, exclude, name],
    );
    if (rows.isNotEmpty) {
      throw const FormatException(
        'Nama kelas sudah digunakan pada lingkup tahun/semester ini.',
      );
    }
  }

  Future<int> nextColorIndex() async {
    final rows = await database.rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS last_id FROM school_class',
    );
    return (rows.single['last_id'] as int) % 9;
  }

  Future<void> updateClass(int id, String name, int colorIndex) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('Nama kelas wajib diisi.');
    if (colorIndex < 0 || colorIndex > 8) {
      throw const FormatException('Warna kelas tidak valid.');
    }
    final current = await classById(id);
    if (current == null) throw StateError('Kelas tidak ditemukan.');
    if (current.name != trimmed) {
      await _checkName(database, current.periodId, trimmed, exclude: id);
    }
    final changed = await database.update(
      'school_class',
      {
        'name': trimmed,
        'color_index': colorIndex,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Kelas tidak ditemukan.');
  }

  Future<void> renameClass(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('Nama kelas wajib diisi.');
    final current = await classById(id);
    if (current == null) throw StateError('Kelas tidak ditemukan.');
    if (current.name != trimmed) {
      await _checkName(database, current.periodId, trimmed, exclude: id);
    }
    final changed = await database.update(
      'school_class',
      {'name': trimmed, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Kelas tidak ditemukan.');
  }

  Future<void> archiveClass(int id) async {
    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      final changed = await txn.update(
        'school_class',
        {'archived_at': now, 'updated_at': now},
        where: 'id = ? AND archived_at IS NULL',
        whereArgs: [id],
      );
      if (changed == 0) throw StateError('Kelas tidak ditemukan.');
      await txn.update(
        'student',
        {'archived_at': now, 'updated_at': now},
        where: 'class_id = ? AND archived_at IS NULL',
        whereArgs: [id],
      );
      await txn.update(
        'class_subject',
        {'archived_at': now},
        where: 'class_id = ? AND archived_at IS NULL',
        whereArgs: [id],
      );
    });
  }

  void refreshDashboard(WidgetRef ref) =>
      ref.invalidate(dashboardSummaryProvider);
}
