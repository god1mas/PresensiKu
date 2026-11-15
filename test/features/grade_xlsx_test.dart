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
    'matrix orders dynamic columns and forty students without losing grades',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      final db = app.database;
      const now = '2026-11-16T00:00:00Z';
      final period = await db.insert('academic_period', {
        'year_label': '2026/2027',
        'semester': 'genap',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      final classId = await db.insert('school_class', {
        'period_id': period,
        'name': 'IX B',
        'created_at': now,
        'updated_at': now,
      });
      final subjectId = await db.insert('subject', {
        'name': 'Matematika',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('class_subject', {
        'class_id': classId,
        'subject_id': subjectId,
        'created_at': now,
        'updated_at': now,
      });
      final students = <int>[];
      for (var number = 40; number >= 1; number--) {
        students.add(
          await db.insert('student', {
            'class_id': classId,
            'name': 'Siswa $number',
            'attendance_number': number,
            'created_at': now,
            'updated_at': now,
          }),
        );
      }
      final repo = GradingRepository(db);
      final customId = await repo.createCategory('Proyek');
      Future<int> add(
        int categoryId,
        String date,
        String title, {
        double maxScore = 100,
      }) => repo.createAssessment(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        categoryId: categoryId,
        date: date,
        title: title,
        maxScore: maxScore,
      );
      final late = await add(1, '2026-11-20', 'Tugas akhir');
      final early = await add(1, '2026-11-10', 'Tugas awal', maxScore: 20);
      final sameDate = await add(1, '2026-11-10', 'Tugas kedua');
      final quiz2 = await add(2, '2026-11-18', 'Ulangan kedua');
      final quiz1 = await add(2, '2026-11-12', 'Ulangan pertama');
      final uts = await add(3, '2026-11-21', 'UTS');
      final uas = await add(4, '2026-11-22', 'UAS');
      final sikap = await add(5, '2026-11-23', 'Sikap');
      final proyek = await add(customId, '2026-11-24', 'Proyek akhir');
      final firstStudent = students.last; // No. Absen 1 was inserted last.
      final secondStudent = students[38];
      for (final assessmentId in [
        late,
        early,
        sameDate,
        quiz1,
        quiz2,
        uts,
        uas,
        sikap,
        proyek,
      ]) {
        await repo.saveGrades(assessmentId, {
          firstStudent: assessmentId == sameDate
              ? const GradeValue.exempt()
              : GradeValue.graded(assessmentId == early ? 10 : 80),
          if (assessmentId == early) secondStudent: const GradeValue.graded(0),
          if (assessmentId == uas) secondStudent: const GradeValue.exempt(),
        });
      }
      await repo.saveWeights(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        values: {1: 30, 2: 15, 3: 25, 4: 20, 5: 5, customId: 5},
      );
      final report = await GradeReportRepository(db)
          .load(classId: classId, subjectId: subjectId, periodId: period);
      final workbook = Excel.decodeBytes(
        const GradeXlsxExporter().build(report),
      );
      expect(workbook.sheets.keys.toList(), [
        'Detail Penilaian',
        'Rekap per Kategori',
        'Nilai Akhir',
        'Matriks Nilai',
      ]);
      final matrix = workbook['Matriks Nilai'].rows;
      final merges = workbook.getMergedCells('Matriks Nilai');
      expect(
        merges,
        containsAll([
          'A1:A2',
          'B1:B2',
          'C1:E1',
          'F1:G1',
          'L1:L2',
          'M1:M2',
          'N1:N2',
        ]),
      );
      expect(matrix[0][2]?.value, TextCellValue('Nilai Tugas (30%)'));
      expect(
        matrix[0][2]?.cellStyle?.backgroundColor.colorHex,
        endsWith('1762F3'),
      );
      expect(
        matrix[2][1]?.cellStyle?.horizontalAlignment,
        HorizontalAlign.Left,
      );
      expect(workbook['Matriks Nilai'].getColumnWidth(1), 30);
      expect(matrix[0][5]?.value, TextCellValue('Ulangan (15%)'));
      expect(matrix[0][10]?.value, TextCellValue('Proyek (5%)'));
      expect(
        [matrix[1][2]?.value, matrix[1][3]?.value, matrix[1][4]?.value],
        [IntCellValue(1), IntCellValue(2), IntCellValue(3)],
      );
      expect(matrix[2][0]?.value, IntCellValue(1));
      expect(matrix[2][1]?.value, TextCellValue('Siswa 1'));
      expect(matrix[2][2]?.value, IntCellValue(10));
      expect(matrix[2][3]?.value, TextCellValue('EX'));
      expect(matrix[2][4]?.value, IntCellValue(80));
      expect(matrix[3][2]?.value, IntCellValue(0));
      expect(matrix[4][2]?.value, isNull);
      expect(matrix[41][0]?.value, IntCellValue(40));
      expect(matrix[2][12]?.value, TextCellValue('Lengkap'));
      expect(matrix[3][12]?.value, TextCellValue('Belum Lengkap'));
      expect(matrix[3][11]?.value, isNull);
      expect(matrix[3][13]?.value.toString(), contains('EX'));
      expect(matrix[3][13]?.value.toString(), contains('Tugas akhir'));
      expect(matrix[3][13]?.value.toString(), contains('kategori UAS'));
      final official = report.results[firstStudent]!.finalGrade!;
      final matrixFinal = matrix[2][11]!.value;
      final numericFinal = switch (matrixFinal) {
        IntCellValue value => value.value.toDouble(),
        DoubleCellValue value => value.value,
        _ => throw StateError('Nilai akhir bukan angka.'),
      };
      expect(numericFinal, closeTo(official, 0.000001));
      expect(matrix[44][0]?.value, TextCellValue('Legenda Penilaian'));
      expect(
        matrix[43][0]?.value,
        TextCellValue('Lingkup: IX B · Matematika · 2026/2027 Genap'),
      );
      expect(matrix[46][2]?.value, TextCellValue('Tugas awal'));
      expect(matrix[46][3]?.value, TextCellValue('2026-11-10'));
      expect(matrix[46][4]?.value, IntCellValue(20));
      expect(matrix[47][2]?.value, TextCellValue('Tugas kedua'));
      expect(matrix[48][2]?.value, TextCellValue('Tugas akhir'));
    },
  );

  test(
    'four-sheet XLSX preserves blank, numeric zero, EX, and official final',
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
        containsAll([
          'Detail Penilaian',
          'Rekap per Kategori',
          'Nilai Akhir',
          'Matriks Nilai',
        ]),
      );
      expect(workbook.sheets.length, 4);
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
      final matrix = workbook['Matriks Nilai'].rows;
      expect(matrix[0][0]?.value, TextCellValue('No. Absen'));
      expect(matrix[0][2]?.value, TextCellValue('Nilai Tugas (50%)'));
      expect(matrix[0][4]?.value, TextCellValue('UTS (50%)'));
      expect(matrix[1][2]?.value, IntCellValue(1));
      expect(matrix[2][2]?.value, IntCellValue(0));
      expect(matrix[3][2]?.value, TextCellValue('EX'));
      expect(matrix[4][2]?.value, isNull);
      expect(matrix[2][7]?.value, finals[1][7]?.value);
      expect(matrix[3][7]?.value, isNull);
      expect(matrix[2][8]?.value, TextCellValue('Lengkap'));
      expect(matrix[3][8]?.value, TextCellValue('Belum Lengkap'));
      expect(matrix[3][9]?.value.toString(), contains('EX'));
      expect(workbook.getMergedCells('Matriks Nilai'), contains('A1:A2'));
      expect(matrix[7][0]?.value, TextCellValue('Legenda Penilaian'));
      expect(matrix[9][4]?.value, IntCellValue(20));
    },
  );
}
