import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('first launch saves teacher and next launch skips onboarding', (
    tester,
  ) async {
    await initializeDateFormatting('id_ID');
    final appDatabase = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;

    Widget app() => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
      child: const PresensiKuApp(),
    );

    await tester.pumpWidget(app());
    expect(find.text('KelasKu'), findsOneWidget);
    expect(find.text('by god1mas'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kenalan dulu, yuk!'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Budi Santoso');
    await tester.tap(find.textContaining('Mulai pakai KelasKu'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Halo, Budi Santoso!'), findsOneWidget);
    expect(find.text('Mulai Kelas'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Halo, Budi Santoso!'), findsOneWidget);
    expect(find.text('Kenalan dulu, yuk!'), findsNothing);

    await tester.tap(find.text('Kelas').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada kelas'), findsOneWidget);
    await tester.tap(find.text('Riwayat').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Riwayat kosong'), findsOneWidget);

    await tester.tap(find.text('Pengaturan').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(appDatabase.close);
  });
}
