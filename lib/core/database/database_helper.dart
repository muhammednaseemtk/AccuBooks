import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';
import 'database_migrations.dart';
import 'database_tables.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;
  Database? _authDb;
  int? _activeUserId;
  static bool _isFfiInitialized = false;

  int? get activeUserId => _activeUserId;

  /// Ensure FFI is initialized on desktop platforms (idempotent, runs only once)
  static void initializeFfi() {
    if (_isFfiInitialized) return;
    _isFfiInitialized = true;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Switch active authenticated user and isolate database context
  Future<void> setActiveUser(int? userId) async {
    if (_activeUserId != userId) {
      await close();
      _activeUserId = userId;
      if (userId != null) {
        await _migrateExistingUserDataIfNeeded(userId);
      }
    }
  }

  /// Central authentication database (stores users, organizations, password_resets)
  Future<Database> get authDatabase async {
    if (_authDb != null && _authDb!.isOpen) return _authDb!;
    _authDb = await _initAuthDatabase();
    return _authDb!;
  }

  /// Active business database (isolated per authenticated user)
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<String> getAuthDatabasePath() async {
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

  Future<String> getUserDatabasePath(int userId) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final docDir = await getApplicationDocumentsDirectory();
      final appDir = Directory(p.join(docDir.path, 'AccuBooks'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return p.join(appDir.path, 'accounting_user_$userId.db');
    } else {
      final dbPath = await getDatabasesPath();
      return p.join(dbPath, 'accounting_user_$userId.db');
    }
  }

  Future<String> getDatabasePath() async {
    if (_activeUserId != null) {
      return await getUserDatabasePath(_activeUserId!);
    }
    return await getAuthDatabasePath();
  }

  Future<Database> _initAuthDatabase() async {
    initializeFfi();
    final path = await getAuthDatabasePath();

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.currentVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.execute('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA busy_timeout = 30000;');
          await db.execute('PRAGMA cache_size = -64000;');
        },
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
        onOpen: (db) async {
          try {
            await db.execute('ALTER TABLE ${DatabaseTables.tableUsers} ADD COLUMN profile_image TEXT;');
          } catch (_) {}
        },
      ),
    );
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
          await db.execute('PRAGMA busy_timeout = 30000;');
          await db.execute('PRAGMA cache_size = -64000;');
        },
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
        onOpen: (db) async {
          try {
            await db.execute('ALTER TABLE ${DatabaseTables.tableUsers} ADD COLUMN profile_image TEXT;');
          } catch (_) {}
          try {
            await db.execute(DatabaseTables.createAppMetadataTable);
            await stampMetadata(db);
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _migrateExistingUserDataIfNeeded(int userId) async {
    final userPath = await getUserDatabasePath(userId);
    final userFile = File(userPath);
    if (!await userFile.exists()) {
      final masterPath = await getAuthDatabasePath();
      final masterFile = File(masterPath);
      if (await masterFile.exists()) {
        try {
          final auth = await authDatabase;
          try {
            await auth.rawQuery('PRAGMA wal_checkpoint(FULL);');
          } catch (_) {}
          final firstUser = await auth.query(
            DatabaseTables.tableUsers,
            orderBy: 'id ASC',
            limit: 1,
          );
          if (firstUser.isNotEmpty && firstUser.first['id'] == userId) {
            // First user preserves their existing accounts, products, invoices, etc.
            await masterFile.copy(userPath);
            return;
          }
        } catch (_) {}
      }
    }
  }

  /// Stamp ownership and application metadata in the database
  Future<void> stampMetadata(Database db, [int? userId]) async {
    try {
      await db.execute(DatabaseTables.createAppMetadataTable);
      final effectiveUserId = userId ?? _activeUserId;
      String userEmail = '';
      int? orgId;
      String companyName = '';

      if (effectiveUserId != null) {
        try {
          final auth = await authDatabase;
          final userRows = await auth.query(
            DatabaseTables.tableUsers,
            columns: ['email', 'organization_id'],
            where: 'id = ?',
            whereArgs: [effectiveUserId],
            limit: 1,
          );
          if (userRows.isNotEmpty) {
            userEmail = (userRows.first['email'] as String?) ?? '';
            orgId = userRows.first['organization_id'] as int?;
          }
        } catch (_) {}
      }

      try {
        final companyRows = await db.query(
          DatabaseTables.tableCompanies,
          columns: ['name'],
          limit: 1,
        );
        if (companyRows.isNotEmpty) {
          companyName = (companyRows.first['name'] as String?) ?? '';
        }
      } catch (_) {}

      final batch = db.batch();
      void setMeta(String k, String v) {
        batch.insert(
          DatabaseTables.tableAppMetadata,
          {'key': k, 'value': v},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      setMeta('app_name', 'AccuBooks');
      setMeta('user_id', effectiveUserId?.toString() ?? '');
      setMeta('user_email', userEmail);
      setMeta('organization_id', orgId?.toString() ?? '');
      setMeta('company_name', companyName);
      setMeta('schema_version', DatabaseMigrations.currentVersion.toString());
      setMeta('updated_at', DateTime.now().toIso8601String());

      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// Validate a backup SQLite database file for schema, required tables, version, and user/company ownership
  Future<Map<String, String>> validateBackupFile(
    String backupFilePath, {
    int? expectedUserId,
    String? expectedUserEmail,
    int? expectedOrgId,
  }) async {
    initializeFfi();
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file does not exist at $backupFilePath');
    }

    Database? checkDb;
    try {
      try {
        checkDb = await databaseFactory.openDatabase(
          backupFilePath,
          options: OpenDatabaseOptions(
            readOnly: true,
            onConfigure: (db) async {
              await db.execute('PRAGMA busy_timeout = 10000;');
            },
          ),
        );
      } catch (e) {
        throw Exception('Backup file is corrupted or not a valid SQLite database ($e).');
      }

      // 1. Check integrity
      List<Map<String, Object?>> integrity;
      try {
        integrity = await checkDb.rawQuery('PRAGMA integrity_check;');
      } catch (e) {
        throw Exception('Backup file is corrupted or not a valid SQLite database ($e).');
      }

      if (integrity.isEmpty ||
          integrity.first.values.first.toString().toLowerCase() != 'ok') {
        throw Exception('Backup file is corrupted or not a valid SQLite database.');
      }

      // 2. Check schema version
      final versionRes = await checkDb.rawQuery('PRAGMA user_version;');
      final version = (versionRes.first.values.first as int?) ?? 0;
      if (version <= 0 || version > DatabaseMigrations.currentVersion) {
        throw Exception(
          'Incompatible database version ($version). Current supported version is ${DatabaseMigrations.currentVersion}.',
        );
      }

      // 3. Check required accounting tables
      final tablesRes = await checkDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table';",
      );
      final tableNames = tablesRes
          .map((r) => (r['name'] as String?)?.toLowerCase() ?? '')
          .toSet();

      const requiredTables = [
        DatabaseTables.tableCompanies,
        DatabaseTables.tableAccounts,
        DatabaseTables.tableCustomers,
        DatabaseTables.tableSuppliers,
        DatabaseTables.tableProducts,
        DatabaseTables.tableSalesInvoices,
        DatabaseTables.tableSalesOrders,
        DatabaseTables.tablePurchaseInvoices,
        DatabaseTables.tablePurchaseOrders,
        DatabaseTables.tableReceipts,
        DatabaseTables.tablePayments,
        DatabaseTables.tableExpenses,
        DatabaseTables.tableJournalEntries,
        DatabaseTables.tableJournalLines,
      ];

      for (final table in requiredTables) {
        if (!tableNames.contains(table.toLowerCase())) {
          throw Exception(
            'Invalid AccuBooks backup file: Missing required accounting table "$table".',
          );
        }
      }

      // 4. Check user / company isolation metadata
      final Map<String, String> meta = {};
      if (tableNames.contains(DatabaseTables.tableAppMetadata.toLowerCase())) {
        final metaRows = await checkDb.query(DatabaseTables.tableAppMetadata);
        for (final r in metaRows) {
          final k = r['key'] as String?;
          final v = r['value'] as String?;
          if (k != null && v != null) {
            meta[k] = v;
          }
        }
      }

      final targetUserId = expectedUserId ?? _activeUserId;
      if (targetUserId != null) {
        final metaUserId = meta['user_id'];
        if (metaUserId != null &&
            metaUserId.isNotEmpty &&
            metaUserId != targetUserId.toString()) {
          final ownerInfo = meta['user_email'] != null && meta['user_email']!.isNotEmpty
              ? ' (${meta['user_email']})'
              : ' (User ID: $metaUserId)';
          throw Exception(
            'Cannot restore backup: This backup belongs to another user$ownerInfo and cannot be restored into the current account (User ID: $targetUserId).',
          );
        }

        if (expectedUserEmail != null &&
            expectedUserEmail.isNotEmpty &&
            meta['user_email'] != null &&
            meta['user_email']!.isNotEmpty &&
            meta['user_email']!.toLowerCase() != expectedUserEmail.toLowerCase()) {
          throw Exception(
            'Cannot restore backup: This backup belongs to user "${meta['user_email']}" and cannot be restored into account "$expectedUserEmail".',
          );
        }

        if (expectedOrgId != null &&
            meta['organization_id'] != null &&
            meta['organization_id']!.isNotEmpty &&
            meta['organization_id'] != expectedOrgId.toString()) {
          throw Exception(
            'Cannot restore backup: This backup belongs to another organization (Org ID: ${meta['organization_id']}) and cannot be restored into the current account.',
          );
        }
      }

      return meta;
    } finally {
      if (checkDb != null && checkDb.isOpen) {
        await checkDb.close();
      }
    }
  }

  /// Execute an atomic transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Close active user database connection
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Close all database connections
  Future<void> closeAll() async {
    await close();
    _activeUserId = null;
    if (_authDb != null && _authDb!.isOpen) {
      await _authDb!.close();
      _authDb = null;
    }
  }

  /// Create backup of accounting database file, ensuring WAL checkpoint and metadata stamping
  Future<String> backupDatabase({String? customDestinationPath}) async {
    // Ensure database metadata is stamped and WAL is completely flushed/checkpointed
    final db = await database;
    await stampMetadata(db);
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (e) {
      debugPrint('Error checkpointing WAL before backup: $e');
    }

    final currentDbPath = await getDatabasePath();
    final currentFile = File(currentDbPath);
    if (!await currentFile.exists()) {
      throw Exception('Active database file does not exist at $currentDbPath');
    }

    String destPath = customDestinationPath ?? '';
    if (destPath.isEmpty) {
      final docDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      destPath = p.join(docDir.path, 'AccuBooks', 'accubooks_backup_$timestamp.db');
    }

    final destFile = File(destPath);
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    await currentFile.copy(destPath);
    return destPath;
  }

  /// Restore database from a backup file with pre-validation, safety backup, and rollback
  Future<bool> restoreDatabase(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file does not exist at $backupFilePath');
    }

    // 1. Retrieve current user & org info for isolation validation
    String? activeEmail;
    int? activeOrgId;
    if (_activeUserId != null) {
      try {
        final auth = await authDatabase;
        final userRows = await auth.query(
          DatabaseTables.tableUsers,
          where: 'id = ?',
          whereArgs: [_activeUserId],
          limit: 1,
        );
        if (userRows.isNotEmpty) {
          activeEmail = userRows.first['email'] as String?;
          activeOrgId = userRows.first['organization_id'] as int?;
        }
      } catch (_) {}
    }

    // Pre-validate backup file BEFORE touching active database
    await validateBackupFile(
      backupFilePath,
      expectedUserId: _activeUserId,
      expectedUserEmail: activeEmail,
      expectedOrgId: activeOrgId,
    );

    // 2. Safely flush WAL and close active database connection
    if (_db != null && _db!.isOpen) {
      try {
        await _db!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (_) {}
    }
    await close();

    final currentDbPath = await getDatabasePath();
    final currentFile = File(currentDbPath);

    // 3. Keep recoverable safety backup of current active database
    final safetyBackupPath = '$currentDbPath.pre_restore_safety.bak';
    if (await currentFile.exists()) {
      await currentFile.copy(safetyBackupPath);
    }

    // 4. Safely remove lingering WAL/SHM files to prevent WAL replay conflicts
    final walFile = File('$currentDbPath-wal');
    final shmFile = File('$currentDbPath-shm');
    if (await walFile.exists()) {
      try { await walFile.delete(); } catch (_) {}
    }
    if (await shmFile.exists()) {
      try { await shmFile.delete(); } catch (_) {}
    }

    // 5. Replace current database file with validated backup
    try {
      await backupFile.copy(currentDbPath);

      // Reopen database and verify integrity
      _db = await _initDatabase();
      final integrity = await _db!.rawQuery('PRAGMA integrity_check;');
      if (integrity.isEmpty ||
          integrity.first.values.first.toString().toLowerCase() != 'ok') {
        throw Exception('Restored database failed integrity check.');
      }

      return true;
    } catch (e) {
      // Rollback on any failure: restore from safety backup
      await close();
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      final safetyFile = File(safetyBackupPath);
      if (await safetyFile.exists()) {
        await safetyFile.copy(currentDbPath);
      }
      _db = await _initDatabase();
      throw Exception('Database restoration failed and was safely rolled back: $e');
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
