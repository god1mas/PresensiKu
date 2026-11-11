import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/history/data/history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'history filters and corrections stay consistent after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presensiku_history_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'app.db');
      final firstDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final classes = ClassRepository(firstDb.database);
      final roster = RosterRepository(firstDb.database);
      final firstPeriod = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final secondPeriod = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'genap',
      );
      final firstClass = await classes.createClass(
        periodId: firstPeriod,
        name: 'VII A',
      );
      final secondClass = await classes.createClass(
        periodId: secondPeriod,
        name: 'VII B',
      );
      final math = await roster.addSubject('Matematika');
      final science = await roster.addSubject('IPA');
      await roster.assignSubject(classId: firstClass, subjectId: math);
      await roster.assignSubject(classId: secondClass, subjectId: science);
      await roster.addStudent(
        classId: firstClass,
        name: 'Ahmad',
        attendanceNumber: 1,
      );
      await roster.addStudent(
        classId: secondClass,
        name: 'Budi',
        attendanceNumber: 1,
      );
      final attendance = AttendanceRepository(firstDb.database);
      final first = await attendance.prepare(
        classId: firstClass,
        subjectId: math,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      final firstRecord = (await attendance.load(first.sessionId))
          .records
          .single;
      await attendance.mark(
        sessionId: first.sessionId,
        recordId: firstRecord.id,
        status: 'H',
      );
      await attendance.complete(first.sessionId);
      await classes.activatePeriod(secondPeriod);
      final second = await attendance.prepare(
        classId: secondClass,
        subjectId: science,
        date: '2027-02-01',
        meetingNumber: 1,
      );
      final secondRecord = (await attendance.load(second.sessionId))
          .records
          .single;
      await attendance.mark(
        sessionId: second.sessionId,
        recordId: secondRecord.id,
        status: 'S',
      );
      await attendance.complete(second.sessionId);

      final history = HistoryRepository(firstDb.database);
      expect((await history.sessions()).length, 2);
      expect(
        (await history.sessions(const HistoryFilter(classId: 1))).single.id,
        first.sessionId,
      );
      expect(
        (await history.sessions(HistoryFilter(subjectId: science))).single.id,
        second.sessionId,
      );
      expect(
        (await history.sessions(HistoryFilter(periodId: firstPeriod)))
            .single
            .id,
        first.sessionId,
      );
      expect(
        (await history.sessions(
          const HistoryFilter(fromDate: '2027-01-01', toDate: '2027-12-31'),
        )).single.id,
        second.sessionId,
      );
      expect(
        (await history.sessions(const HistoryFilter(search: 'matematika')))
            .single
            .id,
        first.sessionId,
      );
      expect((await history.counts(first.sessionId)).present, 1);
      await history.correct(
        sessionId: first.sessionId,
        recordId: firstRecord.id,
        status: 'I',
      );
      expect((await history.counts(first.sessionId)).present, 0);
      expect((await history.counts(first.sessionId)).excused, 1);
      await firstDb.close();

      final reopenedDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      addTearDown(reopenedDb.close);
      final reopened = HistoryRepository(reopenedDb.database);
      expect((await reopened.sessions()).length, 2);
      expect((await reopened.counts(first.sessionId)).excused, 1);
      expect(
        (await AttendanceRepository(reopenedDb.database).load(first.sessionId))
            .records
            .single
            .status,
        'I',
      );
    },
  );
}
