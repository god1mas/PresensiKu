import 'package:presensiku/core/education/education_level.dart';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/dashboard/presentation/dashboard_screen.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/reports/data/report_delivery.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('grade export saves and shares the same XLSX workbook', (
    tester,
  ) async {
    await initializeDateFormatting('id_ID');
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    addTearDown(app.close);
    await tester.runAsync(() async {
      await ProfileRepository(app.database)
          .save(educationLevel: EducationLevel.smp, name: 'Guru');
      const now = '2026-11-14T00:00:00Z';
      final period = await app.database.insert('academic_period', {
        'year_label': '2026/2027',
        'semester': 'ganjil',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      final schoolClass = await app.database.insert('school_class', {
        'period_id': period,
        'name': 'XII-1',
        'created_at': now,
        'updated_at': now,
      });
      final subject = await app.database.insert('subject', {
        'name': 'Bahasa Indonesia',
        'created_at': now,
        'updated_at': now,
      });
      await app.database.insert('class_subject', {
        'class_id': schoolClass,
        'subject_id': subject,
        'created_at': now,
        'updated_at': now,
      });
      final student = await app.database.insert('student', {
        'class_id': schoolClass,
        'name': 'Ahmad',
        'attendance_number': 1,
        'created_at': now,
        'updated_at': now,
      });
      final repo = GradingRepository(app.database);
      final assessment = await repo.createAssessment(
        classId: schoolClass,
        subjectId: subject,
        periodId: period,
        categoryId: 1,
        date: '2026-11-14',
        title: 'Tugas',
      );
      await repo.saveGrades(assessment, {student: const GradeValue.graded(0)});
      await repo.saveWeights(
        classId: schoolClass,
        subjectId: subject,
        periodId: period,
        values: const {1: 100},
      );
    });
    String? savedName;
    Uint8List? savedBytes;
    String? sharedName;
    Uint8List? sharedBytes;
    final delivery = ReportDelivery(
      saveWorkbook: (name, bytes) async {
        savedName = name;
        savedBytes = bytes;
        return Uri.file('C:/tmp/$name');
      },
      shareWorkbook: (name, bytes) async {
        sharedName = name;
        sharedBytes = bytes;
        return true;
      },
    );
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
    await _settle(tester);
    GoRouter.of(tester.element(find.byType(DashboardScreen)))
        .go('/kelas/1/mapel/1/ekspor');
    await _settle(tester);
    expect(find.text('Ekspor Nilai Excel'), findsOneWidget);
    await tester.tap(find.text('Ekspor Nilai (.xlsx)'));
    await _settle(tester);
    expect(savedName, endsWith('.xlsx'));
    expect(savedBytes?.take(2), [0x50, 0x4b]);
    expect(find.text('Ekspor Berhasil'), findsOneWidget);
    await tester.tap(find.text('Bagikan'));
    await _settle(tester);
    expect(sharedName, savedName);
    expect(sharedBytes, savedBytes);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}
