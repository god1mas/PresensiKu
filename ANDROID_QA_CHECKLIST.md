# Android manual QA

These checks are pending: no connected Android device or installed emulator was available during final verification. Automated widget tests use desktop SQLite and test adapters for file delivery; they do not verify Android system pickers or sharing.

Record the device model, Android version, APK SHA-256, result, and any screenshot or error for each check. Use disposable sample data for restore checks.

- [ ] Install the APK and launch PresensiKu from its branded launcher icon.
- [ ] On a fresh install, validate the required teacher name, save the optional school, and reach the dashboard. Relaunch and confirm onboarding is skipped.
- [ ] Create an academic period, class, two subjects, and 40 students. Check duplicate validation, sorting, searching, editing, and subject assignments.
- [ ] Record H/S/I/A, confirm bulk Hadir, close the app during a draft, reopen it, and confirm saved marks. Finish the session and verify dashboard totals.
- [ ] Open an existing session with the same class/subject/date/meeting key. Confirm it opens without overwriting or duplicating records.
- [ ] Correct saved attendance. Verify history, report totals, and percentages. Archive a student and switch periods; verify historical records remain available.
- [ ] Filter reports by class, subject, period, and inclusive date range. Test an empty result.
- [ ] Save an XLSX with the Android document picker and share it through an installed app. Cancel each flow once. Open the saved file in Excel or another spreadsheet reader and verify Detail Absensi and Rekap Absensi.
- [ ] Save a `.pkbackup`, change sample data, select the backup, cancel restore, and verify current data remains. Confirm restore and verify profile, periods, classes, students, subjects, assignments, sessions, and records after relaunch.
- [ ] Select a corrupt or incompatible backup and verify rejection without losing current data.
- [ ] Enable airplane mode and repeat normal attendance, reporting, local export, and backup tasks.
- [ ] Compare screens 01–16 and supporting states with the Figma design. Check small screens, large text, keyboard visibility, scrolling, safe areas, and H/S/I/A button spacing.
- [ ] Confirm Android back navigation and repeated save taps do not create duplicate records or leave blocked controls.

The current database schema is v1. Existing tests verify creation and reopening at v1; no upgrade from an earlier released schema exists to test yet.
