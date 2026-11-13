import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/dashboard/presentation/dashboard_screen.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('subject opens V4 assessment empty state and add form', (
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
      await ProfileRepository(app.database).save(name: 'Guru');
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
      await app.database.insert('student', {
        'class_id': schoolClass,
        'name': 'Ahmad Fauzi',
        'attendance_number': 1,
        'created_at': now,
        'updated_at': now,
      });
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(app)],
        child: const PresensiKuApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _settle(tester);
    GoRouter.of(tester.element(find.byType(DashboardScreen)))
        .go('/kelas/1/mapel/1');
    await _settle(tester);
    expect(find.text('Detail Mata Pelajaran'), findsOneWidget);
    expect(find.text('Presensi'), findsOneWidget);
    expect(find.text('Penilaian'), findsOneWidget);
    await tester.tap(find.text('Penilaian'));
    await _settle(tester);
    expect(find.text('Belum ada penilaian'), findsOneWidget);
    await tester.tap(find.text('+ Tambah Penilaian'));
    await _settle(tester);
    expect(find.text('Tambah Penilaian'), findsOneWidget);
    expect(find.text('Tema / Judul Tugas'), findsOneWidget);
    expect(find.text('Skor Maksimal'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tema / Judul Tugas'),
      'Tugas 1',
    );
    await tester.tap(find.text('Simpan & Isi Nilai'));
    await _settle(tester);
    expect(find.text('Input Nilai Siswa'), findsOneWidget);
    expect(find.text('Belum dinilai ≠ 0'), findsOneWidget);
    expect(find.text('0 dari 1 siswa dinilai'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.tap(find.text('Simpan Nilai'));
    await _settle(tester);
    expect(find.text('Detail Penilaian'), findsOneWidget);
    expect(find.text('Ahmad Fauzi'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali').last);
    await _settle(tester);
    await tester.tap(find.text('Atur Bobot'));
    await _settle(tester);
    expect(find.text('Atur Bobot Penilaian'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.pumpAndSettle();
    expect(find.text('Simpan Bobot (90%)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '30');
    await tester.pumpAndSettle();
    expect(find.text('Simpan Bobot'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}
