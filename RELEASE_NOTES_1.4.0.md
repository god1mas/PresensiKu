# KelasKu 1.4.0+5 — Android QA release

## Changes

- Education-level profile and terminology, including university NIM validation and text storage. Existing teacher profile data can be completed without reentry.
- School classes, rosters, subjects, and colors persist across Ganjil/Genap in one academic year. Attendance, assessments, grades, and weights stay in their actual semester. University classes and enrollment are semester-specific without automatic copying.
- Explicit period selection versus activation, historical attendance and grading access, and active-period dashboard counts.
- Class Aktif/Arsip recovery preserves the original class ID and history. Restoration of linked children follows archive provenance and rejects naming conflicts transactionally.
- Riwayat Penilaian search and compact class, subject, period, and date filters. University attendance XLSX detail and summary keep NIM as text, including leading zeros.

## Verified APK

- Path: `C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk`.
- Size: 59,588,113 bytes; SHA-256: `124730A4A3DC1B8719B8B05E9272DB2E9C56CEBA02B10F21547A4B67A9E813CC`.
- Android package `com.presensiku.presensiku`; version name `1.4.0`, code `5`; launcher label `KelasKu`; minimum API 24, target API 36.
- `flutter build apk --release --no-pub` succeeded. Android SDK `aapt` verified manifest identity and packaged launcher icon resources; `apksigner verify` confirmed APK Signature Scheme v2 and `zipalign -c -v 4` passed.
- Release-mode **QA APK signed with the existing Android Debug certificate**, SHA-256 `e25c8af199928e96c035770b423bf522680c8aef3449e153555148e5ff2d1e3e`. This exactly matches the preserved `KelasKu-1.3.0+4-qa.apk` certificate. No production key was generated or committed.

## Automated verification and limits

- `dart format lib test` completed; `flutter analyze --no-pub` found no issues; complete `flutter test --no-pub` passed **61/61** tests.
- Automated coverage includes populated V1/V2/V3 SQLite migration and backup compatibility, V5 semester mapping, repeated period switching/restart, Ganjil/Genap Meeting 1, dashboard scope, class archive restoration/conflicts, attendance, grading, four-sheet grade XLSX, two-sheet attendance XLSX, and a 40-student workflow.
- No Android device was connected. In-place installation, installed-app certificate, retained phone data, native picker/share, airplane mode, and rendered Figma layout remain **PENDING**. See `ANDROID_QA_CHECKLIST.md`.
- Back up phone data to an off-device `.pkbackup` before updating. If Android rejects the update, stop; do not uninstall or clear data. A matching previous QA APK certificate supports an in-place update, but the installed phone APK may have a different certificate.

## Installation for a matching QA-signed app

After backing up and comparing the installed certificate, copy the APK to the phone and open it, or connect USB debugging and run:

```powershell
& 'C:\Android\Sdk\platform-tools\adb.exe' install -r 'C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk'
```

This QA build is not production signed. Production distribution requires an owner-controlled key and an upgrade plan for existing installations.
