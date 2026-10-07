import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/database/database_helper.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Create backup of current SQLite database
  Future<String> createBackup({String? targetFilePath}) async {
    final activePath = await _dbHelper.getDatabasePath();
    final activeFile = File(activePath);
    if (!await activeFile.exists()) {
      throw Exception('Database file not found at $activePath');
    }

    final bytes = await activeFile.readAsBytes();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final defaultFileName = 'accubooks_backup_$timestamp.db';

    String? destPath = targetFilePath;
    if (destPath == null || destPath.isEmpty) {
      try {
        final chosenUri = await FilePicker.saveFile(
          dialogTitle: 'Select Backup Destination',
          fileName: defaultFileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['db', 'sqlite'],
        );
        if (chosenUri != null) {
          final filePath = chosenUri.toFilePath();
          if (filePath.isNotEmpty) {
            destPath = filePath;
            final destFile = File(destPath);
            if (!await destFile.parent.exists()) {
              await destFile.parent.create(recursive: true);
            }
            await destFile.writeAsBytes(bytes);
          }
        }
      } catch (_) {
        // Fallback to Documents directory
      }
    }

    if (destPath == null || destPath.isEmpty) {
      final docDir = await getApplicationDocumentsDirectory();
      destPath = p.join(docDir.path, 'AccuBooks', defaultFileName);
      final destFile = File(destPath);
      if (!await destFile.parent.exists()) {
        await destFile.parent.create(recursive: true);
      }
      await destFile.writeAsBytes(bytes);
    }

    return destPath;
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
    final path = await _dbHelper.getDatabasePath();
    final file = File(path);
    int sizeInBytes = 0;
    DateTime? lastModified;

    if (await file.exists()) {
      sizeInBytes = await file.length();
      lastModified = await file.lastModified();
    }

    return {
      'path': path,
      'size_kb': (sizeInBytes / 1024).toStringAsFixed(1),
      'last_modified': lastModified,
      'exists': await file.exists(),
    };
  }
}
