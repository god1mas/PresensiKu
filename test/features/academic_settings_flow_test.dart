import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/onboarding/presentation/onboarding_screens.dart';
import 'package:presensiku/features/settings/presentation/period_settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();
  testWidgets(
    'legacy completion retains name and institution without reentry',
    (tester) async {
      final app = (await tester.runAsync(
        () => AppDatabase.open(
          factory: databaseFactoryFfiNoIsolate,
          path: inMemoryDatabasePath,
        ),
      ))!;
      await tester.runAsync(
        () =>
            ProfileRepository(app.database)
                .save(name: 'Nama Lama', schoolName: 'Kampus Lama'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(app)],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await settle(tester);
      expect(find.text('Lengkapi profil'), findsOneWidget);
      expect(find.text('Nama Lama'), findsOneWidget);
      expect(find.text('Kampus Lama'), findsOneWidget);
      await tester.tap(find.textContaining('Mulai pakai'));
      await settle(tester);
      expect(find.text('Pilih jenjang pendidikan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(app.close);
    },
  );

  testWidgets(
    'temporary period selection requires confirmation and activation refreshes exactly one active period',
    (tester) async {
      final app = (await tester.runAsync(
        () => AppDatabase.open(
          factory: databaseFactoryFfiNoIsolate,
          path: inMemoryDatabasePath,
        ),
      ))!;
      final classes = ClassRepository(app.database);
      await tester.runAsync(() async {
        await classes.createPeriod(yearLabel: '2026/2027', semester: 'ganjil');
        await classes.createPeriod(yearLabel: '2026/2027', semester: 'genap');
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(app)],
          child: const MaterialApp(home: PeriodSettingsScreen()),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('2026/2027 Genap'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('2026/2027 Genap').last);
      await settle(tester);
      expect(find.textContaining('belum aktif'), findsOneWidget);
      expect(
        (await tester.runAsync(classes.periods))!
            .where((p) => p.isActive)
            .single
            .semester,
        'ganjil',
      );
      await tester.tap(find.text('Jadikan Aktif').last);
      await settle(tester);
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(
        (await tester.runAsync(classes.periods))!
            .where((p) => p.isActive)
            .single
            .semester,
        'ganjil',
      );
      await tester.tap(find.text('Jadikan Aktif').last);
      await settle(tester);
      await tester.tap(find.text('Jadikan Aktif').last);
      await settle(tester);
      expect(
        (await tester.runAsync(classes.periods))!
            .where((p) => p.isActive)
            .single
            .semester,
        'genap',
      );
      expect(find.textContaining('belum aktif'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(app.close);
    },
  );
}
