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

## Data

SQLite is the sole operational datastore. Schema V2 adds assessments, student grades, categories, scoped weights, and a weight audit log through an additive V1→V2 migration. Existing attendance tables and IDs are preserved. Foreign keys, active-data uniqueness indexes, archive fields, and display snapshots support historical integrity. Figma SVG assets and fonts are bundled locally. No login, cloud database, or telemetry is configured.

Before upgrading a phone with V1 data, save a `.pkbackup` from the installed V1 app using Pengaturan → Cadangkan data, copy it off the phone, and retain the previous APK until the upgrade is accepted. V4 can restore both V1 and V2 backups. Restoring V1 keeps attendance and leaves grading empty. A restore replaces current data only after preview and confirmation.

## Current scope

Teacher onboarding, dashboard, academic periods, classes, students, subjects, attendance recording, history, saved-session corrections, and attendance Excel reports remain available. V4 adds assessments, numeric/blank/EX grade entry, required assessments, custom categories, scoped weights, final versus provisional calculations, grading recap, three-sheet grade XLSX, and V1/V2 backup compatibility. Save a `.pkbackup` using Pengaturan → Cadangkan data and restore it using Pengaturan → Pulihkan data. See [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md) for verification and [ANDROID_QA_CHECKLIST.md](ANDROID_QA_CHECKLIST.md) for pending device checks.

## Install and use

The existing V4 release output is the previous PresensiKu build, not the KelasKu rebrand. No KelasKu APK has been generated yet. Its path is `C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk` (58,981,581 bytes). Package: `com.presensiku.presensiku`; version: `1.1.0` (code 2); Android 7.0 / API 24 or later. SHA-256: `69B396A66FE940B04EBF4F1EB5790B6746AF321C28D780B0DD09434B61F7D9E7`.

For the previous PresensiKu build only, copy the APK to an Android phone, open it from the file manager, and allow that file manager to install apps when Android prompts. Alternatively, enable USB debugging, connect the phone, and run:

```powershell
& 'C:\Android\Sdk\platform-tools\adb.exe' install -r 'C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk'
```

Once a KelasKu APK is built in the next task, open KelasKu and enter the teacher profile, create an academic period and class, and add students and subjects. Choose Mulai Kelas → Pilih Kelas → Mata Pelajaran, then use Presensi for H/S/I/A attendance or Penilaian for grades. The selected class and subject carry into attendance setup. Create assessments, enter each student's score or EX, set weights totaling 100%, and open Rekap Nilai. The app labels incomplete results as provisional. Use Ekspor Nilai Excel to save or share the three-sheet workbook.

The previous V4 release build uses the Android **debug signing key**, as configured in `android/app/build.gradle.kts`. It is intended for local installation and QA; production distribution requires an owner-controlled release key and signing configuration. No signing credentials are tracked. Back up app data before changing signing keys or uninstalling: an APK signed with another key cannot update the installed app directly.

## Verification limits and GitHub

No Android device or emulator was available for installation, launch, airplane-mode tests, native file dialogs, or screen comparison. Automated tests do not replace those checks. Follow the manual QA checklist before relying on the app for daily records.

The V4 release verification, APK metadata, signing result, and test count are recorded in [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md). The automated suite covers the V1→V2 migration, attendance regression, grading, XLSX, and V1/V2 backup restoration. Native Android picker/share and device visual checks require the manual checklist.

GitHub synchronization remains blocked by the earlier automatic approval denial. No bypass or retry was attempted. A future push requires explicit authorization and approval by the applicable mechanism.

