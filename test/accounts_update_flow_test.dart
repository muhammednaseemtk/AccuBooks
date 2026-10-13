import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/controllers/account_controller.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/repositories/account_repository.dart';
import 'package:accubooks/screens/accounts/accounts_screen.dart';

class FakeAccountRepository extends AccountRepository {
  final List<AccountModel> storage = [];
  bool shouldFail = false;

  @override
  Future<List<AccountModel>> getAllAccounts({String? search, String? type, bool activeOnly = false}) async {
    return List.from(storage);
  }

  @override
  Future<int> insertAccount(AccountModel account) async {
    final newId = storage.length + 1;
    final item = account.copyWith(id: newId);
    storage.add(item);
    return newId;
  }

  @override
  Future<int> updateAccount(AccountModel account) async {
    if (shouldFail) {
      throw Exception('Simulated database update failure');
    }
    final index = storage.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      storage[index] = account;
      return 1;
    }
    return 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    DatabaseHelper.initializeFfi();
  });

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    Get.put(SettingsController());
  });

  tearDown(() {
    Get.reset();
  });

  void ignoreLayoutOverflow() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final isOverflow = details.toString().contains('overflowed');
      if (!isOverflow) {
        originalOnError?.call(details);
      }
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });
  }

  Widget wrapWithApp(Widget child) {
    return GetMaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Accounts Module Update Flow - UI & Dialog Tests', () {
    testWidgets('1. Successful Update: closes dialog automatically, refreshes list, shows success message', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeAccountRepository();
      final acc = AccountModel(
        id: 1,
        accountCode: '1001',
        accountName: 'Original Account Name',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 1500.0,
        openingBalanceType: AccountingConstants.balanceDebit,
        isActive: true,
      );
      fakeRepo.storage.add(acc);

      final controller = AccountController(accountRepo: fakeRepo);
      Get.put(controller);
      await controller.loadAccounts();

      await tester.pumpWidget(wrapWithApp(const AccountsScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      // Find the account row
      expect(find.text('Original Account Name'), findsOneWidget);

      // Tap Edit button on this account
      final editButton = find.byTooltip('Edit Account');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is open
      expect(find.text('Edit Account'), findsOneWidget);
      expect(Get.isDialogOpen, isTrue);

      // Modify the account name
      final nameField = find.widgetWithText(TextFormField, 'Original Account Name');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Updated Account Name');
      await tester.pump();

      // Tap Update button
      final updateButton = find.widgetWithText(ElevatedButton, 'Update');
      expect(updateButton, findsOneWidget);
      await tester.tap(updateButton);

      // Pump frames for async update and dialog pop
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // 1. Verify Edit Account dialog is automatically closed
      expect(find.text('Edit Account'), findsNothing);
      expect(Get.isDialogOpen, isFalse);

      // 2. Verify AccountsScreen is still present (did not navigate away)
      expect(find.text('Chart of Accounts'), findsOneWidget);

      // 3. Verify success message is displayed
      expect(find.text('Account updated successfully'), findsOneWidget);

      // 4. Verify the updated name appears in the accounts list immediately
      expect(find.text('Updated Account Name'), findsOneWidget);
      expect(fakeRepo.storage.first.accountName, equals('Updated Account Name'));

      // Let snackbar timer finish cleanly
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('2. Validation Failure: keeps dialog open, displays validation message, preserves inputs', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeAccountRepository();
      final acc = AccountModel(
        id: 1,
        accountCode: '1001',
        accountName: 'Valid Account Name',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 500.0,
        openingBalanceType: AccountingConstants.balanceDebit,
        isActive: true,
      );
      fakeRepo.storage.add(acc);

      final controller = AccountController(accountRepo: fakeRepo);
      Get.put(controller);
      await controller.loadAccounts();

      await tester.pumpWidget(wrapWithApp(const AccountsScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      // Open Edit dialog
      final editButton = find.byTooltip('Edit Account');
      await tester.tap(editButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit Account'), findsOneWidget);

      // Clear the account name to cause validation failure
      final nameField = find.widgetWithText(TextFormField, 'Valid Account Name');
      await tester.enterText(nameField, '');
      await tester.pump();

      // Tap Update
      final updateButton = find.widgetWithText(ElevatedButton, 'Update');
      await tester.tap(updateButton);
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog MUST remain open
      expect(find.text('Edit Account'), findsOneWidget);
      expect(Get.isDialogOpen, isTrue);

      // Validation error message must appear
      expect(find.text('Name required'), findsOneWidget);

      // Success message MUST NOT appear
      expect(find.text('Account updated successfully'), findsNothing);

      // Database repository was NOT updated
      expect(fakeRepo.storage.first.accountName, equals('Valid Account Name'));

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('3. Database Failure: keeps dialog open, preserves values, shows error message', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeAccountRepository();
      fakeRepo.shouldFail = true; // Trigger failure on update

      final acc = AccountModel(
        id: 1,
        accountCode: '1001',
        accountName: 'Pre-Fail Name',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 100.0,
        openingBalanceType: AccountingConstants.balanceDebit,
        isActive: true,
      );
      fakeRepo.storage.add(acc);

      final controller = AccountController(accountRepo: fakeRepo);
      Get.put(controller);
      controller.accounts.add(acc);
      controller.isLoading.value = false;

      await tester.pumpWidget(wrapWithApp(const AccountsScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      // Open Edit dialog
      final editButton = find.byTooltip('Edit Account');
      await tester.tap(editButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit Account'), findsOneWidget);

      // Enter a new name
      final nameField = find.widgetWithText(TextFormField, 'Pre-Fail Name');
      await tester.enterText(nameField, 'Attempted Name');
      await tester.pump();

      // Tap Update
      final updateButton = find.widgetWithText(ElevatedButton, 'Update');
      await tester.tap(updateButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog MUST remain open
      expect(find.text('Edit Account'), findsOneWidget);
      expect(Get.isDialogOpen, isTrue);

      // Preserves entered value
      expect(find.text('Attempted Name'), findsOneWidget);

      // Shows error snackbar
      expect(find.textContaining('Failed to save account'), findsOneWidget);

      // Does not show success snackbar
      expect(find.text('Account updated successfully'), findsNothing);

      // Let timers drain
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });

    test('4. Repeated Submission: isSubmitting flag prevents duplicate submissions', () async {
      final fakeRepo = FakeAccountRepository();
      final controller = AccountController(accountRepo: fakeRepo);
      expect(controller.isSubmitting.value, isFalse);

      final acc = AccountModel(
        id: 1,
        accountCode: '1001',
        accountName: 'Submitting Test',
        accountType: AccountingConstants.typeAsset,
      );

      final future = controller.updateAccount(acc);
      expect(controller.isSubmitting.value, isTrue);

      final result = await future;
      expect(result, isTrue);
      expect(controller.isSubmitting.value, isFalse);
    });
  });

  group('Accounts Module Update Flow - Real Database Persistence Tests', () {
    test('5. Real Database updateAccount updates record and refreshes balances', () async {
      final accountRepo = AccountRepository();
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final acc = AccountModel(
        accountCode: '95$ts',
        accountName: 'Db Test Account $ts',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 2000.0,
        openingBalanceType: AccountingConstants.balanceDebit,
        isActive: true,
      );
      final id = await accountRepo.insertAccount(acc);
      expect(id, isPositive);

      final controller = AccountController(accountRepo: accountRepo);
      await controller.loadAccounts();

      final created = controller.accounts.firstWhere((a) => a.id == id);
      expect(created.accountName, equals('Db Test Account $ts'));

      // Perform update via controller
      final updated = created.copyWith(
        accountName: 'Db Test Account $ts - Updated',
        openingBalance: 3500.0,
      );
      final ok = await controller.updateAccount(updated);
      expect(ok, isTrue);

      // Verify controller accounts reloaded with updated data
      final reloadedFromCtrl = controller.accounts.firstWhere((a) => a.id == id);
      expect(reloadedFromCtrl.accountName, equals('Db Test Account $ts - Updated'));
      expect(reloadedFromCtrl.openingBalance, equals(3500.0));

      // Verify direct database query also confirms update
      final reloadedFromDb = await accountRepo.getAccountById(id);
      expect(reloadedFromDb, isNotNull);
      expect(reloadedFromDb!.accountName, equals('Db Test Account $ts - Updated'));
      expect(reloadedFromDb.openingBalance, equals(3500.0));
    });
  });
}
