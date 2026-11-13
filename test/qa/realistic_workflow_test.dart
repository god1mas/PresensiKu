import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/grading/data/grade_report_repository.dart';
import 'package:presensiku/features/grading/data/grade_xlsx_exporter.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:presensiku/features/history/data/history_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/reports/data/report_repository.dart';
import 'package:presensiku/features/reports/data/xlsx_exporter.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    '40-student attendance, grading, corrections, Excel, and restore agree',
    () async {
      final directory = await Directory.systemTemp.createTemp('presensiku-qa-');
      addTearDown(() => directory.delete(recursive: true));
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/source.db',
      );
      addTearDown(app.close);
      await ProfileRepository(app.database).save(name: 'Ibu Sari');
      final classes = ClassRepository(app.database);
      final roster = RosterRepository(app.database);
      final attendance = AttendanceRepository(app.database);
      final period = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final classId = await classes.createClass(
        periodId: period,
        name: 'VII A',
      );
      final subjectId = await roster.addSubject('Matematika');
      await roster.assignSubject(classId: classId, subjectId: subjectId);
      for (var number = 1; number <= 40; number++) {
        await roster.addStudent(
          classId: classId,
          name: 'Siswa $number',
          attendanceNumber: number,
        );
      }
      int? firstSessionId;
      int? firstRecordId;
      const statuses = ['H', 'S', 'I', 'A'];
      for (var meeting = 1; meeting <= 4; meeting++) {
        final session = await attendance.prepare(
          classId: classId,
          subjectId: subjectId,
          date: '2026-11-${meeting.toString().padLeft(2, '0')}',
          meetingNumber: meeting,
        );
        final records = (await attendance.load(session.sessionId)).records;
        expect(records.length, 40);
        if (meeting == 1) {
          firstSessionId = session.sessionId;
          firstRecordId = records.first.id;
        }
        for (var index = 0; index < records.length; index++) {
          await attendance.mark(
            sessionId: session.sessionId,
            recordId: records[index].id,
            status: statuses[(index + meeting - 1) % 4],
          );
        }
        await attendance.complete(session.sessionId);
      }
      await HistoryRepository(app.database).correct(
        sessionId: firstSessionId!,
        recordId: firstRecordId!,
        status: 'A',
      );
      final firstStudent =
          (await app.database.query(
                'student',
                columns: ['id'],
                where: 'attendance_number = 1',
              )).single['id']
              as int;
      await roster.archiveStudent(firstStudent);
      final report = await ReportRepository(app.database).load();
      expect(report.details.length, 160);
      expect(report.summaries.length, 40);
      expect(report.summaries.first.attendancePercentage, 0);
      expect(
        report.summaries.skip(1).every((s) => s.attendancePercentage == 25),
        isTrue,
      );
      final workbook = Excel.decodeBytes(const XlsxExporter().build(report));
      expect(workbook['Detail Absensi'].rows.length, 161);
      expect(workbook['Rekap Absensi'].rows.length, 41);

      final grading = GradingRepository(app.database);
      final assessmentIds = <int, int>{};
      final categories = await grading.categories();
      final categoryIds = <String, int>{
        for (final row in categories) row['name'] as String: row['id'] as int,
      };
      final maxima = <String, double>{
        'Tugas': 20,
        'Ulangan': 50,
        'UTS': 100,
        'UAS': 100,
        'Sikap': 100,
      };
      for (final category in maxima.entries) {
        assessmentIds[categoryIds[category.key]!] = await grading
            .createAssessment(
              classId: classId,
              subjectId: subjectId,
              periodId: period,
              categoryId: categoryIds[category.key]!,
              date: '2026-11-14',
              title: '${category.key} BAB 1',
              maxScore: category.value,
            );
      }
      final allStudents = await app.database.query(
        'student',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'attendance_number',
      );
      for (final category in maxima.entries) {
        final values = <int, GradeValue>{};
        for (var index = 0; index < allStudents.length; index++) {
          final id = allStudents[index]['id'] as int;
          if (category.key == 'Tugas' && index == 0) {
            values[id] = const GradeValue.graded(0);
          } else if (category.key == 'Ulangan' && index == 1) {
            values[id] = const GradeValue.exempt();
          } else if (category.key == 'UAS' && index == 2) {
            values[id] = const GradeValue.ungraded();
          } else {
            values[id] = GradeValue.graded(category.value * 0.8);
          }
        }
        await grading.saveGrades(
          assessmentIds[categoryIds[category.key]!]!,
          values,
        );
      }
      await grading.saveWeights(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        values: {
          categoryIds['Tugas']!: 30,
          categoryIds['Ulangan']!: 15,
          categoryIds['UTS']!: 25,
          categoryIds['UAS']!: 25,
          categoryIds['Sikap']!: 5,
        },
      );
      final firstResult = await grading.resultForStudent(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        studentId: allStudents[0]['id'] as int,
      );
      final secondResult = await grading.resultForStudent(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        studentId: allStudents[1]['id'] as int,
      );
      final thirdResult = await grading.resultForStudent(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        studentId: allStudents[2]['id'] as int,
      );
      expect(firstResult?.finalGrade, closeTo(56, 0.00001));
      expect(secondResult?.finalGrade, isNull);
      expect(secondResult?.provisional, closeTo(80, 0.00001));
      expect(secondResult?.incompleteReasons.join(' '), contains('EX'));
      expect(thirdResult?.finalGrade, isNull);
      expect(thirdResult?.provisional, closeTo(80, 0.00001));
      final gradeReport = await GradeReportRepository(app.database)
          .load(classId: classId, subjectId: subjectId, periodId: period);
      final gradeWorkbook = Excel.decodeBytes(
        const GradeXlsxExporter().build(gradeReport),
      );
      expect(gradeWorkbook['Detail Penilaian'].rows.length, 201);
      expect(gradeWorkbook['Rekap per Kategori'].rows.length, 201);
      expect(gradeWorkbook['Nilai Akhir'].rows.length, 41);
      final scoreCells = gradeWorkbook['Detail Penilaian'].rows
          .skip(1)
          .map((row) => row[12]?.value)
          .toList();
      expect(scoreCells, contains(IntCellValue(0)));
      expect(scoreCells, contains(TextCellValue('EX')));
      expect(scoreCells, contains(null));

      await grading.saveGrades(assessmentIds[categoryIds['Ulangan']!]!, {
        allStudents[1]['id'] as int: const GradeValue.graded(40),
      });
      await grading.saveGrades(assessmentIds[categoryIds['UAS']!]!, {
        allStudents[2]['id'] as int: const GradeValue.graded(80),
      });
      await grading.saveWeights(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        values: {
          categoryIds['Tugas']!: 0,
          categoryIds['Ulangan']!: 15,
          categoryIds['UTS']!: 25,
          categoryIds['UAS']!: 55,
          categoryIds['Sikap']!: 5,
        },
      );
      final corrected = await grading.resultForStudent(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        studentId: allStudents[0]['id'] as int,
      );
      expect(corrected?.finalGrade, closeTo(80, 0.00001));
      expect(
        (await grading.auditLog(
          classId: classId,
          subjectId: subjectId,
          periodId: period,
        )).length,
        2,
      );

      final backup = await BackupRepository(app.database).create();
      final restored = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/restored.db',
      );
      addTearDown(restored.close);
      await BackupRepository(restored.database).restore(backup);
      final after = await ReportRepository(restored.database).load();
      expect(after.details.length, report.details.length);
      expect(after.summaries.first.attendancePercentage, 0);
      final restoredGrading = GradingRepository(restored.database);
      expect(
        (await restoredGrading.resultForStudent(
          classId: classId,
          subjectId: subjectId,
          periodId: period,
          studentId: allStudents[0]['id'] as int,
        ))?.finalGrade,
        closeTo(80, 0.00001),
      );
      expect(
        (await restoredGrading.auditLog(
          classId: classId,
          subjectId: subjectId,
          periodId: period,
        )).length,
        2,
      );
      expect(
        (await restored.database.rawQuery('PRAGMA foreign_key_check')),
        isEmpty,
      );
    },
  );
}
