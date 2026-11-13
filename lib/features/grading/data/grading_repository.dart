import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/grade_calculator.dart';

final gradingRepositoryProvider = Provider<GradingRepository>((ref) {
  return GradingRepository(ref.watch(appDatabaseProvider).database);
});

class GradingRepository {
  const GradingRepository(this.database);

  final Database database;

  String get _now => DateTime.now().toUtc().toIso8601String();

  Future<List<Map<String, Object?>>> categories({
    bool includeArchived = false,
  }) {
    return database.query(
      'assessment_category',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'id',
    );
  }

  Future<int> createCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty)
      throw const FormatException('Nama kategori wajib diisi.');
    final now = _now;
    return database.insert('assessment_category', {
      'name': clean,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> renameCategory(int id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty)
      throw const FormatException('Nama kategori wajib diisi.');
    final changed = await database.update(
      'assessment_category',
      {'name': clean, 'updated_at': _now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed != 1) throw const FormatException('Kategori tidak ditemukan.');
  }

  Future<void> archiveCategory(int id) async {
    final changed = await database.update(
      'assessment_category',
      {'archived_at': _now, 'updated_at': _now},
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed != 1) throw const FormatException('Kategori tidak ditemukan.');
  }

  Future<int> createAssessment({
    required int classId,
    required int subjectId,
    required int periodId,
    required int categoryId,
    required String date,
    required String title,
    double maxScore = 100,
    String? bab,
    String? description,
    bool isRequired = true,
  }) async {
    if (title.trim().isEmpty ||
        date.trim().isEmpty ||
        !maxScore.isFinite ||
        maxScore <= 0) {
      throw const FormatException('Data penilaian tidak valid.');
    }
    return database.transaction((txn) async {
      final scope = await _scope(txn, classId, subjectId, periodId);
      final category = await _one(txn, 'assessment_category', categoryId);
      if (category['archived_at'] != null) {
        throw const FormatException('Kategori telah diarsipkan.');
      }
      if (category['name'] == 'Sikap' && maxScore > 100) {
        throw const FormatException('Nilai maksimal Sikap adalah 100.');
      }
      final now = _now;
      return txn.insert('assessment', {
        'class_id': classId,
        'subject_id': subjectId,
        'period_id': periodId,
        'category_id': categoryId,
        'date': date,
        'bab': bab?.trim(),
        'title': title.trim(),
        'description': description?.trim(),
        'max_score': maxScore,
        'is_required': isRequired ? 1 : 0,
        'class_name_snapshot': scope.className,
        'subject_name_snapshot': scope.subjectName,
        'period_snapshot': scope.periodName,
        'category_name_snapshot': category['name'],
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> assessments({
    required int classId,
    required int subjectId,
    required int periodId,
    bool includeArchived = false,
  }) {
    return database.query(
      'assessment',
      where:
          'class_id = ? AND subject_id = ? AND period_id = ? '
          '${includeArchived ? '' : 'AND archived_at IS NULL AND deleted_at IS NULL'}',
      whereArgs: [classId, subjectId, periodId],
      orderBy: 'date DESC, id DESC',
    );
  }

  Future<Map<String, Object?>> assessment(int id) =>
      _one(database, 'assessment', id);

  Future<void> updateAssessment({
    required int id,
    required String title,
    required String date,
    required int categoryId,
    required double maxScore,
    String? bab,
    String? description,
    bool isRequired = true,
  }) async {
    if (title.trim().isEmpty ||
        date.trim().isEmpty ||
        !maxScore.isFinite ||
        maxScore <= 0) {
      throw const FormatException('Data penilaian tidak valid.');
    }
    await database.transaction((txn) async {
      final existing = await _one(txn, 'assessment', id);
      if (existing['deleted_at'] != null) {
        throw const FormatException('Penilaian telah dihapus.');
      }
      final category = await _one(txn, 'assessment_category', categoryId);
      if (category['archived_at'] != null &&
          categoryId != existing['category_id']) {
        throw const FormatException('Kategori telah diarsipkan.');
      }
      if (category['name'] == 'Sikap' && maxScore > 100) {
        throw const FormatException('Nilai maksimal Sikap adalah 100.');
      }
      final grades = await txn.query(
        'assessment_grade',
        columns: ['score'],
        where: 'assessment_id = ? AND state = ?',
        whereArgs: [id, 'GRADED'],
      );
      if (grades.any(
        (grade) => (grade['score'] as num).toDouble() > maxScore,
      )) {
        throw const FormatException(
          'Nilai tersimpan melebihi nilai maksimal baru.',
        );
      }
      await txn.update(
        'assessment',
        {
          'title': title.trim(),
          'date': date,
          'category_id': categoryId,
          'category_name_snapshot': categoryId == existing['category_id']
              ? existing['category_name_snapshot']
              : category['name'],
          'max_score': maxScore,
          'bab': bab?.trim(),
          'description': description?.trim(),
          'is_required': isRequired ? 1 : 0,
          'updated_at': _now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> archiveAssessment(int id) => _markAssessment(id, 'archived_at');

  /// Soft deletion retains grades and allows recovery from a backup or history.
  Future<void> deleteAssessment(int id) => _markAssessment(id, 'deleted_at');

  Future<void> _markAssessment(int id, String column) async {
    final changed = await database.update(
      'assessment',
      {column: _now, 'updated_at': _now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (changed != 1) throw const FormatException('Penilaian tidak ditemukan.');
  }

  Future<List<Map<String, Object?>>> grades(int assessmentId) {
    return database.query(
      'assessment_grade',
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
      orderBy: 'attendance_number_snapshot',
    );
  }

  Future<void> saveGrades(int assessmentId, Map<int, GradeValue> values) async {
    await database.transaction((txn) async {
      final assessment = await _one(txn, 'assessment', assessmentId);
      if (assessment['deleted_at'] != null ||
          assessment['archived_at'] != null) {
        throw const FormatException('Penilaian tidak aktif.');
      }
      final maxScore = (assessment['max_score'] as num).toDouble();
      final isAttitude = assessment['category_name_snapshot'] == 'Sikap';
      final now = _now;
      for (final entry in values.entries) {
        final student = await _one(txn, 'student', entry.key);
        if (student['class_id'] != assessment['class_id']) {
          throw const FormatException('Siswa bukan anggota kelas penilaian.');
        }
        final grade = entry.value;
        if (grade.state == GradeState.ungraded) {
          await txn.delete(
            'assessment_grade',
            where: 'assessment_id = ? AND student_id = ?',
            whereArgs: [assessmentId, entry.key],
          );
          continue;
        }
        final score = grade.score;
        if (grade.state == GradeState.graded &&
            (score == null ||
                !score.isFinite ||
                score < 0 ||
                score > maxScore ||
                (isAttitude && score > 100))) {
          throw const FormatException('Nilai siswa di luar rentang.');
        }
        final existing = await txn.query(
          'assessment_grade',
          where: 'assessment_id = ? AND student_id = ?',
          whereArgs: [assessmentId, entry.key],
          limit: 1,
        );
        final row = <String, Object?>{
          'state': grade.state == GradeState.exempt ? 'EXEMPT' : 'GRADED',
          'score': grade.state == GradeState.exempt ? null : score,
          'student_name_snapshot': student['name'],
          'attendance_number_snapshot': student['attendance_number'],
          'updated_at': now,
        };
        if (existing.isEmpty) {
          await txn.insert('assessment_grade', {
            ...row,
            'assessment_id': assessmentId,
            'student_id': entry.key,
            'created_at': now,
          });
        } else {
          // Keep the first historical student snapshot on corrections.
          row.remove('student_name_snapshot');
          row.remove('attendance_number_snapshot');
          await txn.update(
            'assessment_grade',
            row,
            where: 'id = ?',
            whereArgs: [existing.single['id']],
          );
        }
      }
    });
  }

  Future<Map<int, int>> weights({
    required int classId,
    required int subjectId,
    required int periodId,
  }) async {
    final sets = await database.query(
      'grading_weight_set',
      where:
          'class_id = ? AND subject_id = ? AND period_id = ? AND is_active = 1',
      whereArgs: [classId, subjectId, periodId],
      limit: 1,
    );
    if (sets.isEmpty) return {};
    final items = await database.query(
      'grading_weight_item',
      where: 'weight_set_id = ?',
      whereArgs: [sets.single['id']],
    );
    return {
      for (final item in items)
        item['category_id'] as int: item['percent'] as int,
    };
  }

  Future<void> saveWeights({
    required int classId,
    required int subjectId,
    required int periodId,
    required Map<int, int> values,
  }) async {
    GradeCalculator.validateWeights(values);
    await database.transaction((txn) async {
      await _scope(txn, classId, subjectId, periodId);
      for (final id in values.keys) {
        await _one(txn, 'assessment_category', id);
      }
      final existing = await txn.query(
        'grading_weight_set',
        where: 'class_id = ? AND subject_id = ? AND period_id = ?',
        whereArgs: [classId, subjectId, periodId],
        limit: 1,
      );
      final now = _now;
      final setId = existing.isEmpty
          ? await txn.insert('grading_weight_set', {
              'class_id': classId,
              'subject_id': subjectId,
              'period_id': periodId,
              'is_active': 1,
              'created_at': now,
              'updated_at': now,
            })
          : existing.single['id'] as int;
      final oldItems = await txn.query(
        'grading_weight_item',
        where: 'weight_set_id = ?',
        whereArgs: [setId],
      );
      final previous = {
        for (final item in oldItems)
          item['category_id'] as int: item['percent'] as int,
      };
      await txn.delete(
        'grading_weight_item',
        where: 'weight_set_id = ?',
        whereArgs: [setId],
      );
      for (final entry in values.entries) {
        await txn.insert('grading_weight_item', {
          'weight_set_id': setId,
          'category_id': entry.key,
          'percent': entry.value,
        });
      }
      await txn.update(
        'grading_weight_set',
        {'is_active': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [setId],
      );
      final changed =
          previous.length != values.length ||
          previous.keys.any((key) => previous[key] != values[key]);
      if (changed) {
        await txn.insert('grading_audit_log', {
          'class_id': classId,
          'subject_id': subjectId,
          'period_id': periodId,
          'action': 'weights_changed',
          'details_json': jsonEncode({
            'before': previous.map((key, value) => MapEntry('$key', value)),
            'after': values.map((key, value) => MapEntry('$key', value)),
          }),
          'created_at': now,
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> auditLog({
    required int classId,
    required int subjectId,
    required int periodId,
  }) => database.query(
    'grading_audit_log',
    where: 'class_id = ? AND subject_id = ? AND period_id = ?',
    whereArgs: [classId, subjectId, periodId],
    orderBy: 'id DESC',
  );

  Future<GradeResult?> resultForStudent({
    required int classId,
    required int subjectId,
    required int periodId,
    required int studentId,
  }) async {
    final configuredWeights = await weights(
      classId: classId,
      subjectId: subjectId,
      periodId: periodId,
    );
    if (configuredWeights.isEmpty) return null;
    final items = await assessments(
      classId: classId,
      subjectId: subjectId,
      periodId: periodId,
    );
    final values = <int, GradeValue>{};
    for (final item in items) {
      final rows = await database.query(
        'assessment_grade',
        where: 'assessment_id = ? AND student_id = ?',
        whereArgs: [item['id'], studentId],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      final grade = rows.single;
      values[item['id'] as int] = grade['state'] == 'EXEMPT'
          ? const GradeValue.exempt()
          : GradeValue.graded((grade['score'] as num).toDouble());
    }
    return const GradeCalculator().calculate(
      assessments: items
          .map(
            (item) => AssessmentValue(
              id: item['id'] as int,
              categoryId: item['category_id'] as int,
              maxScore: (item['max_score'] as num).toDouble(),
              isRequired: item['is_required'] == 1,
              isAttitude: item['category_name_snapshot'] == 'Sikap',
            ),
          )
          .toList(),
      grades: values,
      weights: configuredWeights,
    );
  }

  Future<Map<String, Object?>> _one(
    DatabaseExecutor txn,
    String table,
    int id,
  ) async {
    final rows = await txn.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw FormatException('$table tidak ditemukan.');
    return rows.single;
  }

  Future<_Scope> _scope(
    DatabaseExecutor txn,
    int classId,
    int subjectId,
    int periodId,
  ) async {
    final schoolClass = await _one(txn, 'school_class', classId);
    final subject = await _one(txn, 'subject', subjectId);
    final period = await _one(txn, 'academic_period', periodId);
    if (schoolClass['period_id'] != periodId ||
        schoolClass['archived_at'] != null ||
        subject['archived_at'] != null ||
        period['archived_at'] != null) {
      throw const FormatException('Kelas, mapel, dan periode tidak sesuai.');
    }
    final linked = await txn.query(
      'class_subject',
      where: 'class_id = ? AND subject_id = ? AND archived_at IS NULL',
      whereArgs: [classId, subjectId],
      limit: 1,
    );
    if (linked.isEmpty)
      throw const FormatException('Mapel belum terhubung ke kelas.');
    return _Scope(
      schoolClass['name'] as String,
      subject['name'] as String,
      '${period['year_label']} ${period['semester']}',
    );
  }
}

class _Scope {
  const _Scope(this.className, this.subjectName, this.periodName);
  final String className;
  final String subjectName;
  final String periodName;
}
