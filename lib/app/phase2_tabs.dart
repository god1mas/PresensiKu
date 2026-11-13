import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/app_database.dart';
import '../core/design/tokens.dart';
import '../features/onboarding/data/profile_repository.dart';

class ClassesTab extends ConsumerWidget {
  const ClassesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider).database;
    return FutureBuilder(
      future: db.query(
        'school_class',
        where: 'archived_at IS NULL',
        orderBy: 'name COLLATE NOCASE',
      ),
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(title: const Text('Ruang Kelasmu')),
          body: snapshot.hasError
              ? const Center(child: Text('Daftar kelas belum dapat dimuat.'))
              : !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : snapshot.data!.isEmpty
              ? const _EmptyState(
                  icon: Icons.school_outlined,
                  title: 'Belum ada kelas',
                  detail: 'Kelas yang kamu buat akan tampil di sini.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final row = snapshot.data![index];
                    return Card(
                      child: ListTile(
                        title: Text(row['name'] as String),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/kelas/${row['id'] as int}'),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class ClassReadOnlyDetail extends ConsumerWidget {
  const ClassReadOnlyDetail({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider).database;
    return FutureBuilder(
      future: db.query(
        'school_class',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      ),
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/kelas')),
          title: Text(
            snapshot.hasData && snapshot.data!.isNotEmpty
                ? snapshot.data!.single['name'] as String
                : 'Detail kelas',
          ),
        ),
        body: !snapshot.hasData
            ? const Center(child: CircularProgressIndicator())
            : snapshot.data!.isEmpty
            ? const Center(child: Text('Kelas tidak ditemukan.'))
            : Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text('Kelas ${snapshot.data!.single['name'] as String}'),
              ),
      ),
    );
  }
}

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider).database;
    return FutureBuilder(
      future: db.query(
        'attendance_session',
        where: "state = 'completed'",
        orderBy: 'date DESC, meeting_number DESC',
      ),
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(title: const Text('Riwayat Absensi')),
        body: snapshot.hasError
            ? const Center(child: Text('Riwayat belum dapat dimuat.'))
            : !snapshot.hasData
            ? const Center(child: CircularProgressIndicator())
            : snapshot.data!.isEmpty
            ? const _EmptyState(
                icon: Icons.history,
                title: 'Riwayat kosong',
                detail: 'Absensi yang tersimpan akan tampil di sini.',
              )
            : ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final row = snapshot.data![index];
                  return ListTile(
                    title: Text(
                      '${row['subject_name_snapshot'] as String} · ${row['class_name_snapshot'] as String}',
                    ),
                    subtitle: Text(row['date'] as String),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/riwayat/${row['id'] as int}'),
                  );
                },
              ),
      ),
    );
  }
}

class HistoryReadOnlyDetail extends ConsumerWidget {
  const HistoryReadOnlyDetail({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider).database;
    return FutureBuilder(
      future: db.query(
        'attendance_record',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'attendance_number_snapshot',
      ),
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/riwayat')),
          title: const Text('Detail Absensi'),
        ),
        body: snapshot.hasError
            ? const Center(child: Text('Detail belum dapat dimuat.'))
            : !snapshot.hasData
            ? const Center(child: CircularProgressIndicator())
            : snapshot.data!.isEmpty
            ? const Center(child: Text('Belum ada catatan kehadiran.'))
            : ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final row = snapshot.data![index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (row['attendance_number_snapshot'] as int).toString(),
                      ),
                    ),
                    title: Text(row['student_name_snapshot'] as String),
                    trailing: Text(row['status'] as String? ?? '—'),
                  );
                },
              ),
      ),
    );
  }
}

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    TeacherProfile profile,
  ) async {
    final name = TextEditingController(text: profile.name);
    final school = TextEditingController(text: profile.schoolName);
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Profil Guru'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama guru'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama guru wajib diisi'
                    : null,
              ),
              const SizedBox(height: AppSpace.base),
              TextFormField(
                controller: school,
                decoration: const InputDecoration(
                  labelText: 'Nama sekolah (opsional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref
                    .read(profileRepositoryProvider)
                    .save(name: name.text, schoolName: school.text);
                ref.invalidate(teacherProfileProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Profil belum tersimpan. Coba lagi.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    name.dispose();
    school.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(teacherProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Profil belum dapat dimuat.')),
        data: (data) => data == null
            ? const Center(child: Text('Profil guru belum tersedia.'))
            : ListView(
                padding: const EdgeInsets.all(AppSpace.lg),
                children: [
                  Text(
                    'Semuanya diatur dari sini.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Card(
                    color: AppColors.blue,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          data.name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((word) => word[0].toUpperCase())
                              .join(),
                          style: const TextStyle(color: AppColors.blue),
                        ),
                      ),
                      title: Text(
                        data.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        data.schoolName ?? 'Nama sekolah belum diisi',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Profil & akademik',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Profil guru'),
                    subtitle: const Text('Nama dan informasi sekolah'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editProfile(context, ref, data),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Tahun ajaran'),
                    subtitle: const Text('Atur periode aktif'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/periode'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Mata pelajaran'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/mata-pelajaran'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.summarize_outlined),
                    title: const Text('Rekap dan laporan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/laporan'),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Data di perangkat',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ListTile(
                    leading: const Icon(Icons.save_alt_outlined),
                    title: const Text('Cadangkan data'),
                    subtitle: const Text('Simpan salinan untuk berjaga-jaga'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/cadangan'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore),
                    title: const Text('Pulihkan data'),
                    subtitle: const Text('Ambil salinan dari file cadangan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pulihkan'),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.base),
                    decoration: BoxDecoration(
                      color: AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Text(
                      'Data disimpan di HP ini. Cadangkan secara berkala, ya!',
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'KelasKu',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'by god1mas',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
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

class AttendanceGateScreen extends StatelessWidget {
  const AttendanceGateScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => context.go('/beranda')),
      title: const Text('Mulai absensi'),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 64, color: AppColors.blue),
            const SizedBox(height: AppSpace.base),
            const Text('Pilih kelas untuk menyiapkan absensi.'),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: () => context.go('/kelas'),
              child: const Text('Lihat kelas'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.blue),
          const SizedBox(height: AppSpace.base),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
