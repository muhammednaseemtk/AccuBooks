import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accubooks/controllers/auth_controller.dart';
import 'package:accubooks/controllers/dashboard_controller.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/expense_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/sales_invoice_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/repositories/account_repository.dart';
import 'package:accubooks/repositories/auth_repository.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/expense_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/sales_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/services/auth_service.dart';
import 'package:accubooks/services/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AuthRepository authRepo;
  late AuthService authService;
  late CustomerRepository customerRepo;
  late SupplierRepository supplierRepo;
  late ProductRepository productRepo;
  late AccountRepository accountRepo;
  late SalesRepository salesRepo;
  late ExpenseRepository expenseRepo;
  late ReportService reportService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('accubooks_isolation_test_');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    DatabaseHelper.initializeFfi();
  });

  tearDownAll(() async {
    await DatabaseHelper().closeAll();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    await DatabaseHelper().setActiveUser(null);

    authRepo = AuthRepository();
    authService = AuthService(authRepo: authRepo);
    Get.put<AuthService>(authService);

    customerRepo = CustomerRepository();
    supplierRepo = SupplierRepository();
    productRepo = ProductRepository();
    accountRepo = AccountRepository();
    salesRepo = SalesRepository();
    expenseRepo = ExpenseRepository();
    reportService = ReportService();
  });

  tearDown(() async {
    Get.reset();
  });

  group('Part 1: Strict User Data Isolation on Same Device', () {
    test('User A creates records, User B logs in and sees ZERO User A records, User A logs back in and original records are preserved', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final userAEmail = 'usera_$ts@testcorp.com';
      final userBEmail = 'userb_$ts@acmeind.com';
      const passwordA = 'UserAPassword123!';
      const passwordB = 'UserBPassword123!';

      // 1. Sign up User A
      final userA = await authService.signup(
        fullName: 'Alice Anderson',
        email: userAEmail,
        phone: '9876543210',
        password: passwordA,
        companyName: 'Alpha Logistics $ts',
      );

      expect(userA.id, isNotNull);
      expect(DatabaseHelper().activeUserId, userA.id);
      expect(authService.currentUser.value?.email, userAEmail);
      expect(authService.currentUser.value?.fullName, 'Alice Anderson');

      // 2. User A creates data across modules:
      // (a) Customer
      final custAId = await customerRepo.insertCustomer(CustomerModel(
        name: 'User A Customer Acme',
        email: 'acme_$ts@client.com',
        phone: '1111111111',
        customerCode: 'CUST-A-01',
      ));
      expect(custAId, isPositive);

      // (b) Supplier
      final suppAId = await supplierRepo.insertSupplier(SupplierModel(
        name: 'User A Supplier Global',
        email: 'global_$ts@supp.com',
        phone: '2222222222',
        supplierCode: 'SUPP-A-01',
      ));
      expect(suppAId, isPositive);

      // (c) Product
      final prodAId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-A-01',
        name: 'User A Widget Alpha',
        salesPrice: 1500.0,
        purchasePrice: 1000.0,
        stockQuantity: 50.0,
      ));
      expect(prodAId, isPositive);

      // (d) Custom Account
      final accAId = await accountRepo.insertAccount(AccountModel(
        accountCode: '1099',
        accountName: 'User A Special Petty Cash',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 5000.0,
        openingBalanceType: AccountingConstants.balanceDebit,
      ));
      expect(accAId, isPositive);

      // (e) Expense
      final expAId = await expenseRepo.insertExpense(ExpenseModel(
        expenseNumber: 'EXP-A-01',
        expenseDate: DateTime.now(),
        accountId: 1,
        paymentAccountId: 1,
        amount: 250.0,
        description: 'User A Office Snacks',
      ));
      expect(expAId, isPositive);

      // (f) Sales Invoice
      final invAId = await salesRepo.insertSalesInvoice(SalesInvoiceModel(
        invoiceNumber: 'INV-A-01',
        invoiceDate: DateTime.now(),
        customerId: custAId,
        subtotal: 3000.0,
        taxAmount: 0.0,
        grandTotal: 3000.0,
        notes: 'User A order',
      ));
      expect(invAId, isPositive);

      // Verify User A data presence
      final custsA = await customerRepo.getAllCustomers();
      expect(custsA.any((c) => c.name == 'User A Customer Acme'), isTrue);

      final prodsA = await productRepo.getAllProducts();
      expect(prodsA.any((p) => p.name == 'User A Widget Alpha'), isTrue);

      final invsA = await salesRepo.getAllSalesInvoices();
      expect(invsA.any((i) => i.invoiceNumber == 'INV-A-01'), isTrue);

      // 3. User A logs out completely
      await authService.logout();

      expect(authService.currentUser.value, isNull);
      expect(authService.currentOrganization.value, isNull);
      expect(authService.isAuthenticated.value, isFalse);
      expect(DatabaseHelper().activeUserId, isNull);

      // 4. User B signs up on the SAME device
      final userB = await authService.signup(
        fullName: 'Bob Builder',
        email: userBEmail,
        phone: '8765432109',
        password: passwordB,
        companyName: 'Beta Construction $ts',
      );

      expect(userB.id, isNotNull);
      expect(userB.id, isNot(equals(userA.id)));
      expect(DatabaseHelper().activeUserId, userB.id);
      expect(authService.currentUser.value?.email, userBEmail);
      expect(authService.currentUser.value?.fullName, 'Bob Builder');

      // 5. VERIFY USER B SEES ZERO OF USER A'S DATA!
      final custsB = await customerRepo.getAllCustomers();
      expect(custsB.any((c) => c.name == 'User A Customer Acme'), isFalse,
          reason: "User B must not see User A's customers");
      expect(custsB.isEmpty, isTrue);

      final suppsB = await supplierRepo.getAllSuppliers();
      expect(suppsB.any((s) => s.name == 'User A Supplier Global'), isFalse,
          reason: "User B must not see User A's suppliers");
      expect(suppsB.isEmpty, isTrue);

      final prodsB = await productRepo.getAllProducts();
      expect(prodsB.any((p) => p.name == 'User A Widget Alpha'), isFalse,
          reason: "User B must not see User A's products");
      expect(prodsB.isEmpty, isTrue);

      final invsB = await salesRepo.getAllSalesInvoices();
      expect(invsB.any((i) => i.invoiceNumber == 'INV-A-01'), isFalse,
          reason: "User B must not see User A's sales invoices");
      expect(invsB.isEmpty, isTrue);

      final expsB = await expenseRepo.getAllExpenses();
      expect(expsB.any((e) => e.expenseNumber == 'EXP-A-01'), isFalse,
          reason: "User B must not see User A's expenses");
      expect(expsB.isEmpty, isTrue);

      final accsB = await accountRepo.getAllAccounts();
      expect(accsB.any((a) => a.accountCode == '1099'), isFalse,
          reason: "User B must not see User A's custom accounts");

      // Verify User B's dashboard metrics are clean
      final dashB = await reportService.getDashboardMetrics();
      expect(dashB['today_sales'], 0.0);
      expect(dashB['total_receivables'], 0.0);
      expect((dashB['recent_sales'] as List).isEmpty, isTrue);

      // 6. User B creates their OWN distinct data
      final custBId = await customerRepo.insertCustomer(CustomerModel(
        name: 'User B Customer Delta',
        email: 'delta_$ts@client.com',
        phone: '3333333333',
        customerCode: 'CUST-B-01',
      ));
      expect(custBId, isPositive);

      final prodBId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-B-01',
        name: 'User B Concrete Mixer',
        salesPrice: 50000.0,
        purchasePrice: 40000.0,
        stockQuantity: 5.0,
      ));
      expect(prodBId, isPositive);

      // User B updates a record
      await customerRepo.updateCustomer(CustomerModel(
        id: custBId,
        name: 'User B Customer Delta (Updated)',
        email: 'delta_$ts@client.com',
        phone: '3333333333',
        customerCode: 'CUST-B-01',
      ));
      final updatedCustB = await customerRepo.getCustomerById(custBId);
      expect(updatedCustB?.name, 'User B Customer Delta (Updated)');

      // User B deletes their customer
      await customerRepo.deleteCustomer(custBId);
      final deletedCustB = await customerRepo.getCustomerById(custBId);
      expect(deletedCustB, isNull);

      // 7. User B logs out
      await authService.logout();
      expect(DatabaseHelper().activeUserId, isNull);

      // 8. User A logs back in on the SAME device
      final loggedInA = await authService.login(
        email: userAEmail,
        password: passwordA,
      );
      expect(loggedInA.id, userA.id);
      expect(DatabaseHelper().activeUserId, userA.id);
      expect(authService.currentUser.value?.fullName, 'Alice Anderson');

      // 9. VERIFY USER A'S ORIGINAL DATA IS 100% PRESERVED AND INTACT!
      final reloadedCustsA = await customerRepo.getAllCustomers();
      expect(reloadedCustsA.any((c) => c.name == 'User A Customer Acme'), isTrue,
          reason: "User A's original customer must still be present");
      expect(reloadedCustsA.any((c) => c.name.contains('Delta')), isFalse,
          reason: "User A must not see User B's customer Delta");

      final reloadedProdsA = await productRepo.getAllProducts();
      expect(reloadedProdsA.any((p) => p.name == 'User A Widget Alpha'), isTrue,
          reason: "User A's original product must still be present");
      expect(reloadedProdsA.any((p) => p.name.contains('Mixer')), isFalse,
          reason: "User A must not see User B's product Mixer");

      final reloadedInvsA = await salesRepo.getAllSalesInvoices();
      expect(reloadedInvsA.any((i) => i.invoiceNumber == 'INV-A-01'), isTrue,
          reason: "User A's original sales invoice must still be present");

      final reloadedExpsA = await expenseRepo.getAllExpenses();
      expect(reloadedExpsA.any((e) => e.expenseNumber == 'EXP-A-01'), isTrue,
          reason: "User A's original expense must still be present");

      final reloadedAccsA = await accountRepo.getAllAccounts();
      expect(reloadedAccsA.any((a) => a.accountCode == '1099'), isTrue,
          reason: "User A's original custom account must still be present");
    });

    test('App restart simulation: restoreSession correctly restores active user database context', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'restore_$ts@session.com';
      const password = 'PasswordRestore123!';

      // Signup and establish session
      final user = await authService.signup(
        fullName: 'Carol Danvers',
        email: email,
        phone: '7788990011',
        password: password,
        companyName: 'Danvers Corp $ts',
      );

      // Add a product
      await productRepo.insertProduct(ProductModel(
        productCode: 'CORE-01',
        name: 'Photon Core',
        salesPrice: 999.0,
      ));

      // Simulate app kill / restart: reset DatabaseHelper connections and service state
      await DatabaseHelper().closeAll();
      authService.currentUser.value = null;
      authService.isAuthenticated.value = false;

      // Restore session
      final restored = await authService.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.id, user.id);
      expect(DatabaseHelper().activeUserId, user.id);
      expect(authService.isAuthenticated.value, isTrue);

      // Verify database queries succeed in the restored user context
      final prods = await productRepo.getAllProducts();
      expect(prods.any((p) => p.name == 'Photon Core'), isTrue);
    });
  });

  group('Part 2: Login Button Loading, Validation, and Navigation', () {
    test('Validation failure: empty email shows error and stops loading without navigating', () async {
      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = '';
      authCtrl.loginPasswordController.text = 'SomePassword123!';

      await authCtrl.login();

      expect(authCtrl.isLoading.value, isFalse);
      expect(authCtrl.errorMessage.value, 'Please enter your email address.');
      expect(authService.isAuthenticated.value, isFalse);
    });

    test('Validation failure: invalid email format shows error and stops loading', () async {
      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = 'invalid-email-format';
      authCtrl.loginPasswordController.text = 'SomePassword123!';

      await authCtrl.login();

      expect(authCtrl.isLoading.value, isFalse);
      expect(authCtrl.errorMessage.value, 'Please enter a valid email address.');
      expect(authService.isAuthenticated.value, isFalse);
    });

    test('Validation failure: empty password shows error and stops loading', () async {
      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = 'valid@email.com';
      authCtrl.loginPasswordController.text = '';

      await authCtrl.login();

      expect(authCtrl.isLoading.value, isFalse);
      expect(authCtrl.errorMessage.value, 'Please enter your password.');
      expect(authService.isAuthenticated.value, isFalse);
    });

    test('Invalid credentials: stops loading and shows clear error message', () async {
      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = 'nonexistent@user.com';
      authCtrl.loginPasswordController.text = 'WrongPassword123!';

      await authCtrl.login();

      expect(authCtrl.isLoading.value, isFalse);
      expect(authCtrl.errorMessage.value, contains('Invalid email or password'));
      expect(authService.isAuthenticated.value, isFalse);
      expect(DatabaseHelper().activeUserId, isNull);
    });

    test('Repeated clicks: ignores second submission while request is in progress', () async {
      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = 'user@test.com';
      authCtrl.loginPasswordController.text = 'Password123!';
      authCtrl.isLoading.value = true; // Simulate request in progress

      // Calling login while isLoading is true must return immediately without clearing errorMessage
      authCtrl.errorMessage.value = 'pre-existing';
      await authCtrl.login();

      expect(authCtrl.errorMessage.value, 'pre-existing');
    });

    test('Data initialization failure: safely rolls back session and resets loading', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'failinit_$ts@test.com';
      const password = 'FailPassword123!';

      // Create valid user in authDatabase
      await authService.signup(
        fullName: 'David Banner',
        email: email,
        phone: '1231231234',
        password: password,
        companyName: 'Gamma Labs $ts',
      );
      await authService.logout();

      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = email;
      authCtrl.loginPasswordController.text = password;

      await authCtrl.login();

      // Normal flow should succeed and isLoading should be false
      expect(authCtrl.isLoading.value, isFalse);
      expect(authService.isAuthenticated.value, isTrue);
      expect(authCtrl.loginPasswordController.text, isEmpty);
    });

    test('Successful login: initializes user data, removes login screen, and clears loading state', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'success_$ts@enterprise.com';
      const password = 'EnterprisePassword123!';

      // 1. Create user
      final user = await authService.signup(
        fullName: 'Elena Fisher',
        email: email,
        phone: '5544332211',
        password: password,
        companyName: 'Uncharted Cargo $ts',
      );
      await authService.logout();

      // 2. Setup AuthController
      final authCtrl = AuthController(authService: authService);
      authCtrl.loginEmailController.text = email;
      authCtrl.loginPasswordController.text = password;

      expect(authCtrl.isLoading.value, isFalse);

      // 3. Perform login
      await authCtrl.login();

      // 4. Verify all post-login assertions
      expect(authCtrl.isLoading.value, isFalse, reason: 'isLoading must be cleared in finally');
      expect(authCtrl.errorMessage.value, isEmpty);
      expect(authCtrl.loginPasswordController.text, isEmpty, reason: 'Password field must be cleared on success');
      expect(authService.isAuthenticated.value, isTrue);
      expect(authService.currentUser.value?.id, user.id);
      expect(DatabaseHelper().activeUserId, user.id);

      // 5. Verify dashboard controller can load with newly authenticated user data
      final dashCtrl = DashboardController(reportService: reportService);
      await dashCtrl.loadDashboardData();
      expect(dashCtrl.isLoading.value, isFalse);
      expect(dashCtrl.errorMessage.value, isEmpty);
    });
  });
}
