import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('The app database must be initialized before runApp.');
});

class AppDatabase {
  AppDatabase._(this.database);

  static const schemaVersion = 1;
  final Database database;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final selectedPath =
        path ?? p.join(await getDatabasesPath(), 'presensiku.db');
    final database = await selectedFactory.openDatabase(
      selectedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
      ),
    );
    return AppDatabase._(database);
  }

  Future<void> close() => database.close();

  static Future<void> _createSchema(Database db, int version) async {
    final statements = <String>[
      '''CREATE TABLE teacher_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        school_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE academic_period (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year_label TEXT NOT NULL CHECK (length(trim(year_label)) > 0),
        semester TEXT NOT NULL CHECK (semester IN ('ganjil', 'genap')),
        is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (year_label, semester)
      )''',
      '''CREATE TABLE school_class (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL REFERENCES academic_period(id) ON DELETE RESTRICT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE student (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL REFERENCES school_class(id) ON DELETE RESTRICT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        attendance_number INTEGER NOT NULL CHECK (attendance_number > 0),
        nis TEXT,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE subject (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE class_subject (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL REFERENCES school_class(id) ON DELETE RESTRICT,
        subject_id INTEGER NOT NULL REFERENCES subject(id) ON DELETE RESTRICT,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE attendance_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL REFERENCES school_class(id) ON DELETE RESTRICT,
        subject_id INTEGER NOT NULL REFERENCES subject(id) ON DELETE RESTRICT,
        period_id INTEGER NOT NULL REFERENCES academic_period(id) ON DELETE RESTRICT,
        date TEXT NOT NULL,
        meeting_number INTEGER NOT NULL CHECK (meeting_number > 0),
        state TEXT NOT NULL DEFAULT 'draft' CHECK (state IN ('draft', 'completed')),
        class_name_snapshot TEXT NOT NULL,
        subject_name_snapshot TEXT NOT NULL,
        period_snapshot TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        UNIQUE (class_id, subject_id, date, meeting_number)
      )''',
      '''CREATE TABLE attendance_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES attendance_session(id) ON DELETE RESTRICT,
        student_id INTEGER NOT NULL REFERENCES student(id) ON DELETE RESTRICT,
        status TEXT CHECK (status IS NULL OR status IN ('H', 'S', 'I', 'A')),
        student_name_snapshot TEXT NOT NULL,
        attendance_number_snapshot INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (session_id, student_id)
      )''',
      'CREATE UNIQUE INDEX one_active_period ON academic_period(is_active) WHERE is_active = 1',
      'CREATE UNIQUE INDEX active_class_name ON school_class(period_id, lower(trim(name))) WHERE archived_at IS NULL',
      'CREATE UNIQUE INDEX active_student_number ON student(class_id, attendance_number) WHERE archived_at IS NULL',
      'CREATE UNIQUE INDEX active_subject_name ON subject(lower(trim(name))) WHERE archived_at IS NULL',
      'CREATE UNIQUE INDEX active_class_subject ON class_subject(class_id, subject_id) WHERE archived_at IS NULL',
      'CREATE INDEX student_class_order ON student(class_id, archived_at, attendance_number)',
      'CREATE INDEX class_subject_class ON class_subject(class_id, archived_at)',
      'CREATE INDEX session_date ON attendance_session(date DESC, state)',
      'CREATE INDEX session_period ON attendance_session(period_id, class_id, subject_id, date)',
      'CREATE INDEX record_session ON attendance_record(session_id, status)',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
  }
}
