import 'package:presensiku/core/education/academic_scope.dart';
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
  final searchController = TextEditingController();
  int? periodId;
  int? classId;
  int? subjectId;
  DateTimeRange? dateRange;
  String search = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void resetFilters() {
    searchController.clear();
    setState(() {
      search = '';
      periodId = null;
      classId = null;
      subjectId = null;
      dateRange = null;
    });
  }

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
          db.rawQuery(
            'SELECT c.*, cp.period_id AS scope_period_id FROM school_class c JOIN class_period cp ON cp.class_id = c.id ORDER BY c.name COLLATE NOCASE',
          ),
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
              .where(
                (row) => periodId == null || row['scope_period_id'] == periodId,
              )
              .fold<Map<int, Map<String, Object?>>>(
                {},
                (map, row) => map..[row['id'] as int] = row,
              )
              .values
              .toList();
          final subjects = snapshot.data![2];
          final filterWidth =
              (MediaQuery.sizeOf(context).width -
                  2 * AppSpace.lg -
                  AppSpace.base) /
              2;
          final hasFilters =
              periodId != null ||
              classId != null ||
              subjectId != null ||
              dateRange != null ||
              search.trim().isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              if (widget.history)
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: educationTerms(
                      context,
                    ).translate('Cari penilaian, kelas, atau mata pelajaran'),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
              if (widget.history) const SizedBox(height: AppSpace.base),
              Wrap(
                spacing: AppSpace.base,
                runSpacing: AppSpace.base,
                children: [
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('period:$periodId'),
                      isExpanded: true,
                      initialValue: periodId,
                      decoration: const InputDecoration(labelText: 'Periode'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Semua periode'),
                        ),
                        for (final row in periods)
                          DropdownMenuItem(
                            value: row['id'] as int,
                            child: Text(
                              '${row['year_label']} · ${row['semester']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        periodId = value;
                        classId = null;
                        subjectId = null;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('class:$periodId:$classId'),
                      isExpanded: true,
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
                            child: Text(
                              row['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        classId = value;
                        subjectId = null;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('subject:$classId:$subjectId'),
                      isExpanded: true,
                      initialValue: subjectId,
                      decoration: InputDecoration(
                        labelText: educationTerms(context)
                            .translate('Mata pelajaran'),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: AcademicText('Semua mata pelajaran'),
                        ),
                        for (final row in subjects)
                          DropdownMenuItem(
                            value: row['id'] as int,
                            child: Text(
                              row['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => subjectId = value),
                    ),
                  ),
                  if (widget.history)
                    SizedBox(
                      width: filterWidth,
                      child: OutlinedButton.icon(
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
                          dateRange == null ? 'Tanggal' : 'Tanggal aktif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.history && hasFilters) ...[
                const SizedBox(height: AppSpace.base),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (search.trim().isNotEmpty)
                      Chip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            'Cari: $search',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (periodId != null)
                      Chip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            'Periode: ${periods.firstWhere((p) => p['id'] == periodId)['year_label']} ${periods.firstWhere((p) => p['id'] == periodId)['semester']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (classId != null)
                      Chip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            'Kelas: ${classes.firstWhere((c) => c['id'] == classId)['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (subjectId != null)
                      Chip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            '${educationTerms(context).subject}: ${subjects.firstWhere((s) => s['id'] == subjectId)['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (dateRange != null)
                      const Chip(label: Text('Tanggal aktif')),
                    TextButton.icon(
                      onPressed: resetFilters,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset filter'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              if (widget.history)
                FutureBuilder<List<Map<String, Object?>>>(
                  key: ValueKey(
                    '$periodId:$classId:$subjectId:$search:$dateRange',
                  ),
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
                                '${gradingPath(row['class_id'] as int, row['subject_id'] as int)}/penilaian/${row['id']}?periode=${row['period_id']}',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              else if (classId != null && subjectId != null && periodId != null)
                FilledButton.icon(
                  onPressed: () => context.push(
                    '${gradingPath(classId!, subjectId!)}/rekap?periode=$periodId',
                  ),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('Buka Rekap Penilaian'),
                )
              else
                const AcademicText(
                  'Pilih periode, kelas dan mata pelajaran untuk melihat rekap nilai.',
                ),
            ],
          );
        },
      ),
    );
  }
}
