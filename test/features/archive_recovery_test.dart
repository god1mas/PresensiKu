import 'package:presensiku/core/education/education_level.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'subject restore keeps its ID and only reactivates current class links',
    () async {
      final directory = await Directory.systemTemp.createTemp('kelas_archive_');
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'app.db');
      var app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      await ProfileRepository(app.database)
          .save(educationLevel: EducationLevel.smp, name: 'Guru');
      final classes = ClassRepository(app.database);
      final period = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final first = await classes.createClass(periodId: period, name: 'VII A');
      final second = await classes.createClass(periodId: period, name: 'VII B');
      var roster = RosterRepository(app.database);
      final subject = await roster.addSubject('Matematika');
      await roster.assignSubject(classId: first, subjectId: subject);
      await roster.assignSubject(classId: second, subjectId: subject);
      await roster.addStudent(classId: first, name: 'Ayu', attendanceNumber: 1);
      final attendance = AttendanceRepository(app.database);
      final session = await attendance.prepare(
        classId: first,
        subjectId: subject,
        date: '2026-11-16',
        meetingNumber: 1,
      );
      final record = (await attendance.load(session.sessionId)).records.single;
      await attendance.mark(
        sessionId: session.sessionId,
        recordId: record.id,
        status: 'H',
      );
      await attendance.complete(session.sessionId);
      await roster.unassignSubject(classId: second, subjectId: subject);
      await roster.archiveSubject(subject);
      expect(
        (await roster.subjects(includeArchived: true)).single.archivedAt,
        isNotNull,
      );
      final duplicate = await roster.addSubject('Matematika');
      await expectLater(roster.restoreSubject(subject), throwsFormatException);
      await roster.renameSubject(duplicate, 'Matematika Baru');
      await app.close();
      app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      addTearDown(app.close);
      roster = RosterRepository(app.database);
      await roster.restoreSubject(subject);
      expect((await roster.subjects()).any((row) => row.id == subject), isTrue);
      expect((await roster.subjectsForClass(first)).single.id, subject);
      expect(await roster.subjectsForClass(second), isEmpty);
      expect(
        (await app.database.query(
          'attendance_record',
          where: 'session_id = ?',
          whereArgs: [session.sessionId],
        )).single['status'],
        'H',
      );
      final backup = await BackupRepository(app.database).create();
      final restored = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(restored.close);
      await BackupRepository(restored.database).restore(backup);
      expect(
        (await RosterRepository(restored.database).subjectsForClass(first))
            .single
            .id,
        subject,
      );
    },
  );

  test(
    'default and custom category restore preserve IDs, weights and references',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      final repo = GradingRepository(app.database);
      final classes = ClassRepository(app.database);
      final period = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final classId = await classes.createClass(
        periodId: period,
        name: 'VII A',
      );
      final roster = RosterRepository(app.database);
      final subjectId = await roster.addSubject('Matematika');
      await roster.assignSubject(classId: classId, subjectId: subjectId);
      final studentId = await roster.addStudent(
        classId: classId,
        name: 'Ayu',
        attendanceNumber: 1,
      );
      final categories = await repo.categories();
      final sikap =
          categories.firstWhere((row) => row['name'] == 'Sikap')['id'] as int;
      final custom = await repo.createCategory('Praktik');
      final assessment = await repo.createAssessment(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        categoryId: custom,
        date: '2026-11-16',
        title: 'Praktik 1',
      );
      await repo.saveGrades(assessment, {
        studentId: const GradeValue.graded(87),
      });
      await repo.saveWeights(
        classId: classId,
        subjectId: subjectId,
        periodId: period,
        values: {custom: 100},
      );
      await repo.archiveCategory(sikap);
      await repo.archiveCategory(custom);
      await expectLater(repo.createCategory('Sikap'), throwsFormatException);
      await expectLater(repo.createCategory('Praktik'), throwsFormatException);
      expect(
        (await repo.categories(includeArchived: true))
            .where((row) => row['archived_at'] != null)
            .length,
        2,
      );
      await repo.restoreCategory(sikap);
      await repo.restoreCategory(custom);
      expect(
        (await repo.categories()).map((row) => row['id']),
        containsAll([sikap, custom]),
      );
      expect((await repo.assessment(assessment))['category_id'], custom);
      expect((await repo.grades(assessment)).single['score'], 87);
      expect(
        await repo.weights(
          classId: classId,
          subjectId: subjectId,
          periodId: period,
        ),
        {custom: 100},
      );
      expect(
        (await repo.resultForStudent(
          classId: classId,
          subjectId: subjectId,
          periodId: period,
          studentId: studentId,
        ))?.finalGrade,
        87,
      );
      await repo.archiveCategory(custom);
      await app.database.insert('assessment_category', {
        'name': 'Praktik',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await expectLater(repo.restoreCategory(custom), throwsFormatException);
    },
  );
}
