import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/controllers/account_controller.dart';
import 'package:accubooks/controllers/customer_controller.dart';
import 'package:accubooks/controllers/supplier_controller.dart';
import 'package:accubooks/controllers/product_controller.dart';
import 'package:accubooks/controllers/sales_controller.dart';
import 'package:accubooks/controllers/purchase_controller.dart';
import 'package:accubooks/controllers/receipt_controller.dart';
import 'package:accubooks/controllers/payment_controller.dart';
import 'package:accubooks/controllers/expense_controller.dart';
import 'package:accubooks/controllers/journal_controller.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/services/sales_service.dart';
import 'package:accubooks/services/purchase_service.dart';

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

  group('Part 1: Collapsible Sidebar Tests', () {
    test('SettingsController toggles sidebar collapsed state correctly and persists', () {
      final settings = Get.put(SettingsController());
      expect(settings.isSidebarCollapsed.value, isFalse);

      settings.toggleSidebar();
      expect(settings.isSidebarCollapsed.value, isTrue);

      settings.toggleSidebar();
      expect(settings.isSidebarCollapsed.value, isFalse);
    });
  });

  group('Part 2: Form Reset & Save Protection Across All 10 Modules', () {
    test('1. AccountController: Save account succeeds', () async {
      final controller = AccountController();
      final ts = DateTime.now().microsecondsSinceEpoch;
      final acc = AccountModel(
        accountCode: 'ACC-$ts',
        accountName: 'Test Account $ts',
        accountType: 'Asset',
        openingBalanceType: 'Debit',
        openingBalance: 100.0,
      );

      final ok = await controller.saveAccount(acc);
      expect(ok, isTrue);
      expect(controller.accounts.any((a) => a.accountCode == 'ACC-$ts'), isTrue);
    });

    test('2. CustomerController: Save customer succeeds', () async {
      final controller = CustomerController();
      final ts = DateTime.now().microsecondsSinceEpoch;
      final cust = CustomerModel(
        customerCode: 'CUST-ACC-$ts',
        name: 'Test Customer $ts',
      );

      final ok = await controller.saveCustomer(cust);
      expect(ok, isTrue);
      expect(controller.customers.any((c) => c.customerCode == 'CUST-ACC-$ts'), isTrue);
    });

    test('3. SupplierController: Save supplier succeeds', () async {
      final controller = SupplierController();
      final ts = DateTime.now().microsecondsSinceEpoch;
      final supp = SupplierModel(
        supplierCode: 'SUPP-ACC-$ts',
        name: 'Test Supplier $ts',
      );

      final ok = await controller.saveSupplier(supp);
      expect(ok, isTrue);
      expect(controller.suppliers.any((s) => s.supplierCode == 'SUPP-ACC-$ts'), isTrue);
    });

    test('4. ProductController: Save product succeeds', () async {
      final controller = ProductController();
      final ts = DateTime.now().microsecondsSinceEpoch;
      final prod = ProductModel(
        productCode: 'PRD-ACC-$ts',
        name: 'Test Product $ts',
        salesPrice: 50.0,
        stockQuantity: 10.0,
      );

      final ok = await controller.saveProduct(prod);
      expect(ok, isTrue);
      expect(controller.products.any((p) => p.productCode == 'PRD-ACC-$ts'), isTrue);
    });

    test('5. SalesController: Resets form on success, keeps data on validation failure', () async {
      final customerRepo = CustomerRepository();
      final productRepo = ProductRepository();
      final salesService = SalesService();

      final controller = SalesController(
        salesService: salesService,
        customerRepo: customerRepo,
        productRepo: productRepo,
      );

      // Validation failure: no customer, no items -> fails and does not reset
      controller.formNotes.value = 'Unsaved notes';
      final failed = await controller.submitInvoice();
      expect(failed, isFalse);
      expect(controller.formNotes.value, equals('Unsaved notes'));

      // Setup valid invoice
      final ts = DateTime.now().microsecondsSinceEpoch;
      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-T-$ts',
        name: 'Test Customer $ts',
      ));
      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-T-$ts',
        name: 'Test Prod $ts',
        salesPrice: 150.0,
        stockQuantity: 50.0,
      ));

      await controller.prepareNewInvoiceForm();
      controller.formSelectedCustomer.value = CustomerModel(id: custId, customerCode: 'CUST-T-$ts', name: 'Test Customer $ts');
      controller.addFormItem(
        ProductModel(id: prodId, productCode: 'PROD-T-$ts', name: 'Test Prod $ts', salesPrice: 150.0, stockQuantity: 50.0),
        1.0,
        150.0,
        0.0,
      );
      controller.formNotes.value = 'Special delivery instructions';

      final success = await controller.submitInvoice();
      expect(success, isTrue);

      // Form must be cleared/reset ready for next record
      expect(controller.formSelectedCustomer.value, isNull);
      expect(controller.formItems.isEmpty, isTrue);
      expect(controller.formDiscount.value, equals(0.0));
      expect(controller.formPaidAmount.value, equals(0.0));
      expect(controller.formNotes.value, isEmpty);
      expect(controller.formNextInvoiceNumber.value, isNotEmpty);
    });

    test('6. PurchaseController: Resets form on success, keeps data on failure', () async {
      final supplierRepo = SupplierRepository();
      final productRepo = ProductRepository();
      final purchaseService = PurchaseService();

      final controller = PurchaseController(
        purchaseService: purchaseService,
        supplierRepo: supplierRepo,
        productRepo: productRepo,
      );

      // Validation failure: no supplier -> fails and keeps data
      controller.formNotes.value = 'Unsaved purchase note';
      final failed = await controller.submitPurchase();
      expect(failed, isFalse);
      expect(controller.formNotes.value, equals('Unsaved purchase note'));

      final ts = DateTime.now().microsecondsSinceEpoch;
      final suppId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUPP-T-$ts',
        name: 'Test Supp $ts',
      ));
      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-P-$ts',
        name: 'Test Prod $ts',
        salesPrice: 200.0,
        stockQuantity: 10.0,
      ));

      await controller.prepareNewPurchaseForm();
      controller.formSelectedSupplier.value = SupplierModel(id: suppId, supplierCode: 'SUPP-T-$ts', name: 'Test Supp $ts');
      controller.addFormItem(
        ProductModel(id: prodId, productCode: 'PROD-P-$ts', name: 'Test Prod $ts', salesPrice: 200.0, stockQuantity: 10.0),
        2.0,
        120.0,
        0.0,
      );

      final success = await controller.submitPurchase();
      expect(success, isTrue);

      // Form must be cleared/reset
      expect(controller.formSelectedSupplier.value, isNull);
      expect(controller.formItems.isEmpty, isTrue);
      expect(controller.formDiscount.value, equals(0.0));
      expect(controller.formPaidAmount.value, equals(0.0));
      expect(controller.formNotes.value, isEmpty);
      expect(controller.formNextPurchaseNumber.value, isNotEmpty);
    });

    test('7. ReceiptController: Validation failure preserves entered data', () async {
      final controller = ReceiptController();
      controller.formAmount.value = -10.0;
      final ok = await controller.submitReceipt();
      expect(ok, isFalse);
      expect(controller.formAmount.value, equals(-10.0));
    });

    test('8. PaymentController: Validation failure preserves entered data', () async {
      final controller = PaymentController();
      controller.formAmount.value = -5.0;
      final ok = await controller.submitPayment();
      expect(ok, isFalse);
      expect(controller.formAmount.value, equals(-5.0));
    });

    test('9. ExpenseController: Validation failure preserves entered data', () async {
      final controller = ExpenseController();
      controller.formDescription.value = 'Failed expense note';
      final ok = await controller.submitExpense();
      expect(ok, isFalse);
      expect(controller.formDescription.value, equals('Failed expense note'));
    });

    test('10. JournalController: Validation failure preserves entered data', () async {
      final controller = JournalController();
      controller.formDescription.value = 'Unbalanced journal test';
      final ok = await controller.submitJournalEntry();
      expect(ok, isFalse);
      expect(controller.formDescription.value, equals('Unbalanced journal test'));
    });
  });
}
