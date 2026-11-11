import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/settings/data/backup_delivery.dart';
import 'package:presensiku/features/settings/data/backup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('settings save and restore require confirmation', (tester) async {
    await initializeDateFormatting('id_ID');
    final source = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(() async {
      await ProfileRepository(source.database).save(name: 'Cadangan');
    });
    final backupBytes = (await tester.runAsync(
      () => BackupRepository(source.database).create(),
    ))!;
    await tester.runAsync(source.close);

    final app = (await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(() async {
      await ProfileRepository(app.database).save(name: 'Sekarang');
    });
    Uint8List? saved;
    final delivery = BackupDelivery(
      saveBackup: (filename, bytes) async {
        expect(filename, endsWith('.pkbackup'));
        saved = bytes;
        return true;
      },
      pickBackup: () async => backupBytes,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(app),
          backupDeliveryProvider.overrideWithValue(delivery),
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
    await tester.scrollUntilVisible(find.text('Cadangkan data'), 250);
    await tester.tap(find.text('Cadangkan data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat file cadangan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(
      BackupRepository(app.database).inspect(saved!).teacherName,
      'Sekarang',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pulihkan data'), 250);
    await tester.tap(find.text('Pulihkan data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih & pulihkan data'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pulihkan cadangan?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => ProfileRepository(app.database).load()))!
          .name,
      'Sekarang',
    );

    await tester.tap(find.text('Pilih & pulihkan data'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulihkan data').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => ProfileRepository(app.database).load()))!
          .name,
      'Cadangan',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });
}
