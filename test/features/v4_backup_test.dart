import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'V2 backup round trip preserves grade states, weights and attendance',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presensiku-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/source.db',
      );
      addTearDown(source.close);
      final ids = await _seed(source);
      final repo = GradingRepository(source.database);
      final assessment = await repo.createAssessment(
        classId: ids.$1,
        subjectId: ids.$2,
        periodId: ids.$3,
        categoryId: 1,
        date: '2026-11-14',
        title: 'Tugas',
      );
      await repo.saveGrades(assessment, {
        ids.$4: const GradeValue.graded(0),
        ids.$5: const GradeValue.exempt(),
      });
      await repo.saveWeights(
        classId: ids.$1,
        subjectId: ids.$2,
        periodId: ids.$3,
        values: const {1: 100},
      );
      final bytes = await BackupRepository(source.database).create();
      final target = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/target.db',
      );
      addTearDown(target.close);
      final backup = BackupRepository(target.database);
      expect(backup.inspect(bytes).count('assessment_grade'), 2);
      await backup.restore(bytes);
      for (final table in BackupRepository.tables) {
        expect(
          await target.database.query(table),
          await source.database.query(table),
          reason: table,
        );
      }
      expect(
        (await target.database.query('attendance_record')).single['status'],
        'H',
      );
      expect(
        await target.database.rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );

  test(
    'authentic V1 envelope restores attendance and clears V2 grading',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presensiku-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/source.db',
      );
      addTearDown(source.close);
      await _seed(source);
      final envelope = jsonDecode(
        utf8.decode(await BackupRepository(source.database).create()),
      ) as Map<String, dynamic>;
      final allData = envelope['data'] as Map<String, dynamic>;
      final legacyData = <String, dynamic>{
        for (final table in BackupRepository.legacyTables)
          table: allData[table],
      };
      envelope['schemaVersion'] = 1;
      envelope['data'] = legacyData;
      envelope['sha256'] = sha256
          .convert(utf8.encode(jsonEncode(legacyData)))
          .toString();
      final legacyBytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

      final target = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/target.db',
      );
      addTearDown(target.close);
      final ids = await _seed(target);
      final repo = GradingRepository(target.database);
      await repo.createAssessment(
        classId: ids.$1,
        subjectId: ids.$2,
        periodId: ids.$3,
        categoryId: 1,
        date: '2026-11-14',
        title: 'Temporary',
      );
      final backup = BackupRepository(target.database);
      expect(backup.inspect(legacyBytes).count('assessment'), 0);
      await backup.restore(legacyBytes);
      expect(await target.database.query('assessment'), isEmpty);
      expect(await target.database.query('assessment_grade'), isEmpty);
      expect((await target.database.query('assessment_category')).length, 5);
      expect(
        (await target.database.query('attendance_record')).single['status'],
        'H',
      );
      expect(
        await target.database.rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );

  test(
    'invalid V2 relations roll back grading and attendance replacement',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      final ids = await _seed(app);
      final repo = GradingRepository(app.database);
      await repo.createAssessment(
        classId: ids.$1,
        subjectId: ids.$2,
        periodId: ids.$3,
        categoryId: 1,
        date: '2026-11-14',
        title: 'Keep',
      );
      final envelope = jsonDecode(
        utf8.decode(await BackupRepository(app.database).create()),
      ) as Map<String, dynamic>;
      final data = envelope['data'] as Map<String, dynamic>;
      final assessmentRows = data['assessment'] as List;
      assessmentRows.first['class_id'] = 999;
      envelope['sha256'] = sha256
          .convert(utf8.encode(jsonEncode(data)))
          .toString();
      final invalid = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
      await expectLater(
        BackupRepository(app.database).restore(invalid),
        throwsA(anything),
      );
      expect((await app.database.query('assessment')).single['title'], 'Keep');
      expect(
        (await app.database.query('attendance_record')).single['status'],
        'H',
      );
    },
  );
}

Future<(int, int, int, int, int)> _seed(AppDatabase app) async {
  final db = app.database;
  const now = '2026-11-14T00:00:00Z';
  await db.insert('teacher_profile', {
    'id': 1,
    'name': 'Guru',
    'created_at': now,
    'updated_at': now,
  });
  final period = await db.insert('academic_period', {
    'year_label': '2026/2027',
    'semester': 'ganjil',
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  });
  final schoolClass = await db.insert('school_class', {
    'period_id': period,
    'name': 'XII-1',
    'created_at': now,
    'updated_at': now,
  });
  final subject = await db.insert('subject', {
    'name': 'Bahasa Indonesia',
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('class_subject', {
    'class_id': schoolClass,
    'subject_id': subject,
    'created_at': now,
    'updated_at': now,
  });
  final first = await db.insert('student', {
    'class_id': schoolClass,
    'name': 'Ahmad',
    'attendance_number': 1,
    'created_at': now,
    'updated_at': now,
  });
  final second = await db.insert('student', {
    'class_id': schoolClass,
    'name': 'Siti',
    'attendance_number': 2,
    'created_at': now,
    'updated_at': now,
  });
  final session = await db.insert('attendance_session', {
    'class_id': schoolClass,
    'subject_id': subject,
    'period_id': period,
    'date': '2026-11-14',
    'meeting_number': 1,
    'state': 'completed',
    'class_name_snapshot': 'XII-1',
    'subject_name_snapshot': 'Bahasa Indonesia',
    'period_snapshot': '2026/2027 Ganjil',
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('attendance_record', {
    'session_id': session,
    'student_id': first,
    'status': 'H',
    'student_name_snapshot': 'Ahmad',
    'attendance_number_snapshot': 1,
    'created_at': now,
    'updated_at': now,
  });
  return (schoolClass, subject, period, first, second);
}
