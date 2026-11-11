import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../onboarding/data/profile_repository.dart';
import '../data/backup_delivery.dart';
import '../data/backup_repository.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key, required this.restoreMode});
  final bool restoreMode;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool busy = false;

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> createBackup() async {
    setState(() => busy = true);
    try {
      final bytes = await ref.read(backupRepositoryProvider).create();
      final filename =
          'PresensiKu_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pkbackup';
      final saved = await ref
          .read(backupDeliveryProvider)
          .save(filename, bytes);
      if (saved) message('Cadangan data berhasil disimpan.');
    } catch (_) {
      message('Cadangan data belum berhasil dibuat.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restoreBackup() async {
    setState(() => busy = true);
    try {
      final bytes = await ref.read(backupDeliveryProvider).pick();
      if (bytes == null) return;
      final repository = ref.read(backupRepositoryProvider);
      final preview = repository.inspect(bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pulihkan cadangan?'),
          content: Text(
            'Data saat ini akan diganti dengan cadangan milik ${preview.teacherName}. '
            'Berisi ${preview.count('school_class')} kelas, '
            '${preview.count('student')} siswa, dan '
            '${preview.count('attendance_session')} sesi absensi. '
            'Pastikan kamu sudah menyimpan cadangan data saat ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pulihkan data'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await repository.restore(bytes);
      ref.invalidate(teacherProfileProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        message('Data berhasil dipulihkan.');
        context.go('/');
      }
    } on FormatException catch (error) {
      message(error.message);
    } catch (_) {
      message('Pemulihan gagal. Data lama tetap tersimpan.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.restoreMode ? 'Pulihkan data' : 'Cadangkan data'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Text(
          widget.restoreMode
              ? 'Kembalikan data dari file cadangan.'
              : 'Amankan data sebelum berganti HP.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpace.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: widget.restoreMode
                ? const Color(0xFFFFE8DF)
                : const Color(0xFFFFE7A0),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                widget.restoreMode
                    ? Icons.download_outlined
                    : Icons.upload_outlined,
                size: 70,
                color: AppColors.blue,
              ),
              const SizedBox(width: AppSpace.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restoreMode
                          ? 'Punya file cadangan?'
                          : 'Simpan untuk nanti.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      widget.restoreMode
                          ? 'Pilih file yang sebelumnya kamu simpan.'
                          : 'Semua kelas, siswa, dan riwayat absensi ikut tersimpan.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(
          widget.restoreMode ? 'File cadangan' : 'Nama file',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.sm),
        InputDecorator(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          child: Text(
            widget.restoreMode
                ? 'Pilih file .pkbackup'
                : 'PresensiKu_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pkbackup',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: widget.restoreMode
                ? const Color(0xFFFFE7A0)
                : AppColors.iceBlue,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            widget.restoreMode
                ? 'PERLU DIPERHATIKAN\nMemulihkan cadangan akan mengganti data pada HP ini. Buat salinan data terbaru sebelum melanjutkan.'
                : 'Pastikan file cadangan disimpan di tempat yang aman. Cadangan tidak otomatis tersinkron ke cloud.',
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: FilledButton(
          onPressed: busy
              ? null
              : widget.restoreMode
              ? restoreBackup
              : createBackup,
          child: Text(
            widget.restoreMode ? 'Pilih & pulihkan data' : 'Buat file cadangan',
          ),
        ),
      ),
    ),
  );
}
