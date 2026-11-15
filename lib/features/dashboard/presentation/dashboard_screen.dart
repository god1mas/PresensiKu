import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/class_colors.dart';
import '../../onboarding/data/profile_repository.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(teacherProfileProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    if (profile.isLoading || summary.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile.hasError ||
        summary.hasError ||
        profile.value == null ||
        summary.value == null) {
      return Center(
        child: TextButton(
          onPressed: () {
            ref.invalidate(teacherProfileProvider);
            ref.invalidate(dashboardSummaryProvider);
          },
          child: const Text('Data belum dapat dimuat. Coba lagi'),
        ),
      );
    }
    final teacher = profile.value!;
    final data = summary.value!;
    final date = DateFormat('EEEE, d MMMM y', 'id_ID').format(DateTime.now());
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teacherProfileProvider);
        ref.invalidate(dashboardSummaryProvider);
        await ref.read(dashboardSummaryProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 8, 23, 0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/brand/presensiku_emblem.svg',
                  width: 52,
                  height: 52,
                ),
                const SizedBox(width: 3),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                        children: [
                          TextSpan(
                            text: 'Kelas',
                            style: TextStyle(color: AppColors.navy),
                          ),
                          TextSpan(
                            text: 'Ku',
                            style: TextStyle(color: AppColors.blue),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'by god1mas',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Text(
              'Halo, ${teacher.name}!',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: 29),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Text(
              date[0].toUpperCase() + date.substring(1),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 137,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kelola kelasmu, catat presensi,\ndan nilai siswa di satu tempat.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontSize: 13),
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/figma/dashboard_illustration.svg',
                    width: 151,
                    height: 152,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 0, 23, AppSpace.lg),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(59),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () => context.go('/kelas?pilih=1'),
              child: const Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 27),
                  SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      'Mulai Kelas',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 27),
                ],
              ),
            ),
          ),
          _Notebook(data: data),
          const SizedBox(height: AppSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 23),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kelas Saya',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/kelas'),
                  child: const Text('Lihat Semua ›'),
                ),
              ],
            ),
          ),
          if (data.classes.isEmpty)
            const _EmptyCard(
              'Belum ada kelas. Tambahkan kelas untuk mulai mengelola presensi dan penilaian.',
            )
          else
            SizedBox(
              height: 102,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 23),
                scrollDirection: Axis.horizontal,
                itemCount: data.classes.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, index) {
                  final item = data.classes[index];
                  return InkWell(
                    onTap: () => context.go('/kelas/${item.id}'),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Container(
                      width: 169,
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: classColor(item.colorIndex).tint,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            color: classColor(item.colorIndex).accent,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 18),
                                ),
                                Text(
                                  '${item.studentCount} siswa',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 23),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Absensi Terbaru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/riwayat'),
                  child: const Text('Lihat Semua ›'),
                ),
              ],
            ),
          ),
          if (data.recentSessions.isEmpty)
            const _EmptyCard('Belum ada absensi tersimpan.')
          else
            ...data.recentSessions.map(
              (item) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 23),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.iceBlue,
                  child: Icon(Icons.calendar_month, color: AppColors.blue),
                ),
                title: Text('${item.subjectName} · ${item.className}'),
                subtitle: Text(item.date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/riwayat/${item.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Notebook extends StatelessWidget {
  const _Notebook({required this.data});
  final DashboardSummary data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(33, 20, 18, 27),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(AppRadius.featured),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ringkasan Data', style: Theme.of(context).textTheme.titleLarge),
          Container(width: 130, height: 3, color: AppColors.yellow),
          const SizedBox(height: AppSpace.base),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  data.classCount,
                  'Kelas',
                  Icons.school_outlined,
                  AppColors.iceBlue,
                  AppColors.blue,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _Metric(
                  data.studentCount,
                  'Siswa',
                  Icons.people_outline,
                  AppColors.lightGreen,
                  AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  data.subjectCount,
                  'Mata Pelajaran',
                  Icons.menu_book_outlined,
                  AppColors.peach,
                  AppColors.amber,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _Metric(
                  data.sessionCount,
                  'Pertemuan',
                  Icons.calendar_month_outlined,
                  AppColors.lavender,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.icon, this.color, this.iconColor);
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 29),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: 26),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 23),
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );
}
