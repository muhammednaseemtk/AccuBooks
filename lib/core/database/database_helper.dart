import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';
import 'database_migrations.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  /// Ensure FFI is initialized on desktop platforms
  static void initializeFfi() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<String> getDatabasePath() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final docDir = await getApplicationDocumentsDirectory();
      final appDir = Directory(p.join(docDir.path, 'AccuBooks'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return p.join(appDir.path, AppConstants.dbName);
    } else {
      final dbPath = await getDatabasesPath();
      return p.join(dbPath, AppConstants.dbName);
    }
  }

  Future<Database> _initDatabase() async {
    initializeFfi();
    final path = await getDatabasePath();

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.currentVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.execute('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA cache_size = -64000;');
        },
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
      ),
    );
  }

  /// Execute an atomic transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Close database connection
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Create backup of accounting database file
  Future<String> backupDatabase({String? customDestinationPath}) async {
    final currentDbPath = await getDatabasePath();
    final currentFile = File(currentDbPath);
    if (!await currentFile.exists()) {
      throw Exception('Active database file does not exist at $currentDbPath');
    }

    String destPath = customDestinationPath ?? '';
    if (destPath.isEmpty) {
      final docDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      destPath = p.join(docDir.path, 'AccuBooks', 'accubooks_backup_$timestamp.db');
    }

    final destFile = File(destPath);
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    // Ensure database is in a consistent state by running checkpoint or simple query
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL);');

    await currentFile.copy(destPath);
    return destPath;
  }

  /// Restore database from a backup file
  Future<bool> restoreDatabase(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file does not exist at $backupFilePath');
    }

    // Close active database
    await close();

    final currentDbPath = await getDatabasePath();
    final currentFile = File(currentDbPath);

    // Keep temporary safety backup of active database
    final tempBackupPath = '$currentDbPath.tmp';
    if (await currentFile.exists()) {
      await currentFile.copy(tempBackupPath);
    }

    try {
      await backupFile.copy(currentDbPath);
      // Reopen database to verify integrity
      _db = await _initDatabase();
      await _db!.rawQuery('PRAGMA integrity_check;');

      // Remove temp file
      final tempFile = File(tempBackupPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return true;
    } catch (e) {
      // Revert if restore failed
      final tempFile = File(tempBackupPath);
      if (await tempFile.exists()) {
        await tempFile.copy(currentDbPath);
        await tempFile.delete();
      }
      _db = await _initDatabase();
      rethrow;
    }
  }

  /// Reset/Recreate database for fresh start or sample data
  Future<void> resetDatabase() async {
    await close();
    final path = await getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _db = await _initDatabase();
  }
}
