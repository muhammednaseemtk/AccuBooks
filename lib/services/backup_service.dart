import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../core/database/database_helper.dart';
import '../core/utils/date_utils.dart';

class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Create backup of current SQLite database
  /// Returns the saved file path, or null if cancelled by the user.
  Future<String?> createBackup({String? targetFilePath}) async {
    // If target file path is explicitly provided (e.g. testing or programmatic backup),
    // delegate directly to databaseHelper.backupDatabase.
    if (targetFilePath != null && targetFilePath.isNotEmpty) {
      return await _dbHelper.backupDatabase(customDestinationPath: targetFilePath);
    }

    // Ensure database metadata is stamped and WAL is checkpointed before reading
    final db = await _dbHelper.database;
    await _dbHelper.stampMetadata(db);
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');

    final activePath = await _dbHelper.getDatabasePath();
    final activeFile = File(activePath);
    if (!await activeFile.exists()) {
      throw Exception('Database file not found at $activePath');
    }

    final bytes = await activeFile.readAsBytes();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final defaultFileName = 'accubooks_backup_$timestamp.db';

    final chosenUri = await FilePicker.saveFile(
      dialogTitle: 'Select Backup Destination',
      fileName: defaultFileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite'],
    );

    // If user cancelled, return null cleanly without creating a fallback file
    if (chosenUri == null) {
      return null;
    }

    final filePath = chosenUri.toFilePath();
    if (filePath.isEmpty) {
      return null;
    }

    final destFile = File(filePath);
    if (!await destFile.exists() || (await destFile.length()) == 0) {
      if (!await destFile.parent.exists()) {
        await destFile.parent.create(recursive: true);
      }
      await destFile.writeAsBytes(bytes);
    }
    return filePath;
  }

  /// Pick and restore database from a chosen backup file
  Future<bool> restoreFromBackup({String? sourceFilePath}) async {
    String? backupPath = sourceFilePath;

    if (backupPath == null || backupPath.isEmpty) {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select Database Backup File',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite'],
      );

      if (result.isEmpty || result.first.path == null) {
        return false; // User cancelled
      }
      backupPath = result.first.path!;
    }

    return await _dbHelper.restoreDatabase(backupPath);
  }

  /// Get active database path and size information
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      await _dbHelper.database;
    } catch (_) {}

    final path = await _dbHelper.getDatabasePath();
    final file = File(path);
    int sizeInBytes = 0;
    DateTime? lastModified;

    if (await file.exists()) {
      sizeInBytes = await file.length();
      lastModified = await file.lastModified();
    }

    final sizeKb = (sizeInBytes / 1024).toStringAsFixed(1);
    final formattedDate = lastModified != null
        ? AppDateUtils.formatDb(lastModified)
        : 'N/A';

    return {
      'path': path,
      'size': '$sizeKb KB',
      'size_kb': sizeKb,
      'lastModified': formattedDate,
      'last_modified': formattedDate,
      'exists': await file.exists(),
    };
  }
}
