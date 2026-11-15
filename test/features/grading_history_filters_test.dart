import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:presensiku/app/feature_selection_screens.dart';
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/academics/data/roster_repository.dart';
import 'package:presensiku/features/grading/data/grading_repository.dart';
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
    'grading history searches titles, filters periods, resets, and opens historical details at 320/393 px',
    (tester) async {
      final app = (await tester.runAsync(
        () => AppDatabase.open(
          factory: databaseFactoryFfiNoIsolate,
          path: inMemoryDatabasePath,
        ),
      ))!;
      final ids = (await tester.runAsync(() async {
        final classes = ClassRepository(app.database);
        final odd = await classes.createPeriod(
          yearLabel: '2026/2027',
          semester: 'ganjil',
        );
        final even = await classes.createPeriod(
          yearLabel: '2026/2027',
          semester: 'genap',
        );
        final classroom = await classes.createClass(
          periodId: odd,
          name: 'XII-1',
        );
        final roster = RosterRepository(app.database);
        final subject = await roster.addSubject('Matematika');
        await roster.assignSubject(classId: classroom, subjectId: subject);
        final grading = GradingRepository(app.database);
        await grading.createAssessment(
          classId: classroom,
          subjectId: subject,
          periodId: odd,
          categoryId: 1,
          date: '2026-11-16',
          title: 'Tugas Ganjil',
        );
        await grading.createAssessment(
          classId: classroom,
          subjectId: subject,
          periodId: even,
          categoryId: 1,
          date: '2027-02-16',
          title: 'Tugas Genap',
        );
        return (odd, even);
      }))!;
      final router = GoRouter(
        initialLocation: '/history',
        routes: [
          GoRoute(
            path: '/history',
            builder: (_, _) => const GradingDestinationScreen(history: true),
          ),
          GoRoute(
            path: '/kelas/:classId/mapel/:subjectId/penilaian/:assessmentId',
            builder: (_, state) => Scaffold(
              body: Text('DETAIL ${state.uri.queryParameters['periode']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 720));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(app)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      expect(find.text('Tugas Ganjil'), findsOneWidget);
      expect(find.text('Tugas Genap'), findsOneWidget);
      expect(find.text('Tanggal'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField).first, 'Genap');
      await settle(tester);
      expect(find.text('Tugas Ganjil'), findsNothing);
      expect(find.text('Tugas Genap'), findsOneWidget);
      expect(find.text('Reset filter'), findsOneWidget);
      await tester.tap(find.text('Reset filter'));
      await settle(tester);
      expect(find.text('Tugas Ganjil'), findsOneWidget);
      expect(find.text('Reset filter'), findsNothing);

      await tester.tap(find.text('Semua periode').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ganjil').last);
      await settle(tester);
      expect(find.text('Tugas Ganjil'), findsOneWidget);
      expect(find.text('Tugas Genap'), findsNothing);
      expect(find.textContaining('Periode: 2026/2027 ganjil'), findsOneWidget);
      await tester.tap(find.text('Reset filter'));
      await settle(tester);
      await tester.tap(find.text('Semua kelas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('XII-1').last);
      await settle(tester);
      expect(find.text('Kelas: XII-1'), findsOneWidget);
      await tester.tap(find.text('Semua mata pelajaran').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Matematika').last);
      await settle(tester);
      expect(find.text('Mata Pelajaran: Matematika'), findsOneWidget);
      expect(find.text('Tugas Ganjil'), findsOneWidget);
      expect(find.text('Tugas Genap'), findsOneWidget);
      await tester.tap(find.text('Reset filter'));
      await settle(tester);
      await tester.binding.setSurfaceSize(const Size(393, 720));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Tugas Ganjil'));
      await tester.tap(find.text('Tugas Ganjil'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL ${ids.$1}'), findsOneWidget);
      expect(ids.$2, isNot(ids.$1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(app.close);
    },
  );
}
