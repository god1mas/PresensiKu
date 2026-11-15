import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(appDatabaseProvider).database);
});

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.name,
    required this.number,
    this.status,
  });
  final int id;
  final int studentId;
  final String name;
  final int number;
  final String? status;
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.className,
    required this.subjectName,
    required this.date,
    required this.meetingNumber,
    required this.state,
    required this.records,
  });
  final int id;
  final int classId;
  final int subjectId;
  final String className;
  final String subjectName;
  final String date;
  final int meetingNumber;
  final String state;
  final List<AttendanceRecord> records;

  int get markedCount =>
      records.where((record) => record.status != null).length;
  int get unmarkedCount => records.length - markedCount;
}

class PrepareSessionResult {
  const PrepareSessionResult({
    required this.sessionId,
    required this.existed,
    required this.completed,
  });
  final int sessionId;
  final bool existed;
  final bool completed;
}

class AttendanceRepository {
  const AttendanceRepository(this.database);
  final Database database;

  Future<PrepareSessionResult> prepare({
    required int classId,
    required int subjectId,
    required String date,
    required int meetingNumber,
  }) async {
    if (meetingNumber <= 0) {
      throw const FormatException('Nomor pertemuan harus lebih dari nol.');
    }
    final parsed = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Tanggal tidak valid.');
    }
    return database.transaction((txn) async {
      final classes = await txn.rawQuery(
        '''SELECT c.name, c.period_id, p.year_label, p.semester
        FROM school_class c JOIN academic_period p ON p.id = c.period_id
        WHERE c.id = ? AND c.archived_at IS NULL AND p.is_active = 1 AND p.archived_at IS NULL''',
        [classId],
      );
      if (classes.isEmpty) throw StateError('Pilih kelas aktif.');
      final subjects = await txn.rawQuery(
        '''SELECT s.name FROM subject s
        JOIN class_subject cs ON cs.subject_id = s.id
        WHERE s.id = ? AND cs.class_id = ? AND s.archived_at IS NULL AND cs.archived_at IS NULL''',
        [subjectId, classId],
      );
      if (subjects.isEmpty) {
        throw StateError('Mata pelajaran belum terhubung ke kelas.');
      }
      final existing = await txn.query(
        'attendance_session',
        columns: ['id', 'state'],
        where: 'class_id = ? AND subject_id = ? AND date = ? AND meeting_number = ?',
        whereArgs: [classId, subjectId, date, meetingNumber],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return PrepareSessionResult(
          sessionId: existing.single['id'] as int,
          existed: true,
          completed: existing.single['state'] == 'completed',
        );
      }
      final students = await txn.query(
        'student',
        columns: ['id', 'name', 'attendance_number'],
        where: 'class_id = ? AND archived_at IS NULL',
        whereArgs: [classId],
        orderBy: 'attendance_number',
      );
      if (students.isEmpty) {
        throw StateError('Tambahkan siswa sebelum memulai absensi.');
      }
      final classRow = classes.single;
      final now = DateTime.now().toIso8601String();
      final sessionId = await txn.insert('attendance_session', {
        'class_id': classId,
        'subject_id': subjectId,
        'period_id': classRow['period_id'],
        'date': date,
        'meeting_number': meetingNumber,
        'state': 'draft',
        'class_name_snapshot': classRow['name'],
        'subject_name_snapshot': subjects.single['name'],
        'period_snapshot': '${classRow['year_label']} ${classRow['semester']}',
        'created_at': now,
        'updated_at': now,
      });
      for (final student in students) {
        await txn.insert('attendance_record', {
          'session_id': sessionId,
          'student_id': student['id'],
          'status': null,
          'student_name_snapshot': student['name'],
          'attendance_number_snapshot': student['attendance_number'],
          'created_at': now,
          'updated_at': now,
        });
      }
      return PrepareSessionResult(
        sessionId: sessionId,
        existed: false,
        completed: false,
      );
    });
  }

  Future<AttendanceSession> load(int sessionId) async {
    final sessions = await database.query(
      'attendance_session',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessions.isEmpty) throw StateError('Sesi absensi tidak ditemukan.');
    final session = sessions.single;
    final rows = await database.query(
      'attendance_record',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'attendance_number_snapshot',
    );
    return AttendanceSession(
      id: sessionId,
      classId: session['class_id'] as int,
      subjectId: session['subject_id'] as int,
      className: session['class_name_snapshot'] as String,
      subjectName: session['subject_name_snapshot'] as String,
      date: session['date'] as String,
      meetingNumber: session['meeting_number'] as int,
      state: session['state'] as String,
      records: rows
          .map(
            (row) => AttendanceRecord(
              id: row['id'] as int,
              studentId: row['student_id'] as int,
              name: row['student_name_snapshot'] as String,
              number: row['attendance_number_snapshot'] as int,
              status: row['status'] as String?,
            ),
          )
          .toList(),
    );
  }

  Future<void> mark({
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
      if (sessions.isEmpty || sessions.single['state'] != 'draft') {
        throw StateError('Sesi tidak dapat diubah.');
      }
      final changed = await txn.update(
        'attendance_record',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND session_id = ?',
        whereArgs: [recordId, sessionId],
      );
      if (changed == 0) throw StateError('Siswa tidak ditemukan dalam sesi.');
    });
  }

  Future<void> markAllPresent(int sessionId) async {
    await database.transaction((txn) async {
      final sessions = await txn.query(
        'attendance_session',
        columns: ['state'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty || sessions.single['state'] != 'draft') {
        throw StateError('Sesi tidak dapat diubah.');
      }
      await txn.update(
        'attendance_record',
        {'status': 'H', 'updated_at': DateTime.now().toIso8601String()},
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<void> complete(int sessionId) async {
    await database.transaction((txn) async {
      final sessions = await txn.query(
        'attendance_session',
        columns: ['state'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty || sessions.single['state'] != 'draft') {
        throw StateError('Sesi tidak dapat disimpan.');
      }
      final rows = await txn.rawQuery(
        'SELECT count(*) AS total, sum(CASE WHEN status IS NULL THEN 1 ELSE 0 END) AS missing FROM attendance_record WHERE session_id = ?',
        [sessionId],
      );
      final total = rows.single['total'] as int;
      final missing = rows.single['missing'] as int? ?? 0;
      if (total == 0 || missing > 0) {
        throw StateError('$missing siswa belum ditandai.');
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'attendance_session',
        {'state': 'completed', 'completed_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }
}
