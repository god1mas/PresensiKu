import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('schema initializes with foreign keys and required tables', () async {
    final appDatabase = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);
    final db = appDatabase.database;

    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.single.values.single, 1);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll(<String>{
        'teacher_profile',
        'academic_period',
        'school_class',
        'student',
        'subject',
        'class_subject',
        'attendance_session',
        'attendance_record',
      }),
    );
  });

  test('active class and student uniqueness is enforced by SQLite', () async {
    final appDatabase = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);
    final db = appDatabase.database;
    const now = '2026-11-11T00:00:00.000';
    final period = await db.insert('academic_period', {
      'year_label': '2026/2027',
      'semester': 'ganjil',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    final schoolClass = await db.insert('school_class', {
      'period_id': period,
      'name': 'VII A',
      'created_at': now,
      'updated_at': now,
    });
    expect(
      () => db.insert('school_class', {
        'period_id': period,
        'name': ' vii a ',
        'created_at': now,
        'updated_at': now,
      }),
      throwsException,
    );
    await db.insert('student', {
      'class_id': schoolClass,
      'name': 'Ahmad',
      'attendance_number': 1,
      'created_at': now,
      'updated_at': now,
    });
    expect(
      () => db.insert('student', {
        'class_id': schoolClass,
        'name': 'Budi',
        'attendance_number': 1,
        'created_at': now,
        'updated_at': now,
      }),
      throwsException,
    );
  });
}
