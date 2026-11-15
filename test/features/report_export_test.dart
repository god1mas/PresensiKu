import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/education/education_level.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/reports/data/report_repository.dart';
import 'package:presensiku/features/reports/data/xlsx_exporter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('university attendance workbook keeps NIM as text in both sheets', () {
    const nim = '0012345678';
    final report = ReportData(
      educationLevel: EducationLevel.university,
      details: const [
        ReportDetail(
          studentId: 1,
          number: 1,
          studentName: 'Ayu',
          nis: nim,
          className: 'Informatika A',
          subjectName: 'Algoritma',
          date: '2026-11-16',
          meetingNumber: 1,
          status: 'H',
        ),
      ],
      summaries: const [
        StudentSummary(
          studentId: 1,
          number: 1,
          name: 'Ayu',
          nis: nim,
          present: 1,
          sick: 0,
          excused: 0,
          absent: 0,
        ),
      ],
    );
    final workbook = Excel.decodeBytes(const XlsxExporter().build(report));
    final detail = workbook['Detail Absensi'].rows;
    final summary = workbook['Rekap Absensi'].rows;
    expect(detail.first[2]?.value, TextCellValue('NIM'));
    expect(detail[1][2]?.value, TextCellValue(nim));
    expect(summary.first[2]?.value, TextCellValue('NIM'));
    expect(summary[1][2]?.value, TextCellValue(nim));
    expect(summary.first.length, 9);
  });

  test(
    'report denominators, filters, and Excel workbook stay accurate',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
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
      final math = await roster.addSubject('Matematika');
      await roster.assignSubject(classId: classId, subjectId: math);
      await roster.addStudent(
        classId: classId,
        name: 'Ahmad',
        attendanceNumber: 1,
      );
      final first = await attendance.prepare(
        classId: classId,
        subjectId: math,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      final ahmadFirst = (await attendance.load(first.sessionId))
          .records
          .single;
      await attendance.mark(
        sessionId: first.sessionId,
        recordId: ahmadFirst.id,
        status: 'H',
      );
      await attendance.complete(first.sessionId);
      await roster.addStudent(
        classId: classId,
        name: 'Budi',
        attendanceNumber: 2,
      );
      final second = await attendance.prepare(
        classId: classId,
        subjectId: math,
        date: '2026-11-12',
        meetingNumber: 2,
      );
      final secondRecords = (await attendance.load(second.sessionId)).records;
      await attendance.mark(
        sessionId: second.sessionId,
        recordId: secondRecords.first.id,
        status: 'S',
      );
      await attendance.mark(
        sessionId: second.sessionId,
        recordId: secondRecords.last.id,
        status: 'H',
      );
      await attendance.complete(second.sessionId);

      final reports = ReportRepository(app.database);
      final all = await reports.load();
      expect(all.details.length, 3);
      expect(all.summaries.length, 2);
      final ahmad = all.summaries.firstWhere((row) => row.name == 'Ahmad');
      final budi = all.summaries.firstWhere((row) => row.name == 'Budi');
      expect(ahmad.completedSessions, 2);
      expect(ahmad.attendancePercentage, 50);
      expect(budi.completedSessions, 1);
      expect(budi.attendancePercentage, 100);
      expect(
        (await reports.load(
          ReportFilter(
            classId: classId,
            subjectId: math,
            periodId: period,
            fromDate: '2026-11-12',
            toDate: '2026-11-12',
          ),
        )).details.length,
        2,
      );
      final empty = await reports.load(
        const ReportFilter(fromDate: '2027-01-01'),
      );
      expect(empty.details, isEmpty);
      expect(empty.summaries, isEmpty);

      final bytes = const XlsxExporter().build(all);
      expect(bytes.take(2), [0x50, 0x4b]);
      final workbook = Excel.decodeBytes(bytes);
      expect(
        workbook.sheets.keys,
        containsAll(['Detail Absensi', 'Rekap Absensi']),
      );
      final detailRows = workbook['Detail Absensi'].rows;
      final summaryRows = workbook['Rekap Absensi'].rows;
      expect(detailRows.length, 4);
      expect(summaryRows.length, 3);
      expect(detailRows.first[1]?.value, TextCellValue('Nama Siswa'));
      expect(
        summaryRows.first[7]?.value,
        TextCellValue('Persentase Kehadiran (%)'),
      );
      expect(summaryRows[1][7]?.value, IntCellValue(50));
    },
  );
}
