# KelasKu 1.3.0+4 — Android QA release

## Included changes

- Custom class colors, refined attendance UI, and Back navigation that preserves attendance drafts.
- Four-sheet grading Excel export, including Matriks Nilai.
- Aktif/Arsip views and confirmed restoration for global subjects and assessment categories. Restored records keep their original IDs; deliberate class unlinks remain archived.
- Presensi/Penilaian selection for Riwayat and Rekap & Laporan, grading-history filters, and responsive attendance-history filters.

## Verified artifact

- APK: `C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk`
- Size: 59,243,957 bytes.
- APK SHA-256: `E1C3B2424AE9CBA865FD4EA3207717DDDC65C0CC9B3A7D77E6CD74B7003F4256`.
- Package: `com.presensiku.presensiku`; version name `1.3.0`; version code `4`; launcher label `KelasKu`; minimum API 24; target API 36.
- `apksigner verify` passed with APK Signature Scheme v2; `zipalign -c -v 4` passed.
- Signing: existing Android Debug certificate SHA-256 `e25c8af199928e96c035770b423bf522680c8aef3449e153555148e5ff2d1e3e`. This matches the preserved KelasKu 1.2.0+3 APK at `C:\Project\PresensiKu\build\app\outputs\flutter-apk\KelasKu-1.2.0+3-qa.apk` (code 3). The final build explicitly used the pre-existing ignored `.tooling/android-user/debug.keystore`; no production key was created or committed.
- The first intermediate 1.3.0 build used a different Windows-profile debug key. It was overwritten by the verified final artifact above. Do not distribute that intermediate artifact.

## Verification and upgrade limits

- `dart format lib test`: no source changes; `flutter analyze --no-pub`: no issues; complete `flutter test --no-pub --reporter expanded`: 50/50 passed; `flutter build apk --release --no-pub`: succeeded.
- Automated coverage includes V1→V2→V3 SQLite migration, V1/V2/V3 backup handling, attendance and grading regression, four-sheet Excel export, archive recovery, Back navigation, and narrow history layouts.
- No Android device was connected. The installed app's actual signing certificate and in-place upgrade behavior have not been checked. Back up data before updating. Never uninstall to force an update.
- Native file picker, share sheet, offline device operation, and rendered layouts remain pending in `ANDROID_QA_CHECKLIST.md`.

For a device whose installed APK is signed with the matching certificate, connect it with USB debugging and run:

```powershell
& 'C:\Android\Sdk\platform-tools\adb.exe' install -r 'C:\Project\PresensiKu\build\app\outputs\flutter-apk\app-release.apk'
```

This is a release-mode **QA** APK signed with a debug key. Production distribution requires an owner-controlled production signing key and a separate migration plan for existing installs.
