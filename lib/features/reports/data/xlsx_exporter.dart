import '../../../core/education/education_level.dart';

import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'report_repository.dart';

class XlsxExporter {
  const XlsxExporter();

  Uint8List build(ReportData report) {
    final terms = EducationTerms(report.educationLevel);
    final workbook = Excel.createExcel();
    final detail = workbook['Detail Absensi'];
    final summary = workbook['Rekap Absensi'];
    workbook.delete('Sheet1');

    detail.appendRow([
      TextCellValue(terms.translate('No. Absen')),
      TextCellValue(terms.translate('Nama Siswa')),
      TextCellValue(terms.translate('NIS/NISN')),
      TextCellValue('Kelas'),
      TextCellValue(terms.translate('Mata Pelajaran')),
      TextCellValue('Tanggal'),
      TextCellValue('Pertemuan'),
      TextCellValue('Status'),
    ]);
    for (final row in report.details) {
      detail.appendRow([
        IntCellValue(row.number),
        TextCellValue(row.studentName),
        TextCellValue(row.nis ?? ''),
        TextCellValue(row.className),
        TextCellValue(row.subjectName),
        TextCellValue(row.date),
        IntCellValue(row.meetingNumber),
        TextCellValue(_statusLabel(row.status)),
      ]);
    }

    summary.appendRow([
      TextCellValue(terms.translate('No. Absen')),
      TextCellValue(terms.translate('Nama Siswa')),
      if (terms.university) TextCellValue('NIM'),
      TextCellValue('Total H'),
      TextCellValue('Total S'),
      TextCellValue('Total I'),
      TextCellValue('Total A'),
      TextCellValue('Total Sesi Selesai'),
      TextCellValue('Persentase Kehadiran (%)'),
    ]);
    for (final row in report.summaries) {
      summary.appendRow([
        IntCellValue(row.number),
        TextCellValue(row.name),
        if (terms.university) TextCellValue(row.nis ?? ''),
        IntCellValue(row.present),
        IntCellValue(row.sick),
        IntCellValue(row.excused),
        IntCellValue(row.absent),
        IntCellValue(row.completedSessions),
        row.attendancePercentage == null
            ? TextCellValue('—')
            : DoubleCellValue(row.attendancePercentage!),
      ]);
    }

    _formatHeader(detail, 8);
    _formatHeader(summary, terms.university ? 9 : 8);
    for (final sheet in [detail, summary]) {
      final columns = sheet == summary && terms.university ? 9 : 8;
      for (var column = 0; column < columns; column++) {
        sheet.setColumnWidth(
          column,
          column == 1 || column == 4 || column == 7 ? 25 : 18,
        );
      }
    }
    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Berkas Excel belum dapat dibuat.');
    }
    return Uint8List.fromList(bytes);
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

String _statusLabel(String status) => switch (status) {
  'H' => 'Hadir',
  'S' => 'Sakit',
  'I' => 'Izin',
  _ => 'Alpha',
};
