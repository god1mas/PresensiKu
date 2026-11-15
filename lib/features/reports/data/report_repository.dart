import '../../../core/education/education_level.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(appDatabaseProvider).database);
});

class ReportFilter {
  const ReportFilter({
    this.classId,
    this.subjectId,
    this.periodId,
    this.fromDate,
    this.toDate,
  });
  final int? classId;
  final int? subjectId;
  final int? periodId;
  final String? fromDate;
  final String? toDate;
}

class ReportDetail {
  const ReportDetail({
    required this.studentId,
    required this.number,
    required this.studentName,
    this.nis,
    required this.className,
    required this.subjectName,
    required this.date,
    required this.meetingNumber,
    required this.status,
  });
  final int studentId;
  final int number;
  final String studentName;
  final String? nis;
  final String className;
  final String subjectName;
  final String date;
  final int meetingNumber;
  final String status;
}

class StudentSummary {
  const StudentSummary({
    required this.studentId,
    required this.number,
    required this.name,
    this.nis,
    required this.present,
    required this.sick,
    required this.excused,
    required this.absent,
  });
  final int studentId;
  final int number;
  final String name;
  final String? nis;
  final int present;
  final int sick;
  final int excused;
  final int absent;
  int get completedSessions => present + sick + excused + absent;
  double? get attendancePercentage =>
      completedSessions == 0 ? null : present * 100 / completedSessions;
}

class ReportData {
  const ReportData({
    required this.details,
    required this.summaries,
    this.educationLevel,
  });
  final EducationLevel? educationLevel;
  final List<ReportDetail> details;
  final List<StudentSummary> summaries;
}

class ReportRepository {
  const ReportRepository(this.database);
  final Database database;

  Future<ReportData> load([ReportFilter filter = const ReportFilter()]) async {
    final where = <String>["sess.state = 'completed'"];
    final args = <Object?>[];
    if (filter.classId != null) {
      where.add('sess.class_id = ?');
      args.add(filter.classId);
    }
    if (filter.subjectId != null) {
      where.add('sess.subject_id = ?');
      args.add(filter.subjectId);
    }
    if (filter.periodId != null) {
      where.add('sess.period_id = ?');
      args.add(filter.periodId);
    }
    if (filter.fromDate != null) {
      where.add('sess.date >= ?');
      args.add(filter.fromDate);
    }
    if (filter.toDate != null) {
      where.add('sess.date <= ?');
      args.add(filter.toDate);
    }
    final rows = await database.rawQuery('''
      SELECT rec.student_id, rec.attendance_number_snapshot, rec.student_name_snapshot,
        c.education_level, rec.identifier_snapshot AS nis, sess.class_name_snapshot, sess.subject_name_snapshot,
        sess.date, sess.meeting_number, rec.status
      FROM attendance_record rec
      JOIN attendance_session sess ON sess.id = rec.session_id
      JOIN student ON student.id = rec.student_id
      JOIN school_class c ON c.id = sess.class_id
      WHERE ${where.join(' AND ')}
      ORDER BY sess.date DESC, sess.meeting_number DESC, sess.id DESC, rec.attendance_number_snapshot
    ''', args);
    final details = rows
        .map(
          (row) => ReportDetail(
            studentId: row['student_id'] as int,
            number: row['attendance_number_snapshot'] as int,
            studentName: row['student_name_snapshot'] as String,
            nis: row['nis'] as String?,
            className: row['class_name_snapshot'] as String,
            subjectName: row['subject_name_snapshot'] as String,
            date: row['date'] as String,
            meetingNumber: row['meeting_number'] as int,
            status: row['status'] as String,
          ),
        )
        .toList();
    final grouped = <int, List<ReportDetail>>{};
    for (final detail in details) {
      grouped.putIfAbsent(detail.studentId, () => []).add(detail);
    }
    final summaries =
        grouped.entries.map((entry) {
          final records = entry.value;
          final latest = records.first;
          int count(String status) =>
              records.where((record) => record.status == status).length;
          return StudentSummary(
            studentId: entry.key,
            number: latest.number,
            name: latest.studentName,
            nis: latest.nis,
            present: count('H'),
            sick: count('S'),
            excused: count('I'),
            absent: count('A'),
          );
        }).toList()..sort((a, b) {
          final byNumber = a.number.compareTo(b.number);
          return byNumber != 0 ? byNumber : a.name.compareTo(b.name);
        });
    return ReportData(
      details: details,
      summaries: summaries,
      educationLevel:
          rows.isNotEmpty &&
              rows.every((r) => r['education_level'] == 'university')
          ? EducationLevel.university
          : null,
    );
  }
}
