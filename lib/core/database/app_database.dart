import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('The app database must be initialized before runApp.');
});

class AppDatabase {
  AppDatabase._(this.database);

  static const schemaVersion = 5;
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
        onUpgrade: _upgradeSchema,
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
        color_index INTEGER NOT NULL DEFAULT 0 CHECK (color_index BETWEEN 0 AND 8),
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
        UNIQUE (class_id, subject_id, period_id, date, meeting_number)
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
    await _createGradingSchema(db);
    await _createEducationSchema(db);
    await _createAcademicSchema(db, rebuildAttendance: false);
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _createGradingSchema(db);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await db.execute(
        'ALTER TABLE school_class ADD COLUMN color_index INTEGER NOT NULL DEFAULT 0 CHECK (color_index BETWEEN 0 AND 8)',
      );
      await db.execute('UPDATE school_class SET color_index = (id - 1) % 9');
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await _createEducationSchema(db);
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await _createAcademicSchema(db, rebuildAttendance: true);
    }
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('Migrasi dibatalkan: relasi database tidak valid.');
    }
  }

  static Future<void> _createAcademicSchema(
    Database db, {
    required bool rebuildAttendance,
  }) async {
    await db.execute(
      'CREATE TABLE academic_year (id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT NOT NULL UNIQUE)',
    );
    await db.execute(
      'ALTER TABLE academic_period ADD COLUMN year_id INTEGER REFERENCES academic_year(id) ON DELETE RESTRICT',
    );
    await populateAcademicYears(db);
    await db.execute(
      '''CREATE TRIGGER period_year_insert AFTER INSERT ON academic_period BEGIN
      INSERT OR IGNORE INTO academic_year(label) VALUES (NEW.year_label);
      UPDATE academic_period SET year_id = (SELECT id FROM academic_year WHERE label = NEW.year_label) WHERE id = NEW.id AND year_id IS NULL;
      SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM academic_year y JOIN academic_period p ON p.year_id = y.id WHERE p.id = NEW.id AND y.label = p.year_label) THEN RAISE(ABORT, 'Academic year mismatch') END;
    END''',
    );
    await db.execute('''CREATE VIEW class_period AS
      SELECT c.id AS class_id, p.id AS period_id
      FROM school_class c
      JOIN academic_period origin ON origin.id = c.period_id
      JOIN academic_period p ON
        (c.education_level = 'university' AND p.id = c.period_id) OR
        (c.education_level != 'university' AND p.year_id = origin.year_id)''');
    if (rebuildAttendance) {
      // Rebuild parent and child together inside sqflite's upgrade transaction.
      // FK enforcement remains enabled; every row and primary key is copied.
      final definitions = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name IN ('attendance_session', 'attendance_record')",
      );
      final indexes = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'index' AND tbl_name IN ('attendance_session', 'attendance_record') AND sql IS NOT NULL",
      );
      final sessionSql =
          definitions.firstWhere(
                (r) => r['name'] == 'attendance_session',
              )['sql']
              as String;
      final recordSql =
          definitions.firstWhere((r) => r['name'] == 'attendance_record')['sql']
              as String;
      final rewritten = sessionSql
          .replaceFirst('attendance_session', 'attendance_session_new')
          .replaceAll(
            RegExp(
              r'UNIQUE\s*\(\s*class_id\s*,\s*subject_id\s*,\s*date\s*,\s*meeting_number\s*\)',
              caseSensitive: false,
            ),
            'UNIQUE (class_id, subject_id, period_id, date, meeting_number)',
          );
      await db.execute(rewritten);
      await db.execute(
        'INSERT INTO attendance_session_new SELECT * FROM attendance_session',
      );
      await db.execute(
        'CREATE TEMP TABLE attendance_record_copy AS SELECT * FROM attendance_record',
      );
      await db.execute('DROP TABLE attendance_record');
      await db.execute('DROP TABLE attendance_session');
      await db.execute(
        'ALTER TABLE attendance_session_new RENAME TO attendance_session',
      );
      await db.execute(recordSql);
      await db.execute(
        'INSERT INTO attendance_record SELECT * FROM attendance_record_copy',
      );
      await db.execute('DROP TABLE attendance_record_copy');
      for (final index in indexes) {
        await db.execute(index['sql'] as String);
      }
    }
    await db.execute(
      'ALTER TABLE attendance_record ADD COLUMN identifier_snapshot TEXT',
    );
    await db.execute(
      'ALTER TABLE assessment_grade ADD COLUMN identifier_snapshot TEXT',
    );
    await populateIdentifierSnapshots(db);
  }

  static Future<void> populateAcademicYears(DatabaseExecutor db) async {
    await db.execute(
      'INSERT OR IGNORE INTO academic_year(label) SELECT DISTINCT year_label FROM academic_period',
    );
    await db.execute(
      'UPDATE academic_period SET year_id = (SELECT id FROM academic_year WHERE label = academic_period.year_label) WHERE year_id IS NULL',
    );
  }

  static Future<void> populateIdentifierSnapshots(DatabaseExecutor db) async {
    for (final table in ['attendance_record', 'assessment_grade']) {
      await db.execute(
        'UPDATE $table SET identifier_snapshot = (SELECT nis FROM student WHERE student.id = $table.student_id) WHERE identifier_snapshot IS NULL',
      );
    }
  }

  static Future<void> _createEducationSchema(Database db) async {
    await db.execute(
      'ALTER TABLE teacher_profile ADD COLUMN education_level TEXT CHECK (education_level IN (\'tk\', \'sd\', \'smp\', \'sma\', \'university\'))',
    );
    await db.execute(
      "ALTER TABLE school_class ADD COLUMN education_level TEXT NOT NULL DEFAULT 'legacy_school' CHECK (education_level IN ('legacy_school', 'tk', 'sd', 'smp', 'sma', 'university'))",
    );
    await db.execute('''CREATE TABLE student_identity (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      institution TEXT NOT NULL DEFAULT '',
      nim TEXT,
      created_at TEXT NOT NULL,
      UNIQUE (institution, nim)
    )''');
    await db.execute(
      'ALTER TABLE student ADD COLUMN identity_id INTEGER REFERENCES student_identity(id) ON DELETE RESTRICT',
    );
    await populateStudentIdentities(db);
  }

  /// Legacy names/identifiers are deliberately not used to guess identity merges.
  static Future<void> populateStudentIdentities(DatabaseExecutor db) async {
    final rows = await db.query('student', where: 'identity_id IS NULL');
    for (final row in rows) {
      final id = await db.insert('student_identity', {
        'name': row['name'],
        'created_at': row['created_at'],
      });
      await db.update(
        'student',
        {'identity_id': id},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  static Future<void> _createGradingSchema(Database db) async {
    final statements = <String>[
      '''CREATE TABLE assessment_category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE assessment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL REFERENCES school_class(id) ON DELETE RESTRICT,
        subject_id INTEGER NOT NULL REFERENCES subject(id) ON DELETE RESTRICT,
        period_id INTEGER NOT NULL REFERENCES academic_period(id) ON DELETE RESTRICT,
        category_id INTEGER NOT NULL REFERENCES assessment_category(id) ON DELETE RESTRICT,
        date TEXT NOT NULL,
        bab TEXT,
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        description TEXT,
        max_score REAL NOT NULL DEFAULT 100 CHECK (max_score > 0),
        is_required INTEGER NOT NULL DEFAULT 1 CHECK (is_required IN (0, 1)),
        class_name_snapshot TEXT NOT NULL,
        subject_name_snapshot TEXT NOT NULL,
        period_snapshot TEXT NOT NULL,
        category_name_snapshot TEXT NOT NULL,
        archived_at TEXT,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE assessment_grade (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER NOT NULL REFERENCES assessment(id) ON DELETE RESTRICT,
        student_id INTEGER NOT NULL REFERENCES student(id) ON DELETE RESTRICT,
        state TEXT NOT NULL CHECK (state IN ('GRADED', 'EXEMPT')),
        score REAL,
        student_name_snapshot TEXT NOT NULL,
        attendance_number_snapshot INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK ((state = 'GRADED' AND score IS NOT NULL AND score >= 0) OR
               (state = 'EXEMPT' AND score IS NULL)),
        UNIQUE (assessment_id, student_id)
      )''',
      '''CREATE TABLE grading_weight_set (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL REFERENCES school_class(id) ON DELETE RESTRICT,
        subject_id INTEGER NOT NULL REFERENCES subject(id) ON DELETE RESTRICT,
        period_id INTEGER NOT NULL REFERENCES academic_period(id) ON DELETE RESTRICT,
        is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (class_id, subject_id, period_id)
      )''',
      '''CREATE TABLE grading_weight_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight_set_id INTEGER NOT NULL REFERENCES grading_weight_set(id) ON DELETE RESTRICT,
        category_id INTEGER NOT NULL REFERENCES assessment_category(id) ON DELETE RESTRICT,
        percent INTEGER NOT NULL CHECK (percent BETWEEN 0 AND 100),
        UNIQUE (weight_set_id, category_id)
      )''',
      '''CREATE TABLE grading_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL REFERENCES school_class(id) ON DELETE RESTRICT,
        subject_id INTEGER NOT NULL REFERENCES subject(id) ON DELETE RESTRICT,
        period_id INTEGER NOT NULL REFERENCES academic_period(id) ON DELETE RESTRICT,
        action TEXT NOT NULL,
        details_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''',
      'CREATE UNIQUE INDEX active_assessment_category_name ON assessment_category(lower(trim(name))) WHERE archived_at IS NULL',
      'CREATE INDEX assessment_scope_date ON assessment(class_id, subject_id, period_id, date DESC)',
      'CREATE INDEX assessment_grade_assessment ON assessment_grade(assessment_id, state)',
      'CREATE INDEX grading_audit_scope ON grading_audit_log(class_id, subject_id, period_id, created_at)',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    for (final name in ['Tugas', 'Ulangan', 'UTS', 'UAS', 'Sikap']) {
      await db.insert('assessment_category', {
        'name': name,
        'is_default': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}
