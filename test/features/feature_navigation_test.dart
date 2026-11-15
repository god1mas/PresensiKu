import 'package:presensiku/core/education/education_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/history/presentation/history_screens.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('history types open and Back returns to selection', (
    tester,
  ) async {
    await initializeDateFormatting('id_ID');
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(
      () =>
          ProfileRepository(app.database)
              .save(educationLevel: EducationLevel.smp, name: 'Guru'),
    );
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
    await tester.tap(find.text('Riwayat').last);
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Riwayat'), findsOneWidget);
    await tester.tap(find.text('Riwayat Presensi'));
    await tester.pumpAndSettle();
    expect(find.text('Jejak kehadiran'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Riwayat'), findsOneWidget);
    await tester.tap(find.text('Riwayat Penilaian'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Riwayat Penilaian'), findsWidgets);
    expect(find.text('Tanggal'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Riwayat'), findsOneWidget);
    await tester.tap(find.text('Pengaturan').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rekap dan laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Laporan'), findsOneWidget);
    await tester.tap(find.text('Rekap Penilaian'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Pilih periode, kelas dan mata pelajaran untuk melihat rekap nilai.',
      ),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Laporan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });

  testWidgets('attendance history filters fit narrow Android widths', (
    tester,
  ) async {
    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 393.0]) {
      await tester.binding.setSurfaceSize(Size(width, 720));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(app)],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tanggal'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final date = tester.getRect(find.text('Tanggal'));
      expect(date.right, lessThanOrEqualTo(width));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });
}
