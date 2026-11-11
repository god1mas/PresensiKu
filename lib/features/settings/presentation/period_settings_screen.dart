import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../academics/data/class_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

class PeriodSettingsScreen extends ConsumerStatefulWidget {
  const PeriodSettingsScreen({super.key});

  @override
  ConsumerState<PeriodSettingsScreen> createState() =>
      _PeriodSettingsScreenState();
}

class _PeriodSettingsScreenState extends ConsumerState<PeriodSettingsScreen> {
  final year = TextEditingController();
  String semester = 'ganjil';
  bool initialized = false;
  bool busy = false;
  int revision = 0;

  @override
  void dispose() {
    year.dispose();
    super.dispose();
  }

  Future<void> save(List<AcademicPeriod> periods) async {
    setState(() => busy = true);
    try {
      final cleaned = year.text.trim().replaceAll(' ', '');
      final repository = ref.read(classRepositoryProvider);
      final existing = periods
          .where(
            (item) => item.yearLabel == cleaned && item.semester == semester,
          )
          .firstOrNull;
      final id =
          existing?.id ??
          await repository.createPeriod(yearLabel: cleaned, semester: semester);
      await repository.activatePeriod(id);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Periode aktif berhasil disimpan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Periode belum berhasil disimpan.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(classRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Periode akademik')),
      body: FutureBuilder<List<AcademicPeriod>>(
        key: ValueKey(revision),
        future: repository.periods(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Periode belum dapat dimuat.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final periods = snapshot.data!;
          final active = periods.where((item) => item.isActive).firstOrNull;
          if (!initialized) {
            year.text = active?.yearLabel ?? '';
            semester = active?.semester ?? 'ganjil';
            initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              const Text('Biar data tiap semester tetap terpisah.'),
              const SizedBox(height: AppSpace.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE5FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAHUN AKTIF'),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      active?.yearLabel ?? 'Belum ada periode',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              TextField(
                controller: year,
                decoration: const InputDecoration(
                  labelText: 'Tahun ajaran',
                  hintText: '2026/2027',
                ),
              ),
              const SizedBox(height: AppSpace.base),
              DropdownButtonFormField<String>(
                key: ValueKey(semester),
                initialValue: semester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: const [
                  DropdownMenuItem(value: 'ganjil', child: Text('Ganjil')),
                  DropdownMenuItem(value: 'genap', child: Text('Genap')),
                ],
                onChanged: (value) =>
                    setState(() => semester = value ?? 'ganjil'),
              ),
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: AppColors.iceBlue,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Text(
                  'Riwayat semester sebelumnya tetap tersedia. Mengubah periode tidak menghapus data lama.',
                ),
              ),
              if (periods.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Periode tersimpan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final item in periods)
                  ListTile(
                    title: Text(item.label),
                    trailing: item.isActive
                        ? const Icon(Icons.check_circle, color: AppColors.blue)
                        : null,
                    onTap: () => setState(() {
                      year.text = item.yearLabel;
                      semester = item.semester;
                    }),
                  ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final periods = await repository.periods();
                    await save(periods);
                  },
            child: const Text('Simpan periode'),
          ),
        ),
      ),
    );
  }
}
