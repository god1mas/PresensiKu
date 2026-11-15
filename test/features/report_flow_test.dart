import 'package:presensiku/core/education/education_level.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/attendance/data/attendance_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/reports/data/report_delivery.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('settings opens report and filtered Excel export screen', (
    tester,
  ) async {
    Uint8List? savedBytes;
    Uint8List? sharedBytes;
    final delivery = ReportDelivery(
      saveWorkbook: (filename, bytes) async {
        expect(filename, startsWith('KelasKu_'));
        expect(filename, endsWith('.xlsx'));
        savedBytes = bytes;
        return Uri.parse('content://presensiku/report.xlsx');
      },
      shareWorkbook: (filename, bytes) async {
        expect(filename, startsWith('KelasKu_'));
        expect(filename, endsWith('.xlsx'));
        sharedBytes = bytes;
        return true;
      },
    );
    await initializeDateFormatting('id_ID');
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(() async {
      await ProfileRepository(app.database)
          .save(educationLevel: EducationLevel.smp, name: 'Budi');
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
      final attendance = AttendanceRepository(app.database);
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
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(app),
          reportDeliveryProvider.overrideWithValue(delivery),
        ],
        child: const PresensiKuApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rekap dan laporan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Laporan'), findsOneWidget);
    expect(find.text('Rekap Penilaian'), findsOneWidget);
    await tester.tap(find.text('Rekap Presensi'));
    await tester.pumpAndSettle();
    expect(find.text('Rekap absensi'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(find.text('Ahmad'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('VII A').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ekspor Excel'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ekspor laporan'), findsOneWidget);
    expect(find.text('Simpan Excel'), findsOneWidget);
    await tester.tap(find.text('Simpan Excel'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ekspor berhasil'), findsOneWidget);
    expect(savedBytes?.take(2), [0x50, 0x4b]);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagikan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ekspor berhasil'), findsOneWidget);
    expect(sharedBytes?.take(2), [0x50, 0x4b]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });
}
