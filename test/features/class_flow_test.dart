import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
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
    expect(find.text('0 siswa'), findsOneWidget);

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

    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah nama kelas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'VII B');
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('VII B'), findsOneWidget);

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
