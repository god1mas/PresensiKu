# KelasKu production signing and migration

The production key is permanent. Keep it outside this repository at `%USERPROFILE%\.android\kelasku\kelasku-release.p12`. The alias is `kelasku_release`; the script creates an RSA 4096-bit PKCS#12 key valid for 36,500 days. Only the owner enters its password in a local interactive terminal. Passwords are passed to Gradle through the build process environment with its persistent daemon disabled, then removed from that PowerShell session afterward. No password or keystore belongs in Git, chat, a command argument, a log, or an APK release note.

## Build

From the project root, run `& .\scripts\build_production.ps1` in an interactive PowerShell terminal. On first run, keytool asks for the permanent password and certificate identity. The script then prompts for the password again to build `1.4.1+6`. It verifies the APK signature differs from the known QA debug certificate before copying the result to `releases/production/KelasKu-v1.4.1-production.apk`. The script refuses to overwrite an existing production artifact or key.

Gradle release builds require `KELASKU_RELEASE_KEYSTORE` and `KELASKU_KEYSTORE_PASSWORD` environment variables and fail when they are missing. The release variant uses only the `production` signing config. Debug builds keep Android's debug signing. Do not use `flutter build apk --release` from another terminal unless these variables are set securely for that process.

## Protect the key

After creation, make at least two encrypted offline backups of the `.p12` file in separate locations. Store the password in a password manager separately from those copies. Record the alias, SHA-256 certificate fingerprint, key creation date, and backup locations in the owner's private records. Test recovery of a backup on a spare machine without changing the original key. Loss of this key can prevent updates to installations signed with it; publishing a replacement key under the same package ID is not a direct update path.

## Migration from QA signing

QA APKs use the Android Debug certificate SHA-256 `e25c8af199928e96c035770b423bf522680c8aef3449e153555148e5ff2d1e3e`. A production APK with a different certificate cannot update that package in place on an existing phone. Keep the QA APK and installed app intact.

1. In the QA app, create a `.pkbackup`, copy it off the phone, and retain a second copy. Record its checksum.
2. On a spare device or emulator, fresh-install the production APK and restore a real V5 `.pkbackup`. Check the teacher profile, academic years/semesters, classes, enrollments, attendance, grades, archives, and Excel exports after restart.
3. Only after that test succeeds, plan a separate owner-approved migration of the existing phone. Do not uninstall, clear data, or force an incompatible APK update during release verification.
4. Keep the QA-signed artifact and backup until the production device is accepted.

Physical-device migration is **PENDING** until it is performed and recorded. Automated SQLite and backup tests do not prove Android document-picker or phone restoration behavior.
