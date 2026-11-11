import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/dashboard/data/dashboard_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('teacher profile survives database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'presensiku_profile_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'app.db');
    final first = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    await ProfileRepository(first.database)
        .save(name: '  Budi Santoso  ', schoolName: ' SMP Negeri 1 ');
    await first.close();

    final second = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(second.close);
    final profile = await ProfileRepository(second.database).load();
    expect(profile?.name, 'Budi Santoso');
    expect(profile?.schoolName, 'SMP Negeri 1');
  });

  test('dashboard counts only active masters and completed sessions', () async {
    final appDatabase = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);
    final db = appDatabase.database;
    const now = '2026-11-11T00:00:00';
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
    await db.insert('student', {
      'class_id': schoolClass,
      'name': 'Ahmad',
      'attendance_number': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('student', {
      'class_id': schoolClass,
      'name': 'Arsip',
      'attendance_number': 2,
      'archived_at': now,
      'created_at': now,
      'updated_at': now,
    });
    final subject = await db.insert('subject', {
      'name': 'Matematika',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('attendance_session', {
      'class_id': schoolClass,
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
    await db.insert('attendance_session', {
      'class_id': schoolClass,
      'subject_id': subject,
      'period_id': period,
      'date': '2026-11-11',
      'meeting_number': 2,
      'state': 'draft',
      'class_name_snapshot': 'VII A',
      'subject_name_snapshot': 'Matematika',
      'period_snapshot': '2026/2027 Ganjil',
      'created_at': now,
      'updated_at': now,
    });

    final summary = await DashboardRepository(db).load();
    expect(summary.classCount, 1);
    expect(summary.studentCount, 1);
    expect(summary.subjectCount, 1);
    expect(summary.sessionCount, 1);
    expect(summary.classes.single.studentCount, 1);
    expect(summary.recentSessions.single.subjectName, 'Matematika');
  });
}
