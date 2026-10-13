import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/widgets/app_dialog.dart';
import 'package:accubooks/controllers/customer_controller.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/screens/customers/customers_screen.dart';

class InMemoryCustomerRepository extends CustomerRepository {
  final List<CustomerModel> storage = [];
  final Set<String> reservedCodes = {};

  @override
  Future<List<CustomerModel>> getAllCustomers({String? search, bool activeOnly = false}) async {
    return List.from(storage);
  }

  @override
  Future<CustomerModel?> getCustomerById(int id, {dynamic txn}) async {
    final idx = storage.indexWhere((c) => c.id == id);
    return idx >= 0 ? storage[idx] : null;
  }

  @override
  Future<Set<String>> getReservedCodes() async {
    return Set.from(reservedCodes);
  }

  @override
  Future<void> reserveCustomerCode(String code) async {
    reservedCodes.add(code.trim().toUpperCase());
  }

  @override
  Future<bool> isCustomerCodeExists(String customerCode, {int? excludeId, dynamic txn}) async {
    final clean = customerCode.trim().toUpperCase();
    if (clean.isEmpty) return false;

    final existsInStorage = storage.any((c) =>
        c.customerCode.trim().toUpperCase() == clean &&
        (excludeId == null || c.id != excludeId));
    if (existsInStorage) return true;

    if (reservedCodes.contains(clean)) return true;

    return false;
  }

  @override
  Future<String> getNextCustomerCode({dynamic txn}) async {
    int maxNumber = 0;
    for (final c in storage) {
      final matches = RegExp(r'\d+').allMatches(c.customerCode);
      if (matches.isNotEmpty) {
        final num = int.tryParse(matches.last.group(0)!);
        if (num != null && num > maxNumber) maxNumber = num;
      }
    }
    for (final code in reservedCodes) {
      final matches = RegExp(r'\d+').allMatches(code);
      if (matches.isNotEmpty) {
        final num = int.tryParse(matches.last.group(0)!);
        if (num != null && num > maxNumber) maxNumber = num;
      }
    }

    int nextNumber = maxNumber + 1;
    String candidate = '${AccountingConstants.prefixCustomer}${nextNumber.toString().padLeft(3, '0')}';
    while (storage.any((c) => c.customerCode.trim().toUpperCase() == candidate.toUpperCase()) ||
        reservedCodes.contains(candidate.toUpperCase())) {
      nextNumber++;
      candidate = '${AccountingConstants.prefixCustomer}${nextNumber.toString().padLeft(3, '0')}';
    }
    return candidate;
  }

  @override
  Future<int> insertCustomer(CustomerModel customer) async {
    if (await isCustomerCodeExists(customer.customerCode)) {
      throw Exception('Customer code already exists. Please use a unique code.');
    }
    final newId = storage.length + 1;
    final saved = customer.copyWith(id: newId);
    storage.add(saved);
    return newId;
  }

  @override
  Future<int> updateCustomer(CustomerModel customer) async {
    if (await isCustomerCodeExists(customer.customerCode, excludeId: customer.id)) {
      throw Exception('Customer code already exists. Please use a unique code.');
    }
    final idx = storage.indexWhere((c) => c.id == customer.id);
    if (idx >= 0) {
      storage[idx] = customer;
      return 1;
    }
    return 0;
  }

  @override
  Future<bool> canDeleteCustomer(int id) async => true;

  @override
  Future<int> deleteCustomer(int id) async {
    final idx = storage.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      await reserveCustomerCode(storage[idx].customerCode);
      storage.removeAt(idx);
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
    CustomerRepository.clearReservedCodesForTesting();
  });

  tearDown(() {
    Get.reset();
  });

  Widget wrapWithApp(Widget child) {
    return GetMaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Customer Code Auto-Generation & Sequence Tests', () {
    test('Empty repository generates CUST-001', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      final nextCode = await controller.getNextCustomerCode();
      expect(nextCode, equals('CUST-001'));
    });

    test('Adding customers sequentially advances code: CUST-001, CUST-002, CUST-003', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      // Customer 1
      final code1 = await controller.getNextCustomerCode();
      expect(code1, equals('CUST-001'));
      final ok1 = await controller.saveCustomer(CustomerModel(customerCode: code1, name: 'Alice'));
      expect(ok1, isTrue);

      // Customer 2
      final code2 = await controller.getNextCustomerCode();
      expect(code2, equals('CUST-002'));
      final ok2 = await controller.saveCustomer(CustomerModel(customerCode: code2, name: 'Bob'));
      expect(ok2, isTrue);

      // Customer 3
      final code3 = await controller.getNextCustomerCode();
      expect(code3, equals('CUST-003'));
      final ok3 = await controller.saveCustomer(CustomerModel(customerCode: code3, name: 'Charlie'));
      expect(ok3, isTrue);

      expect(controller.customers.length, equals(3));
      expect(controller.customers.map((c) => c.customerCode).toList(),
          equals(['CUST-001', 'CUST-002', 'CUST-003']));
    });

    test('Deleted customer codes remain reserved and are never reused', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Alice'));
      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-002', name: 'Bob'));

      // Delete customer 2 (Bob with CUST-002)
      final bob = controller.customers.firstWhere((c) => c.customerCode == 'CUST-002');
      final delOk = await controller.deleteCustomer(bob);
      expect(delOk, isTrue);

      // Next code must advance to CUST-003, NOT reuse CUST-002
      final nextCode = await controller.getNextCustomerCode();
      expect(nextCode, equals('CUST-003'));

      // Trying to manually re-add CUST-002 must be rejected
      final reject = await controller.saveCustomer(CustomerModel(customerCode: 'CUST-002', name: 'Imposter Bob'));
      expect(reject, isFalse);
    });

    test('Duplicate customer code is rejected for new customer', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Alice'));

      // Attempt duplicate code
      final dupOk = await controller.saveCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Duplicate Alice'));
      expect(dupOk, isFalse);
      expect(controller.customers.length, equals(1));
    });

    test('Editing customer without changing its code works correctly', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Alice'));
      final alice = controller.customers.first;

      final updatedAlice = alice.copyWith(name: 'Alice Cooper');
      final updateOk = await controller.updateCustomer(updatedAlice);
      expect(updateOk, isTrue);

      final reloadedAlice = controller.customers.firstWhere((c) => c.id == alice.id);
      expect(reloadedAlice.name, equals('Alice Cooper'));
      expect(reloadedAlice.customerCode, equals('CUST-001'));
    });

    test('Editing customer to use another customer code is rejected', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Alice'));
      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-002', name: 'Bob'));

      final bob = controller.customers.firstWhere((c) => c.customerCode == 'CUST-002');
      final stolenCodeBob = bob.copyWith(customerCode: 'CUST-001');

      final updateOk = await controller.updateCustomer(stolenCodeBob);
      expect(updateOk, isFalse);

      // Bob's code remains unchanged
      final reloadedBob = controller.customers.firstWhere((c) => c.id == bob.id);
      expect(reloadedBob.customerCode, equals('CUST-002'));
    });

    test('Existing customer records remain completely unchanged when other customers are added or edited', () async {
      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);

      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Alice', phone: '111'));
      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-002', name: 'Bob', phone: '222'));

      // Add a third customer
      await controller.saveCustomer(CustomerModel(customerCode: 'CUST-003', name: 'Charlie', phone: '333'));

      // Verify Alice and Bob are untouched
      final alice = controller.customers.firstWhere((c) => c.id == 1);
      expect(alice.name, equals('Alice'));
      expect(alice.customerCode, equals('CUST-001'));
      expect(alice.phone, equals('111'));

      final bob = controller.customers.firstWhere((c) => c.id == 2);
      expect(bob.name, equals('Bob'));
      expect(bob.customerCode, equals('CUST-002'));
      expect(bob.phone, equals('222'));
    });
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

  group('Customer UI Dialog Code Auto-Generation & Uniqueness Tests', () {
    testWidgets('Add Customer Dialog opens with auto-generated code and advances after adding', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryCustomerRepository();
      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);
      await controller.loadCustomers();

      await tester.pumpWidget(wrapWithApp(const CustomersScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      // Click Add Customer
      await tester.tap(find.byIcon(Icons.person_add_alt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Code field should be prepopulated with CUST-001
      expect(find.text('CUST-001'), findsOneWidget);

      // Enter customer name into dialog field
      final dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogFields.at(1), 'First Customer');
      await tester.pump();

      // Tap Save Customer
      await tester.tap(find.text('Save Customer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Code field in the open dialog should now advance to CUST-002
      expect(find.text('CUST-002'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify customer was added to list
      expect(find.text('First Customer'), findsOneWidget);
      expect(find.text('CUST-001'), findsOneWidget);

      // Drain snackbar animations
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Duplicate customer code displays error message and preserves inputs in dialog', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryCustomerRepository();
      await repo.insertCustomer(CustomerModel(customerCode: 'CUST-001', name: 'Existing Customer'));

      final controller = CustomerController(customerRepo: repo);
      Get.put(controller);
      await controller.loadCustomers();

      await tester.pumpWidget(wrapWithApp(const CustomersScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      // Open Add Customer
      await tester.tap(find.byIcon(Icons.person_add_alt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );

      // Overwrite auto code with duplicate CUST-001
      await tester.enterText(dialogFields.at(0), 'CUST-001');
      await tester.pump();

      await tester.enterText(dialogFields.at(1), 'Duplicate Customer');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save Customer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should remain open
      expect(find.text('Add New Customer'), findsOneWidget);
      expect(Get.isDialogOpen, isTrue);

      // Input should be preserved
      expect(find.text('Duplicate Customer'), findsOneWidget);

      // Duplicate message should be shown
      expect(find.text('Customer code already exists. Please use a unique code.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
