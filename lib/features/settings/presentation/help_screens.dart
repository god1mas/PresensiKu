import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/tokens.dart';
import '../../../core/education/academic_scope.dart';

class _GuideSection {
  const _GuideSection(this.title, this.icon, this.steps);

  final String title;
  final IconData icon;
  final List<String> steps;
}

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  List<_GuideSection> _sections(BuildContext context) {
    final terms = educationTerms(context);
    final university = terms.university;
    final student = terms.student.toLowerCase();
    final subject = terms.subject.toLowerCase();
    return [
      _GuideSection('Memulai KelasKu', Icons.rocket_launch_outlined, [
        'Isi nama ${terms.educator.toLowerCase()}, nama ${university ? 'institusi' : 'sekolah'}, dan jenjang pendidikan saat pertama membuka aplikasi.',
        'Data pembelajaran disimpan secara lokal di perangkat. KelasKu dapat digunakan tanpa internet.',
      ]),
      _GuideSection('Tahun Ajaran & Semester', Icons.calendar_month_outlined, [
        'Buka Pengaturan → Tahun ajaran untuk membuat periode Ganjil atau Genap.',
        'Memilih periode untuk melihat data berbeda dari mengaktifkannya. Aktifkan periode yang akan dipakai untuk pekerjaan saat ini.',
        university
            ? 'Di perguruan tinggi, kelas, mata kuliah, dan peserta tiap semester terpisah; tidak disalin otomatis.'
            : 'Dalam satu tahun ajaran, kelas, siswa, mata pelajaran, dan warna berlanjut dari Ganjil ke Genap. Presensi dan penilaian dimulai lagi tiap semester.',
        'Riwayat periode sebelumnya tetap tersimpan dan dapat dibuka kembali.',
      ]),
      _GuideSection('Mengelola Kelas', Icons.school_outlined, [
        'Buka tab Kelas untuk menambah kelas; buka detailnya untuk mengubah data atau warna.',
        'Arsipkan kelas yang tidak aktif. Pilih Arsip pada daftar kelas, lalu Pulihkan untuk mengembalikannya.',
        university
            ? 'Kelas dan pesertanya berlaku pada semester yang dipilih.'
            : 'Kelas berlaku dalam satu tahun ajaran; tahun ajaran lain memiliki susunan kelas tersendiri.',
      ]),
      _GuideSection(terms.subject, Icons.menu_book_outlined, [
        'Buka Pengaturan → ${terms.subject} untuk menambah $subject. Di Detail Kelas, pilih Atur untuk menghubungkannya ke kelas.',
        'Item yang diarsipkan dapat dicari di tab Arsip dan dipulihkan tanpa menghapus riwayat lama.',
      ]),
      _GuideSection('Mengelola ${terms.student}', Icons.people_outline, [
        'Buka Detail Kelas → Kelola ${terms.student} untuk melihat, mencari, menambah, atau mengubah data $student.',
        'Atur ${university ? 'urutan presensi' : 'nomor absen'} agar daftar kehadiran sesuai kebutuhan.',
        if (university) 'NIM wajib untuk mahasiswa baru dan disimpan sebagai teks, termasuk angka nol di awal.',
      ]),
      _GuideSection('Mengisi Presensi', Icons.fact_check_outlined, [
        'Pilih Mulai Kelas, kelas, lalu $subject; buka Presensi.',
        'Tandai Hadir, Sakit, Izin, atau Alpha untuk setiap $student, kemudian simpan.',
        'Buka Riwayat → Presensi untuk melihat dan memperbaiki catatan yang sudah disimpan.',
      ]),
      _GuideSection('Mengelola Penilaian', Icons.grade_outlined, [
        'Dari detail $subject, buka Penilaian dan buat penilaian beserta kategorinya.',
        'Isi nilai angka, biarkan kosong bila belum dinilai, gunakan 0 untuk nilai nol, atau EX bila dikecualikan.',
        'Atur bobot kategori hingga totalnya 100%, lalu lihat Rekap Nilai.',
        'Penilaian, nilai, dan bobot mengikuti semester masing-masing; riwayat lama tetap tersedia.',
      ]),
      _GuideSection('Riwayat, Rekap & Excel', Icons.insert_chart_outlined, [
        'Buka Riwayat untuk mencari dan memfilter Presensi atau Penilaian menurut periode, kelas, $subject, dan tanggal.',
        'Buka Pengaturan → Rekap dan laporan untuk memilih laporan Presensi atau Penilaian.',
        'Simpan atau bagikan Excel. Ekspor penilaian berisi empat sheet, termasuk Matriks Nilai.',
      ]),
      _GuideSection('Backup & Restore', Icons.backup_outlined, [
        'Buka Pengaturan → Cadangkan data, lalu simpan file .pkbackup di luar ponsel.',
        'Gunakan Pulihkan data untuk memilih, meninjau, dan mengonfirmasi file cadangan. Pemulihan mengganti data aktif.',
        'Cadangkan sebelum menghapus aplikasi atau pindah ponsel. Cadangan bukan sinkronisasi cloud otomatis.',
      ]),
      _GuideSection('Pertanyaan Umum', Icons.help_outline, [
        'Di mana data disimpan? Di penyimpanan lokal aplikasi pada perangkat ini.',
        'Perlu internet? Tidak untuk penggunaan utama; pemindahan file cadangan dapat memakai cara yang Anda pilih.',
        'Apa yang terjadi saat ganti semester? Riwayat lama tetap ada; data semester baru mengikuti aturan jenjang di atas.',
        'Bagaimana memulihkan kelas arsip? Buka Kelas → Arsip → Pulihkan.',
        'Bagaimana pindah ponsel? Buat .pkbackup, salin ke ponsel baru, lalu gunakan Pulihkan data di KelasKu.',
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Panduan Penggunaan')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.base),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.iceBlue,
              borderRadius: BorderRadius.circular(AppRadius.featured),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belajar KelasKu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                const Text(
                  'Pilih topik untuk melihat langkah singkat. Panduan ini tersedia tanpa internet.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.base),
          for (var index = 0; index < sections.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: ExpansionTile(
                  key: ValueKey('guide-$index'),
                  leading: Icon(sections[index].icon, color: AppColors.blue),
                  title: Text(
                    sections[index].title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  children: [
                    for (
                      var step = 0;
                      step < sections[index].steps.length;
                      step++
                    )
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.base,
                          AppSpace.sm,
                          AppSpace.base,
                          AppSpace.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.iceBlue,
                              child: Text(
                                '${step + 1}',
                                style: const TextStyle(
                                  color: AppColors.blue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(child: Text(sections[index].steps[step])),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AboutKelasKuScreen extends StatefulWidget {
  const AboutKelasKuScreen({super.key});

  @override
  State<AboutKelasKuScreen> createState() => _AboutKelasKuScreenState();
}

class _AboutKelasKuScreenState extends State<AboutKelasKuScreen> {
  static const _channel = MethodChannel('com.presensiku.presensiku/app_info');
  late final Future<String?> _version = _channel.invokeMethod<String>(
    'version',
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang KelasKu')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(AppSpace.base),
            decoration: BoxDecoration(
              color: AppColors.iceBlue,
              borderRadius: BorderRadius.circular(AppRadius.featured),
            ),
            child: SvgPicture.asset(
              'assets/brand/presensiku_emblem.svg',
              semanticsLabel: 'Logo KelasKu',
            ),
          ),
        ),
        const SizedBox(height: AppSpace.base),
        Text(
          'KelasKu',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'by god1mas',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.xl),
        Card(
          color: AppColors.iceBlue,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tentang aplikasi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                const Text(
                  'KelasKu adalah aplikasi pengelolaan kelas, presensi, dan penilaian untuk guru dan dosen. Data pembelajaran disimpan secara lokal di perangkat dan fitur utamanya dapat digunakan tanpa internet.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.base),
        ListTile(
          leading: const Icon(Icons.info_outline, color: AppColors.blue),
          title: const Text('Versi aplikasi'),
          subtitle: FutureBuilder<String?>(
            future: _version,
            builder: (context, snapshot) => Text(
              snapshot.hasError
                  ? 'Versi tidak tersedia'
                  : snapshot.data ?? 'Memuat versi…',
            ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.person_outline, color: AppColors.blue),
          title: Text('Pengembang'),
          subtitle: Text('Dimas Abdus Syukur'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.copyright_outlined, color: AppColors.blue),
          title: Text('Hak cipta'),
          subtitle: Text(
            '© 2026 Dimas Abdus Syukur (god1mas)\nPaket, font, dan aset pihak ketiga mengikuti lisensinya masing-masing.',
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.description_outlined,
            color: AppColors.blue,
          ),
          title: const Text('Lisensi Pihak Ketiga'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              showLicensePage(context: context, applicationName: 'KelasKu'),
        ),
      ],
    ),
  );
}
