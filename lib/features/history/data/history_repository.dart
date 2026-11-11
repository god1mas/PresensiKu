import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(appDatabaseProvider).database);
});

class HistorySession {
  const HistorySession({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.periodId,
    required this.className,
    required this.subjectName,
    required this.date,
    required this.meetingNumber,
  });
  final int id;
  final int classId;
  final int subjectId;
  final int periodId;
  final String className;
  final String subjectName;
  final String date;
  final int meetingNumber;
}

class HistoryFilter {
  const HistoryFilter({
    this.search = '',
    this.classId,
    this.subjectId,
    this.periodId,
    this.fromDate,
    this.toDate,
  });
  final String search;
  final int? classId;
  final int? subjectId;
  final int? periodId;
  final String? fromDate;
  final String? toDate;
}

class HistoryOption {
  const HistoryOption(this.id, this.label);
  final int id;
  final String label;
}

class SessionCounts {
  const SessionCounts({
    required this.present,
    required this.sick,
    required this.excused,
    required this.absent,
  });
  final int present;
  final int sick;
  final int excused;
  final int absent;
  int get total => present + sick + excused + absent;
}

class HistoryRepository {
  const HistoryRepository(this.database);
  final Database database;

  Future<List<HistorySession>> sessions([
    HistoryFilter filter = const HistoryFilter(),
  ]) async {
    final where = <String>["state = 'completed'"];
    final args = <Object?>[];
    if (filter.classId != null) {
      where.add('class_id = ?');
      args.add(filter.classId);
    }
    if (filter.subjectId != null) {
      where.add('subject_id = ?');
      args.add(filter.subjectId);
    }
    if (filter.periodId != null) {
      where.add('period_id = ?');
      args.add(filter.periodId);
    }
    if (filter.fromDate != null) {
      where.add('date >= ?');
      args.add(filter.fromDate);
    }
    if (filter.toDate != null) {
      where.add('date <= ?');
      args.add(filter.toDate);
    }
    final term = filter.search.trim().toLowerCase();
    if (term.isNotEmpty) {
      where.add(
        '(lower(class_name_snapshot) LIKE ? OR lower(subject_name_snapshot) LIKE ?)',
      );
      args.add('%$term%');
      args.add('%$term%');
    }
    final rows = await database.query(
      'attendance_session',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, meeting_number DESC, id DESC',
    );
    return rows
        .map(
          (row) => HistorySession(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            subjectId: row['subject_id'] as int,
            periodId: row['period_id'] as int,
            className: row['class_name_snapshot'] as String,
            subjectName: row['subject_name_snapshot'] as String,
            date: row['date'] as String,
            meetingNumber: row['meeting_number'] as int,
          ),
        )
        .toList();
  }

  Future<List<HistoryOption>> classOptions() async {
    final rows = await database.rawQuery(
      "SELECT DISTINCT class_id AS id, class_name_snapshot AS name FROM attendance_session WHERE state = 'completed' ORDER BY name COLLATE NOCASE",
    );
    return rows
        .map((row) => HistoryOption(row['id'] as int, row['name'] as String))
        .toList();
  }

  Future<List<HistoryOption>> subjectOptions() async {
    final rows = await database.rawQuery(
      "SELECT DISTINCT subject_id AS id, subject_name_snapshot AS name FROM attendance_session WHERE state = 'completed' ORDER BY name COLLATE NOCASE",
    );
    return rows
        .map((row) => HistoryOption(row['id'] as int, row['name'] as String))
        .toList();
  }

  Future<SessionCounts> counts(int sessionId) async {
    final rows = await database.rawQuery(
      '''SELECT
      SUM(CASE WHEN status = 'H' THEN 1 ELSE 0 END) AS h,
      SUM(CASE WHEN status = 'S' THEN 1 ELSE 0 END) AS s,
      SUM(CASE WHEN status = 'I' THEN 1 ELSE 0 END) AS i,
      SUM(CASE WHEN status = 'A' THEN 1 ELSE 0 END) AS a
      FROM attendance_record WHERE session_id = ?''',
      [sessionId],
    );
    final row = rows.single;
    return SessionCounts(
      present: row['h'] as int? ?? 0,
      sick: row['s'] as int? ?? 0,
      excused: row['i'] as int? ?? 0,
      absent: row['a'] as int? ?? 0,
    );
  }

  Future<void> correct({
    required int sessionId,
    required int recordId,
    required String status,
  }) async {
    if (!const {'H', 'S', 'I', 'A'}.contains(status)) {
      throw const FormatException('Status kehadiran tidak valid.');
    }
    await database.transaction((txn) async {
      final sessions = await txn.query(
        'attendance_session',
        columns: ['state'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty || sessions.single['state'] != 'completed') {
        throw StateError('Sesi belum selesai.');
      }
      final now = DateTime.now().toIso8601String();
      final changed = await txn.update(
        'attendance_record',
        {'status': status, 'updated_at': now},
        where: 'id = ? AND session_id = ?',
        whereArgs: [recordId, sessionId],
      );
      if (changed == 0) throw StateError('Catatan siswa tidak ditemukan.');
      await txn.update(
        'attendance_session',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }
}
