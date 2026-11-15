import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/core/education/education_level.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'legacy profile completion preserves class model and original enrollment',
    () async {
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(app.close);
      final profiles = ProfileRepository(app.database);
      await profiles.save(name: 'Nama Lama', schoolName: 'Institusi Lama');
      expect((await profiles.load())!.educationLevel, isNull);
      final classes = ClassRepository(app.database);
      final period = await classes.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final id = await classes.createClass(
        periodId: period,
        name: 'Kelas Lama',
      );
      final roster = RosterRepository(app.database);
      final student = await roster.addStudent(
        classId: id,
        name: 'Lama',
        attendanceNumber: 1,
        nis: '001',
      );
      await profiles.save(
        name: 'Nama Lama',
        schoolName: 'Institusi Lama',
        educationLevel: EducationLevel.university,
      );
      expect((await profiles.load())!.schoolName, 'Institusi Lama');
      expect(
        (await app.database.query('school_class')).single['education_level'],
        'legacy_school',
      );
      expect((await roster.students(id)).single.id, student);
      expect((await roster.students(id)).single.nis, '001');
    },
  );

  test('university NIM is required text and identity can span distinct enrollments', () async {
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
    final period = await classes.createPeriod(
      yearLabel: '2026/2027',
      semester: 'ganjil',
    );
    final a = await classes.createClass(periodId: period, name: 'A');
    final b = await classes.createClass(periodId: period, name: 'B');
    final roster = RosterRepository(app.database);
    await expectLater(
      roster.addStudent(classId: a, name: 'Ayu', attendanceNumber: 1),
      throwsFormatException,
    );
    await roster.addStudent(
      classId: a,
      name: 'Ayu',
      attendanceNumber: 1,
      nis: '000123',
    );
    await expectLater(
      roster.addStudent(
        classId: a,
        name: 'Ayu',
        attendanceNumber: 2,
        nis: '000123',
      ),
      throwsFormatException,
    );
    await expectLater(
      roster.addStudent(
        classId: b,
        name: 'Orang Lain',
        attendanceNumber: 1,
        nis: '000123',
      ),
      throwsFormatException,
    );
    await roster.addStudent(
      classId: b,
      name: 'Ayu',
      attendanceNumber: 1,
      nis: '000123',
    );
    final rows = await app.database.query('student');
    expect(rows.map((r) => r['identity_id']).toSet().length, 1);
    expect(rows.map((r) => r['id']).toSet().length, 2);
    expect((await roster.students(a, search: '000123')).single.nis, '000123');
    expect(await app.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
