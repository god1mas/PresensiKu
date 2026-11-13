import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../academics/data/class_repository.dart';
import '../../history/data/history_repository.dart';
import '../data/report_delivery.dart';
import '../data/report_repository.dart';
import '../data/xlsx_exporter.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int? classId;
  int? subjectId;
  int? periodId;
  DateTimeRange? range;

  ReportFilter get filter => ReportFilter(
    classId: classId,
    subjectId: subjectId,
    periodId: periodId,
    fromDate: range == null
        ? null
        : DateFormat('yyyy-MM-dd').format(range!.start),
    toDate: range == null ? null : DateFormat('yyyy-MM-dd').format(range!.end),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rekap absensi')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Text(
          'Lebih mudah melihat kemajuan kelas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpace.lg),
        _ReportFilters(
          classId: classId,
          subjectId: subjectId,
          periodId: periodId,
          range: range,
          onClass: (value) => setState(() => classId = value),
          onSubject: (value) => setState(() => subjectId = value),
          onPeriod: (value) => setState(() => periodId = value),
          onRange: (value) => setState(() => range = value),
        ),
        const SizedBox(height: AppSpace.lg),
        FutureBuilder<ReportData>(
          future: ref.watch(reportRepositoryProvider).load(filter),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Rekap belum dapat dimuat.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final report = snapshot.data!;
            if (report.details.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: Text('Belum ada absensi untuk filter ini.'),
              );
            }
            final total = report.details.length;
            final present = report.details
                .where((row) => row.status == 'H')
                .length;
            final sick = report.details
                .where((row) => row.status == 'S')
                .length;
            final excused = report.details
                .where((row) => row.status == 'I')
                .length;
            final absent = report.details
                .where((row) => row.status == 'A')
                .length;
            final rate = present * 100 / total;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F9EB),
                    borderRadius: BorderRadius.circular(AppRadius.featured),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tingkat kehadiran'),
                      Text(
                        '${rate.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const Text('Hadir pada pertemuan tercatat'),
                      const SizedBox(height: AppSpace.base),
                      LinearProgressIndicator(
                        value: present / total,
                        color: AppColors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Rincian ketidakhadiran',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.base),
                Row(
                  children: [
                    _Metric('Sakit', sick, total, const Color(0xFFFFE7A0)),
                    _Metric('Izin', excused, total, AppColors.iceBlue),
                    _Metric('Alpha', absent, total, const Color(0xFFFFE8DF)),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Rekap per siswa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.base),
                for (final student in report.summaries)
                  Card(
                    child: ListTile(
                      title: Text(student.name),
                      subtitle: Text(
                        'No. ${student.number} · ${student.completedSessions} sesi',
                      ),
                      trailing: Text(
                        student.attendancePercentage == null
                            ? '—'
                            : '${student.attendancePercentage!.toStringAsFixed(0)}%',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: FilledButton(
        onPressed: () => context.push('/laporan/ekspor', extra: filter),
        child: const Text('Ekspor Excel ↗'),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.count, this.total, this.color);
  final String label;
  final int count;
  final int total;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(AppSpace.base),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${(count * 100 / total).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(label),
        ],
      ),
    ),
  );
}

class ReportExportScreen extends ConsumerStatefulWidget {
  const ReportExportScreen({
    super.key,
    this.initialFilter = const ReportFilter(),
  });
  final ReportFilter initialFilter;
  @override
  ConsumerState<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends ConsumerState<ReportExportScreen> {
  late int? classId = widget.initialFilter.classId;
  late int? subjectId = widget.initialFilter.subjectId;
  late int? periodId = widget.initialFilter.periodId;
  late DateTimeRange? range =
      widget.initialFilter.fromDate != null &&
          widget.initialFilter.toDate != null
      ? DateTimeRange(
          start: DateTime.parse(widget.initialFilter.fromDate!),
          end: DateTime.parse(widget.initialFilter.toDate!),
        )
      : null;
  bool busy = false;

  ReportFilter get filter => ReportFilter(
    classId: classId,
    subjectId: subjectId,
    periodId: periodId,
    fromDate: range == null
        ? null
        : DateFormat('yyyy-MM-dd').format(range!.start),
    toDate: range == null ? null : DateFormat('yyyy-MM-dd').format(range!.end),
  );

  Future<void> export({required bool share}) async {
    setState(() => busy = true);
    try {
      final report = await ref.read(reportRepositoryProvider).load(filter);
      if (report.details.isEmpty) {
        throw StateError('Tidak ada absensi untuk diekspor.');
      }
      final bytes = const XlsxExporter().build(report);
      final filename =
          'KelasKu_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final delivery = ref.read(reportDeliveryProvider);
      final delivered = share
          ? await delivery.share(filename, bytes)
          : await delivery.save(filename, bytes);
      if (!delivered) return;
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ekspor berhasil'),
            content: const Text('File Excel siap digunakan atau dibagikan.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Ekspor belum berhasil. Coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ekspor laporan')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Text(
          'Simpan catatan ke file Excel.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpace.xl),
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F9EB),
            borderRadius: BorderRadius.circular(AppRadius.featured),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 48,
                color: AppColors.green,
              ),
              const SizedBox(width: AppSpace.base),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laporan kehadiran',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Excel (.xlsx) · Bisa dibagikan'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        _ReportFilters(
          classId: classId,
          subjectId: subjectId,
          periodId: periodId,
          range: range,
          onClass: (value) => setState(() => classId = value),
          onSubject: (value) => setState(() => subjectId = value),
          onPeriod: (value) => setState(() => periodId = value),
          onRange: (value) => setState(() => range = value),
        ),
        const SizedBox(height: AppSpace.lg),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: Text(
              'Di dalam file Excel\n01  Detail absensi      02  Rekap absensi',
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => export(share: true),
              child: const Text('Bagikan'),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : () => export(share: false),
              child: const Text('Simpan Excel'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportFilters extends ConsumerWidget {
  const _ReportFilters({
    required this.classId,
    required this.subjectId,
    required this.periodId,
    required this.range,
    required this.onClass,
    required this.onSubject,
    required this.onPeriod,
    required this.onRange,
  });
  final int? classId;
  final int? subjectId;
  final int? periodId;
  final DateTimeRange? range;
  final ValueChanged<int?> onClass;
  final ValueChanged<int?> onSubject;
  final ValueChanged<int?> onPeriod;
  final ValueChanged<DateTimeRange?> onRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyRepositoryProvider);
    return Column(
      children: [
        FutureBuilder<List<HistoryOption>>(
          future: history.classOptions(),
          builder: (context, snapshot) => DropdownButtonFormField<int?>(
            key: ValueKey('class:$classId:${snapshot.hasData}'),
            initialValue: snapshot.hasData ? classId : null,
            decoration: const InputDecoration(labelText: 'Pilih kelas'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Semua kelas'),
              ),
              ...?snapshot.data?.map(
                (option) => DropdownMenuItem<int?>(
                  value: option.id,
                  child: Text(option.label),
                ),
              ),
            ],
            onChanged: onClass,
          ),
        ),
        const SizedBox(height: AppSpace.base),
        FutureBuilder<List<HistoryOption>>(
          future: history.subjectOptions(),
          builder: (context, snapshot) => DropdownButtonFormField<int?>(
            key: ValueKey('subject:$subjectId:${snapshot.hasData}'),
            initialValue: snapshot.hasData ? subjectId : null,
            decoration: const InputDecoration(labelText: 'Mata pelajaran'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Semua mapel'),
              ),
              ...?snapshot.data?.map(
                (option) => DropdownMenuItem<int?>(
                  value: option.id,
                  child: Text(option.label),
                ),
              ),
            ],
            onChanged: onSubject,
          ),
        ),
        const SizedBox(height: AppSpace.base),
        FutureBuilder<List<AcademicPeriod>>(
          future: ref.watch(classRepositoryProvider).periods(),
          builder: (context, snapshot) => DropdownButtonFormField<int?>(
            key: ValueKey('period:$periodId:${snapshot.hasData}'),
            initialValue: snapshot.hasData ? periodId : null,
            decoration: const InputDecoration(labelText: 'Periode akademik'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Semua periode'),
              ),
              ...?snapshot.data?.map(
                (option) => DropdownMenuItem<int?>(
                  value: option.id,
                  child: Text(option.label),
                ),
              ),
            ],
            onChanged: onPeriod,
          ),
        ),
        const SizedBox(height: AppSpace.base),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rentang tanggal'),
          subtitle: Text(
            range == null
                ? 'Semua tanggal'
                : '${DateFormat('d MMM y', 'id_ID').format(range!.start)} – ${DateFormat('d MMM y', 'id_ID').format(range!.end)}',
          ),
          trailing: const Icon(Icons.date_range_outlined),
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange: range,
            );
            if (picked != null) onRange(picked);
          },
        ),
        if (range != null)
          TextButton(
            onPressed: () => onRange(null),
            child: const Text('Hapus tanggal'),
          ),
      ],
    );
  }
}
