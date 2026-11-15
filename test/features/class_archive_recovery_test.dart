import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/academics/presentation/class_screens.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('class restore retains original ID, color and history; only cascade children return after restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kelasku-class-archive-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/app.db';
    var app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    await ProfileRepository(app.database).save(name: 'Guru');
    final classes = ClassRepository(app.database);
    final roster = RosterRepository(app.database);
    final odd = await classes.createPeriod(
      yearLabel: '2026/2027',
      semester: 'ganjil',
    );
    final even = await classes.createPeriod(
      yearLabel: '2026/2027',
      semester: 'genap',
    );
    final id = await classes.createClass(
      periodId: odd,
      name: 'VII A',
      colorIndex: 6,
    );
    final currentStudent = await roster.addStudent(
      classId: id,
      name: 'Aktif',
      attendanceNumber: 1,
    );
    final oldStudent = await roster.addStudent(
      classId: id,
      name: 'Arsip Lama',
      attendanceNumber: 2,
    );
    await roster.archiveStudent(oldStudent);
    final currentSubject = await roster.addSubject('Matematika');
    final oldSubject = await roster.addSubject('Bahasa');
    await roster.assignSubject(classId: id, subjectId: currentSubject);
    await roster.assignSubject(classId: id, subjectId: oldSubject);
    await roster.unassignSubject(classId: id, subjectId: oldSubject);
    final attendance = AttendanceRepository(app.database);
    final session = await attendance.prepare(
      classId: id,
      subjectId: currentSubject,
      date: '2026-11-16',
      meetingNumber: 1,
    );
    await attendance.markAllPresent(session.sessionId);
    await attendance.complete(session.sessionId);
    await classes.archiveClass(id);
    expect(await classes.classes(even), isEmpty);
    expect((await classes.archivedClasses(even)).single.id, id);
    final replacement = await classes.createClass(
      periodId: even,
      name: 'VII A',
      colorIndex: 2,
    );
    await expectLater(classes.restoreClass(id), throwsFormatException);
    expect((await classes.archivedClasses(odd)).single.id, id);
    await classes.renameClass(replacement, 'VII B');
    await app.close();
    app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    await ClassRepository(app.database).restoreClass(id);
    expect((await ClassRepository(app.database).classById(id))!.colorIndex, 6);
    expect(
      (await RosterRepository(app.database).students(id)).single.id,
      currentStudent,
    );
    expect(
      (await RosterRepository(app.database).subjectsForClass(id)).single.id,
      currentSubject,
    );
    expect(
      (await app.database.query(
        'student',
        where: 'id = ?',
        whereArgs: [oldStudent],
      )).single['archived_at'],
      isNotNull,
    );
    expect(
      (await app.database.query(
        'class_subject',
        where: 'class_id = ? AND subject_id = ?',
        whereArgs: [id, oldSubject],
      )).single['archived_at'],
      isNotNull,
    );
    expect(
      (await app.database.query('attendance_session')).single['id'],
      session.sessionId,
    );
    final backup = await BackupRepository(app.database).create();
    final restored = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(restored.close);
    await BackupRepository(restored.database).restore(backup);
    expect(
      (await ClassRepository(restored.database).classById(id))!.colorIndex,
      6,
    );
    expect(
      await restored.database.rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
    await app.close();
  });

  testWidgets('archive tab shows context and restores after confirmation', (
    tester,
  ) async {
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    final classes = ClassRepository(app.database);
    final period = (await tester.runAsync(() async {
      final p = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final id = await classes.createClass(
        periodId: p,
        name: 'VII A',
        colorIndex: 3,
      );
      await classes.archiveClass(id);
      return p;
    }))!;
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(app)],
        child: const MaterialApp(home: ClassListScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsip'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Arsip kelas'), findsOneWidget);
    expect(find.text('VII A'), findsOneWidget);
    await tester.tap(find.text('Pulihkan'));
    await tester.pumpAndSettle();
    expect(find.text('Pulihkan Kelas?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => classes.archivedClasses(period)))!.length,
      1,
    );
    await tester.tap(find.text('Pulihkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulihkan Kelas'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => classes.classes(period)))!.single.name,
      'VII A',
    );
    expect(find.text('Belum ada kelas di arsip'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });
}
