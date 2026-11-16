# KelasKu 1.4.2+7 — guide and About

## Changes

- Pengaturan now opens a bundled, offline Panduan Penggunaan with ten expandable topics covering onboarding, periods, classes, subjects, students, attendance, grading, history/reports/Excel, backup/restore, and common questions. Wording follows the school or university profile.
- Tentang KelasKu shows the bundled logo, by god1mas, developer Dimas Abdus Syukur, a local-data description, and `© 2026 Dimas Abdus Syukur (god1mas)`. Android package metadata supplies the installed version. Flutter's license page displays third-party notices. No repository LICENSE file was present; the app makes no claim over third-party packages, fonts, or assets.
- Android version increased from `1.4.1+6` to `1.4.2+7`. The application ID and SQLite V5 schema did not change. The existing production signing key was reused; no key was created or replaced.

## Verified production APK (2026-11-17)

- Path: `C:\Project\PresensiKu\releases\production\KelasKu-v1.4.2-production.apk`.
- Size: **59,605,421 bytes**. APK SHA-256: **`BCEEFF4A6A745CEE230E7D214049A683BAE5528640D764BBEF8942C1FCDF9548`**.
- `aapt dump badging`: package `com.presensiku.presensiku`, version `1.4.2`/code `7`, launcher `KelasKu`, icon resources at five densities, minimum API 24, target API 36.
- `apksigner verify`: valid v2 signature; one RSA 4096 signer. Certificate SHA-256: **`500b34efbb470855b3fbb9ec721eeb2a1be9af0e2d4fdb979d10b9b46889bda1`**, identical to 1.4.1 production and different from the QA debug certificate.
- `zipalign -c -v 4`: verification successful. The previous `KelasKu-v1.4.1-production.apk` and read-only `KelasKu-1.4.0+5-qa.apk` remain separate and unchanged.
- The first v1.4.2 helper-script run built a correctly signed APK but its multi-line fingerprint check rejected the valid result. That check was corrected. The already built APK was independently checked for package, version, signature, and alignment before it was copied to the final path; no second password entry or key change was required.

## Automated verification and limits

- `dart format lib test`: 66 files, no further changes. `flutter analyze --no-pub`: no issues. Complete `flutter test --no-pub --reporter expanded`: **65/65 passed**. `flutter build apk --debug --no-pub` also compiled the Android package-version bridge.
- Tests cover guide expansion and education terminology, About metadata and license access, settings navigation/Back, 320/393 px layouts, and the existing SQLite migration, backup, attendance, grading, and Excel flows.
- `adb devices -l` found no device. Fresh installation, production 1.4.1→1.4.2 in-place update, local-data retention, native save/share, and real V5 `.pkbackup` restore remain **PENDING**. The matching certificate and higher version code support update compatibility from the specific 1.4.1 production APK, but device acceptance has not been observed.
- A debug-signed QA installation cannot be updated in place with this production-signed APK. Do not uninstall, clear, or force-update that phone app. Back up first and follow [PRODUCTION_SIGNING.md](PRODUCTION_SIGNING.md) and [ANDROID_QA_CHECKLIST.md](ANDROID_QA_CHECKLIST.md).
