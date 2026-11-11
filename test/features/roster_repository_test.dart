import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'students sort, search, enforce numbers, and persist after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presensiku_roster_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'app.db');
      final firstDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final classes = ClassRepository(firstDb.database);
      final period = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final classId = await classes.createClass(
        periodId: period,
        name: 'VII A',
      );
      final roster = RosterRepository(firstDb.database);
      final second = await roster.addStudent(
        classId: classId,
        name: 'Budi',
        attendanceNumber: 2,
      );
      final first = await roster.addStudent(
        classId: classId,
        name: 'Ahmad',
        attendanceNumber: 1,
        nis: '123',
      );
      expect((await roster.students(classId)).map((s) => s.name), [
        'Ahmad',
        'Budi',
      ]);
      expect((await roster.students(classId, search: 'ahm')).single.id, first);
      expect((await roster.students(classId, search: '2')).single.id, second);
      await expectLater(
        roster.addStudent(
          classId: classId,
          name: 'Duplikat',
          attendanceNumber: 1,
        ),
        throwsA(isA<DatabaseException>()),
      );
      await roster.updateStudent(
        id: second,
        name: 'Budi Baru',
        attendanceNumber: 3,
      );
      await firstDb.close();

      final secondDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      addTearDown(secondDb.close);
      final reopened = RosterRepository(secondDb.database);
      expect((await reopened.students(classId)).last.name, 'Budi Baru');
      await reopened.archiveStudent(first);
      expect((await reopened.students(classId)).single.attendanceNumber, 3);
      await reopened.addStudent(
        classId: classId,
        name: 'Cici',
        attendanceNumber: 1,
      );
      expect((await reopened.students(classId)).length, 2);
    },
  );

  test(
    'subjects assign to multiple classes and reject duplicate active pairs',
    () async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final classes = ClassRepository(db.database);
      final period = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final firstClass = await classes.createClass(
        periodId: period,
        name: 'VII A',
      );
      final secondClass = await classes.createClass(
        periodId: period,
        name: 'VII B',
      );
      final roster = RosterRepository(db.database);
      final subject = await roster.addSubject('Matematika');
      await expectLater(
        roster.addSubject(' matematika '),
        throwsA(isA<DatabaseException>()),
      );
      await roster.assignSubject(classId: firstClass, subjectId: subject);
      await roster.assignSubject(classId: secondClass, subjectId: subject);
      await expectLater(
        roster.assignSubject(classId: firstClass, subjectId: subject),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        (await roster.subjectsForClass(firstClass)).single.name,
        'Matematika',
      );
      expect(
        (await roster.subjectsForClass(secondClass)).single.name,
        'Matematika',
      );
      await roster.renameSubject(subject, 'Matematika Lanjut');
      expect(
        (await roster.subjectsForClass(firstClass)).single.name,
        'Matematika Lanjut',
      );
      await roster.unassignSubject(classId: firstClass, subjectId: subject);
      expect(await roster.subjectsForClass(firstClass), isEmpty);
      await roster.assignSubject(classId: firstClass, subjectId: subject);
      await roster.archiveSubject(subject);
      expect(await roster.subjectsForClass(firstClass), isEmpty);
      expect(await roster.subjectsForClass(secondClass), isEmpty);
    },
  );

  test('edits and archives preserve saved attendance snapshots', () async {
    final app = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(app.close);
    final db = app.database;
    final classes = ClassRepository(db);
    final roster = RosterRepository(db);
    final period = await classes.createPeriod(
      yearLabel: '2026/2027',
      semester: 'ganjil',
    );
    final classId = await classes.createClass(periodId: period, name: 'VII A');
    final student = await roster.addStudent(
      classId: classId,
      name: 'Ahmad',
      attendanceNumber: 1,
    );
    final subject = await roster.addSubject('Matematika');
    await roster.assignSubject(classId: classId, subjectId: subject);
    const now = '2026-11-11T00:00:00';
    final session = await db.insert('attendance_session', {
      'class_id': classId,
      'subject_id': subject,
      'period_id': period,
      'date': '2026-11-11',
      'meeting_number': 1,
      'state': 'completed',
      'class_name_snapshot': 'VII A',
      'subject_name_snapshot': 'Matematika',
      'period_snapshot': '2026/2027 Ganjil',
      'created_at': now,
      'updated_at': now,
      'completed_at': now,
    });
    await db.insert('attendance_record', {
      'session_id': session,
      'student_id': student,
      'student_name_snapshot': 'Ahmad',
      'attendance_number_snapshot': 1,
      'status': 'H',
      'created_at': now,
      'updated_at': now,
    });
    await roster.updateStudent(
      id: student,
      name: 'Ahmad Baru',
      attendanceNumber: 2,
    );
    await roster.renameSubject(subject, 'Matematika Lanjut');
    await roster.archiveStudent(student);
    await roster.archiveSubject(subject);
    final savedSession = (await db.query(
      'attendance_session',
      where: 'id = ?',
      whereArgs: [session],
    )).single;
    final savedRecord = (await db.query(
      'attendance_record',
      where: 'session_id = ?',
      whereArgs: [session],
    )).single;
    expect(savedSession['subject_name_snapshot'], 'Matematika');
    expect(savedRecord['student_name_snapshot'], 'Ahmad');
    expect(savedRecord['attendance_number_snapshot'], 1);
    expect(savedRecord['status'], 'H');
  });
}
