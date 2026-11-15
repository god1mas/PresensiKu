import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('teacher creates period and class, searches, and views details', (
    tester,
  ) async {
    await initializeDateFormatting('id_ID');
    final db = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(
      () => ProfileRepository(db.database).save(name: 'Budi'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const PresensiKuApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kelas').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada kelas'), findsOneWidget);

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah periode akademik'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2026/2027');
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Tambah kelas').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'VII A');
    await tester.tap(find.byTooltip('Hijau'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pratinjau · Hijau'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('VII A'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'VIII');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kelas tidak ditemukan'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'VII');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('VII A').first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail Kelas'), findsOneWidget);
    expect(find.text('0 siswa aktif'), findsOneWidget);
    expect(find.text('Mata pelajaran'), findsOneWidget);
    expect(find.text('Daftar siswa'), findsNothing);

    await tester.tap(find.text('Kelola siswa'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar siswa'), findsWidgets);
    await tester.tap(find.text('+ Tambah siswa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ahmad Fauzi');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ahmad Fauzi'), findsOneWidget);
    expect(find.text('1 siswa'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Tidak ada');
    await tester.pumpAndSettle();
    expect(find.text('Siswa tidak ditemukan'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Ahmad');
    await tester.pumpAndSettle();
    expect(find.text('Ahmad Fauzi'), findsOneWidget);
    await tester.tap(find.byTooltip('Ubah Ahmad Fauzi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Ahmad Fauzi Baru',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmad Fauzi Baru'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 siswa aktif'), findsOneWidget);
    expect(find.text('Ahmad Fauzi Baru'), findsNothing);

    await tester.tap(find.text('Atur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kelola mata pelajaran'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Tambah mata pelajaran'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Matematika');
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Matematika'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atur'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematika'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Matematika'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    await tester.tap(find.text('Matematika'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Mata Pelajaran'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lepas Matematika dari kelas'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada mata pelajaran untuk kelas ini.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah kelas dan warna'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'VII B');
    await tester.tap(find.byTooltip('Ungu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('VII B'), findsOneWidget);
    final colorIndex = await tester.runAsync(() async {
      final period = (await ClassRepository(db.database).periods()).first;
      return (await ClassRepository(db.database).classes(period.id))
          .single
          .colorIndex;
    });
    expect(colorIndex, 2);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan kelas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kelas tidak ditemukan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
}
