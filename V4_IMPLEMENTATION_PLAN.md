# PresensiKu V4 implementation plan

## Baseline and scope

- Local `main` was clean at `41077d6` before V4 work. The prior GitHub push denial still applies.
- Existing app: Flutter/Riverpod/go_router, SQLite schema 1, eight operational tables, four navigation tabs, attendance XLSX, and local backup/restore. Preserve every V1 table, ID, and attendance snapshot.
- The V4 Figma page contains 22 frames (`72:112` through `77:140`). The new flow starts at class detail, then subject detail, assessment overview, grade input, category and weight settings, recap, student detail, and export. It also defines empty, invalid, unsaved, deletion, and export states.
- Current `AppDatabase.open` has only `onCreate`, so schema 2 requires explicit `onUpgrade`. Current backup accepts exactly schema 1 and eight tables, so it must recognize both formats after V4 migration. Existing attendance routes and four tabs remain.

## Schema 2 design

Add `assessment_category` (stable ID, name, archive timestamp), `assessment` (class, subject, period, category, date, BAB, title, maximum, required flag, snapshots, archive/soft-delete timestamp), `assessment_grade` (assessment/student unique pair, state `GRADED`/`EXEMPT`, nullable numeric score, student name/number snapshots), `grading_weight_set` (class/subject/period unique scope, active flag), `grading_weight_item` (set/category unique pair, integer 0–100), and `grading_audit_log` (scope, action, payload, timestamp). An absent grade row means `UNGRADED`; explicit zero is a `GRADED` row with score 0. FKs restrict destructive master-data deletion. Cross-scope writes are checked in repository transactions. Category rename preserves the stable ID and assessment category snapshot.

Fresh schema 2 creation runs V1 DDL then V2 DDL. Upgrade from 1 runs only additive V2 DDL through sqflite `onUpgrade`, which is wrapped in SQLite's version-change transaction. Reopening must preserve all preexisting records. On migration failure, SQLite rolls back to schema 1. No automatic deletion or data conversion is needed.

## Recovery and backup

Before upgrading a real installation, create and retain a V1 `.pkbackup` through the installed app's Settings > Backup. Copy it off the device and verify it can be inspected. Keep a copy of the old APK. Schema 2 backup includes all 14 tables and a checksum. Restore recognizes schema 1 with its exact eight-table list and schema 2 with its exact 14-table list. Restore clears all schema 2 tables in reverse dependency order inside one transaction, inserts present rows in dependency order, then checks foreign keys and integrity. A V1 restore leaves all grading tables empty. UI must preview and confirm replacement.

## Phase verification

1. Audit: run baseline suite, inspect source and Figma, record conflicts and plan.
2. Migration: test fresh schema 2, populated V1 upgrade, reopen, preserved attendance, FK integrity, and failed migration rollback.
3. Domain: pure Dart tests for normalization, blank/0/EX, required grades, all EX, zero weights, 99/100/101 totals, final versus provisional, corrections.
4. Persistence: transaction and restart tests for categories, assessments, grades, weight audit, archive and scope validation.
5. UI: widget tests for navigation and critical interactions; compare the V4 frames and responsive states.
6. Reports: inspect actual XLSX cells and V1/V2 backup round trips, corruption rejection, rollback, attendance preservation.
7. QA: format, analyze, full tests, 40-student workflow, release APK, package/version/signature checks. Device-specific results remain pending if no device exists.

Each phase advances only after its required verification passes and a local checkpoint is committed.
