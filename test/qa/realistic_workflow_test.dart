import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/history/data/history_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/reports/data/report_repository.dart';
import 'package:presensiku/features/reports/data/xlsx_exporter.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    '40-student sessions, correction, archive, Excel, and restore agree',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
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

      final backup = await BackupRepository(app.database).create();
      final restored = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(restored.close);
      await BackupRepository(restored.database).restore(backup);
      final after = await ReportRepository(restored.database).load();
      expect(after.details.length, report.details.length);
      expect(after.summaries.first.attendancePercentage, 0);
      expect(
        (await restored.database.rawQuery('PRAGMA foreign_key_check')),
        isEmpty,
      );
    },
  );
}
