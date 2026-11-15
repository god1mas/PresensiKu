import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/grade_calculator.dart';
import 'grade_report_repository.dart';

class GradeXlsxExporter {
  const GradeXlsxExporter();

  Uint8List build(GradeReportData report) {
    final workbook = Excel.createExcel();
    final detail = workbook['Detail Penilaian'];
    final categories = workbook['Rekap per Kategori'];
    final finalSheet = workbook['Nilai Akhir'];
    final matrix = workbook['Matriks Nilai'];
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

    _writeMatrix(matrix, report);

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

  String _status(GradeResult? result) {
    if (result?.finalGrade != null) return 'Final';
    if (result?.provisional != null) return 'Sementara';
    return 'Belum lengkap';
  }

  void _writeMatrix(Sheet sheet, GradeReportData report) {
    final assessments = [...report.assessments]
      ..sort((a, b) {
        final dateOrder = (a['date'] as String).compareTo(b['date'] as String);
        return dateOrder != 0
            ? dateOrder
            : (a['id'] as int).compareTo(b['id'] as int);
      });
    final relevantIds = <int>{
      ...report.weights.keys,
      ...assessments.map((assessment) => assessment['category_id'] as int),
    };
    final categoryIds = <int>[
      for (final id in [1, 2, 3, 4, 5])
        if (report.categories.containsKey(id) || relevantIds.contains(id)) id,
      ...(relevantIds.where((id) => id > 5).toList()..sort()),
    ];
    final grouped = <int, List<Map<String, Object?>>>{
      for (final id in categoryIds)
        id: assessments
            .where((assessment) => assessment['category_id'] == id)
            .toList(),
    };
    final students = [...report.students]
      ..sort((a, b) {
        final numberOrder = (a['attendance_number'] as int).compareTo(
          b['attendance_number'] as int,
        );
        return numberOrder != 0
            ? numberOrder
            : (a['id'] as int).compareTo(b['id'] as int);
      });
    final border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#CBD7EA'),
    );
    final groupedStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1762F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
    final numberStyle = groupedStyle.copyWith(
      fontColorHexVal: ExcelColor.fromHexString('#14243F'),
      backgroundColorHexVal: ExcelColor.fromHexString('#EAF2FF'),
    );
    CellIndex cell(int column, int row) =>
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);
    void write(int column, int row, CellValue? value, CellStyle style) {
      sheet.updateCell(cell(column, row), value, cellStyle: style);
    }

    void verticalHeader(int column, String title) {
      write(column, 0, TextCellValue(title), groupedStyle);
      sheet.merge(cell(column, 0), cell(column, 1));
      sheet.setMergedCellStyle(cell(column, 0), groupedStyle);
    }

    verticalHeader(0, 'No. Absen');
    verticalHeader(1, 'Nama Siswa');
    sheet.setColumnWidth(0, 13);
    sheet.setColumnWidth(1, 30);
    var column = 2;
    final assessmentColumns = <(Map<String, Object?>, int)>[];
    final placeholderColumns = <int>[];
    for (final id in categoryIds) {
      final categoryAssessments = grouped[id]!;
      final start = column;
      final name =
          report.categories[id] ??
          (categoryAssessments.isEmpty
              ? 'Kategori $id'
              : categoryAssessments.first['category_name_snapshot'] as String);
      final label = id == 1 ? 'Nilai $name' : name;
      write(
        start,
        0,
        TextCellValue('$label (${report.weights[id] ?? 0}%)'),
        groupedStyle,
      );
      if (categoryAssessments.isEmpty) {
        write(column, 1, TextCellValue('—'), numberStyle);
        placeholderColumns.add(column);
        sheet.setColumnWidth(column, 15);
        column++;
      } else {
        for (var index = 0; index < categoryAssessments.length; index++) {
          final assessment = categoryAssessments[index];
          write(column, 1, IntCellValue(index + 1), numberStyle);
          assessmentColumns.add((assessment, column));
          sheet.setColumnWidth(column, 13);
          column++;
        }
      }
      if (column - start > 1) {
        sheet.merge(cell(start, 0), cell(column - 1, 0));
        sheet.setMergedCellStyle(cell(start, 0), groupedStyle);
      }
    }
    final finalColumn = column;
    verticalHeader(finalColumn, 'Nilai Akhir');
    verticalHeader(finalColumn + 1, 'Status');
    verticalHeader(finalColumn + 2, 'Keterangan');
    sheet.setColumnWidth(finalColumn, 16);
    sheet.setColumnWidth(finalColumn + 1, 18);
    sheet.setColumnWidth(finalColumn + 2, 56);
    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 27);

    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      final studentId = student['id'] as int;
      final result = report.results[studentId];
      final row = index + 2;
      final bodyStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: ExcelColor.fromHexString(
          index.isEven ? '#FFFFFF' : '#F4F8FF',
        ),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: border,
        rightBorder: border,
        topBorder: border,
        bottomBorder: border,
      );
      write(
        0,
        row,
        IntCellValue(student['attendance_number'] as int),
        bodyStyle,
      );
      write(
        1,
        row,
        TextCellValue(student['name'] as String),
        bodyStyle.copyWith(horizontalAlignVal: HorizontalAlign.Left),
      );
      final exemptTitles = <String>[];
      for (final (assessment, assessmentColumn) in assessmentColumns) {
        final grade = report.grades[(assessment['id'] as int, studentId)];
        if (grade?['state'] == 'EXEMPT') {
          exemptTitles.add(assessment['title'] as String);
        }
        write(assessmentColumn, row, _scoreCell(grade), bodyStyle);
      }
      for (final placeholder in placeholderColumns) {
        write(placeholder, row, null, bodyStyle);
      }
      write(
        finalColumn,
        row,
        result?.finalGrade == null
            ? null
            : DoubleCellValue(result!.finalGrade!),
        bodyStyle,
      );
      write(
        finalColumn + 1,
        row,
        TextCellValue(result?.isComplete == true ? 'Lengkap' : 'Belum Lengkap'),
        bodyStyle,
      );
      final notes = <String>[
        for (final reason in result?.incompleteReasons ?? <String>[])
          _explainMatrixReason(reason, report),
        if (exemptTitles.isNotEmpty) 'EX: ${exemptTitles.join(', ')}',
      ];
      final noteText = notes.join('; ');
      write(
        finalColumn + 2,
        row,
        TextCellValue(noteText),
        bodyStyle.copyWith(
          horizontalAlignVal: HorizontalAlign.Left,
          textWrappingVal: TextWrapping.WrapText,
        ),
      );
      sheet.setRowHeight(
        row,
        noteText.isEmpty ? 25 : (noteText.length > 80 ? 60 : 40),
      );
    }

    final legendStart = students.length + 4;
    final semester = report.semester == 'ganjil' ? 'Ganjil' : 'Genap';
    write(
      0,
      legendStart - 1,
      TextCellValue(
        'Lingkup: ${report.className} · ${report.subjectName} · ${report.yearLabel} $semester',
      ),
      CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#14243F'),
        backgroundColorHex: ExcelColor.fromHexString('#EAF2FF'),
      ),
    );
    sheet.merge(cell(0, legendStart - 1), cell(5, legendStart - 1));
    sheet.setRowHeight(legendStart - 1, 26);
    write(0, legendStart, TextCellValue('Legenda Penilaian'), groupedStyle);
    sheet.merge(cell(0, legendStart), cell(5, legendStart));
    sheet.setMergedCellStyle(cell(0, legendStart), groupedStyle);
    sheet.setRowHeight(legendStart, 27);
    final legendHeaders = [
      'Kategori',
      'No.',
      'Judul',
      'Tanggal',
      'Skor Maksimal',
      'Wajib',
    ];
    for (var index = 0; index < legendHeaders.length; index++) {
      write(
        index,
        legendStart + 1,
        TextCellValue(legendHeaders[index]),
        numberStyle,
      );
    }
    var legendRow = legendStart + 2;
    for (final id in categoryIds) {
      final name = report.categories[id] ?? 'Kategori $id';
      final categoryAssessments = grouped[id]!;
      for (var index = 0; index < categoryAssessments.length; index++) {
        final assessment = categoryAssessments[index];
        final maxScore = (assessment['max_score'] as num).toDouble();
        final legendStyle = CellStyle(
          fontSize: 10,
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Center,
          leftBorder: border,
          rightBorder: border,
          topBorder: border,
          bottomBorder: border,
        );
        final values = <CellValue>[
          TextCellValue(name),
          IntCellValue(index + 1),
          TextCellValue(assessment['title'] as String),
          TextCellValue(assessment['date'] as String),
          maxScore == maxScore.toInt()
              ? IntCellValue(maxScore.toInt())
              : DoubleCellValue(maxScore),
          TextCellValue(assessment['is_required'] == 1 ? 'Ya' : 'Tidak'),
        ];
        for (
          var legendColumn = 0;
          legendColumn < values.length;
          legendColumn++
        ) {
          write(legendColumn, legendRow, values[legendColumn], legendStyle);
        }
        sheet.setRowHeight(legendRow, 34);
        legendRow++;
      }
    }
  }

  String _explainMatrixReason(String reason, GradeReportData report) {
    final withAssessment = reason.replaceAllMapped(
      RegExp(r'Penilaian wajib (\d+) belum dinilai\.'),
      (match) {
        final id = int.parse(match.group(1)!);
        final assessment = report.assessments
            .where((row) => row['id'] == id)
            .firstOrNull;
        if (assessment == null) return match.group(0)!;
        return 'Penilaian wajib "${assessment['title']}" belum dinilai.';
      },
    );
    return withAssessment.replaceAllMapped(RegExp(r'([Kk]ategori) (\d+)'), (
      match,
    ) {
      final id = int.parse(match.group(2)!);
      return '${match.group(1)} ${report.categories[id] ?? id}';
    });
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
