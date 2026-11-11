# PresensiKu

An offline-first Android attendance app for one teacher, built with Flutter. Development follows the phase plan in [PHASE_0_ARCHITECTURE.md](PHASE_0_ARCHITECTURE.md); current verified work is tracked in [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md).

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
.\.tooling\flutter\bin\flutter.bat build apk --release
```

The `.tooling` directory is local and excluded from Git. Install Flutter separately if this directory is absent.

## Data

SQLite is the sole operational datastore. The schema is versioned in `lib/core/database/app_database.dart`. Foreign keys, active-data uniqueness indexes, archival fields, and immutable attendance display snapshots support historical integrity. Figma SVG assets and the licensed fonts are bundled locally. No login, cloud database, or telemetry is configured.

## Current scope

Teacher onboarding, dashboard, academic periods, classes, students, subjects, attendance recording, history, saved-session corrections, Excel reports, and local backup/restore are implemented. A `.pkbackup` file contains all app data; save it using Pengaturan → Cadangkan data and restore it using Pengaturan → Pulihkan data. Restore replaces current data only after confirmation. See [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md) for release verification and [ANDROID_QA_CHECKLIST.md](ANDROID_QA_CHECKLIST.md) for pending device checks.

## Install and use

The verified release output is `C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk` (58,030,917 bytes). Package: `com.presensiku.presensiku`; version: `1.0.0` (code 1); Android 7.0 / API 24 or later. SHA-256: `5B06C3CD11DCDD15652C073A8AC3F8C7416FE2DADDC4F51F06ABB9C8C96EBD5A`.

Copy the APK to an Android phone, open it from the file manager, and allow that file manager to install apps when Android prompts. Alternatively, enable USB debugging, connect the phone, and run:

```powershell
& 'C:\Android\Sdk\platform-tools\adb.exe' install -r 'C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk'
```

Open PresensiKu, enter the teacher profile, create an academic period and class, add students and subjects, and select Mulai Absensi. Complete H/S/I/A marks before saving. Use Riwayat for corrections and Pengaturan → Rekap dan laporan for Excel export.

The release build currently uses the Android **debug signing key**, as configured in `android/app/build.gradle.kts`. It is intended for local installation and QA; production distribution requires an owner-controlled release key and signing configuration. No signing credentials are tracked. Back up app data before changing signing keys or uninstalling: an APK signed with another key cannot update the installed app directly.

## Verification limits and GitHub

No Android device or emulator was available for installation, launch, airplane-mode tests, native file dialogs, or screen comparison. Automated tests do not replace those checks. Follow the manual QA checklist before relying on the app for daily records.

Final local verification: analysis clean, 23/23 tests passed, release APK build succeeded, package metadata and launcher icon checked, and APK v2 signature verified. The release manifest contains no INTERNET permission. Schema v1 creation/reopening is covered; no migration from an earlier released schema is claimed.

GitHub synchronization remains blocked by the earlier automatic approval denial. No bypass or retry was attempted. A future push requires explicit authorization and approval by the applicable mechanism.

