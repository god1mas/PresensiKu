import '../../../core/education/education_level.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/grade_calculator.dart';
import 'grading_repository.dart';

final gradeReportRepositoryProvider = Provider<GradeReportRepository>((ref) {
  return GradeReportRepository(ref.watch(appDatabaseProvider).database);
});

class GradeReportData {
  const GradeReportData({
    required this.className,
    this.educationLevel,
    required this.subjectName,
    required this.yearLabel,
    required this.semester,
    required this.students,
    required this.assessments,
    required this.categories,
    required this.weights,
    required this.grades,
    required this.results,
  });

  final EducationLevel? educationLevel;
  final String className;
  final String subjectName;
  final String yearLabel;
  final String semester;
  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> assessments;
  final Map<int, String> categories;
  final Map<int, int> weights;
  final Map<(int, int), Map<String, Object?>> grades;
  final Map<int, GradeResult?> results;
}

class GradeReportRepository {
  const GradeReportRepository(this.database);
  final Database database;

  Future<GradeReportData> load({
    required int classId,
    required int subjectId,
    required int periodId,
  }) async {
    final classes = await database.query(
      'school_class',
      where: 'id = ? AND id IN (SELECT class_id FROM class_period WHERE period_id = ?)',
      whereArgs: [classId, periodId],
    );
    final subjects = await database.query(
      'subject',
      where: 'id = ?',
      whereArgs: [subjectId],
    );
    final periods = await database.query(
      'academic_period',
      where: 'id = ?',
      whereArgs: [periodId],
    );
    if (classes.isEmpty || subjects.isEmpty || periods.isEmpty) {
      throw const FormatException('Lingkup laporan tidak valid.');
    }
    final repo = GradingRepository(database);
    final assessments = await repo.assessments(
      classId: classId,
      subjectId: subjectId,
      periodId: periodId,
    );
    final students = await database.query(
      'student',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'attendance_number, id',
    );
    final categories = <int, String>{
      for (final category in await repo.categories(includeArchived: true))
        category['id'] as int: category['name'] as String,
    };
    final weights = await repo.weights(
      classId: classId,
      subjectId: subjectId,
      periodId: periodId,
    );
    final grades = <(int, int), Map<String, Object?>>{};
    for (final assessment in assessments) {
      for (final grade in await repo.grades(assessment['id'] as int)) {
        grades[(assessment['id'] as int, grade['student_id'] as int)] = grade;
      }
    }
    final historicalStudents = [
      for (final student in students) Map<String, Object?>.from(student),
    ];
    for (final student in historicalStudents) {
      for (final assessment in assessments) {
        final grade = grades[(assessment['id'] as int, student['id'] as int)];
        if (grade != null) {
          student['name'] = grade['student_name_snapshot'];
          student['attendance_number'] = grade['attendance_number_snapshot'];
          student['nis'] = grade['identifier_snapshot'];
          break;
        }
      }
    }
    final assessmentValues = [
      for (final assessment in assessments)
        AssessmentValue(
          id: assessment['id'] as int,
          categoryId: assessment['category_id'] as int,
          maxScore: (assessment['max_score'] as num).toDouble(),
          isRequired: assessment['is_required'] == 1,
          isAttitude: assessment['category_name_snapshot'] == 'Sikap',
        ),
    ];
    final results = <int, GradeResult?>{};
    for (final student in students) {
      final studentId = student['id'] as int;
      final values = <int, GradeValue>{};
      for (final assessment in assessments) {
        final id = assessment['id'] as int;
        final grade = grades[(id, studentId)];
        if (grade == null) continue;
        values[id] = grade['state'] == 'EXEMPT'
            ? const GradeValue.exempt()
            : GradeValue.graded((grade['score'] as num).toDouble());
      }
      results[studentId] = const GradeCalculator().calculate(
        assessments: assessmentValues,
        grades: values,
        weights: weights,
      );
    }
    return GradeReportData(
      educationLevel: EducationLevel.parse(classes.single['education_level']),
      className: classes.single['name'] as String,
      subjectName: subjects.single['name'] as String,
      yearLabel: periods.single['year_label'] as String,
      semester: periods.single['semester'] as String,
      students: historicalStudents,
      assessments: assessments,
      categories: categories,
      weights: weights,
      grades: grades,
      results: results,
    );
  }
}
