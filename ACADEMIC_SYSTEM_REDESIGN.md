# Academic system redesign — KelasKu 1.4

## Phase 0: audit

Baseline commit: `75c503b`. Worktree was clean. Existing suite: 50 tests PASS.
Schema 3 stores classes under a creation semester. Students are class enrollment
rows; their IDs are referenced by attendance and grades. Attendance uniqueness
omits semester. Grading weights already include semester. Dashboard attendance
counts incorrectly span all periods. Class archive cascades only to active
children using one timestamp; this is usable legacy archive provenance.
Backups support schemas 1–3. Profiles contain no education level.

## Design and preservation rules

- Add education level to profile, and freeze the education model on each class.
  Existing classes are explicitly `legacy_school`, independent of later profile
  edits. Completing/changing a profile never reinterprets existing classes.
- Keep `school_class.period_id` as the original creation semester. Never rewrite
  historical period IDs. A relational `class_period` view exposes school classes
  in both semesters of their original year; university classes only in their
  original semester. An explicit academic-year table normalizes year identity.
- Keep `student` IDs as enrollment IDs; add a separate student identity table.
  Legacy rows each receive their own identity (no guessed merges). New university
  enrollment can reuse an identity with the same institution/NIM and matching
  name. NIM is text; duplicate active enrollment in a class is rejected.
- Attendance uniqueness includes period. Meeting sequences, assessments,
  grades, weights, dashboard and reports use the selected actual semester.
  Switching periods performs no copying/deletion.
- Legacy classes with the same name in both semesters remain distinct IDs.
  They are not merged. Their creation-semester context distinguishes them;
  new duplicate names in a school year are rejected.
- Class restoration uses known cascade provenance; independently archived
  children stay archived. Restore is transactional and conflicts roll back.
- Upgrade and restore run transactionally with foreign-key/integrity checks.
  Versioned backups retain support for all previously supported versions.
- Historical screen routes carry a selected period independently of the active
  period. Opening history does not activate that period.

## Verification gates

0. Audit and baseline: PASS (50 tests; analyzer result recorded separately).
1. Education/profile/identity/terminology: PASS — 14 targeted tests, clean analyzer.
2. Year and semester scope, migration, backup, switching: PASS — `dart format`, clean `flutter analyze`, 57/57 full tests. School Ganjil/Genap meeting 1 coexist; 40-student year continuity, isolated assessments/weights, repeat switching, restart, university enrollment isolation, populated V1/V2/V3 upgrades/backups, historical reports and active-period dashboard were verified.
3. Class archive recovery: PASS — original ID/color/history retained, known cascade children restored, prior archives/unlinks retained, duplicate names roll back, backup/reopen verified, 320 px UI test and clean analyzer.
4. Grading history filters and responsive UI: IN PROGRESS.
5. Full regression: NOT STARTED.
6. APK, signing comparison, release documentation: NOT STARTED.

Device QA must be reported separately from automated verification. No GitHub
push or production signing is part of this task.
