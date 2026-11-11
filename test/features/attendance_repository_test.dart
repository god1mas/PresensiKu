import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'draft marks survive restart; duplicate opens draft; complete is atomic',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presensiku_attendance_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'app.db');
      final firstDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final classes = ClassRepository(firstDb.database);
      final roster = RosterRepository(firstDb.database);
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
      await roster.addStudent(
        classId: classId,
        name: 'Ahmad',
        attendanceNumber: 1,
      );
      await roster.addStudent(
        classId: classId,
        name: 'Budi',
        attendanceNumber: 2,
      );
      final first = AttendanceRepository(firstDb.database);
      final prepared = await first.prepare(
        classId: classId,
        subjectId: subjectId,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      expect(prepared.existed, isFalse);
      final initial = await first.load(prepared.sessionId);
      expect(initial.markedCount, 0);
      expect(initial.unmarkedCount, 2);
      expect(initial.records.every((record) => record.status == null), isTrue);
      await first.mark(
        sessionId: prepared.sessionId,
        recordId: initial.records.first.id,
        status: 'S',
      );
      await expectLater(
        first.complete(prepared.sessionId),
        throwsA(isA<StateError>()),
      );
      expect((await first.load(prepared.sessionId)).state, 'draft');
      await firstDb.close();

      final secondDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      addTearDown(secondDb.close);
      final second = AttendanceRepository(secondDb.database);
      final reopened = await second.prepare(
        classId: classId,
        subjectId: subjectId,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      expect(reopened.existed, isTrue);
      expect(reopened.sessionId, prepared.sessionId);
      expect((await second.load(reopened.sessionId)).records.first.status, 'S');
      await second.mark(
        sessionId: reopened.sessionId,
        recordId: initial.records.last.id,
        status: 'H',
      );
      expect((await second.load(reopened.sessionId)).markedCount, 2);
      await second.complete(reopened.sessionId);
      final complete = await second.load(reopened.sessionId);
      expect(complete.state, 'completed');
      expect(complete.records.map((r) => r.status), ['S', 'H']);
      final again = await second.prepare(
        classId: classId,
        subjectId: subjectId,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      expect(again.existed, isTrue);
      expect(again.completed, isTrue);
      await expectLater(
        second.mark(
          sessionId: again.sessionId,
          recordId: initial.records.first.id,
          status: 'A',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('bulk marking handles 40 students and roster stays frozen', () async {
    final app = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(app.close);
    final classes = ClassRepository(app.database);
    final roster = RosterRepository(app.database);
    final period = await classes.createPeriod(
      yearLabel: '2026/2027',
      semester: 'ganjil',
    );
    final classId = await classes.createClass(periodId: period, name: 'VII A');
    final subjectId = await roster.addSubject('Matematika');
    await roster.assignSubject(classId: classId, subjectId: subjectId);
    for (var number = 1; number <= 40; number++) {
      await roster.addStudent(
        classId: classId,
        name: 'Siswa $number',
        attendanceNumber: number,
      );
    }
    final attendance = AttendanceRepository(app.database);
    final prepared = await attendance.prepare(
      classId: classId,
      subjectId: subjectId,
      date: '2026-11-11',
      meetingNumber: 1,
    );
    await roster.addStudent(
      classId: classId,
      name: 'Siswa Baru',
      attendanceNumber: 41,
    );
    expect((await attendance.load(prepared.sessionId)).records.length, 40);
    await attendance.markAllPresent(prepared.sessionId);
    final marked = await attendance.load(prepared.sessionId);
    expect(marked.markedCount, 40);
    expect(marked.unmarkedCount, 0);
    await attendance.complete(prepared.sessionId);
    expect((await attendance.load(prepared.sessionId)).state, 'completed');
    expect((await app.database.query('attendance_session')).length, 1);
    expect((await app.database.query('attendance_record')).length, 40);
  });
}
