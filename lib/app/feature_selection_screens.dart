import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/database/app_database.dart';
import '../core/design/tokens.dart';
import '../features/grading/presentation/grading_screens.dart';

class FeatureSelectionScreen extends StatelessWidget {
  const FeatureSelectionScreen({super.key, required this.reports});
  final bool reports;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(reports ? 'Rekap & Laporan' : 'Riwayat')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Text(
          reports ? 'Pilih Jenis Laporan' : 'Pilih Jenis Riwayat',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpace.lg),
        _choice(
          context,
          reports ? 'Rekap Presensi' : 'Riwayat Presensi',
          reports
              ? 'Lihat ringkasan kehadiran siswa.'
              : 'Lihat dan koreksi catatan kehadiran.',
          Icons.fact_check_outlined,
          reports ? '/laporan/presensi' : '/riwayat/presensi',
        ),
        const SizedBox(height: AppSpace.base),
        _choice(
          context,
          reports ? 'Rekap Penilaian' : 'Riwayat Penilaian',
          reports
              ? 'Lihat rekap dan nilai akhir siswa.'
              : 'Lihat penilaian dan nilai siswa sebelumnya.',
          Icons.assessment_outlined,
          reports ? '/laporan/penilaian' : '/riwayat/penilaian',
        ),
      ],
    ),
  );

  Widget _choice(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String path,
  ) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push(path),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.iceBlue,
              child: Icon(icon, color: AppColors.blue),
            ),
            const SizedBox(width: AppSpace.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class GradingDestinationScreen extends ConsumerStatefulWidget {
  const GradingDestinationScreen({super.key, required this.history});
  final bool history;
  @override
  ConsumerState<GradingDestinationScreen> createState() =>
      _GradingDestinationScreenState();
}

class _GradingDestinationScreenState
    extends ConsumerState<GradingDestinationScreen> {
  int? periodId;
  int? classId;
  int? subjectId;
  DateTimeRange? dateRange;
  String search = '';

  bool _matchesDate(String date) {
    final selected = dateRange;
    if (selected == null) return true;
    final formatter = DateFormat('yyyy-MM-dd');
    return date.compareTo(formatter.format(selected.start)) >= 0 &&
        date.compareTo(formatter.format(selected.end)) <= 0;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider).database;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.history ? 'Riwayat Penilaian' : 'Rekap Penilaian'),
      ),
      body: FutureBuilder<List<List<Map<String, Object?>>>>(
        future: Future.wait([
          db.query('academic_period', orderBy: 'id DESC'),
          db.query('school_class', orderBy: 'name COLLATE NOCASE'),
          db.query('subject', orderBy: 'name COLLATE NOCASE'),
        ]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Data penilaian belum dapat dimuat.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final periods = snapshot.data![0];
          final classes = snapshot.data![1]
              .where((row) => periodId == null || row['period_id'] == periodId)
              .toList();
          final subjects = snapshot.data![2];
          return ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              DropdownButtonFormField<int?>(
                initialValue: periodId,
                decoration: const InputDecoration(
                  labelText: 'Periode akademik',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Semua periode'),
                  ),
                  for (final row in periods)
                    DropdownMenuItem(
                      value: row['id'] as int,
                      child: Text('${row['year_label']} · ${row['semester']}'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  periodId = value;
                  classId = null;
                  subjectId = null;
                }),
              ),
              const SizedBox(height: AppSpace.base),
              DropdownButtonFormField<int?>(
                key: ValueKey('class:$periodId:$classId'),
                initialValue: classId,
                decoration: const InputDecoration(labelText: 'Kelas'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Semua kelas'),
                  ),
                  for (final row in classes)
                    DropdownMenuItem(
                      value: row['id'] as int,
                      child: Text(row['name'] as String),
                    ),
                ],
                onChanged: (value) => setState(() {
                  classId = value;
                  subjectId = null;
                }),
              ),
              const SizedBox(height: AppSpace.base),
              DropdownButtonFormField<int?>(
                key: ValueKey('subject:$classId:$subjectId'),
                initialValue: subjectId,
                decoration: const InputDecoration(labelText: 'Mata pelajaran'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Semua mata pelajaran'),
                  ),
                  for (final row in subjects)
                    DropdownMenuItem(
                      value: row['id'] as int,
                      child: Text(row['name'] as String),
                    ),
                ],
                onChanged: (value) => setState(() => subjectId = value),
              ),
              const SizedBox(height: AppSpace.base),
              if (widget.history)
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari penilaian, kelas, atau mata pelajaran',
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
              if (widget.history) ...[
                const SizedBox(height: AppSpace.base),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppSpace.base,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: dateRange,
                          );
                          if (picked != null) {
                            setState(() => dateRange = picked);
                          }
                        },
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          dateRange == null
                              ? 'Semua tanggal'
                              : '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} – ${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}',
                        ),
                      ),
                      if (dateRange != null)
                        IconButton(
                          tooltip: 'Hapus filter tanggal',
                          onPressed: () => setState(() => dateRange = null),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              if (widget.history)
                FutureBuilder<List<Map<String, Object?>>>(
                  key: ValueKey('$periodId:$classId:$subjectId:$search'),
                  future: db.query(
                    'assessment',
                    where: [
                      if (periodId != null) 'period_id = ?',
                      if (classId != null) 'class_id = ?',
                      if (subjectId != null) 'subject_id = ?',
                      'deleted_at IS NULL',
                    ].join(' AND '),
                    whereArgs: [
                      if (periodId != null) periodId,
                      if (classId != null) classId,
                      if (subjectId != null) subjectId,
                    ],
                    orderBy: 'date DESC, id DESC',
                  ),
                  builder: (context, result) {
                    if (result.hasError) {
                      return const Text(
                        'Riwayat penilaian belum dapat dimuat.',
                      );
                    }
                    if (!result.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final term = search.trim().toLowerCase();
                    final rows = result.data!
                        .where(
                          (row) =>
                              _matchesDate(row['date'] as String) &&
                              (term.isEmpty ||
                                  [
                                    row['title'],
                                    row['class_name_snapshot'],
                                    row['subject_name_snapshot'],
                                    row['category_name_snapshot'],
                                  ].any(
                                    (value) =>
                                        '$value'.toLowerCase().contains(term),
                                  )),
                        )
                        .toList();
                    if (rows.isEmpty) {
                      return const Text(
                        'Belum ada penilaian untuk filter ini.',
                      );
                    }
                    return Column(
                      children: [
                        for (final row in rows)
                          Card(
                            child: ListTile(
                              title: Text(row['title'] as String),
                              subtitle: Text(
                                '${row['date']} · ${row['class_name_snapshot']} · ${row['subject_name_snapshot']} · ${row['period_snapshot']}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                '${gradingPath(row['class_id'] as int, row['subject_id'] as int)}/penilaian/${row['id']}',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              else if (classId != null && subjectId != null)
                FilledButton.icon(
                  onPressed: () => context.push(
                    '${gradingPath(classId!, subjectId!)}/rekap',
                  ),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('Buka Rekap Penilaian'),
                )
              else
                const Text(
                  'Pilih kelas dan mata pelajaran untuk melihat rekap nilai.',
                ),
            ],
          );
        },
      ),
    );
  }
}
