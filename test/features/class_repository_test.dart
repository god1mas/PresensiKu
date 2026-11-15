import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presensiku/core/database/app_database.dart';
import 'package:presensiku/features/academics/data/class_repository.dart';
import 'package:presensiku/features/dashboard/data/dashboard_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('periods isolate classes and active period can switch', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final repository = ClassRepository(db.database);
    final first = await repository.createPeriod(
      yearLabel: '2026/2027',
      semester: 'ganjil',
    );
    final second = await repository.createPeriod(
      yearLabel: '2026/2027',
      semester: 'genap',
    );
    expect(
      (await repository.periods()).singleWhere((p) => p.id == first).isActive,
      isTrue,
    );
    await repository.createClass(periodId: first, name: 'VII A');
    await repository.createClass(periodId: second, name: 'VII B');
    expect((await repository.classes(first)).single.colorIndex, 0);
    expect((await repository.classes(second)).single.colorIndex, 1);
    expect((await repository.classes(first)).single.name, 'VII A');
    expect((await repository.classes(second)).single.name, 'VII B');
    expect((await DashboardRepository(db.database).load()).classCount, 1);
    expect(
      (await DashboardRepository(db.database).load()).classes.single.name,
      'VII A',
    );
    await repository.activatePeriod(second);
    expect(
      (await repository.periods()).singleWhere((p) => p.id == second).isActive,
      isTrue,
    );
    expect(
      (await repository.periods()).singleWhere((p) => p.id == first).isActive,
      isFalse,
    );
    expect((await repository.classes(first)).single.name, 'VII A');
    expect(
      (await DashboardRepository(db.database).load()).classes.single.name,
      'VII B',
    );
  });

  test(
    'class search, rename, duplicate rejection and archive persist',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presensiku_classes_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'app.db');
      final firstDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final first = ClassRepository(firstDb.database);
      final period = await first.createPeriod(
        yearLabel: '2026/2027',
        semester: 'ganjil',
      );
      final id = await first.createClass(periodId: period, name: ' VII A ');
      await first.updateClass(id, 'VII A', 5);
      expect((await first.classById(id))!.colorIndex, 5);
      expect((await first.classes(period, search: 'vii')).single.id, id);
      await first.renameClass(id, 'VII B');
      expect(
        (await first.classes(period, search: 'vii b')).single.name,
        'VII B',
      );
      await expectLater(
        first.createClass(periodId: period, name: ' vii b '),
        throwsA(isA<DatabaseException>()),
      );
      await firstDb.close();

      final secondDb = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      addTearDown(secondDb.close);
      final second = ClassRepository(secondDb.database);
      expect((await second.classes(period)).single.name, 'VII B');
      expect((await second.classes(period)).single.colorIndex, 5);
      await second.archiveClass(id);
      expect(await second.classes(period), isEmpty);
      await second.createClass(periodId: period, name: 'VII B');
      expect((await second.classes(period)).single.name, 'VII B');
    },
  );
}
