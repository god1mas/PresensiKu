# PHASE 0 — Repository and Design Audit

Audit date: 2026-11-11 (Asia/Jakarta)

## Verified starting point

- GitHub repository: [god1mas/PresensiKu](https://github.com/god1mas/PresensiKu). The connected GitHub API reports a public, unarchived repository with `size: 0` and default branch `main`. The local `C:\Project\PresensiKu` directory contains no project files and is not a Git checkout. A direct `git ls-remote` attempt was blocked by this environment's network restriction, so branch history was not independently confirmed.
- Figma: [PresensiKu design](https://www.figma.com/design/ZTwqubcNOH64JDUJgmtQ8i/PresensiKu?node-id=0-1) was read through the connected Figma tool. One page contains sixteen numbered 393 × 852 mobile screens, supplementary states, reusable components, token variables, and separate `EXPLORE` concepts. The numbered screens and relevant refinements are the implementation baseline; `EXPLORE` is not.
- Local toolchain: `flutter`, `dart`, `adb`, and `gradle` are not on PATH. Common Flutter and Android SDK paths, and the common Android Studio path, were absent. Java 23.0.2 and Git are present. No build or device test was possible in this phase.
- The supplied `logo presensiku.png` is a square image with a light background. Figma also contains editable brand emblem/logo layers. Inspect and export the appropriate Figma asset in PHASE 1; keep the supplied image as a brand reference, without assuming it is a transparent launcher icon.

## Figma feature map

| Design | Application flow |
| --- | --- |
| 01–03 | Splash, first-run teacher profile, live dashboard |
| 04–05 | Class list/search, class creation |
| 06–07 | Class details, student list, student creation |
| 08, 08A | Subject list and creation |
| 09–11 | Session setup, attendance entry, saved state |
| 12–13 | History, session details, editing |
| 14–15 | Summary and Excel export |
| 16 | Settings and local data management |
| 04B, 06B, 12B | Empty class, student, and history states |
| 10A, 10B, 15B | Bulk confirmation, complete attendance, export success |
| 16A–16D | Backup/restore confirmations, profile edit, academic period |
| REVIEW / PresensiKu V3 Dashboard | Full scroll dashboard refinement; compare with 03 during implementation |

The inspected dashboard uses an editable logo, greeting, date, large blue attendance action, notebook-style statistics, pastel metric cards, class shortcuts, recent history, and four-tab bottom navigation. The inspected attendance screen uses a progress card, scrolling student list, four status controls per row, bulk action, and fixed save footer. Its unmarked sample state and bulk confirmation screen must remain functional behavior, not static decoration.

Local Figma styles include `PresensiKu / Friendly Headline` (Nunito ExtraBold, 28) and `PresensiKu / Body` (Plus Jakarta Sans Medium, 13). Brand variables include blue `#1762F3`, cyan `#20A9F4`, navy `#14243F`, green `#10C65A`, background `#F6F9FE`, and semantic red/amber/pastel colors. Layout variables use 4, 8, 12, 16, 24, 32, 40 spacing and 12, 16, 24 radii. Exact usage still needs per-screen inspection in its implementation phase.

## Proposed architecture

Use Flutter for Android with feature-first folders and a small shared core:

```text
lib/
  app/                 # App bootstrap, router, theme, localization
  core/
    database/          # SQLite open, schema, migrations, transactions
    design/            # Figma tokens and reusable widgets
    files/             # Android document and share adapters
    utils/             # Date, validation, result formatting
  features/
    onboarding/        # profile form and persistence
    dashboard/         # read-only aggregates and shortcuts
    academics/         # academic periods, classes, students, subjects
    attendance/        # setup, draft, marking, save, edit
    history/           # filters and detail
    reports/           # aggregates and XLSX export
    settings/          # profile, academic period, backup/restore
test/
  core/                # schema and migration tests
  features/            # domain/repository/widget tests
integration_test/      # critical real-device flows
assets/                # approved Figma exports and supplied brand assets
```

Each feature separates widgets/controllers, domain models/services, and repositories. Riverpod owns reactive screen state and dependencies; `go_router` owns navigation; SQLite is the single source of operational data. The route tree follows splash/onboarding, a four-tab shell (`/beranda`, `/kelas`, `/riwayat`, `/pengaturan`), then class/student/subject, attendance, report, and settings detail routes. Reports and data-management actions remain reachable from their matching Figma controls.

Candidate packages: `flutter_riverpod`, `go_router`, `sqflite`, `path_provider`, `path`, `intl`, `file_picker`, `share_plus`, and a maintained Dart XLSX writer. Select and pin compatible versions only after the Flutter SDK is installed and package compatibility can be checked. Avoid unnecessary permissions, network services, and telemetry.

## SQLite model and data rules

| Table | Essential fields and constraints |
| --- | --- |
| `teacher_profile` | Singleton ID, required name, optional school, timestamps |
| `academic_period` | ID, year label, semester enum, active flag, unique `(year_label, semester)` |
| `class` | ID, period FK, required name, archived timestamp; unique active normalized `(period_id, name)` |
| `student` | ID, class FK, required name and attendance number, optional NIS/NISN, archived timestamp; unique active `(class_id, attendance_number)` |
| `subject` | ID, required name, archived timestamp; unique active normalized name |
| `class_subject` | Class and subject FKs, archived timestamp; unique active pair |
| `attendance_session` | ID, class/subject/period FKs, local calendar date, positive meeting number, `draft`/`completed`, timestamps, class/subject/period display snapshots; unique `(class_id, subject_id, date, meeting_number)` |
| `attendance_record` | Session and student FKs, nullable status in draft and required H/S/I/A when complete, student name/number snapshots, unique `(session_id, student_id)` |

Enable SQLite foreign keys and indexes for class/student lists, assignments, session history, and report filters. Use schema versioning with explicit forward migrations. A transaction creates or updates the session and its roster records, validates that every record has one status before completion, and commits only as a complete unit. Drafts keep the same unique session key and persist partial marks. Editing a completed session updates records transactionally and uses the stored roster.

Student membership belongs to one class. To move a student, archive the old enrollment and create a new one in the destination class; do not rewrite old sessions. Archiving classes, students, or subjects hides them from new-entry choices while preserving old FKs. Session and record display snapshots keep historical names/numbers stable after master-data edits. The roster is captured when a draft begins, so enrollment changes during an unfinished session do not silently change its membership. A report denominator is the number of completed sessions containing a saved record for that student; attendance rate is `H / (H+S+I+A) × 100%`, with zero sessions shown as no rate rather than a fabricated percentage.

For backup, export a consistent SQLite snapshot with a manifest/schema version. Restore only after copying the chosen file to a staging location, checking format/version, `integrity_check`, foreign keys, and required tables, then replacing the live database with rollback protection. An XLSX report is never a backup. Android's document picker and share sheet handle user-selected files; backup and report bytes are the only data leaving app storage.

## Delivery sequence and acceptance gates

| Phase | Gate |
| --- | --- |
| 1 Foundation | Android project opens; dependencies resolve; theme/router/database initialize; baseline tests and analysis pass |
| 2 Onboarding/dashboard | First launch saves profile; restart skips onboarding; dashboard counts and empty states read SQLite |
| 3 Classes/periods | Period and class CRUD/archive/search work; duplicate active class rejected |
| 4 Students/subjects | Student and subject CRUD/archive/assignment work; unique attendance number and pair enforced |
| 5 Attendance | Session uniqueness, unmarked initial state, draft persistence, bulk confirmation, completion validation, transactional save pass |
| 6 History/editing | Filters, detail, edit, and summary recalculation pass with stable snapshots |
| 7 Reports | Filters produce correct detail/summary sheets; workbook opens in Excel; save/share pass |
| 8 Settings/backup | Profile and period editing, valid restore, corrupt-file rejection, and rollback pass |
| 9 QA/release | Relevant Figma comparison, responsive/device/offline/restart tests, analysis/tests, and installable APK pass |

At each phase, inspect its Figma nodes and local code, implement only that phase, run targeted tests, report evidence, and stop. Release testing should cover a fresh install, 30–40 students, app restart during draft, duplicate sessions, archived data, XLSX readability, backup/restore round trip, and airplane mode.

## Open risks and decisions for PHASE 1

1. Install and verify a stable Flutter SDK and Android SDK/ADB before choosing exact dependency versions or promising an APK build.
2. Verify repository branch contents through an authenticated checkout when network access is available; do not overwrite remote history.
3. Export the exact Figma logo and illustrations where accessible; verify font licenses and bundle the required font files. The provided square PNG may need separate launcher-icon preparation.
4. Reconcile Figma's visible controls with the full functional scope (for example, edit/archive and report date range) by adding the least intrusive native paths that retain the established visual identity.

## PHASE 0 result

Architecture, feature mapping, data-integrity rules, project structure, dependencies, risks, and acceptance gates are defined from the verified repository metadata and Figma file. No application code was written. PHASE 0 is **PASS** for audit/planning; toolchain and build verification remain PHASE 1 prerequisites.
