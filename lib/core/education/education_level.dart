enum EducationLevel {
  tk('TK'),
  sd('SD/MI'),
  smp('SMP/MTs'),
  sma('SMA/MA'),
  university('Perguruan Tinggi');

  const EducationLevel(this.label);
  final String label;
  bool get isUniversity => this == university;

  static EducationLevel? parse(Object? value) =>
      values.where((level) => level.name == value).firstOrNull;
}

/// A class keeps its own terminology even after the profile level changes.
class EducationTerms {
  const EducationTerms(this.level);
  final EducationLevel? level;
  bool get university => level == EducationLevel.university;
  String get educator => university ? 'Dosen' : 'Guru';
  String get student => university ? 'Mahasiswa' : 'Siswa';
  String get subject => university ? 'Mata Kuliah' : 'Mata Pelajaran';
  String get identifier => university ? 'NIM' : 'NIS/NISN';

  String translate(String text) {
    if (!university) return text;
    const words = {
      'Mata Pelajaran': 'Mata Kuliah',
      'Mata pelajaran': 'Mata kuliah',
      'mata pelajaran': 'mata kuliah',
      'MAPEL': 'MATA KULIAH',
      'Mapel': 'Mata Kuliah',
      'mapel': 'mata kuliah',
      'NIS/NISN (opsional)': 'NIM',
      'NIS/NISN': 'NIM',
      'Siswa': 'Mahasiswa',
      'siswa': 'mahasiswa',
      'SISWA': 'MAHASISWA',
      'Guru': 'Dosen',
      'guru': 'dosen',
      'GURU': 'DOSEN',
      'sekolah': 'institusi',
      'Sekolah': 'Institusi',
    };
    var result = text;
    for (final entry in words.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
