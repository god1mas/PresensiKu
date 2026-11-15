import 'package:presensiku/core/education/academic_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../academics/data/class_repository.dart';
import '../../academics/data/roster_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/attendance_repository.dart';

class AttendanceSetupScreen extends ConsumerStatefulWidget {
  const AttendanceSetupScreen({
    super.key,
    this.initialClassId,
    this.initialSubjectId,
  });

  final int? initialClassId;
  final int? initialSubjectId;

  @override
  ConsumerState<AttendanceSetupScreen> createState() =>
      _AttendanceSetupScreenState();
}

class _AttendanceSetupScreenState extends ConsumerState<AttendanceSetupScreen> {
  int? classId;
  int? subjectId;
  DateTime date = DateTime.now();
  int meeting = 1;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    classId = widget.initialClassId;
    subjectId = widget.initialSubjectId;
  }

  Future<void> continueAttendance() async {
    if (classId == null || subjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AcademicText('Pilih kelas dan mata pelajaran.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final result = await ref
          .read(attendanceRepositoryProvider)
          .prepare(
            classId: classId!,
            subjectId: subjectId!,
            date: DateFormat('yyyy-MM-dd').format(date),
            meetingNumber: meeting,
            periodId: ref.read(selectedAcademicPeriodProvider),
          );
      if (!mounted) return;
      context.push(
        result.completed
            ? '/riwayat/${result.sessionId}'
            : '/absensi/${result.sessionId}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classRepositoryProvider);
    final roster = ref.watch(rosterRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mulai absensi')),
      body: FutureBuilder<List<AcademicPeriod>>(
        future: classes.periods(),
        builder: (context, periodSnapshot) {
          if (!periodSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = periodSnapshot.data!
              .where(
                (p) => ref.read(selectedAcademicPeriodProvider) == null
                    ? p.isActive
                    : p.id == ref.read(selectedAcademicPeriodProvider),
              )
              .firstOrNull;
          if (active == null) {
            return const Center(
              child: Text('Buat periode akademik dan kelas terlebih dahulu.'),
            );
          }
          return FutureBuilder<List<SchoolClass>>(
            future: classes.classes(active.id),
            builder: (context, classSnapshot) {
              if (!classSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final available = classSnapshot.data!;
              if (available.isEmpty) {
                return const Center(
                  child: Text('Tambahkan kelas sebelum memulai absensi.'),
                );
              }
              final selectedClassId =
                  available.any((item) => item.id == classId) ? classId : null;
              if (classId != null && selectedClassId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && classId != null) {
                    setState(() {
                      classId = null;
                      subjectId = null;
                    });
                  }
                });
              }
              return ListView(
                padding: const EdgeInsets.all(AppSpace.lg),
                children: [
                  Text(
                    active.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.base),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.base),
                    decoration: BoxDecoration(
                      color: AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(AppRadius.featured),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LANGKAH 01 / 02',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: AppSpace.sm),
                        Text('Siap mencatat kehadiran?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  DropdownButtonFormField<int>(
                    key: ValueKey(selectedClassId),
                    initialValue: selectedClassId,
                    decoration: InputDecoration(labelText: 'Pilih kelas'),
                    items: available
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.name} · ${item.studentCount} ${educationTerms(context).student.toLowerCase()}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      classId = value;
                      subjectId = null;
                    }),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (selectedClassId != null)
                    FutureBuilder<List<Subject>>(
                      future: roster.subjectsForClass(selectedClassId),
                      builder: (context, snapshot) {
                        final subjects = snapshot.data ?? [];
                        if (snapshot.hasData && subjects.isEmpty) {
                          return const AcademicText(
                            'Hubungkan mata pelajaran ke kelas ini terlebih dahulu.',
                          );
                        }
                        return DropdownButtonFormField<int>(
                          key: ValueKey('$selectedClassId:$subjectId'),
                          initialValue:
                              subjects.any((item) => item.id == subjectId)
                              ? subjectId
                              : null,
                          decoration: InputDecoration(
                            labelText: educationTerms(context)
                                .translate('Mata pelajaran'),
                          ),
                          items: subjects
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => subjectId = value),
                        );
                      },
                    ),
                  const SizedBox(height: AppSpace.lg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal absensi'),
                    subtitle: Text(
                      DateFormat('EEEE, d MMMM y', 'id_ID').format(date),
                    ),
                    trailing: const Icon(Icons.calendar_month_outlined),
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
                  const SizedBox(height: AppSpace.base),
                  TextFormField(
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Pertemuan / Sesi'),
                    onChanged: (value) => meeting = int.tryParse(value) ?? 0,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.base),
                    decoration: BoxDecoration(
                      color: AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Text(
                      'Pertemuan yang sudah ada akan dibuka kembali agar tidak tercatat dua kali.',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: FilledButton(
          onPressed: busy ? null : continueAttendance,
          child: const Text('Lanjutkan absensi ↗'),
        ),
      ),
    );
  }
}

class AttendanceRecordScreen extends ConsumerStatefulWidget {
  const AttendanceRecordScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<AttendanceRecordScreen> createState() =>
      _AttendanceRecordScreenState();
}

class _AttendanceRecordScreenState
    extends ConsumerState<AttendanceRecordScreen> {
  int revision = 0;
  bool busy = false;
  final Map<int, String> pendingStatus = {};

  void back(AttendanceSession session) {
    if (busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunggu sampai perubahan tersimpan.')),
      );
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        '/absensi?kelas=${session.classId}&mapel=${session.subjectId}',
      );
    }
  }

  Future<void> mark(int recordId, String status) async {
    if (busy) return;
    setState(() {
      busy = true;
      pendingStatus[recordId] = status;
    });
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .mark(sessionId: widget.id, recordId: recordId, status: status);
      if (mounted) {
        setState(() {
          pendingStatus.remove(recordId);
          revision++;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          pendingStatus.remove(recordId);
          busy = false;
        });
      }
    }
  }

  Future<void> markAll() async {
    if (busy) return;
    final confirmed = await showAcademicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tandai semua hadir?'),
        content: const AcademicText(
          'Status siswa yang sudah dipilih juga akan berubah menjadi Hadir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, semua hadir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await ref.read(attendanceRepositoryProvider).markAllPresent(widget.id);
      if (mounted) setState(() => revision++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> complete() async {
    setState(() => busy = true);
    try {
      await ref.read(attendanceRepositoryProvider).complete(widget.id);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) context.go('/absensi/sukses/${widget.id}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AttendanceSession>(
    key: ValueKey(revision),
    future: ref.watch(attendanceRepositoryProvider).load(widget.id),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('Sesi absensi belum dapat dimuat.')),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final session = snapshot.data!;
      if (session.state == 'completed') {
        return const Scaffold(
          body: Center(child: Text('Absensi sudah tersimpan.')),
        );
      }
      final progress = session.records.isEmpty
          ? 0.0
          : session.markedCount / session.records.length;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back(session);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Kembali',
              onPressed: () => back(session),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Absensi ${session.className}'),
                Text(
                  '${session.subjectName} · Pertemuan ${session.meetingNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.base),
                  decoration: BoxDecoration(
                    color: AppColors.iceBlue,
                    borderRadius: BorderRadius.circular(AppRadius.featured),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hari ini'),
                      AcademicText(
                        '${session.markedCount} dari ${session.records.length} siswa',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpace.base),
                      LinearProgressIndicator(value: progress),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar kehadiran',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: markAll,
                      child: const Text('✓ Semua hadir'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  itemCount: session.records.length,
                  itemBuilder: (context, index) {
                    final record = session.records[index];
                    final selectedStatus =
                        pendingStatus[record.id] ?? record.status;
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 19,
                                  backgroundColor: AppColors.iceBlue,
                                  child: Text(
                                    '${record.number}'.padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                    record.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (selectedStatus == null)
                                  const Text(
                                    'Belum diisi',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.md),
                            Row(
                              children: [
                                for (final status in const ['H', 'S', 'I', 'A'])
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: status == 'A' ? 0 : 7,
                                      ),
                                      child: FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => mark(record.id, status),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 0,
                                          ),
                                          backgroundColor:
                                              selectedStatus == status
                                              ? _statusColor(status)
                                              : _statusColor(status)
                                                    .withValues(alpha: 0.11),
                                          foregroundColor:
                                              selectedStatus == status
                                              ? Colors.white
                                              : _statusColor(status),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.card,
                                            ),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$status ${_statusLabel(status)}',
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: FilledButton(
                onPressed: busy || session.unmarkedCount > 0 ? null : complete,
                child: Text(
                  session.unmarkedCount > 0
                      ? 'Simpan absensi · ${session.unmarkedCount} belum diisi'
                      : 'Simpan absensi',
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AttendanceSuccessScreen extends ConsumerWidget {
  const AttendanceSuccessScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => FutureBuilder<AttendanceSession>(
    future: ref.watch(attendanceRepositoryProvider).load(id),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final session = snapshot.data!;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/riwayat/$id');
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Absensi tersimpan'),
            leading: IconButton(
              tooltip: 'Kembali',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/riwayat/$id'),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                const SizedBox(height: AppSpace.xl),
                const Chip(label: Text('SELESAI!')),
                const SizedBox(height: AppSpace.lg),
                const CircleAvatar(
                  radius: 80,
                  backgroundColor: AppColors.green,
                  child: Icon(Icons.check, size: 64, color: Colors.white),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Sip, absensi tersimpan!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Catatan kelas ${session.className} sudah aman tersimpan di perangkat ini.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.xl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      children: [
                        Text(
                          '${session.subjectName} · Pertemuan ${session.meetingNumber}',
                        ),
                        Text(session.date),
                        const SizedBox(height: AppSpace.base),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final status in const ['H', 'S', 'I', 'A'])
                              Column(
                                children: [
                                  Text(
                                    '${session.records.where((r) => r.status == status).length}',
                                  ),
                                  Text(_statusLabel(status)),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go('/riwayat/$id'),
                    child: const Text('Lihat rekap'),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/beranda'),
                    child: const Text('Kembali ke beranda'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _statusLabel(String status) => switch (status) {
  'H' => 'Hadir',
  'S' => 'Sakit',
  'I' => 'Izin',
  _ => 'Alpha',
};
Color _statusColor(String status) => switch (status) {
  'H' => const Color(0xFF168345),
  'S' => const Color(0xFF985A08),
  'I' => AppColors.blue,
  _ => const Color(0xFFB84045),
};
String _message(Object error) {
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  return 'Absensi belum dapat disimpan. Coba lagi.';
}
