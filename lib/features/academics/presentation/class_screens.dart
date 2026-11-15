import 'package:presensiku/core/education/academic_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/class_colors.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/class_repository.dart';
import 'roster_screens.dart';

class ClassListScreen extends ConsumerStatefulWidget {
  const ClassListScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  ConsumerState<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends ConsumerState<ClassListScreen> {
  int? selectedPeriodId;
  String search = '';
  int revision = 0;

  void refresh() {
    setState(() => revision++);
    ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> addPeriod() async {
    var year = '';
    var semester = 'ganjil';
    final result = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah periode akademik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => year = value,
                decoration: const InputDecoration(
                  labelText: 'Tahun ajaran',
                  hintText: '2026/2027',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: semester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: const [
                  DropdownMenuItem(value: 'ganjil', child: Text('Ganjil')),
                  DropdownMenuItem(value: 'genap', child: Text('Genap')),
                ],
                onChanged: (value) =>
                    setDialogState(() => semester = value ?? 'ganjil'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final id = await ref
                      .read(classRepositoryProvider)
                      .createPeriod(yearLabel: year, semester: semester);
                  selectedPeriodId = id;
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
      ),
    );
    if (result == true && mounted) refresh();
  }

  Future<void> addClass(int periodId) async {
    var name = '';
    var colorIndex = await ref.read(classRepositoryProvider).nextColorIndex();
    if (!mounted) return;
    final result = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah kelas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => name = value,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nama kelas',
                    hintText: 'VII A',
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                ClassColorPicker(
                  value: colorIndex,
                  onChanged: (value) =>
                      setDialogState(() => colorIndex = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(classRepositoryProvider)
                      .createClass(
                        periodId: periodId,
                        name: name,
                        colorIndex: colorIndex,
                      );
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
      ),
    );
    if (result == true && mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(classRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 98,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.selectionMode ? 'Pilih Kelas' : 'Ruang Kelasmu',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              widget.selectionMode
                  ? 'Pilih kelas untuk membuka mata pelajaran.'
                  : 'Semua kelas di satu tempat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<AcademicPeriod>>(
        key: ValueKey(revision),
        future: repository.periods(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Periode akademik belum dapat dimuat.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final periods = snapshot.data!;
          if (periods.isEmpty) {
            return _EmptyClasses(onAdd: addPeriod, message: 'Belum ada kelas');
          }
          final chosen =
              periods.where((p) => p.id == selectedPeriodId).firstOrNull ??
              periods.first;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.base,
                  AppSpace.lg,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(chosen.id),
                        initialValue: chosen.id,
                        decoration: const InputDecoration(
                          labelText: 'Periode akademik',
                        ),
                        items: periods
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${p.label}${p.isActive ? ' · Aktif' : ''}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) =>
                            setState(() => selectedPeriodId = id),
                      ),
                    ),
                    IconButton(
                      onPressed: addPeriod,
                      tooltip: 'Tambah periode',
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              if (!chosen.isActive)
                TextButton.icon(
                  onPressed: () async {
                    await repository.activatePeriod(chosen.id);
                    refresh();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Jadikan periode aktif'),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.base,
                ),
                child: TextField(
                  onChanged: (value) => setState(() => search = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari kelas',
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<SchoolClass>>(
                  key: ValueKey('${chosen.id}:$revision:$search'),
                  future: repository.classes(chosen.id, search: search),
                  builder: (context, classSnapshot) {
                    if (classSnapshot.hasError) {
                      return const Center(
                        child: Text('Daftar kelas belum dapat dimuat.'),
                      );
                    }
                    if (!classSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final classes = classSnapshot.data!;
                    if (classes.isEmpty) {
                      return _EmptyClasses(
                        onAdd: () => addClass(chosen.id),
                        message: search.isEmpty
                            ? 'Belum ada kelas'
                            : 'Kelas tidak ditemukan',
                      );
                    }
                    Future<void> open(SchoolClass item) async {
                      await context.push(
                        periodPath(
                          context,
                          '/kelas/${item.id}',
                          periodId: chosen.id,
                        ),
                      );
                      if (mounted) refresh();
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg,
                      ),
                      children: [
                        if (search.isEmpty) ...[
                          Text(
                            'Kelas favorit',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpace.base),
                          InkWell(
                            onTap: () => open(classes.first),
                            child: Container(
                              height: 148,
                              padding: const EdgeInsets.all(AppSpace.lg),
                              decoration: BoxDecoration(
                                color: classColor(classes.first.colorIndex)
                                    .tint,
                                border: Border.all(
                                  color: classColor(classes.first.colorIndex)
                                      .accent
                                      .withValues(alpha: 0.25),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.featured,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chosen.yearLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: classColor(
                                            classes.first.colorIndex,
                                          ).accent,
                                        ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    classes.first.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge,
                                  ),
                                  AcademicText(
                                    '${classes.first.studentCount} siswa',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Semua kelas',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${classes.length} kelas',
                              style: const TextStyle(color: AppColors.blue),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.base),
                        for (final item in classes)
                          Card(
                            color: classColor(item.colorIndex).tint,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: classColor(item.colorIndex)
                                    .accent,
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(item.name),
                              subtitle: AcademicText(
                                '${item.studentCount} siswa',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => open(item),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<AcademicPeriod>>(
        future: repository.periods(),
        builder: (context, snapshot) =>
            snapshot.hasData && snapshot.data!.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.lg,
                  AppSpace.base,
                ),
                child: FilledButton(
                  onPressed: () {
                    final periods = snapshot.data!;
                    final chosen =
                        periods
                            .where((p) => p.id == selectedPeriodId)
                            .firstOrNull ??
                        periods.first;
                    addClass(chosen.id);
                  },
                  child: const Text('+ Tambah kelas'),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  int revision = 0;

  Future<void> rename(SchoolClass item) async {
    var name = item.name;
    var colorIndex = item.colorIndex;
    final result = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ubah kelas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: item.name,
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(labelText: 'Nama kelas'),
                ),
                const SizedBox(height: AppSpace.lg),
                ClassColorPicker(
                  value: colorIndex,
                  onChanged: (value) =>
                      setDialogState(() => colorIndex = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(classRepositoryProvider)
                      .updateClass(item.id, name, colorIndex);
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
      ),
    );
    if (result == true && mounted) setState(() => revision++);
  }

  Future<void> archive(SchoolClass item) async {
    final confirmed = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arsipkan kelas?'),
        content: AcademicText(
          'Kelas ${item.name} dan siswa aktifnya akan disembunyikan dari daftar. Riwayat absensi tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(classRepositoryProvider).archiveClass(item.id);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(classRepositoryProvider);
    return FutureBuilder<SchoolClass?>(
      key: ValueKey(revision),
      future: repository.classById(widget.id),
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(
          title: const Text('Detail Kelas'),
          actions: [
            if (snapshot.data != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') {
                    rename(snapshot.data!);
                  } else {
                    archive(snapshot.data!);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Ubah kelas dan warna'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text('Arsipkan kelas'),
                  ),
                ],
              ),
          ],
        ),
        body: !snapshot.hasData && !snapshot.hasError
            ? const Center(child: CircularProgressIndicator())
            : snapshot.data == null
            ? const Center(child: Text('Kelas tidak ditemukan.'))
            : ListView(
                padding: const EdgeInsets.all(AppSpace.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpace.base),
                    decoration: BoxDecoration(
                      color: classColor(snapshot.data!.colorIndex).tint,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border(
                        left: BorderSide(
                          color: classColor(snapshot.data!.colorIndex).accent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: classColor(snapshot.data!.colorIndex)
                              .accent,
                          child: const Icon(
                            Icons.school_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(
                            snapshot.data!.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  AcademicText(
                    'Pilih mata pelajaran untuk membuka area kerja kelas.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  ClassSubjectPanel(classId: widget.id),
                  const SizedBox(height: AppSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(AppRadius.featured),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              color: AppColors.blue,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            AcademicText(
                              'Siswa',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.md),
                        AcademicText(
                          '${snapshot.data!.studentCount} siswa aktif',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        const AcademicText(
                          'Lihat, cari, dan ubah data siswa kelas ini.',
                        ),
                        const SizedBox(height: AppSpace.base),
                        FilledButton.icon(
                          onPressed: () async {
                            await context.push(
                              periodPath(context, '/kelas/${widget.id}/siswa'),
                            );
                            if (mounted) setState(() => revision++);
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const AcademicText('Kelola siswa'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ClassColorPicker extends StatelessWidget {
  const ClassColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Warna kelas', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpace.sm),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < classColors.length; index++)
            Tooltip(
              message: classColors[index].name,
              child: Semantics(
                label: 'Warna ${classColors[index].name}',
                selected: value == index,
                child: InkWell(
                  onTap: () => onChanged(index),
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: classColors[index].accent,
                    child: value == index
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpace.sm),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: classColor(value).tint,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Text(
          'Pratinjau · ${classColor(value).name}',
          style: TextStyle(
            color: classColor(value).accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _EmptyClasses extends StatelessWidget {
  const _EmptyClasses({required this.onAdd, required this.message});
  final VoidCallback onAdd;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.school_outlined, size: 64, color: AppColors.blue),
        const SizedBox(height: AppSpace.base),
        Text(message, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.lg),
        FilledButton(onPressed: onAdd, child: const Text('Tambah')),
      ],
    ),
  );
}

String _message(Object error) {
  if (error is FormatException) return error.message;
  if (error.toString().contains('UNIQUE constraint failed')) {
    return 'Nama sudah digunakan pada periode ini.';
  }
  return 'Data belum dapat disimpan. Coba lagi.';
}
