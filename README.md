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

The foundation, teacher onboarding, dashboard, academic data, attendance recording, history, saved-session corrections, Excel reports, and local backup/restore are implemented. A `.pkbackup` file contains all app data; save it using Pengaturan → Cadangkan data and restore it using Pengaturan → Pulihkan data. Restore replaces current data only after confirmation. See the progress document for verified status. Device-level checks and a release APK remain in the final phase.

