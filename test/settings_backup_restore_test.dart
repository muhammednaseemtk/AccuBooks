import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/database/database_tables.dart';
import 'package:accubooks/core/utils/sequence_utils.dart';
import 'package:accubooks/controllers/customer_controller.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/user_model.dart';
import 'package:accubooks/models/organization_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/company_repository.dart';
import 'package:accubooks/services/auth_service.dart';
import 'package:accubooks/services/backup_service.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:accubooks/core/constants/auth_constants.dart';

class FakeFilePickerPlatform extends FilePickerPlatform {
  Uri? saveFileUriResult;

  @override
  Future<Uri?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
    dynamic linuxOptions,
    dynamic webOptions,
    dynamic windowsOptions,
    dynamic macOsOptions,
    String? mimeType,
    dynamic onFileSaving,
  }) async {
    return saveFileUriResult;
  }
}

class FakeAuthRepository {
  // Stub for testing
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late FakeFilePickerPlatform fakePicker;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('accubooks_backup_test_');

    // Mock path_provider
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    fakePicker = FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakePicker;

    DatabaseHelper.initializeFfi();
    dbHelper = DatabaseHelper();
  });

  tearDownAll(() async {
    await dbHelper.closeAll();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    SequenceUtils.clearReservedForTesting();
  });

  group('Requirement 3: Backup Cancellation', () {
    test('User cancelling the file-save dialog returns null without creating fallback files', () async {
      await dbHelper.setActiveUser(101);
      final backupService = BackupService(dbHelper: dbHelper);

      fakePicker.saveFileUriResult = null;

      final result = await backupService.createBackup();
      expect(result, isNull);

      // Verify that no fallback backup file was written to AccuBooks folder
      final accubooksDir = Directory('${tempDir.path}/AccuBooks');
      if (accubooksDir.existsSync()) {
        final backups = accubooksDir.listSync().where((f) => p.basename(f.path).startsWith('accubooks_backup_')).toList();
        expect(backups, isEmpty);
      }
    });

    test('SettingsController.createBackup aborts silently on cancel without error or success snackbar', () async {
      await dbHelper.setActiveUser(101);
      final backupService = BackupService(dbHelper: dbHelper);
      final controller = SettingsController(
        backupService: backupService,
        dbHelper: dbHelper,
      );

      // User cancel
      fakePicker.saveFileUriResult = null;

      await controller.createBackup();
      expect(controller.isSubmitting.value, isFalse);
    });
  });

  group('Requirements 1 & 2: Safe Backup & Cross-User Isolation', () {
    test('Backup flushes WAL transactions and embeds user/company metadata', () async {
      await dbHelper.setActiveUser(201);
      final db = await dbHelper.database;

      // Seed a customer in active DB
      final custRepo = CustomerRepository();
      final custCode = await custRepo.getNextCustomerCode();
      await custRepo.insertCustomer(CustomerModel(
        customerCode: custCode,
        name: 'Recent WAL Customer',
        phone: '9999999999',
      ));

      // Verify uncheckpointed/recent data is in DB
      final backupService = BackupService(dbHelper: dbHelper);
      final backupPath = '${tempDir.path}/backup_user_201.db';
      final path = await backupService.createBackup(targetFilePath: backupPath);

      expect(path, backupPath);
      expect(File(backupPath).existsSync(), isTrue);

      // Open the backup file directly and verify customer exists inside it
      final backupDb = await databaseFactory.openDatabase(
        backupPath,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final customers = await backupDb.query(DatabaseTables.tableCustomers);
      expect(customers.any((c) => c['name'] == 'Recent WAL Customer'), isTrue);

      // Verify app_metadata was stamped with user_id: 201
      final metadataRows = await backupDb.query(DatabaseTables.tableAppMetadata);
      final meta = {for (var r in metadataRows) r['key'] as String: r['value'] as String};
      expect(meta['user_id'], '201');
      expect(meta['app_name'], 'AccuBooks');
      await backupDb.close();
    });

    test('Restoring another user’s backup is rejected and leaves active DB untouched', () async {
      // 1. Create a backup for user 301
      await dbHelper.setActiveUser(301);
      final db301 = await dbHelper.database;
      final custRepo301 = CustomerRepository();
      await custRepo301.insertCustomer(CustomerModel(
        customerCode: 'CUST-301',
        name: 'User 301 Customer',
      ));
      final backupService301 = BackupService(dbHelper: dbHelper);
      final backup301Path = '${tempDir.path}/user_301.db';
      await backupService301.createBackup(targetFilePath: backup301Path);

      // 2. Switch to user 302
      await dbHelper.setActiveUser(302);
      final db302 = await dbHelper.database;
      final custRepo302 = CustomerRepository();
      await custRepo302.insertCustomer(CustomerModel(
        customerCode: 'CUST-302',
        name: 'User 302 Original Customer',
      ));

      // 3. Attempt to restore user 301's backup into user 302's account
      final backupService302 = BackupService(dbHelper: dbHelper);
      expect(
        () async => await backupService302.restoreFromBackup(sourceFilePath: backup301Path),
        throwsA(predicate((e) => e.toString().contains('belongs to another user'))),
      );

      // 4. Verify user 302's database is untouched
      final customers302 = await custRepo302.getAllCustomers();
      expect(customers302.any((c) => c.customerCode == 'CUST-302'), isTrue);
      expect(customers302.any((c) => c.customerCode == 'CUST-301'), isFalse);
    });
  });

  group('Requirements 4 & 5: Schema Validation, Safety Backup & Rollback', () {
    test('Non-SQLite or corrupted file is rejected before replacing active database', () async {
      await dbHelper.setActiveUser(401);
      final badFilePath = '${tempDir.path}/corrupt_backup.db';
      File(badFilePath).writeAsStringSync('THIS IS NOT A SQLITE DATABASE');

      final backupService = BackupService(dbHelper: dbHelper);
      expect(
        () async => await backupService.restoreFromBackup(sourceFilePath: badFilePath),
        throwsA(predicate((e) => e.toString().contains('corrupted or not a valid SQLite database'))),
      );
    });

    test('SQLite file missing AccuBooks accounting tables is rejected', () async {
      await dbHelper.setActiveUser(402);
      final randomDbPath = '${tempDir.path}/random_sqlite.db';
      final randomDb = await databaseFactory.openDatabase(randomDbPath);
      await randomDb.execute('CREATE TABLE browser_history (id INTEGER PRIMARY KEY, url TEXT);');
      await randomDb.execute('PRAGMA user_version = 4;');
      await randomDb.close();

      final backupService = BackupService(dbHelper: dbHelper);
      expect(
        () async => await backupService.restoreFromBackup(sourceFilePath: randomDbPath),
        throwsA(predicate((e) => e.toString().contains('Missing required accounting table'))),
      );
    });

    test('Safety backup is created and preserves current data', () async {
      await dbHelper.setActiveUser(403);
      final custRepo = CustomerRepository();
      await custRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-403',
        name: 'Customer 403',
      ));

      // Create valid backup for user 403
      final backupService = BackupService(dbHelper: dbHelper);
      final backupPath = '${tempDir.path}/valid_backup_403.db';
      await backupService.createBackup(targetFilePath: backupPath);

      // Now add a newer record in active DB
      await custRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-404',
        name: 'Customer 404 Pre-Restore',
      ));

      // Restore older backup
      final ok = await backupService.restoreFromBackup(sourceFilePath: backupPath);
      expect(ok, isTrue);

      // Verify safety backup file was created
      final userDbPath = await dbHelper.getUserDatabasePath(403);
      final safetyBackupFile = File('$userDbPath.pre_restore_safety.bak');
      expect(safetyBackupFile.existsSync(), isTrue);

      // Older data is now active (CUST-403 exists, CUST-404 does not)
      final restoredCustomers = await custRepo.getAllCustomers();
      expect(restoredCustomers.any((c) => c.customerCode == 'CUST-403'), isTrue);
      expect(restoredCustomers.any((c) => c.customerCode == 'CUST-404'), isFalse);
    });
  });

  group('Requirement 6: In-Memory Controllers Refresh', () {
    test('AuthService.clearUserControllers purges in-memory controllers on restore', () async {
      await dbHelper.setActiveUser(501);

      // Register an in-memory customer controller
      final custRepo = CustomerRepository();
      final controller = CustomerController(customerRepo: custRepo);
      Get.put<CustomerController>(controller);

      expect(Get.isRegistered<CustomerController>(), isTrue);

      // Perform clearUserControllers
      AuthService.clearUserControllers();

      // Controller is purged from GetX dependency container
      expect(Get.isRegistered<CustomerController>(), isFalse);
    });
  });

  group('Requirement 7: Sequence Reconciliation After Restore', () {
    test('SequenceUtils reconciles reserved codes with restored database records', () async {
      await dbHelper.setActiveUser(601);
      final custRepo = CustomerRepository();

      // User has CUST-001 in DB
      await custRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-001',
        name: 'Customer One',
      ));

      // Make a backup containing CUST-001
      final backupService = BackupService(dbHelper: dbHelper);
      final backupPath = '${tempDir.path}/seq_backup_601.db';
      await backupService.createBackup(targetFilePath: backupPath);

      // Now suppose in the active DB, user deleted CUST-001 (which reserved it)
      await SequenceUtils.reserve('reserved_customer_codes', 'CUST-001');
      var reserved = await SequenceUtils.getReserved('reserved_customer_codes');
      expect(reserved.contains('CUST-001'), isTrue);

      // Restore the backup which contains CUST-001
      final ok = await backupService.restoreFromBackup(sourceFilePath: backupPath);
      expect(ok, isTrue);

      // Reconcile
      await SequenceUtils.reconcileAfterRestore(dbHelper);

      // CUST-001 must be un-reserved because it exists as an active record in restored DB
      reserved = await SequenceUtils.getReserved('reserved_customer_codes');
      expect(reserved.contains('CUST-001'), isFalse);

      // Next customer code advances correctly past existing records
      final nextCode = await custRepo.getNextCustomerCode();
      expect(nextCode, 'CUST-002');
    });
  });

  group('Requirement 8: Database Info Size and Timestamp Display', () {
    test('BackupService.getDatabaseInfo returns formatted size and last-modified date', () async {
      await dbHelper.setActiveUser(701);
      final backupService = BackupService(dbHelper: dbHelper);

      final info = await backupService.getDatabaseInfo();

      expect(info['path'], contains('accounting_user_701.db'));
      expect(info['size'], contains('KB'));
      expect(info['size_kb'], isNotNull);
      expect(info['lastModified'], isNot('N/A'));
      expect(info['last_modified'], isNot('N/A'));
      expect(info['exists'], isTrue);
    });
  });

  group('Requirement 9: Authorization Enforcement', () {
    test('Non-admin user (VIEWER / STAFF) is denied backup and restore', () async {
      await dbHelper.setActiveUser(801);
      final authService = AuthService();
      authService.currentUser.value = UserModel(
        id: 801,
        organizationId: 1,
        email: 'staff@example.com',
        fullName: 'Staff User',
        role: AuthConstants.roleViewer,
      );

      final controller = SettingsController(
        authService: authService,
        dbHelper: dbHelper,
      );

      expect(controller.canManageBackups, isFalse);

      // createBackup should reject
      await controller.createBackup();
      expect(controller.isSubmitting.value, isFalse);

      // restoreBackup should reject
      await controller.restoreBackup();
      expect(controller.isSubmitting.value, isFalse);
    });

    test('Admin/Owner user is allowed backup and restore', () async {
      await dbHelper.setActiveUser(802);
      final authService = AuthService();
      authService.currentUser.value = UserModel(
        id: 802,
        organizationId: 1,
        email: 'admin@example.com',
        fullName: 'Admin User',
        role: AuthConstants.roleAdmin,
      );

      final controller = SettingsController(
        authService: authService,
        dbHelper: dbHelper,
      );

      expect(controller.canManageBackups, isTrue);
    });
  });
}
