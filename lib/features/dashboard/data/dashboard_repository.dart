import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class ClassShortcut {
  const ClassShortcut({
    required this.id,
    required this.name,
    required this.studentCount,
    required this.colorIndex,
  });

  final int id;
  final String name;
  final int studentCount;
  final int colorIndex;
}

class RecentSession {
  const RecentSession({
    required this.id,
    required this.className,
    required this.subjectName,
    required this.date,
  });

  final int id;
  final String className;
  final String subjectName;
  final String date;
}

class DashboardSummary {
  const DashboardSummary({
    required this.classCount,
    required this.studentCount,
    required this.subjectCount,
    required this.sessionCount,
    required this.classes,
    required this.recentSessions,
  });

  final int classCount;
  final int studentCount;
  final int subjectCount;
  final int sessionCount;
  final List<ClassShortcut> classes;
  final List<RecentSession> recentSessions;
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(appDatabaseProvider).database);
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).load();
});

class DashboardRepository {
  const DashboardRepository(this.database);

  final Database database;

  Future<int> _count(String query) async {
    final rows = await database.rawQuery(query);
    return rows.single.values.single as int;
  }

  Future<DashboardSummary> load() async {
    final counts = await Future.wait([
      _count('''SELECT count(*) FROM school_class c
        JOIN academic_period p ON p.id = c.period_id
        WHERE c.archived_at IS NULL AND p.is_active = 1'''),
      _count(
        '''SELECT count(*) FROM student s
        JOIN school_class c ON c.id = s.class_id
        JOIN academic_period p ON p.id = c.period_id
        WHERE s.archived_at IS NULL AND c.archived_at IS NULL AND p.is_active = 1''',
      ),
      _count('SELECT count(*) FROM subject WHERE archived_at IS NULL'),
      _count(
        "SELECT count(*) FROM attendance_session WHERE state = 'completed'",
      ),
    ]);
    final classRows = await database.rawQuery(
      '''SELECT c.id, c.name, c.color_index, count(s.id) AS student_count
         FROM school_class c
         LEFT JOIN student s ON s.class_id = c.id AND s.archived_at IS NULL
         JOIN academic_period p ON p.id = c.period_id
         WHERE c.archived_at IS NULL AND p.is_active = 1
         GROUP BY c.id
         ORDER BY c.name COLLATE NOCASE
         LIMIT 4''',
    );
    final sessionRows = await database.query(
      'attendance_session',
      columns: ['id', 'class_name_snapshot', 'subject_name_snapshot', 'date'],
      where: "state = 'completed'",
      orderBy: 'date DESC, meeting_number DESC',
      limit: 3,
    );
    return DashboardSummary(
      classCount: counts[0],
      studentCount: counts[1],
      subjectCount: counts[2],
      sessionCount: counts[3],
      classes: classRows
          .map(
            (row) => ClassShortcut(
              id: row['id'] as int,
              name: row['name'] as String,
              studentCount: row['student_count'] as int,
              colorIndex: row['color_index'] as int,
            ),
          )
          .toList(),
      recentSessions: sessionRows
          .map(
            (row) => RecentSession(
              id: row['id'] as int,
              className: row['class_name_snapshot'] as String,
              subjectName: row['subject_name_snapshot'] as String,
              date: row['date'] as String,
            ),
          )
          .toList(),
    );
  }
}
