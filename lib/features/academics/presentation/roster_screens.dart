import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/roster_repository.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(student == null ? 'Tambah siswa' : 'Ubah siswa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
              ),
              const SizedBox(height: AppSpace.base),
              TextFormField(
                initialValue: number,
                onChanged: (value) => number = value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor absen'),
              ),
              const SizedBox(height: AppSpace.base),
              TextFormField(
                initialValue: nis,
                onChanged: (value) => nis = value,
                decoration: const InputDecoration(
                  labelText: 'NIS/NISN (opsional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (student != null)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('Arsipkan siswa?'),
                    content: const Text(
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
                  child: Text(
                    'Daftar siswa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${students.length} siswa',
                  style: const TextStyle(color: AppColors.blue),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.base),
            TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama siswa',
              ),
            ),
            const SizedBox(height: AppSpace.base),
            if (snapshot.hasError)
              const Text('Daftar siswa belum dapat dimuat.')
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
                    'No. ${student.attendanceNumber.toString().padLeft(2, '0')}',
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
                child: const Text('+ Tambah siswa'),
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
            const ListTile(title: Text('Pilih mata pelajaran')),
            for (final subject in all.where((s) => !linkedIds.contains(s.id)))
              ListTile(
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
              title: const Text('Kelola mata pelajaran'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/mata-pelajaran').then((_) {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mata pelajaran',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: assign, child: const Text('Atur')),
            ],
          ),
          if (subjects.isEmpty)
            const Text('Belum ada mata pelajaran untuk kelas ini.')
          else
            Wrap(
              spacing: 8,
              children: [
                for (final subject in subjects)
                  InputChip(
                    label: Text(subject.name),
                    onDeleted: () async {
                      await ref
                          .read(rosterRepositoryProvider)
                          .unassignSubject(
                            classId: widget.classId,
                            subjectId: subject.id,
                          );
                      if (mounted) setState(() => revision++);
                    },
                  ),
              ],
            ),
        ],
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

  Future<void> edit([Subject? subject]) async {
    var name = subject?.name ?? '';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          subject == null ? 'Tambah mata pelajaran' : 'Ubah mata pelajaran',
        ),
        content: TextFormField(
          initialValue: name,
          onChanged: (value) => name = value,
          decoration: const InputDecoration(labelText: 'Nama mata pelajaran'),
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
    appBar: AppBar(title: const Text('Mata pelajaran')),
    body: FutureBuilder<List<Subject>>(
      key: ValueKey(revision),
      future: ref.watch(rosterRepositoryProvider).subjects(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Mata pelajaran belum dapat dimuat.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final subjects = snapshot.data!;
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
                  Text(
                    '${subjects.length} mata pelajaran',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              'Daftar pelajaran',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.base),
            if (subjects.isEmpty) const Text('Belum ada mata pelajaran'),
            for (var index = 0; index < subjects.length; index++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lavender,
                    child: Text('${index + 1}'.padLeft(2, '0')),
                  ),
                  title: Text(subjects[index].name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => edit(subjects[index]),
                ),
              ),
          ],
        );
      },
    ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: FilledButton(
        onPressed: edit,
        child: const Text('+ Tambah mata pelajaran'),
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
