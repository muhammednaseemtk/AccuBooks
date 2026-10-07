import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../repositories/report_repository.dart';

class ReportService {
  final ReportRepository _reportRepo;

  ReportService({ReportRepository? reportRepo})
      : _reportRepo = reportRepo ?? ReportRepository();

  Future<Map<String, dynamic>> getDashboardMetrics() async {
    return await _reportRepo.getDashboardMetrics();
  }

  Future<List<Map<String, dynamic>>> getDayBook(DateTime date) async {
    return await _reportRepo.getDayBook(date);
  }

  Future<Map<String, dynamic>> getTrialBalance({DateTime? asOfDate}) async {
    return await _reportRepo.getTrialBalance(asOfDate: asOfDate);
  }

  Future<Map<String, dynamic>> getProfitAndLoss({DateTime? fromDate, DateTime? toDate}) async {
    return await _reportRepo.getProfitAndLoss(fromDate: fromDate, toDate: toDate);
  }

  Future<Map<String, dynamic>> getBalanceSheet({DateTime? asOfDate}) async {
    return await _reportRepo.getBalanceSheet(asOfDate: asOfDate);
  }

  Future<List<Map<String, dynamic>>> getReceivables() async {
    return await _reportRepo.getReceivablesReport();
  }

  Future<List<Map<String, dynamic>>> getPayables() async {
    return await _reportRepo.getPayablesReport();
  }

  Future<List<Map<String, dynamic>>> getStockReport() async {
    return await _reportRepo.getStockReport();
  }

  /// Export generic report dataset to modern Excel (.xlsx) file
  Future<String?> exportToExcel({
    required String sheetName,
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> dataRows,
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      FileType type,
      List<String>? allowedExtensions,
      String? dialogTitle,
    })? fileSaver,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[sheetName];

    // Header styling
    final headerCellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Write Headers
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerCellStyle;
    }

    // Write Data Rows
    for (int r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];
      for (int c = 0; c < row.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final val = row[c];
        if (val is num) {
          cell.value = DoubleCellValue(val.toDouble());
        } else if (val is bool) {
          cell.value = BoolCellValue(val);
        } else {
          cell.value = TextCellValue(val?.toString() ?? '');
        }
      }
    }

    // Save File
    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Unable to generate Excel file');

    final uint8Bytes = Uint8List.fromList(fileBytes);
    Uri? savedUri;
    try {
      if (fileSaver != null) {
        savedUri = await fileSaver(
          dialogTitle: 'Save Excel Report',
          fileName: '$fileName.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: uint8Bytes,
        );
      } else {
        savedUri = await FilePicker.saveFile(
          dialogTitle: 'Save Excel Report',
          fileName: '$fileName.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: uint8Bytes,
        );
      }
    } catch (e) {
      debugPrint('[ReportService] Save dialog error: $e');
      rethrow;
    }

    // If user cancelled, closed the dialog, or no path chosen, return null without showing success
    if (savedUri == null) {
      return null;
    }

    String selectedPath = savedUri.toFilePath();
    if (selectedPath.trim().isEmpty) {
      return null;
    }

    // Ensure the filename has .xlsx extension
    if (!selectedPath.toLowerCase().endsWith('.xlsx')) {
      selectedPath = '$selectedPath.xlsx';
    }

    // Actually write the generated Excel bytes to the selected location
    final file = File(selectedPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(fileBytes, flush: true);

    // Verify that the file genuinely exists and is non-empty
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Failed to verify saved Excel file at $selectedPath');
    }

    return selectedPath;
  }
}
