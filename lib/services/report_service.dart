import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';
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
    String? selectedPath;
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Excel Report',
        fileName: '$fileName.xlsx',
        bytes: uint8Bytes,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (uri != null) {
        selectedPath = uri.toFilePath();
      }
    } catch (_) {
      // Fallback if dialog is unavailable
    }

    if (selectedPath == null || selectedPath.isEmpty) {
      final docDir = await getApplicationDocumentsDirectory();
      selectedPath = p.join(docDir.path, 'AccuBooks', '$fileName.xlsx');
      final file = File(selectedPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(fileBytes);
    }

    return selectedPath;
  }
}
