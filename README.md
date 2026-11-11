# PresensiKu

An offline-first Android attendance app for one teacher, built with Flutter. Development follows the phase plan in [PHASE_0_ARCHITECTURE.md](PHASE_0_ARCHITECTURE.md); current verified work is tracked in [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md).

## Local development

Use Flutter 3.47.9 (Dart 3.13.7) and an Android SDK with API 36. This workspace has an ignored local Flutter installation at `.tooling/flutter` and Android SDK at `C:\Android\Sdk`.

In PowerShell, from the project root:

```powershell
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Android\Sdk'
$env:PUB_CACHE = 'C:\Project\PresensiKu\.tooling\pub-cache'
$env:GRADLE_USER_HOME = 'C:\Project\PresensiKu\.tooling\gradle'
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\flutter.bat analyze
.\.tooling\flutter\bin\flutter.bat test
.\.tooling\flutter\bin\flutter.bat build apk --debug
```

The `.tooling` directory is local and excluded from Git. Install Flutter separately if this directory is absent.

## Data

SQLite is the sole operational datastore. The schema is versioned in `lib/core/database/app_database.dart`. Foreign keys, active-data uniqueness indexes, archival fields, and immutable attendance display snapshots support historical integrity. Figma SVG assets and the licensed fonts are bundled locally. No login, cloud database, or telemetry is configured.

## Current scope

The foundation, teacher onboarding, dashboard, academic periods, and class management are implemented. Student, subject, and attendance workflows are developed in later phases; see the progress document for verified status. Do not use the current APK for real attendance records until the relevant phases pass.

