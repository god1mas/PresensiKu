import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'grade_report_repository.dart';

class GradeXlsxExporter {
  const GradeXlsxExporter();

  Uint8List build(GradeReportData report) {
    final workbook = Excel.createExcel();
    final detail = workbook['Detail Penilaian'];
    final categories = workbook['Rekap per Kategori'];
    final finalSheet = workbook['Nilai Akhir'];
    workbook.delete('Sheet1');
    final semester = report.semester == 'ganjil' ? 'Ganjil' : 'Genap';
    final weightLabel = report.weights.entries
        .map(
          (entry) =>
              '${report.categories[entry.key] ?? entry.key}: ${entry.value}%',
        )
        .join('; ');

    detail.appendRow(
      _headers([
        'Kelas',
        'Mata Pelajaran',
        'Tahun',
        'Semester',
        'Tanggal',
        'Kategori',
        'Bobot (%)',
        'Judul Penilaian',
        'BAB / Materi',
        'Skor Maksimal',
        'No. Absen',
        'Nama Siswa',
        'Nilai',
      ]),
    );
    for (final assessment in report.assessments) {
      final assessmentId = assessment['id'] as int;
      final categoryId = assessment['category_id'] as int;
      for (final student in report.students) {
        final grade = report.grades[(assessmentId, student['id'] as int)];
        detail.appendRow([
          TextCellValue(report.className),
          TextCellValue(report.subjectName),
          TextCellValue(report.yearLabel),
          TextCellValue(semester),
          TextCellValue(assessment['date'] as String),
          TextCellValue(assessment['category_name_snapshot'] as String),
          IntCellValue(report.weights[categoryId] ?? 0),
          TextCellValue(assessment['title'] as String),
          TextCellValue(assessment['bab'] as String? ?? ''),
          DoubleCellValue((assessment['max_score'] as num).toDouble()),
          IntCellValue(student['attendance_number'] as int),
          TextCellValue(
            grade?['student_name_snapshot'] as String? ??
                student['name'] as String,
          ),
          _scoreCell(grade),
        ]);
      }
    }

    categories.appendRow(
      _headers([
        'Kelas',
        'Mata Pelajaran',
        'Tahun',
        'Semester',
        'No. Absen',
        'Nama Siswa',
        'Kategori',
        'Bobot (%)',
        'Rata-rata Kategori',
        'Kontribusi Tertimbang',
        'Status',
      ]),
    );
    final categoryIds = <int>{
      ...report.weights.keys,
      ...report.assessments.map((row) => row['category_id'] as int),
    };
    for (final student in report.students) {
      final studentId = student['id'] as int;
      final result = report.results[studentId];
      for (final categoryId in categoryIds) {
        final average = result?.categoryAverages[categoryId];
        final weight = report.weights[categoryId] ?? 0;
        categories.appendRow([
          TextCellValue(report.className),
          TextCellValue(report.subjectName),
          TextCellValue(report.yearLabel),
          TextCellValue(semester),
          IntCellValue(student['attendance_number'] as int),
          TextCellValue(student['name'] as String),
          TextCellValue(
            report.categories[categoryId] ?? 'Kategori $categoryId',
          ),
          IntCellValue(weight),
          average == null ? null : DoubleCellValue(average),
          average == null ? null : DoubleCellValue(average * weight / 100),
          TextCellValue(_status(result)),
        ]);
      }
    }

    finalSheet.appendRow(
      _headers([
        'Kelas',
        'Mata Pelajaran',
        'Tahun',
        'Semester',
        'No. Absen',
        'Nama Siswa',
        'Bobot Aktif',
        'Nilai Akhir',
        'Nilai Sementara',
        'Status',
        'Alasan Belum Lengkap',
      ]),
    );
    for (final student in report.students) {
      final result = report.results[student['id'] as int];
      finalSheet.appendRow([
        TextCellValue(report.className),
        TextCellValue(report.subjectName),
        TextCellValue(report.yearLabel),
        TextCellValue(semester),
        IntCellValue(student['attendance_number'] as int),
        TextCellValue(student['name'] as String),
        TextCellValue(weightLabel),
        result?.finalGrade == null
            ? null
            : DoubleCellValue(result!.finalGrade!),
        result?.finalGrade != null || result?.provisional == null
            ? null
            : DoubleCellValue(result!.provisional!),
        TextCellValue(_status(result)),
        TextCellValue(
          result?.incompleteReasons.join('; ') ?? 'Bobot belum diatur.',
        ),
      ]);
    }

    _formatHeader(detail, 13);
    _formatHeader(categories, 11);
    _formatHeader(finalSheet, 11);
    for (final (sheet, columns) in [
      (detail, 13),
      (categories, 11),
      (finalSheet, 11),
    ]) {
      for (var column = 0; column < columns; column++) {
        sheet.setColumnWidth(column, 20);
      }
    }
    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Berkas Excel belum dapat dibuat.');
    }
    return Uint8List.fromList(bytes);
  }

  List<CellValue?> _headers(List<String> values) => [
    for (final value in values) TextCellValue(value),
  ];

  CellValue? _scoreCell(Map<String, Object?>? grade) {
    if (grade == null) return null;
    if (grade['state'] == 'EXEMPT') return TextCellValue('EX');
    final score = grade['score'] as num;
    return score.toDouble() == score.toInt()
        ? IntCellValue(score.toInt())
        : DoubleCellValue(score.toDouble());
  }

  String _status(result) {
    if (result?.finalGrade != null) return 'Final';
    if (result?.provisional != null) return 'Sementara';
    return 'Belum lengkap';
  }

  void _formatHeader(Sheet sheet, int columns) {
    final style = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1762F3'),
      textWrapping: TextWrapping.WrapText,
    );
    for (var column = 0; column < columns; column++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
              )
              .cellStyle =
          style;
    }
  }
}
