# Android manual QA

Status: PENDING for KelasKu 1.2.0+3. No connected Android device was available during APK verification. Automated widget tests use desktop SQLite and test adapters for file delivery; they do not verify Android system pickers or sharing.

Record the device model, Android version, APK SHA-256, result, and any screenshot or error for each check. Use disposable sample data for restore checks.

- [ ] Compare the previous APK and KelasKu signing fingerprints; if they match, install with adb install -r over the existing app. Never uninstall to force the update. Record whether profile, classes, students, attendance, grades, and backups remain after restart.
- [ ] Install the APK and launch KelasKu from its branded launcher icon. Confirm the label, splash title, onboarding, and subtle by god1mas signature.
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

## KelasKu class workflow and device layout (PENDING)

- [ ] Tap Mulai Kelas and verify Pilih Kelas shows existing classes without creating a new class. Test the no-class state and add a class there.
- [ ] Open Detail Kelas, verify Mata Pelajaran is prominent and selectable without X icons, and verify Kelola siswa opens the dedicated view/search/add/edit page. Return and confirm the active student count refreshes.
- [ ] Select a subject and verify both Presensi and Penilaian actions work. In Presensi setup, verify the selected class and subject remain selected; record, edit, and reopen a session. In Penilaian, enter grades and verify recap after restart.
- [ ] Save and share attendance and grade Excel files; verify KelasKu filenames, workbook contents, Android document picker, and share sheet.
- [ ] Create a KelasKu .pkbackup, restore it, and also restore a previous PresensiKu .pkbackup into disposable sample data. Verify all expected records survive app restart.
- [ ] Repeat class, presensi, penilaian, Excel, and backup flows in airplane mode. Check small screens, large text, keyboard, scroll reachability, safe areas, and overflow against Figma.

## V4 grading and upgrade checks (pending device verification)

- [ ] Before installing V4 over V1, save a V1 `.pkbackup`, copy it off the device, and confirm it can be inspected. Retain the previous APK until the upgrade is accepted.
- [ ] Upgrade the installed V1 app in place. Confirm profile, periods, classes, students, subjects, attendance history, and reports remain unchanged after restart.
- [ ] Follow Kelas → Detail Kelas → Mata Pelajaran → Detail Mata Pelajaran. Open both Presensi and Penilaian without changing the four main tabs.
- [ ] Create Tugas, Ulangan, UTS, UAS, Sikap, and a custom category assessment. Check dates, BAB, title, description, maximum score, required flag, edit, archive, and deletion confirmation.
- [ ] Enter numeric zero, leave a score blank, mark another EX, and correct each. Confirm progress, keyboard behavior, out-of-range validation, and unsaved-change confirmation after Android Back.
- [ ] Configure weights totaling 99%, 100%, and 101%; only 100% should save. Check 0% is allowed, changes update recap, and the audit persists after restart.
- [ ] Compare final and provisional grades for incomplete, all-EX, and completed students. Confirm only complete final grades affect class average, highest/lowest, and distribution.
- [ ] Save and share the three-sheet grade XLSX through Android UI. Open it in a spreadsheet app and check blank, numeric 0, EX, year/semester, and weights.
- [ ] Back up V2 data, modify grades, restore it, and verify attendance plus grades. Restore a V1 backup into V2 and confirm grading records are empty while attendance survives. Cancel restore once and test a corrupt file.
- [ ] Use airplane mode for the full grading flow. Compare V4 frames 72:112–72:340 and 77:112/77:140 with the rendered app at small and large text sizes.

Schema V2 migration, V1/V2 backup formats, and the 40-student flow are covered by automated tests. Android device and native picker/share behavior remain unverified until these checks are recorded on a device.
