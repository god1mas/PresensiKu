import 'package:presensiku/core/education/academic_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/roster_repository.dart';

class StudentManagementScreen extends StatelessWidget {
  const StudentManagementScreen({super.key, required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AcademicText('Daftar siswa')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [StudentListPanel(classId: classId)],
    ),
  );
}

class StudentListPanel extends ConsumerStatefulWidget {
  const StudentListPanel({super.key, required this.classId, this.onChanged});
  final int classId;
  final VoidCallback? onChanged;

  @override
  ConsumerState<StudentListPanel> createState() => _StudentListPanelState();
}

class _StudentListPanelState extends ConsumerState<StudentListPanel> {
  String search = '';
  int revision = 0;

  void refresh() {
    setState(() => revision++);
    ref.invalidate(dashboardSummaryProvider);
    widget.onChanged?.call();
  }

  Future<void> editStudent([Student? student]) async {
    var name = student?.name ?? '';
    var number = student?.attendanceNumber.toString() ?? '';
    var nis = student?.nis ?? '';
    final result = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AcademicText(student == null ? 'Tambah siswa' : 'Ubah siswa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                decoration: InputDecoration(
                  labelText: educationTerms(context).university
                      ? 'Nama Lengkap Mahasiswa'
                      : 'Nama lengkap',
                ),
              ),
              const SizedBox(height: AppSpace.base),
              TextFormField(
                initialValue: number,
                onChanged: (value) => number = value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: educationTerms(context).translate('Nomor absen'),
                ),
              ),
              const SizedBox(height: AppSpace.base),
              TextFormField(
                initialValue: nis,
                onChanged: (value) => nis = value,
                decoration: InputDecoration(
                  labelText: educationTerms(context)
                      .translate('NIS/NISN (opsional)'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (student != null)
            TextButton(
              onPressed: () async {
                final confirmed = await showAcademicDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) => AlertDialog(
                    title: const AcademicText('Arsipkan siswa?'),
                    content: const AcademicText(
                      'Siswa akan disembunyikan dari daftar aktif. Riwayat absensi tetap tersimpan.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmContext, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(confirmContext, true),
                        child: const Text('Arsipkan'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(rosterRepositoryProvider)
                      .archiveStudent(student.id);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Arsipkan'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final parsed = int.tryParse(number);
                if (parsed == null) {
                  throw const FormatException(
                    'Nomor absen harus berupa angka.',
                  );
                }
                final repository = ref.read(rosterRepositoryProvider);
                if (student == null) {
                  await repository.addStudent(
                    classId: widget.classId,
                    name: name,
                    attendanceNumber: parsed,
                    nis: nis,
                  );
                } else {
                  await repository.updateStudent(
                    id: student.id,
                    name: name,
                    attendanceNumber: parsed,
                    nis: nis,
                  );
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(_message(error))));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == true && mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(rosterRepositoryProvider);
    return FutureBuilder<List<Student>>(
      key: ValueKey('$revision:$search'),
      future: repository.students(widget.classId, search: search),
      builder: (context, snapshot) {
        final students = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AcademicText(
                    'Daftar siswa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AcademicText(
                  '${students.length} siswa',
                  style: const TextStyle(color: AppColors.blue),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.base),
            TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: educationTerms(context).translate('Cari nama siswa'),
              ),
            ),
            const SizedBox(height: AppSpace.base),
            if (snapshot.hasError)
              const AcademicText('Daftar siswa belum dapat dimuat.')
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (students.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                child: Text(
                  search.isEmpty ? 'Belum ada siswa' : 'Siswa tidak ditemukan',
                ),
              )
            else
              for (final student in students)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.iceBlue,
                    child: Text(_initials(student.name)),
                  ),
                  title: Text(student.name),
                  subtitle: Text(
                    educationTerms(context).university
                        ? 'NIM ${student.nis ?? 'belum diisi'} ? No. ${student.attendanceNumber}'
                        : 'No. ${student.attendanceNumber.toString().padLeft(2, '0')}',
                  ),
                  trailing: IconButton(
                    onPressed: () => editStudent(student),
                    tooltip: 'Ubah ${student.name}',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.blue,
                    ),
                  ),
                ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: editStudent,
                child: const AcademicText('+ Tambah siswa'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ClassSubjectPanel extends ConsumerStatefulWidget {
  const ClassSubjectPanel({super.key, required this.classId});
  final int classId;

  @override
  ConsumerState<ClassSubjectPanel> createState() => _ClassSubjectPanelState();
}

class _ClassSubjectPanelState extends ConsumerState<ClassSubjectPanel> {
  int revision = 0;

  Future<void> assign() async {
    final repository = ref.read(rosterRepositoryProvider);
    final all = await repository.subjects();
    final linked = await repository.subjectsForClass(widget.classId);
    final linkedIds = linked.map((s) => s.id).toSet();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: AcademicText('Atur mata pelajaran kelas')),
            for (final subject in linked)
              ListTile(
                leading: const Icon(Icons.book_outlined, color: AppColors.blue),
                title: Text(subject.name),
                subtitle: const Text('Terhubung ke kelas'),
                trailing: IconButton(
                  tooltip: 'Lepas ${subject.name} dari kelas',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    try {
                      await repository.unassignSubject(
                        classId: widget.classId,
                        subjectId: subject.id,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) setState(() => revision++);
                    } catch (error) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(_message(error))),
                        );
                      }
                    }
                  },
                ),
              ),
            for (final subject in all.where((s) => !linkedIds.contains(s.id)))
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(subject.name),
                onTap: () async {
                  try {
                    await repository.assignSubject(
                      classId: widget.classId,
                      subjectId: subject.id,
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (mounted) setState(() => revision++);
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(
                        sheetContext,
                      ).showSnackBar(SnackBar(content: Text(_message(error))));
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const AcademicText('Kelola mata pelajaran'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(periodPath(context, '/mata-pelajaran')).then((_) {
                  if (mounted) setState(() => revision++);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Subject>>(
    key: ValueKey(revision),
    future: ref
        .watch(rosterRepositoryProvider)
        .subjectsForClass(widget.classId),
    builder: (context, snapshot) {
      final subjects = snapshot.data ?? [];
      return Container(
        padding: const EdgeInsets.all(AppSpace.base),
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(AppRadius.featured),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: AppColors.blue),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: AcademicText(
                    'Mata pelajaran',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(onPressed: assign, child: const Text('Atur')),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              subjects.isEmpty
                  ? 'Tambahkan mata pelajaran untuk mulai mengelola kelas.'
                  : '${subjects.length} mata pelajaran di kelas ini',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.md),
            if (snapshot.hasError)
              const AcademicText('Mata pelajaran belum dapat dimuat.')
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (subjects.isEmpty)
              const AcademicText('Belum ada mata pelajaran untuk kelas ini.')
            else
              for (final subject in subjects) ...[
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => context.push(
                      periodPath(
                        context,
                        '/kelas/${widget.classId}/mapel/${subject.id}',
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.base),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.book_outlined,
                            color: AppColors.blue,
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              subject.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
          ],
        ),
      );
    },
  );
}

class SubjectScreen extends ConsumerStatefulWidget {
  const SubjectScreen({super.key});

  @override
  ConsumerState<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends ConsumerState<SubjectScreen> {
  int revision = 0;
  bool showingArchive = false;

  Future<void> restore(Subject subject) async {
    final confirmed = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AcademicText('Pulihkan mata pelajaran?'),
        content: Text(
          '${subject.name} dan relasi kelas yang masih berlaku akan diaktifkan kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(rosterRepositoryProvider).restoreSubject(subject.id);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AcademicText('Mata pelajaran dipulihkan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }

  Future<void> edit([Subject? subject]) async {
    var name = subject?.name ?? '';
    final result = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          subject == null ? 'Tambah mata pelajaran' : 'Ubah mata pelajaran',
        ),
        content: TextFormField(
          initialValue: name,
          onChanged: (value) => name = value,
          decoration: InputDecoration(
            labelText: educationTerms(context).translate('Nama mata pelajaran'),
          ),
        ),
        actions: [
          if (subject != null)
            TextButton(
              onPressed: () async {
                await ref
                    .read(rosterRepositoryProvider)
                    .archiveSubject(subject.id);
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Arsipkan'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final repository = ref.read(rosterRepositoryProvider);
                if (subject == null) {
                  await repository.addSubject(name);
                } else {
                  await repository.renameSubject(subject.id, name);
                }
                ref.invalidate(dashboardSummaryProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(_message(error))));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == true && mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AcademicText('Mata pelajaran')),
    body: FutureBuilder<List<Subject>>(
      key: ValueKey(revision),
      future: ref
          .watch(rosterRepositoryProvider)
          .subjects(includeArchived: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: AcademicText('Mata pelajaran belum dapat dimuat.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final subjects = snapshot.data!
            .where(
              (item) => showingArchive
                  ? item.archivedAt != null
                  : item.archivedAt == null,
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.iceBlue,
                borderRadius: BorderRadius.circular(AppRadius.featured),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 48,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  AcademicText(
                    '${subjects.length} mata pelajaran',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Aktif')),
                ButtonSegment(value: true, label: Text('Arsip')),
              ],
              selected: {showingArchive},
              onSelectionChanged: (value) =>
                  setState(() => showingArchive = value.first),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              showingArchive ? 'Mata pelajaran diarsipkan' : 'Daftar pelajaran',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.base),
            if (subjects.isEmpty)
              Text(
                showingArchive
                    ? 'Arsip mata pelajaran kosong'
                    : 'Belum ada mata pelajaran',
              ),
            for (var index = 0; index < subjects.length; index++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: showingArchive
                        ? AppColors.line
                        : AppColors.lavender,
                    child: Text('${index + 1}'.padLeft(2, '0')),
                  ),
                  title: Text(subjects[index].name),
                  subtitle: showingArchive ? const Text('Diarsipkan') : null,
                  trailing: showingArchive
                      ? TextButton(
                          onPressed: () => restore(subjects[index]),
                          child: const Text('Pulihkan'),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: showingArchive ? null : () => edit(subjects[index]),
                ),
              ),
          ],
        );
      },
    ),
    bottomNavigationBar: showingArchive
        ? null
        : Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: FilledButton(
              onPressed: edit,
              child: const AcademicText('+ Tambah mata pelajaran'),
            ),
          ),
  );
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

String _message(Object error) {
  if (error is FormatException) return error.message;
  if (error.toString().contains('UNIQUE constraint failed')) {
    return 'Data sudah digunakan.';
  }
  return 'Data belum dapat disimpan. Coba lagi.';
}
