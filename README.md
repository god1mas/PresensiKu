# KelasKu

**by god1mas** · An offline-first Android classroom management app for one teacher, built with Flutter. The V4 extension follows [V4_IMPLEMENTATION_PLAN.md](V4_IMPLEMENTATION_PLAN.md); verified work is tracked in [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md).

## Local development

Use Flutter 3.47.9 (Dart 3.13.7) and an Android SDK with API 36. This workspace has an ignored local Flutter installation at `.tooling/flutter` and Android SDK at `C:\Android\Sdk`.

In PowerShell, from the project root:

```powershell
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Android\Sdk'
$env:ANDROID_USER_HOME = 'C:\Project\PresensiKu\.tooling\android-user'
$env:PUB_CACHE = 'C:\Project\PresensiKu\.tooling\pub-cache'
$env:GRADLE_USER_HOME = 'C:\Project\PresensiKu\.tooling\gradle'
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\flutter.bat analyze
.\.tooling\flutter\bin\flutter.bat test
```

The `.tooling` directory is local and excluded from Git. Install Flutter separately if this directory is absent.

Production signing uses a permanent owner-controlled key outside this repository. See [production signing and migration](PRODUCTION_SIGNING.md) for the interactive build process and the safety requirements for moving from the differently signed QA APK.

## Data

SQLite is the sole operational datastore. The V1→V2 migration adds grading; V2→V3 adds class colors. V4/V5 add education levels, academic-year identity, semester-aware class mapping, stable student identity, and period-aware attendance. Existing records and IDs are preserved during migration. School classes, rosters, subjects, and colors carry from Ganjil to Genap within one year; attendance and grading begin fresh each semester. University classes and enrollment belong to one semester. Figma SVG assets and fonts are bundled locally. No login, cloud database, or telemetry is configured.

Before upgrading a phone, save a `.pkbackup` from the installed app using Pengaturan → Cadangkan data, copy it off the phone, and retain the previous APK until the upgrade is accepted. KelasKu can restore V1, V2, and V3 backups. Restoring V1 keeps attendance and leaves grading empty. A restore replaces current data only after preview and confirmation.

## Current scope

Teacher onboarding, dashboard, academic periods, classes, students, subjects, attendance recording, history, saved-session corrections, and attendance Excel reports remain available. KelasKu adds assessments, numeric/blank/EX grade entry, custom categories, scoped weights, grading recap, and four-sheet grade XLSX including Matriks Nilai. Subjects and categories can be restored from their archives. History and Reports each offer Presensi and Penilaian. Save a `.pkbackup` using Pengaturan → Cadangkan data and restore it using Pengaturan → Pulihkan data. See [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md) for verification and [ANDROID_QA_CHECKLIST.md](ANDROID_QA_CHECKLIST.md) for pending device checks.

Version 1.4 adds education-level terminology, separate school-year and university semester models, class archive recovery, and period-aware attendance and grading history. Opening a historical period does not activate it. Attendance Excel preserves NIM text in university detail and summary sheets.

## Install and use

KelasKu 1.4.1 (code 6) production-signed APK: `C:\Project\PresensiKu\releases\production\KelasKu-v1.4.1-production.apk` (59,588,113 bytes). Package: `com.presensiku.presensiku`; Android 7.0 / API 24 or later. APK SHA-256: `3CD07324E1E50B6288938F2FB8763B1871F2C887B2E264AF4FFE9D77E91B24F8`. The preserved 1.4.0+5 QA APK is `C:\Project\PresensiKu\build\app\outputs\flutter-apk\KelasKu-1.4.0+5-qa.apk`. See [v1.4.1 release notes](RELEASE_NOTES_1.4.1.md) for certificate fingerprints and validation.

The production and QA APKs have different signing certificates. **Do not install the production APK over an existing QA installation** or uninstall the QA app to make it install. First export a `.pkbackup` and keep two off-device copies. Test a fresh production installation and real V5 backup restoration on a spare device or emulator. Migrate the phone only after that test and a separate owner-approved plan. The phone's actual installed certificate and restore result have not been verified.

For a fresh installation on a spare device, copy the production APK to the device and open it from the file manager. Alternatively, enable USB debugging on that spare device and run:

```powershell
& 'C:\Android\Sdk\platform-tools\adb.exe' install 'C:\Project\PresensiKu\releases\production\KelasKu-v1.4.1-production.apk'
```

Open KelasKu and enter the teacher profile, create an academic period and class, and add students and subjects. Choose Mulai Kelas → Pilih Kelas → Mata Pelajaran, then use Presensi for H/S/I/A attendance or Penilaian for grades. The selected class and subject carry into attendance setup. Create assessments, enter each student's score or EX, set weights totaling 100%, and open Rekap Nilai. The app labels incomplete results as provisional. Use Ekspor Nilai Excel to save or share the four-sheet workbook.

The 1.4.1 APK uses the permanent owner-controlled production key. The QA APK remains separately preserved with its original debug certificate. No signing credentials are tracked. Protect the permanent key and its password according to [production signing and migration](PRODUCTION_SIGNING.md).

## Verification limits and GitHub

No Android device or emulator was available for installation, launch, airplane-mode tests, native file dialogs, or screen comparison. Automated tests do not replace those checks. Follow the manual QA checklist before relying on the app for daily records.

The 1.4.1 production APK verification, metadata, signing result, and test count are recorded in [RELEASE_NOTES_1.4.1.md](RELEASE_NOTES_1.4.1.md). The automated suite covers populated V1/V2/V3 migrations into V5, semester cycles, attendance regression, grading, XLSX, and V1/V2/V3 backup restoration. Native Android picker/share and device visual checks require the manual checklist.

GitHub synchronization remains blocked by the earlier automatic approval denial. No bypass or retry was attempted. A future push requires explicit authorization and approval by the applicable mechanism.

