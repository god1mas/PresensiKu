import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/reports/data/report_repository.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'full backup restores all rows, relationships, and report values',
    () async {
      final source = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(source.close);
      await ProfileRepository(source.database)
          .save(name: 'Ibu Sari', schoolName: 'SMP Harapan');
      final classes = ClassRepository(source.database);
      final roster = RosterRepository(source.database);
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
      final attendance = AttendanceRepository(source.database);
      final session = await attendance.prepare(
        classId: classId,
        subjectId: subjectId,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      final record = (await attendance.load(session.sessionId)).records.single;
      await attendance.mark(
        sessionId: session.sessionId,
        recordId: record.id,
        status: 'H',
      );
      await attendance.complete(session.sessionId);
      final bytes = await BackupRepository(source.database).create();

      final target = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(target.close);
      await ProfileRepository(target.database).save(name: 'Data lama');
      final backup = BackupRepository(target.database);
      final preview = backup.inspect(bytes);
      expect(preview.teacherName, 'Ibu Sari');
      expect(preview.count('attendance_record'), 1);
      await backup.restore(bytes);
      for (final table in BackupRepository.tables) {
        expect(
          await target.database.query(table),
          await source.database.query(table),
          reason: table,
        );
      }
      expect(
        (await target.database.rawQuery('PRAGMA foreign_key_check')),
        isEmpty,
      );
      final report = await ReportRepository(target.database).load();
      expect(report.summaries.single.attendancePercentage, 100);
      expect(
        (await ProfileRepository(target.database).load())!.schoolName,
        'SMP Harapan',
      );
    },
  );

  test(
    'corrupt and incompatible backups are rejected without data loss',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      await ProfileRepository(app.database).save(name: 'Tetap aman');
      final backup = BackupRepository(app.database);
      final valid = await backup.create();
      final decoded = jsonDecode(utf8.decode(valid)) as Map<String, dynamic>;
      decoded['schemaVersion'] = 999;
      expect(
        () => backup.inspect(
          Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
        ),
        throwsFormatException,
      );
      decoded['schemaVersion'] = AppDatabase.schemaVersion;
      decoded['sha256'] = 'invalid';
      expect(
        () => backup.inspect(
          Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
        ),
        throwsFormatException,
      );
      expect(
        () => backup.inspect(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(
        (await ProfileRepository(app.database).load())!.name,
        'Tetap aman',
      );
    },
  );

  test('foreign-key failure rolls back a full restore', () async {
    final app = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(app.close);
    await ProfileRepository(app.database).save(name: 'Tetap aman');
    final backup = BackupRepository(app.database);
    final encoded =
        jsonDecode(utf8.decode(await backup.create())) as Map<String, dynamic>;
    final data = encoded['data'] as Map<String, dynamic>;
    data['student'] = [
      {
        'id': 1,
        'class_id': 999,
        'name': 'Tidak valid',
        'attendance_number': 1,
        'nis': null,
        'archived_at': null,
        'created_at': '2026-11-11',
        'updated_at': '2026-11-11',
      },
    ];
    encoded['sha256'] = sha256
        .convert(utf8.encode(jsonEncode(data)))
        .toString();
    final invalid = Uint8List.fromList(utf8.encode(jsonEncode(encoded)));
    await expectLater(backup.restore(invalid), throwsA(anything));
    expect((await ProfileRepository(app.database).load())!.name, 'Tetap aman');
    expect(await app.database.query('student'), isEmpty);
  });
}
