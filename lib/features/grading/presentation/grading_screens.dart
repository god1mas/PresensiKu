import 'package:presensiku/core/education/academic_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../reports/data/report_delivery.dart';
import '../data/grade_report_repository.dart';
import '../data/grade_xlsx_exporter.dart';
import '../data/grading_repository.dart';
import '../domain/grade_calculator.dart';

String gradingPath(int classId, int subjectId) =>
    '/kelas/$classId/mapel/$subjectId';

class _ScopeInfo {
  const _ScopeInfo(
    this.className,
    this.subjectName,
    this.periodId,
    this.periodName,
    this.studentCount,
  );
  final String className;
  final String subjectName;
  final int periodId;
  final String periodName;
  final int studentCount;
}

Future<_ScopeInfo> _scope(WidgetRef ref, int classId, int subjectId) async {
  final db = ref.read(appDatabaseProvider).database;
  final classes = await db.query(
    'school_class',
    where: 'id = ?',
    whereArgs: [classId],
  );
  final subjects = await db.query(
    'subject',
    where: 'id = ?',
    whereArgs: [subjectId],
  );
  if (classes.isEmpty || subjects.isEmpty) {
    throw const FormatException('Kelas atau mata pelajaran tidak ditemukan.');
  }
  final selected = ref.read(selectedAcademicPeriodProvider);
  final active = await db.rawQuery(
    'SELECT p.id FROM academic_period p JOIN class_period cp ON cp.period_id = p.id WHERE cp.class_id = ? AND p.is_active = 1',
    [classId],
  );
  final periodId =
      selected ??
      (active.isEmpty
          ? classes.single['period_id'] as int
          : active.single['id'] as int);
  final valid = await db.query(
    'class_period',
    where: 'class_id = ? AND period_id = ?',
    whereArgs: [classId, periodId],
  );
  if (valid.isEmpty) {
    throw const FormatException('Kelas tidak tersedia pada periode ini.');
  }
  final periods = await db.query(
    'academic_period',
    where: 'id = ?',
    whereArgs: [periodId],
  );
  final students = await db.rawQuery(
    'SELECT COUNT(*) AS total FROM student WHERE class_id = ? AND archived_at IS NULL',
    [classId],
  );
  return _ScopeInfo(
    classes.single['name'] as String,
    subjects.single['name'] as String,
    periodId,
    '${periods.single['year_label']} · ${periods.single['semester'] == 'ganjil' ? 'Ganjil' : 'Genap'}',
    students.single['total'] as int,
  );
}

class _GradeScaffold extends StatelessWidget {
  const _GradeScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
  }) : actions = null;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? action;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      toolbarHeight: 104,
      leadingWidth: 76,
      leading: Padding(
        padding: const EdgeInsets.only(left: 24, top: 12, bottom: 12),
        child: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.navy),
          tooltip: 'Kembali',
        ),
      ),
      titleSpacing: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 9),
          Container(
            width: 66,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
      actions: actions,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        for (final child in children) ...[child, const SizedBox(height: 16)],
      ],
    ),
    bottomNavigationBar: action == null
        ? null
        : SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: action,
              ),
            ),
          ),
  );
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(19),
      side: BorderSide(color: color == Colors.white ? AppColors.line : color),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

void _showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final message = error is FormatException
      ? error.message
      : 'Data belum dapat disimpan.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });
  final int classId;
  final int subjectId;
  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  int revision = 0;
  @override
  Widget build(BuildContext context) => FutureBuilder<_ScopeInfo>(
    key: ValueKey(revision),
    future: _scope(ref, widget.classId, widget.subjectId),
    builder: (context, scopeSnapshot) {
      if (!scopeSnapshot.hasData) {
        return Scaffold(
          body: Center(
            child: scopeSnapshot.hasError
                ? const Text('Data mapel tidak ditemukan.')
                : const CircularProgressIndicator(),
          ),
        );
      }
      final scope = scopeSnapshot.data!;
      final path = gradingPath(widget.classId, widget.subjectId);
      return FutureBuilder<List<Map<String, Object?>>>(
        future: ref
            .read(gradingRepositoryProvider)
            .assessments(
              classId: widget.classId,
              subjectId: widget.subjectId,
              periodId: scope.periodId,
            ),
        builder: (context, itemSnapshot) {
          final recent = itemSnapshot.data?.firstOrNull;
          return _GradeScaffold(
            title: 'Detail Mata Pelajaran',
            subtitle: '${scope.subjectName} · ${scope.className}',
            action: FilledButton(
              onPressed: () => context
                  .push(periodPath(context, '$path/penilaian'))
                  .then((_) {
                    if (mounted) setState(() => revision++);
                  }),
              child: const Text('Buka Penilaian'),
            ),
            children: [
              _GradeCard(
                color: AppColors.iceBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Pill('SEMESTER', color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      scope.subjectName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${scope.className} · ${scope.studentCount} ${educationTerms(context).student.toLowerCase()} · ${scope.periodName}',
                    ),
                  ],
                ),
              ),
              _GradeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apa yang ingin dikerjakan?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            label: 'Presensi',
                            icon: Icons.check,
                            color: AppColors.iceBlue,
                            onTap: () => context.push(
                              periodPath(
                                context,
                                '/absensi?kelas=${widget.classId}&mapel=${widget.subjectId}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionTile(
                            label: 'Penilaian',
                            icon: Icons.star,
                            color: AppColors.lightGreen,
                            onTap: () => context.push(
                              periodPath(context, '$path/penilaian'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (recent != null)
                _GradeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Penilaian terbaru',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(recent['title'] as String),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push(
                          periodPath(
                            context,
                            '$path/penilaian/${recent['id']}',
                          ),
                        ),
                        child: const Text('Lihat nilai ›'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 82,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.blue),
              const Spacer(),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.color = AppColors.iceBlue});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.blue,
      ),
    ),
  );
}

class AssessmentOverviewScreen extends ConsumerStatefulWidget {
  const AssessmentOverviewScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });
  final int classId;
  final int subjectId;
  @override
  ConsumerState<AssessmentOverviewScreen> createState() =>
      _AssessmentOverviewScreenState();
}

class _AssessmentOverviewScreenState
    extends ConsumerState<AssessmentOverviewScreen> {
  int revision = 0;
  @override
  Widget build(BuildContext context) => FutureBuilder<_ScopeInfo>(
    future: _scope(ref, widget.classId, widget.subjectId),
    builder: (context, scopeSnapshot) {
      if (!scopeSnapshot.hasData) {
        return Scaffold(
          body: Center(
            child: scopeSnapshot.hasError
                ? const Text('Data tidak ditemukan.')
                : const CircularProgressIndicator(),
          ),
        );
      }
      final scope = scopeSnapshot.data!;
      final path = gradingPath(widget.classId, widget.subjectId);
      return FutureBuilder<List<Map<String, Object?>>>(
        key: ValueKey(revision),
        future: ref
            .read(gradingRepositoryProvider)
            .assessments(
              classId: widget.classId,
              subjectId: widget.subjectId,
              periodId: scope.periodId,
            ),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return _GradeScaffold(
            title: 'Penilaian ${scope.subjectName}',
            subtitle: '${scope.className} · ${scope.periodName}',
            action: FilledButton(
              onPressed: () => context
                  .push(periodPath(context, '$path/penilaian/tambah'))
                  .then((_) {
                    if (mounted) setState(() => revision++);
                  }),
              child: const Text('+ Tambah Penilaian'),
            ),
            children: [
              if (!snapshot.hasData && !snapshot.hasError)
                const Center(child: CircularProgressIndicator()),
              if (items.isEmpty && snapshot.hasData) ...[
                const _GradeCard(
                  color: AppColors.iceBlue,
                  child: SizedBox(
                    height: 190,
                    child: Center(
                      child: Icon(Icons.add, size: 90, color: AppColors.blue),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Belum ada penilaian',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Center(
                  child: AcademicText(
                    'Buat penilaian pertama untuk mulai mencatat nilai siswa.',
                  ),
                ),
              ] else ...[
                _GradeCard(
                  color: AppColors.iceBlue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ringkasan Penilaian',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Metric('${items.length}', 'Penilaian', Colors.white),
                          _Metric(
                            '${scope.studentCount}',
                            'Siswa',
                            AppColors.lightGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _GradeCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Atur Bobot'),
                    subtitle: const Text('Kategori & persentase nilai akhir'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(periodPath(context, '$path/bobot')),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        label: 'Kelola Kategori',
                        icon: Icons.category_outlined,
                        color: AppColors.lavender,
                        onTap: () =>
                            context.push(periodPath(context, '$path/kategori')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionTile(
                        label: 'Rekap Nilai',
                        icon: Icons.bar_chart,
                        color: AppColors.iceBlue,
                        onTap: () =>
                            context.push(periodPath(context, '$path/rekap')),
                      ),
                    ),
                  ],
                ),
                _GradeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daftar Penilaian',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      for (final item in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.iceBlue,
                            child: Text(
                              (item['category_name_snapshot'] as String)
                                  .substring(0, 1),
                            ),
                          ),
                          title: Text(
                            item['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item['date']} · ${item['category_name_snapshot']}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context
                              .push('$path/penilaian/${item['id']}')
                              .then((_) {
                                if (mounted) setState(() => revision++);
                              }),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class AssessmentFormScreen extends ConsumerStatefulWidget {
  const AssessmentFormScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    this.assessmentId,
  });
  final int classId;
  final int subjectId;
  final int? assessmentId;
  @override
  ConsumerState<AssessmentFormScreen> createState() =>
      _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends ConsumerState<AssessmentFormScreen> {
  late final Future<_ScopeInfo> scopeFuture;
  late final Future<List<Map<String, Object?>>> categoriesFuture;
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final bab = TextEditingController();
  final description = TextEditingController();
  final maxScore = TextEditingController(text: '100');
  DateTime date = DateTime.now();
  int? categoryId;
  bool required = true;
  bool saving = false;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    scopeFuture = _scope(ref, widget.classId, widget.subjectId);
    categoriesFuture = ref
        .read(gradingRepositoryProvider)
        .categories(includeArchived: widget.assessmentId != null);
  }

  @override
  void dispose() {
    title.dispose();
    bab.dispose();
    description.dispose();
    maxScore.dispose();
    super.dispose();
  }

  Future<void> save(_ScopeInfo scope) async {
    if (!formKey.currentState!.validate() || categoryId == null) {
      _showError(context, const FormatException('Pilih kategori penilaian.'));
      return;
    }
    setState(() => saving = true);
    try {
      final repo = ref.read(gradingRepositoryProvider);
      final score = double.parse(maxScore.text.replaceAll(',', '.'));
      final formattedDate =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final id =
          widget.assessmentId ??
          await repo.createAssessment(
            classId: widget.classId,
            subjectId: widget.subjectId,
            periodId: scope.periodId,
            categoryId: categoryId!,
            date: formattedDate,
            title: title.text,
            maxScore: score,
            bab: bab.text,
            description: description.text,
            isRequired: required,
          );
      if (widget.assessmentId != null) {
        await repo.updateAssessment(
          id: id,
          title: title.text,
          date: formattedDate,
          categoryId: categoryId!,
          maxScore: score,
          bab: bab.text,
          description: description.text,
          isRequired: required,
        );
      }
      if (!mounted) return;
      final path = gradingPath(widget.classId, widget.subjectId);
      if (widget.assessmentId == null) {
        context.pushReplacement('$path/penilaian/$id/nilai');
      } else {
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ScopeInfo>(
    future: scopeFuture,
    builder: (context, scopeSnapshot) {
      if (!scopeSnapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final scope = scopeSnapshot.data!;
      return FutureBuilder<List<Map<String, Object?>>>(
        future: categoriesFuture,
        builder: (context, categorySnapshot) {
          final categories = categorySnapshot.data ?? [];
          if (categories.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          categoryId ??= categories.first['id'] as int;
          if (widget.assessmentId != null && !loaded) {
            return FutureBuilder<Map<String, Object?>>(
              future: ref
                  .read(gradingRepositoryProvider)
                  .assessment(widget.assessmentId!),
              builder: (context, existing) {
                if (!existing.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final item = existing.data!;
                title.text = item['title'] as String;
                bab.text = item['bab'] as String? ?? '';
                description.text = item['description'] as String? ?? '';
                maxScore.text = '${item['max_score']}';
                categoryId = item['category_id'] as int;
                date =
                    DateTime.tryParse(item['date'] as String) ?? DateTime.now();
                required = item['is_required'] == 1;
                loaded = true;
                return _form(scope, categories);
              },
            );
          }
          return _form(scope, categories);
        },
      );
    },
  );

  Widget _form(
    _ScopeInfo scope,
    List<Map<String, Object?>> categories,
  ) => _GradeScaffold(
    title: widget.assessmentId == null ? 'Tambah Penilaian' : 'Edit Penilaian',
    subtitle: '${scope.subjectName} · ${scope.className}',
    action: FilledButton(
      onPressed: saving ? null : () => save(scope),
      child: Text(
        widget.assessmentId == null ? 'Simpan & Isi Nilai' : 'Simpan Perubahan',
      ),
    ),
    children: [
      _GradeCard(
        color: AppColors.yellow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.assessmentId == null ? 'Penilaian baru' : 'Ubah penilaian',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${scope.studentCount} ${educationTerms(context).student.toLowerCase()} kelas ${scope.className} terhubung.',
            ),
          ],
        ),
      ),
      Form(
        key: formKey,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal Penilaian'),
              subtitle: Text('${date.day}/${date.month}/${date.year}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => date = picked);
              },
            ),
            TextFormField(
              controller: bab,
              decoration: const InputDecoration(labelText: 'BAB / Materi'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Tema / Judul Tugas',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Judul wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: categories.any((row) => row['id'] == categoryId)
                  ? categoryId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Kategori Penilaian',
              ),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category['id'] as int,
                    child: Text(category['name'] as String),
                  ),
              ],
              onChanged: (value) => setState(() => categoryId = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: maxScore,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Skor Maksimal'),
              validator: (value) {
                final parsed = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                return parsed == null || !parsed.isFinite || parsed <= 0
                    ? 'Masukkan skor lebih dari 0'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: description,
              decoration: const InputDecoration(
                labelText: 'Deskripsi / Catatan (opsional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Penilaian wajib'),
              value: required,
              onChanged: (value) => setState(() => required = value),
            ),
          ],
        ),
      ),
    ],
  );
}

class AssessmentDetailScreen extends ConsumerStatefulWidget {
  const AssessmentDetailScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.assessmentId,
  });
  final int classId;
  final int subjectId;
  final int assessmentId;
  @override
  ConsumerState<AssessmentDetailScreen> createState() =>
      _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState
    extends ConsumerState<AssessmentDetailScreen> {
  int revision = 0;

  Future<(List<Map<String, Object?>>, List<Map<String, Object?>>)>
  _loadRows() async {
    final grades = await ref
        .read(gradingRepositoryProvider)
        .grades(widget.assessmentId);
    final students = await ref
        .read(appDatabaseProvider)
        .database
        .query(
          'student',
          where: 'class_id = ? AND archived_at IS NULL',
          whereArgs: [widget.classId],
          orderBy: 'attendance_number',
        );
    return (grades, students);
  }

  Future<void> remove() async {
    final decision = await showAcademicDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arsipkan atau hapus penilaian?'),
        content: const Text(
          'Penilaian yang diarsipkan atau dihapus disembunyikan dari daftar aktif. Nilai tersimpan tetap terjaga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'archive'),
            child: const Text('Arsipkan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'delete'),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (decision == null) return;
    try {
      if (decision == 'archive') {
        await ref
            .read(gradingRepositoryProvider)
            .archiveAssessment(widget.assessmentId);
      } else {
        await ref
            .read(gradingRepositoryProvider)
            .deleteAssessment(widget.assessmentId);
      }
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>>(
    key: ValueKey(revision),
    future: ref.read(gradingRepositoryProvider).assessment(widget.assessmentId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final item = snapshot.data!;
      final path = gradingPath(widget.classId, widget.subjectId);
      return FutureBuilder<
        (List<Map<String, Object?>>, List<Map<String, Object?>>)
      >(
        future: _loadRows(),
        builder: (context, gradeSnapshot) {
          final grades = gradeSnapshot.data?.$1 ?? [];
          final students = gradeSnapshot.data?.$2 ?? [];
          final byStudent = {
            for (final grade in grades) grade['student_id'] as int: grade,
          };
          final activeIds = students.map((student) => student['id']).toSet();
          final valid = grades
              .where((row) => row['state'] == 'GRADED')
              .toList();
          final values = valid
              .map((row) => (row['score'] as num).toDouble())
              .toList();
          return _GradeScaffold(
            title: 'Detail Penilaian',
            subtitle:
                '${item['category_name_snapshot']} · ${item['bab'] ?? ''}',
            action: FilledButton(
              onPressed: () => context
                  .push('$path/penilaian/${widget.assessmentId}/nilai')
                  .then((_) {
                    if (mounted) setState(() => revision++);
                  }),
              child: const AcademicText('Edit Nilai Siswa'),
            ),
            children: [
              _GradeCard(
                color: AppColors.lavender,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Pill(
                      '${item['category_name_snapshot']}'.toUpperCase(),
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['title'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${item['bab'] ?? ''} · ${item['date']}'),
                    Text('Skor maksimal: ${item['max_score']}'),
                  ],
                ),
              ),
              Row(
                children: [
                  _Metric(
                    '${grades.length}/${students.length}',
                    'Terisi',
                    AppColors.iceBlue,
                  ),
                  _Metric(
                    values.isEmpty
                        ? '—'
                        : (values.reduce((a, b) => a + b) / values.length)
                              .toStringAsFixed(2),
                    'Rata-rata',
                    AppColors.lightGreen,
                  ),
                ],
              ),
              _GradeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nilai yang tercatat',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (students.isEmpty && grades.isEmpty)
                      const AcademicText('Belum ada siswa di kelas ini.'),
                    for (final student in students)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(student['name'] as String),
                        trailing: _Pill(
                          byStudent[student['id']] == null
                              ? 'Belum dinilai'
                              : byStudent[student['id']]!['state'] == 'EXEMPT'
                              ? 'EX'
                              : '${byStudent[student['id']]!['score']}',
                        ),
                      ),
                    for (final grade in grades.where(
                      (grade) => !activeIds.contains(grade['student_id']),
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(grade['student_name_snapshot'] as String),
                        subtitle: const AcademicText('Siswa diarsipkan'),
                        trailing: _Pill(
                          grade['state'] == 'EXEMPT'
                              ? 'EX'
                              : '${grade['score']}',
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: remove,
                    child: const Text('Arsip / Hapus'),
                  ),
                  TextButton(
                    onPressed: () => context
                        .push('$path/penilaian/${widget.assessmentId}/edit')
                        .then((_) {
                          if (mounted) setState(() => revision++);
                        }),
                    child: const Text('Edit informasi'),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

class GradeEntryScreen extends ConsumerStatefulWidget {
  const GradeEntryScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.assessmentId,
  });
  final int classId;
  final int subjectId;
  final int assessmentId;
  @override
  ConsumerState<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends ConsumerState<GradeEntryScreen> {
  Map<String, Object?>? assessment;
  List<Map<String, Object?>> students = [];
  final controllers = <int, TextEditingController>{};
  final exempt = <int>{};
  bool dirty = false;
  bool saving = false;

  void _popWhenClean() {
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(gradingRepositoryProvider);
      final item = await repo.assessment(widget.assessmentId);
      final db = ref.read(appDatabaseProvider).database;
      final roster = await db.query(
        'student',
        where: 'class_id = ? AND archived_at IS NULL',
        whereArgs: [widget.classId],
        orderBy: 'attendance_number',
      );
      final grades = await repo.grades(widget.assessmentId);
      final byStudent = {
        for (final grade in grades) grade['student_id'] as int: grade,
      };
      for (final student in roster) {
        final id = student['id'] as int;
        final grade = byStudent[id];
        if (grade?['state'] == 'EXEMPT') exempt.add(id);
        controllers[id] = TextEditingController(
          text: grade?['state'] == 'GRADED' ? '${grade!['score']}' : '',
        );
      }
      if (mounted) {
        setState(() {
          assessment = item;
          students = roster;
        });
      }
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!dirty) return true;
    return await showAcademicDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Perubahan belum disimpan'),
            content: const Text(
              'Nilai yang diubah akan hilang jika keluar sekarang.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Tetap di sini'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    final values = <int, GradeValue>{};
    for (final student in students) {
      final id = student['id'] as int;
      final raw = controllers[id]!.text.trim().replaceAll(',', '.');
      if (exempt.contains(id)) {
        values[id] = const GradeValue.exempt();
      } else if (raw.isEmpty) {
        values[id] = const GradeValue.ungraded();
      } else {
        final parsed = double.tryParse(raw);
        if (parsed == null) {
          _showError(
            context,
            FormatException('Nilai ${student['name']} tidak valid.'),
          );
          return;
        }
        values[id] = GradeValue.graded(parsed);
      }
    }
    setState(() => saving = true);
    try {
      await ref
          .read(gradingRepositoryProvider)
          .saveGrades(widget.assessmentId, values);
      if (mounted) {
        setState(() => dirty = false);
        context.pushReplacement(
          '${gradingPath(widget.classId, widget.subjectId)}/penilaian/${widget.assessmentId}',
        );
      }
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (assessment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final filled = students.where((student) {
      final id = student['id'] as int;
      return exempt.contains(id) || controllers[id]!.text.trim().isNotEmpty;
    }).length;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _confirmLeave() && context.mounted) {
          _popWhenClean();
        }
      },
      child: _GradeScaffold(
        title: 'Input Nilai Siswa',
        subtitle:
            '${assessment!['category_name_snapshot']} · ${assessment!['subject_name_snapshot']}',
        action: FilledButton(
          onPressed: saving ? null : _save,
          child: const Text('Simpan Nilai'),
        ),
        children: [
          _GradeCard(
            color: AppColors.iceBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment!['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${assessment!['category_name_snapshot']} · Maksimal ${assessment!['max_score']} · ${assessment!['date']}',
                ),
                const SizedBox(height: 12),
                AcademicText(
                  '$filled dari ${students.length} siswa dinilai',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: students.isEmpty ? 0 : filled / students.length,
                  backgroundColor: Colors.white,
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          _GradeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AcademicText(
                        'Nilai siswa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const _Pill('Belum dinilai ≠ 0', color: AppColors.yellow),
                  ],
                ),
                if (students.isEmpty)
                  const AcademicText('Belum ada siswa aktif di kelas ini.'),
                for (final student in students) _gradeRow(student),
              ],
            ),
          ),
          const _GradeCard(
            color: AppColors.lightGreen,
            child: Text(
              'Gunakan keyboard angka untuk input cepat. Kosong, nilai 0, dan EX adalah status berbeda.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradeRow(Map<String, Object?> student) {
    final id = student['id'] as int;
    final isExempt = exempt.contains(id);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: students.indexOf(student).isEven
            ? Colors.white
            : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _Pill('${student['attendance_number']}'.padLeft(2, '0')),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isExempt
                      ? 'Dikecualikan'
                      : controllers[id]!.text.isEmpty
                      ? 'Belum dinilai'
                      : 'Tercatat',
                  style: TextStyle(
                    fontSize: 10,
                    color: isExempt ? AppColors.muted : AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: isExempt
                ? OutlinedButton(
                    onPressed: () => setState(() {
                      exempt.remove(id);
                      dirty = true;
                    }),
                    child: const Text('EX'),
                  )
                : TextField(
                    controller: controllers[id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '—',
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onChanged: (_) => setState(() => dirty = true),
                  ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Status nilai ${student['name']}',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => setState(() {
              dirty = true;
              if (value == 'EX') {
                exempt.add(id);
                controllers[id]!.clear();
              } else {
                exempt.remove(id);
                controllers[id]!.clear();
              }
            }),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'EX', child: Text('Dikecualikan (EX)')),
              PopupMenuItem(value: 'blank', child: Text('Belum dinilai')),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });
  final int classId;
  final int subjectId;
  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  int revision = 0;
  bool showingArchive = false;

  Future<void> _restore(Map<String, Object?> category) async {
    final confirmed = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pulihkan kategori?'),
        content: Text(
          '${category['name']} akan aktif kembali dengan nilai dan bobot yang sudah tersimpan.',
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
      await ref
          .read(gradingRepositoryProvider)
          .restoreCategory(category['id'] as int);
      if (mounted) {
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kategori dipulihkan. Periksa total bobot sebelum menyimpan perubahan.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _edit({Map<String, Object?>? category}) async {
    final controller = TextEditingController(
      text: category?['name'] as String? ?? '',
    );
    final name = await showAcademicDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category == null ? 'Tambah Kategori' : 'Ubah Kategori'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      final repo = ref.read(gradingRepositoryProvider);
      if (category == null) {
        await repo.createCategory(name);
      } else {
        await repo.renameCategory(category['id'] as int, name);
      }
      if (mounted) setState(() => revision++);
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _archive(Map<String, Object?> category) async {
    final confirmed = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arsipkan kategori?'),
        content: const Text(
          'Penilaian lama tetap menyimpan kategori dan nilainya.',
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
      await ref
          .read(gradingRepositoryProvider)
          .archiveCategory(category['id'] as int);
      if (mounted) setState(() => revision++);
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey(revision),
    future: ref
        .read(gradingRepositoryProvider)
        .categories(includeArchived: true),
    builder: (context, snapshot) => _GradeScaffold(
      title: 'Kategori Penilaian',
      subtitle: 'Kelola kategori penilaian',
      action: showingArchive
          ? null
          : FilledButton(
              onPressed: () => context
                  .push(
                    '${gradingPath(widget.classId, widget.subjectId)}/kategori/tambah',
                  )
                  .then((_) {
                    if (mounted) setState(() => revision++);
                  }),
              child: const Text('+ Tambah Kategori'),
            ),
      children: [
        const _GradeCard(
          color: AppColors.iceBlue,
          child: AcademicText(
            'Kategori Penilaian\nKategori default dan buatan guru',
          ),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Aktif')),
            ButtonSegment(value: true, label: Text('Arsip')),
          ],
          selected: {showingArchive},
          onSelectionChanged: (value) =>
              setState(() => showingArchive = value.first),
        ),
        _GradeCard(
          child: Column(
            children: [
              if (snapshot.hasError) const Text('Kategori belum dapat dimuat.'),
              if (snapshot.hasData &&
                  !(snapshot.data!).any(
                    (row) => showingArchive
                        ? row['archived_at'] != null
                        : row['archived_at'] == null,
                  ))
                Text(
                  showingArchive
                      ? 'Arsip kategori kosong.'
                      : 'Belum ada kategori aktif.',
                ),
              for (final category
                  in (snapshot.data ?? <Map<String, Object?>>[]).where(
                    (row) => showingArchive
                        ? row['archived_at'] != null
                        : row['archived_at'] == null,
                  ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: showingArchive
                        ? AppColors.line
                        : AppColors.yellow,
                    child: Text((category['name'] as String).substring(0, 1)),
                  ),
                  title: Text(category['name'] as String),
                  subtitle: showingArchive ? const Text('Diarsipkan') : null,
                  trailing: showingArchive
                      ? TextButton(
                          onPressed: () => _restore(category),
                          child: const Text('Pulihkan'),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) => value == 'edit'
                              ? _edit(category: category)
                              : _archive(category),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Ubah nama'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Arsipkan'),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        ),
        if (!showingArchive)
          const _GradeCard(
            color: AppColors.lavender,
            child: Text(
              'Kategori kustom seperti Praktik, Proyek, dan Presentasi dapat ditambahkan. Kategori berisi nilai lebih aman diarsipkan.',
            ),
          ),
      ],
    ),
  );
}

class CategoryAddScreen extends ConsumerStatefulWidget {
  const CategoryAddScreen({super.key});
  @override
  ConsumerState<CategoryAddScreen> createState() => _CategoryAddScreenState();
}

class _CategoryAddScreenState extends ConsumerState<CategoryAddScreen> {
  final name = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await ref.read(gradingRepositoryProvider).createCategory(name.text);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _GradeScaffold(
    title: 'Tambah Kategori',
    subtitle: 'Kategori penilaian baru',
    action: FilledButton(
      onPressed: saving ? null : _save,
      child: const Text('Simpan Kategori'),
    ),
    children: [
      const _GradeCard(
        color: AppColors.lavender,
        child: Text(
          'Kategori baru, makin fleksibel.\n'
          'Buat kategori seperti Praktik, Proyek atau Presentasi.',
        ),
      ),
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Nama Kategori'),
      ),
      const TextField(
        enabled: false,
        decoration: InputDecoration(labelText: 'Bobot Awal', hintText: '0%'),
      ),
      const _GradeCard(
        color: AppColors.yellow,
        child: Text(
          'Bobot awal 0% tidak mengubah nilai akhir. '
          'Bobot bisa disesuaikan di Atur Bobot.',
        ),
      ),
    ],
  );
}

class WeightSettingsScreen extends ConsumerStatefulWidget {
  const WeightSettingsScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });
  final int classId;
  final int subjectId;
  @override
  ConsumerState<WeightSettingsScreen> createState() =>
      _WeightSettingsScreenState();
}

class _WeightSettingsScreenState extends ConsumerState<WeightSettingsScreen> {
  late final Future<_ScopeInfo> scopeFuture;
  late final Future<List<Map<String, Object?>>> categoriesFuture;
  final controllers = <int, TextEditingController>{};
  bool loaded = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    scopeFuture = _scope(ref, widget.classId, widget.subjectId);
    categoriesFuture = ref.read(gradingRepositoryProvider).categories();
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(_ScopeInfo scope) async {
    final values = <int, int>{};
    for (final entry in controllers.entries) {
      final parsed = int.tryParse(entry.value.text.trim());
      if (parsed == null) {
        _showError(
          context,
          const FormatException('Bobot harus berupa bilangan bulat.'),
        );
        return;
      }
      values[entry.key] = parsed;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(gradingRepositoryProvider)
          .saveWeights(
            classId: widget.classId,
            subjectId: widget.subjectId,
            periodId: scope.periodId,
            values: values,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        _showError(context, error);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ScopeInfo>(
    future: scopeFuture,
    builder: (context, scopeSnapshot) {
      if (!scopeSnapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final scope = scopeSnapshot.data!;
      return FutureBuilder<List<Map<String, Object?>>>(
        future: categoriesFuture,
        builder: (context, categorySnapshot) {
          if (!categorySnapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!loaded) {
            return FutureBuilder<Map<int, int>>(
              future: ref
                  .read(gradingRepositoryProvider)
                  .weights(
                    classId: widget.classId,
                    subjectId: widget.subjectId,
                    periodId: scope.periodId,
                  ),
              builder: (context, weightSnapshot) {
                if (!weightSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                const defaults = {
                  'Tugas': 30,
                  'Ulangan': 15,
                  'UTS': 25,
                  'UAS': 25,
                  'Sikap': 5,
                };
                for (final category in categorySnapshot.data!) {
                  final id = category['id'] as int;
                  controllers[id] = TextEditingController(
                    text:
                        '${weightSnapshot.data!.isEmpty ? defaults[category['name']] ?? 0 : weightSnapshot.data![id] ?? 0}',
                  );
                }
                loaded = true;
                return _content(scope, categorySnapshot.data!);
              },
            );
          }
          return _content(scope, categorySnapshot.data!);
        },
      );
    },
  );

  Widget _content(_ScopeInfo scope, List<Map<String, Object?>> categories) {
    final total = controllers.values.fold<int>(
      0,
      (sum, controller) => sum + (int.tryParse(controller.text) ?? 0),
    );
    final valid = total == 100;
    return _GradeScaffold(
      title: 'Atur Bobot Penilaian',
      subtitle: '${scope.subjectName} · ${scope.className}',
      action: FilledButton(
        onPressed: valid && !saving ? () => _save(scope) : null,
        child: Text(valid ? 'Simpan Bobot' : 'Simpan Bobot ($total%)'),
      ),
      children: [
        _GradeCard(
          color: valid ? AppColors.iceBlue : AppColors.peach,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL BOBOT',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                '$total%',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                ),
              ),
              Text(
                valid ? 'Valid ✓' : 'Bobot harus tepat 100% untuk disimpan.',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (total / 100).clamp(0, 1),
                color: AppColors.blue,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ),
        _GradeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bobot per kategori',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final category in categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category['name'] as String),
                  trailing: SizedBox(
                    width: 72,
                    child: TextField(
                      controller: controllers[category['id'] as int],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(suffixText: '%'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _GradeCard(
          color: valid ? AppColors.lightGreen : AppColors.yellow,
          child: const Text(
            'Perubahan bobot memengaruhi rekap. Kategori berbobot 0% tetap bisa digunakan.',
          ),
        ),
      ],
    );
  }
}

class GradeRecapScreen extends ConsumerStatefulWidget {
  const GradeRecapScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });
  final int classId;
  final int subjectId;
  @override
  ConsumerState<GradeRecapScreen> createState() => _GradeRecapScreenState();
}

class _RecapData {
  const _RecapData(this.scope, this.students, this.results, this.categories);
  final _ScopeInfo scope;
  final List<Map<String, Object?>> students;
  final Map<int, GradeResult?> results;
  final List<Map<String, Object?>> categories;
}

class _GradeRecapScreenState extends ConsumerState<GradeRecapScreen> {
  int revision = 0;
  Future<_RecapData> _load() async {
    final scope = await _scope(ref, widget.classId, widget.subjectId);
    final db = ref.read(appDatabaseProvider).database;
    final students = await db.query(
      'student',
      where: 'class_id = ? AND archived_at IS NULL',
      whereArgs: [widget.classId],
      orderBy: 'attendance_number',
    );
    final repo = ref.read(gradingRepositoryProvider);
    final results = <int, GradeResult?>{};
    for (final student in students) {
      final id = student['id'] as int;
      results[id] = await repo.resultForStudent(
        classId: widget.classId,
        subjectId: widget.subjectId,
        periodId: scope.periodId,
        studentId: id,
      );
    }
    return _RecapData(
      scope,
      students,
      results,
      await repo.categories(includeArchived: true),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RecapData>(
    key: ValueKey(revision),
    future: _load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          body: Center(
            child: snapshot.hasError
                ? const Text('Rekap belum dapat dibuka.')
                : const CircularProgressIndicator(),
          ),
        );
      }
      final data = snapshot.data!;
      final path = gradingPath(widget.classId, widget.subjectId);
      final finals = data.results.values
          .where((value) => value?.finalGrade != null)
          .map((value) => value!.finalGrade!)
          .toList();
      final average = finals.isEmpty
          ? null
          : finals.reduce((a, b) => a + b) / finals.length;
      final highest = finals.isEmpty
          ? null
          : finals.reduce((a, b) => a > b ? a : b);
      final lowest = finals.isEmpty
          ? null
          : finals.reduce((a, b) => a < b ? a : b);
      final categoryValues = <int, List<double>>{};
      for (final result in data.results.values) {
        if (result == null) continue;
        for (final entry in result.categoryAverages.entries) {
          categoryValues.putIfAbsent(entry.key, () => []).add(entry.value);
        }
      }
      final distribution = <String, int>{
        '0–59': 0,
        '60–74': 0,
        '75–89': 0,
        '90–100': 0,
      };
      for (final value in finals) {
        final band = value < 60
            ? '0–59'
            : value < 75
            ? '60–74'
            : value < 90
            ? '75–89'
            : '90–100';
        distribution[band] = distribution[band]! + 1;
      }
      return _GradeScaffold(
        title: 'Rekap Nilai',
        subtitle: '${data.scope.subjectName} · ${data.scope.className}',
        action: FilledButton(
          onPressed: () => context.push(periodPath(context, '$path/ekspor')),
          child: const Text('Ekspor Nilai Excel'),
        ),
        children: [
          _GradeCard(
            color: AppColors.iceBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _Pill(data.scope.className, color: Colors.white),
                    _Pill(data.scope.subjectName, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 12),
                AcademicText(
                  '${data.scope.periodName} · ${data.students.length} siswa',
                ),
              ],
            ),
          ),
          _GradeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistik Kelas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(
                      average?.toStringAsFixed(2) ?? '—',
                      'Rata-rata',
                      AppColors.iceBlue,
                    ),
                    _Metric(
                      highest?.toStringAsFixed(2) ?? '—',
                      'Tertinggi',
                      AppColors.lightGreen,
                    ),
                    _Metric(
                      lowest?.toStringAsFixed(2) ?? '—',
                      'Terendah',
                      AppColors.yellow,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _GradeCard(
            color: AppColors.lavender,
            child: AcademicText(
              '${finals.length} siswa memiliki nilai akhir lengkap. '
              '${data.students.length - finals.length} siswa masih memiliki nilai sementara atau belum lengkap.',
            ),
          ),
          _GradeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AcademicText(
                  'Rekap siswa',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                for (final student in data.students)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(student['name'] as String),
                    subtitle: Text(
                      data.results[student['id']]?.isComplete == true
                          ? 'Final'
                          : data.results[student['id']]?.provisional != null
                          ? 'Sementara'
                          : 'Belum lengkap',
                    ),
                    trailing: _Pill(
                      data.results[student['id']]?.finalGrade?.toStringAsFixed(
                            2,
                          ) ??
                          data.results[student['id']]?.provisional
                              ?.toStringAsFixed(2) ??
                          '—',
                      color: data.results[student['id']]?.isComplete == true
                          ? AppColors.lightGreen
                          : AppColors.yellow,
                    ),
                    onTap: () => context.push(
                      periodPath(context, '$path/rekap/${student['id']}'),
                    ),
                  ),
              ],
            ),
          ),
          _GradeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rata-rata per kategori',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final entry in categoryValues.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      data.categories.firstWhere(
                            (category) => category['id'] == entry.key,
                            orElse: () => {'name': 'Kategori ${entry.key}'},
                          )['name']
                          as String,
                    ),
                    trailing: Text(
                      (entry.value.reduce((a, b) => a + b) / entry.value.length)
                          .toStringAsFixed(2),
                    ),
                  ),
              ],
            ),
          ),
          _GradeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribusi nilai akhir',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final entry in distribution.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    trailing: AcademicText('${entry.value} siswa'),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class StudentGradeScreen extends ConsumerWidget {
  const StudentGradeScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.studentId,
  });
  final int classId;
  final int subjectId;
  final int studentId;

  Future<
    (
      Map<String, Object?>,
      _ScopeInfo,
      GradeResult?,
      Map<int, int>,
      List<Map<String, Object?>>,
    )
  >
  _load(WidgetRef ref) async {
    final scope = await _scope(ref, classId, subjectId);
    final db = ref.read(appDatabaseProvider).database;
    final student = (await db.query(
      'student',
      where: 'id = ?',
      whereArgs: [studentId],
    )).single;
    final repo = ref.read(gradingRepositoryProvider);
    return (
      student,
      scope,
      await repo.resultForStudent(
        classId: classId,
        subjectId: subjectId,
        periodId: scope.periodId,
        studentId: studentId,
      ),
      await repo.weights(
        classId: classId,
        subjectId: subjectId,
        periodId: scope.periodId,
      ),
      await repo.categories(includeArchived: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<
        (
          Map<String, Object?>,
          _ScopeInfo,
          GradeResult?,
          Map<int, int>,
          List<Map<String, Object?>>,
        )
      >(
        future: _load(ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final (student, scope, result, weights, categories) = snapshot.data!;
          final value = result?.finalGrade ?? result?.provisional;
          return _GradeScaffold(
            title: 'Nilai ${student['name']}',
            subtitle: '${scope.className} · ${scope.subjectName}',
            children: [
              _GradeCard(
                color: AppColors.iceBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Pill(
                      'SISWA ${student['attendance_number']}',
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      student['name'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${scope.className} · ${scope.subjectName} · ${scope.periodName}',
                    ),
                  ],
                ),
              ),
              _GradeCard(
                color: result?.isComplete == true
                    ? AppColors.lightGreen
                    : AppColors.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result?.isComplete == true
                          ? 'Nilai Akhir Semester'
                          : 'Nilai Sementara',
                    ),
                    Text(
                      value?.toStringAsFixed(2) ?? '—',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                      ),
                    ),
                    Text(
                      result?.isComplete == true
                          ? 'Lengkap ✓'
                          : 'Belum menjadi nilai akhir resmi',
                    ),
                  ],
                ),
              ),
              _GradeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Perhitungan nilai',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    for (final entry in weights.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          categories.firstWhere(
                                (category) => category['id'] == entry.key,
                                orElse: () => {'name': 'Kategori ${entry.key}'},
                              )['name']
                              as String,
                        ),
                        subtitle: Text('${entry.value}%'),
                        trailing: Text(
                          result?.categoryAverages[entry.key]?.toStringAsFixed(
                                2,
                              ) ??
                              '—',
                        ),
                      ),
                  ],
                ),
              ),
              if (result != null && result.incompleteReasons.isNotEmpty)
                _GradeCard(
                  color: AppColors.lavender,
                  child: Text(result.incompleteReasons.join('\n')),
                ),
            ],
          );
        },
      );
}

class GradeExportScreen extends ConsumerStatefulWidget {
  const GradeExportScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });
  final int classId;
  final int subjectId;

  @override
  ConsumerState<GradeExportScreen> createState() => _GradeExportScreenState();
}

class _GradeExportScreenState extends ConsumerState<GradeExportScreen> {
  late final Future<_ScopeInfo> scopeFuture;
  bool busy = false;
  Uint8List? lastWorkbook;
  String? lastFilename;

  @override
  void initState() {
    super.initState();
    scopeFuture = _scope(ref, widget.classId, widget.subjectId);
  }

  String _filename(_ScopeInfo scope) {
    String clean(String value) =>
        value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'rekap_${clean(scope.className)}_${clean(scope.subjectName)}_'
        '${clean(scope.periodName)}.xlsx';
  }

  Future<void> _export(_ScopeInfo scope, {bool share = false}) async {
    setState(() => busy = true);
    try {
      final report = await ref
          .read(gradeReportRepositoryProvider)
          .load(
            classId: widget.classId,
            subjectId: widget.subjectId,
            periodId: scope.periodId,
          );
      final bytes = const GradeXlsxExporter().build(report);
      final filename = _filename(scope);
      final delivered = share
          ? await ref.read(reportDeliveryProvider).share(filename, bytes)
          : await ref.read(reportDeliveryProvider).save(filename, bytes);
      if (!mounted) return;
      lastWorkbook = bytes;
      lastFilename = filename;
      if (delivered) {
        await showAcademicDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ekspor Berhasil'),
            content: Text(
              'Berhasil dibuat: $filename\n'
              '4 sheet · Detail, Kategori, Nilai Akhir, Matriks Nilai',
            ),
            actions: [
              if (!share)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _shareLast();
                  },
                  child: const Text('Bagikan'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await showAcademicDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ekspor Gagal'),
          content: const Text(
            'Gagal membuat laporan. Coba pilih lokasi '
            'penyimpanan lain atau periksa izin file pada perangkat.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _shareLast() async {
    if (lastWorkbook == null || lastFilename == null) return;
    try {
      await ref
          .read(reportDeliveryProvider)
          .share(lastFilename!, lastWorkbook!);
    } catch (_) {
      if (mounted) {
        _showError(
          context,
          const FormatException('Berkas belum dapat dibagikan.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ScopeInfo>(
    future: scopeFuture,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final scope = snapshot.data!;
      return _GradeScaffold(
        title: 'Ekspor Nilai Excel',
        subtitle: '${scope.subjectName} · ${scope.className}',
        action: FilledButton(
          onPressed: busy ? null : () => _export(scope),
          child: Text(busy ? 'Membuat laporan…' : 'Ekspor Nilai (.xlsx)'),
        ),
        children: [
          const _GradeCard(
            color: AppColors.lightGreen,
            child: Text(
              'XLSX\nLaporan Penilaian',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          _GradeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih data yang diekspor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kelas'),
                  trailing: Text(scope.className),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AcademicText('Mata Pelajaran'),
                  trailing: Text(scope.subjectName),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Periode'),
                  trailing: Text(scope.periodName),
                ),
              ],
            ),
          ),
          const _GradeCard(
            color: AppColors.iceBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Isi file Excel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ListTile(title: Text('01  Detail Penilaian')),
                ListTile(title: Text('02  Rekap per Kategori')),
                ListTile(title: Text('03  Nilai Akhir')),
                ListTile(title: Text('04  Matriks Nilai')),
              ],
            ),
          ),
          const _GradeCard(
            color: AppColors.yellow,
            child: Text(
              'Format khusus nilai: kosong = belum dinilai · '
              '0 = nilai nol · EX = dikecualikan',
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _export(scope, share: true),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Bagikan Excel'),
          ),
        ],
      );
    },
  );
}
