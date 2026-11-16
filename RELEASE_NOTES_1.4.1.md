# KelasKu 1.4.1+6 — production-signed APK

## Scope

This release keeps the 1.4.0 academic redesign, SQLite V5 schema, backup compatibility, application ID, and app features. The changes are the Android version increment and a dedicated production signing configuration. Release builds require the owner's permanent key and fail when credentials are absent; debug builds remain available. No production key or password is stored in Git.

## Verified artifact (2026-11-17)

- APK: `C:\Project\PresensiKu\releases\production\KelasKu-v1.4.1-production.apk` (separate from the read-only QA copy).
- Size: **59,588,113 bytes**. APK SHA-256: `3CD07324E1E50B6288938F2FB8763B1871F2C887B2E264AF4FFE9D77E91B24F8`.
- Manifest (`aapt dump badging`): package `com.presensiku.presensiku`, version name `1.4.1`, version code `6`, launcher label `KelasKu`, launcher activity `com.presensiku.presensiku.MainActivity`, icon resources at five densities, minimum API 24 and target API 36.
- `apksigner verify --verbose --print-certs`: valid APK Signature Scheme v2, one RSA 4096-bit signer. Production certificate SHA-256: **`500b34efbb470855b3fbb9ec721eeb2a1be9af0e2d4fdb979d10b9b46889bda1`**.
- `zipalign -c -v 4`: verification successful.
- Preserved QA APK: `C:\Project\PresensiKu\build\app\outputs\flutter-apk\KelasKu-1.4.0+5-qa.apk`, 59,588,113 bytes, SHA-256 `124730A4A3DC1B8719B8B05E9272DB2E9C56CEBA02B10F21547A4B67A9E813CC`. Its debug certificate SHA-256 is `e25c8af199928e96c035770b423bf522680c8aef3449e153555148e5ff2d1e3e`, **different** from the production certificate.

## Source and automated verification

- `dart format lib test`: 64 files checked, none changed.
- `flutter analyze --no-pub`: no issues.
- Complete `flutter test --no-pub --reporter expanded`: **61/61 passed**. Coverage includes populated SQLite migrations to V5, V1/V2/V3 backup restoration, period switching, attendance, grading, archive recovery, and Excel exports.
- `flutter build apk --release --no-pub`: succeeded through the owner-operated build script. The release dry run without credentials failed as required; a debug dry run succeeded.
- The production key is outside the repository at `%USERPROFILE%\.android\kelasku\kelasku-release.p12`. The APK output directory is Git-ignored. The key and passwords were not committed.

## Device acceptance and migration

`adb devices -l` reported no device. Fresh installation, real-format V5 `.pkbackup` restoration, Android save/share pickers, airplane mode, and rendered layouts remain **PENDING**. The production certificate cannot update the debug-signed QA app in place. Do not uninstall or clear the existing phone app. Export the QA app's `.pkbackup`, retain two off-device copies, then test fresh production installation and restore on a spare device or emulator before planning phone migration. Follow [PRODUCTION_SIGNING.md](PRODUCTION_SIGNING.md) and [ANDROID_QA_CHECKLIST.md](ANDROID_QA_CHECKLIST.md).

Keep two encrypted offline backups of the permanent `.p12` key in separate locations. Store its password in a password manager separately. Losing the key may prevent future updates to this production-signed app.
