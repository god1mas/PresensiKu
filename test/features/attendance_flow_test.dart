import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/attendance/presentation/attendance_screens.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('setup, mark, bulk confirm, and save attendance', (tester) async {
    await initializeDateFormatting('id_ID');
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(() async {
      await ProfileRepository(app.database).save(name: 'Budi');
      final classes = ClassRepository(app.database);
      final roster = RosterRepository(app.database);
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
      await roster.addStudent(
        classId: classId,
        name: 'Budi',
        attendanceNumber: 2,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(app)],
        child: const PresensiKuApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai Absensi'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mulai absensi'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('VII A').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematika').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Lanjutkan absensi'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 dari 2 siswa'), findsOneWidget);
    expect(find.text('Simpan absensi · 2 belum diisi'), findsOneWidget);

    await tester.tap(find.text('H Hadir').first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 dari 2 siswa'), findsOneWidget);
    await tester.tap(find.text('✓ Semua hadir'));
    await tester.pumpAndSettle();
    expect(find.text('Tandai semua hadir?'), findsOneWidget);
    await tester.tap(find.text('Ya, semua hadir'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 dari 2 siswa'), findsOneWidget);
    await tester.tap(find.text('Simpan absensi'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sip, absensi tersimpan!'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lihat rekap'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Lihat rekap'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail absensi'), findsOneWidget);
    await tester.tap(find.text('Edit absensi'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ahmad'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Hadir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Sakit'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sakit'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });

  testWidgets('forty-student roster scrolls to the last student', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    final sessionId = (await tester.runAsync(() async {
      final classes = ClassRepository(app.database);
      final roster = RosterRepository(app.database);
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
      for (var number = 1; number <= 40; number++) {
        await roster.addStudent(
          classId: classId,
          name: 'Siswa $number',
          attendanceNumber: number,
        );
      }
      final result = await AttendanceRepository(app.database).prepare(
        classId: classId,
        subjectId: subjectId,
        date: '2026-11-11',
        meetingNumber: 1,
      );
      return result.sessionId;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(app)],
        child: MaterialApp(home: AttendanceRecordScreen(id: sessionId)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 dari 40 siswa'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Siswa 40'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Siswa 40'), findsOneWidget);
    expect(find.text('Simpan absensi · 40 belum diisi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });
}
