import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('fresh schema 2 has grading tables and default categories', () async {
    final app = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(app.close);
    expect(await app.database.getVersion(), 2);
    final names = (await app.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((row) => row['name']).toSet();
    expect(
      names,
      containsAll({
        'assessment_category',
        'assessment',
        'assessment_grade',
        'grading_weight_set',
        'grading_weight_item',
        'grading_audit_log',
      }),
    );
    expect((await app.database.query('assessment_category')).length, 5);
  });

  test('populated schema 1 upgrades without changing attendance', () async {
    final directory = await Directory.systemTemp.createTemp('presensiku-v4-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/old.db';
    final old = await _oldDatabase(path);
    const now = '2026-11-11T00:00:00Z';
    await old.insert('teacher_profile', {
      'id': 1,
      'name': 'Guru',
      'created_at': now,
      'updated_at': now,
    });
    final period = await old.insert('academic_period', {
      'year_label': '2026/2027',
      'semester': 'ganjil',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    final schoolClass = await old.insert('school_class', {
      'period_id': period,
      'name': 'VII A',
      'created_at': now,
      'updated_at': now,
    });
    final student = await old.insert('student', {
      'class_id': schoolClass,
      'name': 'Ahmad',
      'attendance_number': 1,
      'created_at': now,
      'updated_at': now,
    });
    final subject = await old.insert('subject', {
      'name': 'Bahasa Indonesia',
      'created_at': now,
      'updated_at': now,
    });
    final session = await old.insert('attendance_session', {
      'class_id': schoolClass,
      'subject_id': subject,
      'period_id': period,
      'date': '2026-11-11',
      'meeting_number': 1,
      'state': 'completed',
      'class_name_snapshot': 'VII A',
      'subject_name_snapshot': 'Bahasa Indonesia',
      'period_snapshot': '2026/2027 Ganjil',
      'created_at': now,
      'updated_at': now,
    });
    await old.insert('attendance_record', {
      'session_id': session,
      'student_id': student,
      'status': 'H',
      'student_name_snapshot': 'Ahmad',
      'attendance_number_snapshot': 1,
      'created_at': now,
      'updated_at': now,
    });
    await old.close();

    final app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    expect(await app.database.getVersion(), 2);
    expect(
      (await app.database.query('attendance_record')).single['status'],
      'H',
    );
    expect(
      (await app.database.query('teacher_profile')).single['name'],
      'Guru',
    );
    expect((await app.database.query('assessment_category')).length, 5);
    expect(await app.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await app.close();

    final reopened = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(reopened.close);
    expect(
      (await reopened.database.query('attendance_record')).single['student_id'],
      student,
    );
    expect((await reopened.database.query('assessment_category')).length, 5);
  });

  test('failed upgrade rolls back schema version and legacy data', () async {
    final directory = await Directory.systemTemp.createTemp('presensiku-v4-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/failed.db';
    final old = await _oldDatabase(path);
    await old.insert('teacher_profile', {
      'id': 1,
      'name': 'Guru',
      'created_at': 'now',
      'updated_at': 'now',
    });
    await old.execute(
      'CREATE TABLE assessment_category (id INTEGER PRIMARY KEY)',
    );
    await old.close();
    await expectLater(
      AppDatabase.open(factory: databaseFactoryFfi, path: path),
      throwsException,
    );
    final check = await databaseFactoryFfi.openDatabase(path);
    addTearDown(check.close);
    expect(await check.getVersion(), 1);
    expect((await check.query('teacher_profile')).single['name'], 'Guru');
    final names = (await check.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((row) => row['name']).toSet();
    expect(names, isNot(contains('assessment')));
  });
}

Future<Database> _oldDatabase(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final sql in <String>[
          'CREATE TABLE teacher_profile (id INTEGER PRIMARY KEY, name TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          'CREATE TABLE academic_period (id INTEGER PRIMARY KEY, year_label TEXT NOT NULL, semester TEXT NOT NULL, is_active INTEGER NOT NULL, archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          'CREATE TABLE school_class (id INTEGER PRIMARY KEY, period_id INTEGER NOT NULL REFERENCES academic_period(id), name TEXT NOT NULL, archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          'CREATE TABLE student (id INTEGER PRIMARY KEY, class_id INTEGER NOT NULL REFERENCES school_class(id), name TEXT NOT NULL, attendance_number INTEGER NOT NULL, nis TEXT, archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          'CREATE TABLE subject (id INTEGER PRIMARY KEY, name TEXT NOT NULL, archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          'CREATE TABLE class_subject (id INTEGER PRIMARY KEY, class_id INTEGER NOT NULL REFERENCES school_class(id), subject_id INTEGER NOT NULL REFERENCES subject(id), archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          'CREATE TABLE attendance_session (id INTEGER PRIMARY KEY, class_id INTEGER NOT NULL REFERENCES school_class(id), subject_id INTEGER NOT NULL REFERENCES subject(id), period_id INTEGER NOT NULL REFERENCES academic_period(id), date TEXT NOT NULL, meeting_number INTEGER NOT NULL, state TEXT NOT NULL, class_name_snapshot TEXT NOT NULL, subject_name_snapshot TEXT NOT NULL, period_snapshot TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, completed_at TEXT)',
          'CREATE TABLE attendance_record (id INTEGER PRIMARY KEY, session_id INTEGER NOT NULL REFERENCES attendance_session(id), student_id INTEGER NOT NULL REFERENCES student(id), status TEXT, student_name_snapshot TEXT NOT NULL, attendance_number_snapshot INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        ]) {
          await db.execute(sql);
        }
      },
    ),
  );
}
