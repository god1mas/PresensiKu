import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/history_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String search = '';
  int? classId;
  int? subjectId;
  DateTimeRange? range;
  int revision = 0;

  HistoryFilter get filter => HistoryFilter(
    search: search,
    classId: classId,
    subjectId: subjectId,
    fromDate: range == null
        ? null
        : DateFormat('yyyy-MM-dd').format(range!.start),
    toDate: range == null ? null : DateFormat('yyyy-MM-dd').format(range!.end),
  );

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(historyRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        actions: [
          IconButton(
            onPressed: () => context.push('/laporan'),
            tooltip: 'Rekap dan laporan',
            icon: const Icon(Icons.summarize_outlined),
          ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jejak kehadiran',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Cari catatan absensi sebelumnya.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari kelas atau mata pelajaran',
              ),
            ),
          ),
          const SizedBox(height: AppSpace.base),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              children: [
                FutureBuilder<List<HistoryOption>>(
                  future: repository.classOptions(),
                  builder: (context, snapshot) => DropdownButton<int?>(
                    value: classId,
                    hint: const Text('Semua kelas'),
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
                    onChanged: (value) => setState(() => classId = value),
                  ),
                ),
                const SizedBox(width: AppSpace.base),
                FutureBuilder<List<HistoryOption>>(
                  future: repository.subjectOptions(),
                  builder: (context, snapshot) => DropdownButton<int?>(
                    value: subjectId,
                    hint: const Text('Semua mapel'),
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
                    onChanged: (value) => setState(() => subjectId = value),
                  ),
                ),
                const SizedBox(width: AppSpace.base),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: range,
                    );
                    if (picked != null) setState(() => range = picked);
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(range == null ? 'Tanggal' : 'Rentang tanggal'),
                ),
                if (range != null)
                  IconButton(
                    onPressed: () => setState(() => range = null),
                    icon: const Icon(Icons.close),
                    tooltip: 'Hapus tanggal',
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<HistorySession>>(
              key: ValueKey('$revision:$search:$classId:$subjectId:$range'),
              future: repository.sessions(filter),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Riwayat belum dapat dimuat.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snapshot.data!;
                if (sessions.isEmpty) {
                  return const Center(child: Text('Riwayat kosong'));
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Riwayat absensi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '${sessions.length} pertemuan',
                          style: const TextStyle(color: AppColors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.base),
                    for (final session in sessions)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${session.subjectName} · ${session.className}',
                          ),
                          subtitle: Text(
                            '${session.date} · Pertemuan ${session.meetingNumber}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await context.push('/riwayat/${session.id}');
                            if (mounted) setState(() => revision++);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryDetailScreen extends ConsumerStatefulWidget {
  const HistoryDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<HistoryDetailScreen> createState() =>
      _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends ConsumerState<HistoryDetailScreen> {
  int revision = 0;
  bool editing = false;

  Future<void> changeStatus(AttendanceRecord record) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Ubah kehadiran ${record.name}'),
        children: [
          for (final status in const ['H', 'S', 'I', 'A'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, status),
              child: Text(_label(status)),
            ),
        ],
      ),
    );
    if (selected == null || selected == record.status) return;
    try {
      await ref
          .read(historyRepositoryProvider)
          .correct(sessionId: widget.id, recordId: record.id, status: selected);
      if (mounted) setState(() => revision++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koreksi belum tersimpan. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AttendanceSession>(
    key: ValueKey(revision),
    future: ref.watch(attendanceRepositoryProvider).load(widget.id),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('Detail absensi belum dapat dimuat.')),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final session = snapshot.data!;
      if (session.state != 'completed') {
        return const Scaffold(
          body: Center(child: Text('Absensi belum selesai.')),
        );
      }
      int count(String status) =>
          session.records.where((record) => record.status == status).length;
      return Scaffold(
        appBar: AppBar(title: const Text('Detail absensi')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Text(
              '${session.subjectName} · ${session.className}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.iceBlue,
                borderRadius: BorderRadius.circular(AppRadius.featured),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PERTEMUAN ${session.meetingNumber}'),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    session.date,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${session.records.length} siswa tercatat'),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              'Ringkasan kelas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.base),
            Row(
              children: [
                for (final status in const ['H', 'S', 'I', 'A'])
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.base,
                      ),
                      decoration: BoxDecoration(
                        color: _color(status),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${count(status)}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            _label(status),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kehadiran siswa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => editing = !editing),
                  child: Text(editing ? 'Selesai' : 'Edit data'),
                ),
              ],
            ),
            for (final record in session.records)
              ListTile(
                leading: CircleAvatar(
                  child: Text('${record.number}'.padLeft(2, '0')),
                ),
                title: Text(record.name),
                trailing: editing
                    ? TextButton(
                        onPressed: () => changeStatus(record),
                        child: Text(_label(record.status ?? 'A')),
                      )
                    : Chip(label: Text(_label(record.status ?? 'A'))),
              ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: FilledButton(
            onPressed: () => setState(() => editing = !editing),
            child: Text(editing ? 'Selesai mengedit' : 'Edit absensi'),
          ),
        ),
      );
    },
  );
}

String _label(String status) => switch (status) {
  'H' => 'Hadir',
  'S' => 'Sakit',
  'I' => 'Izin',
  _ => 'Alpha',
};
Color _color(String status) => switch (status) {
  'H' => const Color(0xFFE4F9EB),
  'S' => const Color(0xFFFFE7A0),
  'I' => AppColors.iceBlue,
  _ => const Color(0xFFFFE8DF),
};
