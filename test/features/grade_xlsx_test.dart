import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/grading/data/grade_report_repository.dart';
import 'package:presensiku/features/grading/data/grade_xlsx_exporter.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'three-sheet XLSX preserves blank, numeric zero, EX, final and provisional',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      final db = app.database;
      const now = '2026-11-14T00:00:00Z';
      final period = await db.insert('academic_period', {
        'year_label': '2026/2027',
        'semester': 'ganjil',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      final schoolClass = await db.insert('school_class', {
        'period_id': period,
        'name': 'XII-1',
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
      final students = <int>[];
      for (final name in ['Ahmad', 'Siti', 'Budi']) {
        students.add(
          await db.insert('student', {
            'class_id': schoolClass,
            'name': name,
            'attendance_number': students.length + 1,
            'created_at': now,
            'updated_at': now,
          }),
        );
      }
      final repo = GradingRepository(db);
      final tugas = await repo.createAssessment(
        classId: schoolClass,
        subjectId: subject,
        periodId: period,
        categoryId: 1,
        date: '2026-11-14',
        title: 'Tugas 1',
        maxScore: 20,
      );
      final uts = await repo.createAssessment(
        classId: schoolClass,
        subjectId: subject,
        periodId: period,
        categoryId: 3,
        date: '2026-11-15',
        title: 'UTS',
        maxScore: 100,
      );
      await repo.saveGrades(tugas, {
        students[0]: const GradeValue.graded(0),
        students[1]: const GradeValue.exempt(),
      });
      await repo.saveGrades(uts, {
        students[0]: const GradeValue.graded(80),
        students[1]: const GradeValue.graded(90),
        students[2]: const GradeValue.graded(70),
      });
      await repo.saveWeights(
        classId: schoolClass,
        subjectId: subject,
        periodId: period,
        values: const {1: 50, 3: 50},
      );
      final report = await GradeReportRepository(db)
          .load(classId: schoolClass, subjectId: subject, periodId: period);
      expect(report.results[students[0]]?.finalGrade, 40);
      expect(report.results[students[1]]?.provisional, 90);
      expect(report.results[students[1]]?.finalGrade, isNull);
      final bytes = const GradeXlsxExporter().build(report);
      expect(bytes.take(2), [0x50, 0x4b]);
      final workbook = Excel.decodeBytes(bytes);
      expect(
        workbook.sheets.keys,
        containsAll(['Detail Penilaian', 'Rekap per Kategori', 'Nilai Akhir']),
      );
      final detail = workbook['Detail Penilaian'].rows;
      expect(detail.length, 7);
      expect(detail.first[12]?.value, TextCellValue('Nilai'));
      final gradeCells = detail.skip(1).map((row) => row[12]?.value).toList();
      expect(gradeCells, contains(IntCellValue(0)));
      expect(gradeCells, contains(TextCellValue('EX')));
      expect(gradeCells, contains(null));
      final finals = workbook['Nilai Akhir'].rows;
      expect(finals.length, 4);
      expect(finals[1][7]?.value, IntCellValue(40));
      expect(finals[1][8]?.value, isNull);
      expect(finals[2][7]?.value, isNull);
      expect(finals[2][8]?.value, IntCellValue(90));
      expect(finals[2][9]?.value, TextCellValue('Sementara'));
      expect(finals[1][6]?.value, TextCellValue('Tugas: 50%; UTS: 50%'));
    },
  );
}
