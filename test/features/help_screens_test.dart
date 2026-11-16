import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:presensiku/app/app.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/core/education/academic_scope.dart';
import 'package:presensiku/core/education/education_level.dart';
import 'package:presensiku/features/onboarding/data/profile_repository.dart';
import 'package:presensiku/features/settings/presentation/help_screens.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  for (final level in [EducationLevel.smp, EducationLevel.university]) {
    testWidgets(
      'offline guide expands with ${level.label} terms at narrow widths',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(320, 720));
        await tester.pumpWidget(
          MaterialApp(
            home: EducationScope(
              terms: EducationTerms(level),
              child: const UserGuideScreen(),
            ),
          ),
        );
        expect(find.byType(ExpansionTile), findsWidgets);
        expect(find.text('Memulai KelasKu'), findsOneWidget);
        await tester.tap(find.text('Memulai KelasKu'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(level.isUniversity ? 'nama dosen' : 'nama guru'),
          findsOneWidget,
        );
        expect(find.textContaining('tanpa internet'), findsWidgets);
        await tester.tap(find.text('Memulai KelasKu'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(level.isUniversity ? 'nama dosen' : 'nama guru'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.binding.setSurfaceSize(const Size(393, 720));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('About reads installed version and opens third-party licenses', (
    tester,
  ) async {
    const channel = MethodChannel('com.presensiku.presensiku/app_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'version' ? '1.4.2 (7)' : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: AboutKelasKuScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1.4.2 (7)'), findsOneWidget);
    expect(find.text('Dimas Abdus Syukur'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hak cipta'), 200);
    expect(find.textContaining('© 2026 Dimas Abdus Syukur'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lisensi Pihak Ketiga'), 200);
    await tester.tap(find.text('Lisensi Pihak Ketiga'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tentang KelasKu'), findsOneWidget);
  });

  testWidgets('settings opens guide and About and Back returns to settings', (
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
    await tester.tap(find.text('Pengaturan').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Panduan Penggunaan'), 200);
    await tester.tap(find.text('Panduan Penggunaan'));
    await tester.pumpAndSettle();
    expect(find.text('Memulai KelasKu'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tentang KelasKu'), 200);
    await tester.tap(find.text('Tentang KelasKu'));
    await tester.pumpAndSettle();
    expect(find.text('by god1mas'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bantuan & informasi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.close);
  });
}
