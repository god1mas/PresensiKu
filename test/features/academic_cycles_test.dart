import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/core/education/education_level.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/data/grade_report_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:presensiku/features/dashboard/data/dashboard_repository.dart';
import 'package:presensiku/features/reports/data/report_repository.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/legacy_database.dart';

void main() {
  sqfliteFfiInit();
  test('school cycles retain 40-student roster and isolate meetings, grades, weights, years; restart and backup', () async {
    final directory = await Directory.systemTemp.createTemp('kelasku-cycles-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/school.db';
    var app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    await ProfileRepository(app.database)
        .save(name: 'Guru', educationLevel: EducationLevel.sma);
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
    final next = await classes.createPeriod(
      yearLabel: '2027/2028',
      semester: 'ganjil',
    );
    final c = await classes.createClass(
      periodId: odd,
      name: 'XII-1',
      colorIndex: 7,
    );
    final subject = await roster.addSubject('Matematika');
    await roster.assignSubject(classId: c, subjectId: subject);
    final students = <int>[];
    for (var n = 1; n <= 40; n++) {
      students.add(
        await roster.addStudent(
          classId: c,
          name: 'Siswa $n',
          attendanceNumber: n,
          nis: '00$n',
        ),
      );
    }
    final attendance = AttendanceRepository(app.database);
    final oddSession = await attendance.prepare(
      classId: c,
      subjectId: subject,
      date: '2026-11-16',
      meetingNumber: 1,
    );
    await attendance.markAllPresent(oddSession.sessionId);
    await attendance.complete(oddSession.sessionId);
    final grading = GradingRepository(app.database);
    final assessment = await grading.createAssessment(
      classId: c,
      subjectId: subject,
      periodId: odd,
      categoryId: 1,
      date: '2026-11-16',
      title: 'Ganjil',
    );
    await grading.saveGrades(assessment, {
      for (final id in students) id: const GradeValue.graded(80),
    });
    await grading.saveWeights(
      classId: c,
      subjectId: subject,
      periodId: odd,
      values: {1: 100},
    );
    await classes.activatePeriod(even);
    expect((await classes.classes(even)).single.id, c);
    expect((await classes.classes(even)).single.colorIndex, 7);
    expect((await roster.students(c)).length, 40);
    expect((await roster.subjectsForClass(c)).single.id, subject);
    final summary = await DashboardRepository(app.database).load();
    expect(summary.classCount, 1);
    expect(summary.studentCount, 40);
    expect(summary.sessionCount, 0);
    expect(summary.recentSessions, isEmpty);
    expect(
      await grading.assessments(classId: c, subjectId: subject, periodId: even),
      isEmpty,
    );
    expect(
      await grading.weights(classId: c, subjectId: subject, periodId: even),
      isEmpty,
    );
    final report = await GradeReportRepository(app.database)
        .load(classId: c, subjectId: subject, periodId: even);
    expect(report.assessments, isEmpty);
    expect(report.grades, isEmpty);
    final evenSession = await attendance.prepare(
      classId: c,
      subjectId: subject,
      date: '2026-11-16',
      meetingNumber: 1,
    );
    expect(evenSession.sessionId, isNot(oddSession.sessionId));
    expect(evenSession.existed, false);
    expect(
      (await ReportRepository(app.database).load(ReportFilter(periodId: even)))
          .details,
      isEmpty,
    );
    expect(
      (await ReportRepository(app.database).load(ReportFilter(periodId: odd)))
          .details
          .length,
      40,
    );
    await expectLater(
      classes.createClass(periodId: even, name: ' xii-1 '),
      throwsFormatException,
    );
    for (var n = 0; n < 3; n++) {
      await classes.activatePeriod(odd);
      expect((await DashboardRepository(app.database).load()).sessionCount, 1);
      expect(
        (await grading.assessments(
          classId: c,
          subjectId: subject,
          periodId: odd,
        )).single['id'],
        assessment,
      );
      expect((await grading.grades(assessment)).length, 40);
      await classes.activatePeriod(even);
    }
    await expectLater(classes.activatePeriod(-1), throwsStateError);
    expect((await classes.periods()).where((p) => p.isActive).single.id, even);
    await classes.activatePeriod(next);
    expect(await classes.classes(next), isEmpty);
    expect((await DashboardRepository(app.database).load()).classCount, 0);
    await classes.activatePeriod(odd);
    final backup = await BackupRepository(app.database).create();
    await app.close();
    app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    expect((await ClassRepository(app.database).classes(even)).single.id, c);
    expect((await app.database.query('attendance_session')).length, 2);
    await BackupRepository(app.database).restore(backup);
    expect((await app.database.query('attendance_session')).length, 2);
    expect((await app.database.query('assessment_grade')).length, 40);
    expect(await app.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await app.close();
  });

  test('university semesters isolate teaching enrollment and share stable NIM identity only explicitly', () async {
    final app = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(app.close);
    await ProfileRepository(app.database).save(
      name: 'Dosen',
      schoolName: 'Kampus',
      educationLevel: EducationLevel.university,
    );
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
    final a = await classes.createClass(periodId: odd, name: 'A');
    final student = await roster.addStudent(
      classId: a,
      name: 'Ayu',
      attendanceNumber: 1,
      nis: '000123',
    );
    final subject = await roster.addSubject('Basis Data');
    await roster.assignSubject(classId: a, subjectId: subject);
    await classes.activatePeriod(even);
    expect(await classes.classes(even), isEmpty);
    await expectLater(
      AttendanceRepository(app.database).prepare(
        classId: a,
        subjectId: subject,
        date: '2027-01-01',
        meetingNumber: 1,
      ),
      throwsStateError,
    );
    final b = await classes.createClass(periodId: even, name: 'A');
    expect(await roster.students(b), isEmpty);
    expect(await roster.subjectsForClass(b), isEmpty);
    final enrollment = await roster.addStudent(
      classId: b,
      name: 'Ayu',
      attendanceNumber: 1,
      nis: '000123',
    );
    expect(enrollment, isNot(student));
    expect(
      (await app.database.query('student'))
          .map((r) => r['identity_id'])
          .toSet()
          .length,
      1,
    );
    await classes.activatePeriod(odd);
    expect((await classes.classes(odd)).single.id, a);
  });

  test('populated V3 migration and V3 backup preserve IDs, ambiguous names, grades and archived data', () async {
    final directory = await Directory.systemTemp.createTemp('kelasku-legacy3-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/legacy.db';
    final legacy = await LegacyDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final db = legacy.database;
    const now = '2026-11-16';
    await db.insert('teacher_profile', {
      'id': 1,
      'name': 'Guru Lama',
      'school_name': 'Sekolah Lama',
      'created_at': now,
      'updated_at': now,
    });
    for (final (id, semester) in [(1, 'ganjil'), (2, 'genap')]) {
      await db.insert('academic_period', {
        'id': id,
        'year_label': '2026/2027',
        'semester': semester,
        'is_active': id == 1 ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('school_class', {
        'id': id,
        'period_id': id,
        'name': 'XII-1',
        'color_index': id,
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.insert('student', {
      'id': 9,
      'class_id': 1,
      'name': 'Lama',
      'attendance_number': 1,
      'nis': '0009',
      'archived_at': now,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('subject', {
      'id': 8,
      'name': 'Matematika',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('attendance_session', {
      'id': 7,
      'class_id': 1,
      'subject_id': 8,
      'period_id': 1,
      'date': now,
      'meeting_number': 1,
      'state': 'completed',
      'class_name_snapshot': 'XII-1',
      'subject_name_snapshot': 'Matematika',
      'period_snapshot': 'Ganjil',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('attendance_record', {
      'id': 6,
      'session_id': 7,
      'student_id': 9,
      'status': 'H',
      'student_name_snapshot': 'Lama',
      'attendance_number_snapshot': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('assessment', {
      'id': 5,
      'class_id': 1,
      'subject_id': 8,
      'period_id': 1,
      'category_id': 1,
      'date': now,
      'title': 'Lama',
      'max_score': 100,
      'class_name_snapshot': 'XII-1',
      'subject_name_snapshot': 'Matematika',
      'period_snapshot': 'Ganjil',
      'category_name_snapshot': 'Tugas',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('assessment_grade', {
      'id': 4,
      'assessment_id': 5,
      'student_id': 9,
      'state': 'GRADED',
      'score': 0,
      'student_name_snapshot': 'Lama',
      'attendance_number_snapshot': 1,
      'created_at': now,
      'updated_at': now,
    });
    final data = {
      for (final table in BackupRepository.version3Tables)
        table: await db.query(table),
    };
    final backup = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': BackupRepository.format,
          'schemaVersion': 3,
          'data': data,
          'sha256': sha256.convert(utf8.encode(jsonEncode(data))).toString(),
        }),
      ),
    );
    await legacy.close();
    final app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(app.close);
    Future<void> verify() async {
      expect((await app.database.query('attendance_session')).single['id'], 7);
      expect(
        (await app.database.query('attendance_record'))
            .single['identifier_snapshot'],
        '0009',
      );
      expect((await app.database.query('assessment_grade')).single['score'], 0);
      expect((await app.database.query('student')).single['archived_at'], now);
      expect(
        (await ClassRepository(app.database).classes(2))
            .map((c) => c.id)
            .toSet(),
        {1, 2},
      );
      expect(
        (await ProfileRepository(app.database).load())!.educationLevel,
        isNull,
      );
      expect(await app.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    }

    await verify();
    await BackupRepository(app.database).restore(backup);
    await verify();
  });
}
