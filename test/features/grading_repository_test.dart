import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('assessment, grades, snapshots, and weights survive reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'presensiku-grade-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/grades.db';
    var app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final ids = await _seed(app);
    var repo = GradingRepository(app.database);
    final category = await repo.createCategory('Praktik');
    final assessment = await repo.createAssessment(
      classId: ids.classId,
      subjectId: ids.subjectId,
      periodId: ids.periodId,
      categoryId: category,
      date: '2026-11-14',
      title: 'Praktik 1',
      maxScore: 20,
    );
    await repo.saveGrades(assessment, {
      ids.studentId: const GradeValue.graded(0),
    });
    await repo.saveWeights(
      classId: ids.classId,
      subjectId: ids.subjectId,
      periodId: ids.periodId,
      values: {category: 100},
    );
    await repo.renameCategory(category, 'Presentasi');
    await repo.archiveCategory(category);
    await app.database.update(
      'student',
      {'name': 'Nama Baru'},
      where: 'id = ?',
      whereArgs: [ids.studentId],
    );
    await app.close();

    app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(app.close);
    repo = GradingRepository(app.database);
    expect(
      (await repo.assessment(assessment))['category_name_snapshot'],
      'Praktik',
    );
    expect((await repo.grades(assessment)).single['score'], 0);
    expect(
      (await repo.grades(assessment)).single['student_name_snapshot'],
      'Ahmad',
    );
    expect(
      (await repo.categories(includeArchived: true))
          .firstWhere((row) => row['id'] == category)['name'],
      'Presentasi',
    );
    expect(
      await repo.weights(
        classId: ids.classId,
        subjectId: ids.subjectId,
        periodId: ids.periodId,
      ),
      {category: 100},
    );
    expect(
      (await repo.auditLog(
        classId: ids.classId,
        subjectId: ids.subjectId,
        periodId: ids.periodId,
      )).length,
      1,
    );

    final initial = await repo.resultForStudent(
      classId: ids.classId,
      subjectId: ids.subjectId,
      periodId: ids.periodId,
      studentId: ids.studentId,
    );
    expect(initial?.finalGrade, 0);

    await repo.saveGrades(assessment, {
      ids.studentId: const GradeValue.exempt(),
    });
    final corrected = await repo.resultForStudent(
      classId: ids.classId,
      subjectId: ids.subjectId,
      periodId: ids.periodId,
      studentId: ids.studentId,
    );
    expect(corrected?.finalGrade, isNull);
    expect((await repo.grades(assessment)).single['state'], 'EXEMPT');
    expect(
      (await repo.grades(assessment)).single['student_name_snapshot'],
      'Ahmad',
    );
    await repo.deleteAssessment(assessment);
    expect(
      await repo.assessments(
        classId: ids.classId,
        subjectId: ids.subjectId,
        periodId: ids.periodId,
      ),
      isEmpty,
    );
    expect((await repo.grades(assessment)).single['state'], 'EXEMPT');
  });

  test(
    'invalid grade batch and scope roll back without partial writes',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      final ids = await _seed(app);
      final repo = GradingRepository(app.database);
      final assessment = await repo.createAssessment(
        classId: ids.classId,
        subjectId: ids.subjectId,
        periodId: ids.periodId,
        categoryId: 1,
        date: '2026-11-14',
        title: 'Tugas',
        maxScore: 100,
      );
      await expectLater(
        repo.saveGrades(assessment, {
          ids.studentId: const GradeValue.graded(80),
          ids.otherStudentId: const GradeValue.graded(50),
        }),
        throwsFormatException,
      );
      expect(await repo.grades(assessment), isEmpty);
      await expectLater(
        repo.saveGrades(assessment, {
          ids.studentId: const GradeValue.graded(101),
        }),
        throwsFormatException,
      );
      expect(await repo.grades(assessment), isEmpty);
      await expectLater(
        repo.createAssessment(
          classId: ids.classId,
          subjectId: ids.subjectId,
          periodId: ids.otherPeriodId,
          categoryId: 1,
          date: '2026-11-14',
          title: 'Wrong period',
        ),
        throwsFormatException,
      );
      await expectLater(
        repo.saveWeights(
          classId: ids.classId,
          subjectId: ids.subjectId,
          periodId: ids.periodId,
          values: const {1: 99},
        ),
        throwsFormatException,
      );
      expect(
        await repo.auditLog(
          classId: ids.classId,
          subjectId: ids.subjectId,
          periodId: ids.periodId,
        ),
        isEmpty,
      );
    },
  );
}

class _Ids {
  const _Ids(
    this.periodId,
    this.otherPeriodId,
    this.classId,
    this.subjectId,
    this.studentId,
    this.otherStudentId,
  );
  final int periodId;
  final int otherPeriodId;
  final int classId;
  final int subjectId;
  final int studentId;
  final int otherStudentId;
}

Future<_Ids> _seed(AppDatabase app) async {
  final db = app.database;
  const now = '2026-11-14T00:00:00Z';
  final period = await db.insert('academic_period', {
    'year_label': '2026/2027',
    'semester': 'ganjil',
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  });
  final otherPeriod = await db.insert('academic_period', {
    'year_label': '2027/2028',
    'semester': 'genap',
    'is_active': 0,
    'created_at': now,
    'updated_at': now,
  });
  final schoolClass = await db.insert('school_class', {
    'period_id': period,
    'name': 'VII A',
    'created_at': now,
    'updated_at': now,
  });
  final otherClass = await db.insert('school_class', {
    'period_id': period,
    'name': 'VII B',
    'created_at': now,
    'updated_at': now,
  });
  final subject = await db.insert('subject', {
    'name': 'Bahasa Indonesia',
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('class_subject', {
    'class_id': schoolClass,
    'subject_id': subject,
    'created_at': now,
    'updated_at': now,
  });
  final student = await db.insert('student', {
    'class_id': schoolClass,
    'name': 'Ahmad',
    'attendance_number': 1,
    'created_at': now,
    'updated_at': now,
  });
  final otherStudent = await db.insert('student', {
    'class_id': otherClass,
    'name': 'Budi',
    'attendance_number': 1,
    'created_at': now,
    'updated_at': now,
  });
  return _Ids(period, otherPeriod, schoolClass, subject, student, otherStudent);
}
