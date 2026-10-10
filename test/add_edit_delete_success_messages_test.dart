import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/controllers/account_controller.dart';
import 'package:accubooks/controllers/customer_controller.dart';
import 'package:accubooks/controllers/supplier_controller.dart';
import 'package:accubooks/controllers/product_controller.dart';
import 'package:accubooks/controllers/sales_order_controller.dart';
import 'package:accubooks/controllers/sales_controller.dart';
import 'package:accubooks/controllers/purchase_controller.dart';
import 'package:accubooks/controllers/receipt_controller.dart';
import 'package:accubooks/controllers/payment_controller.dart';
import 'package:accubooks/controllers/expense_controller.dart';
import 'package:accubooks/controllers/journal_controller.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/models/category_model.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/sales_order_item_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/account_repository.dart';

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

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  Widget wrapWithApp(Widget child) {
    return GetMaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Add, Edit, and Delete Success Messages Across All Modules', () {
    testWidgets('1. Accounts: Add, Edit, Delete success snackbar messages', (tester) async {
      final controller = AccountController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Accounts Test')));
      await tester.pumpAndSettle();

      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final acc = AccountModel(
        accountCode: 'ACC-MSG-$ts',
        accountName: 'Msg Test Account $ts',
        accountType: AccountingConstants.typeAsset,
        isActive: true,
      );

      // Add
      final addOk = await controller.saveAccount(acc);
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Account added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdAcc = controller.accounts.firstWhere((a) => a.accountCode == acc.accountCode);
      final editAcc = createdAcc.copyWith(accountName: 'Updated Msg Account $ts');
      final editOk = await controller.saveAccount(editAcc);
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Account updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deleteAccount(editAcc);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Account deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('2. Customers: Add, Edit, Delete success snackbar messages', (tester) async {
      final controller = CustomerController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Customers Test')));
      await tester.pumpAndSettle();

      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final cust = CustomerModel(
        customerCode: 'CUST-MSG-$ts',
        name: 'Msg Customer $ts',
        phone: '98765$ts',
        email: 'msg$ts@customer.com',
      );

      // Add
      final addOk = await controller.saveCustomer(cust);
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Customer added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdCust = controller.customers.firstWhere((c) => c.customerCode == cust.customerCode);
      final editCust = createdCust.copyWith(name: 'Updated Msg Cust $ts');
      final editOk = await controller.saveCustomer(editCust);
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Customer updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deleteCustomer(editCust);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Customer deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('3. Suppliers: Add, Edit, Delete success snackbar messages', (tester) async {
      final controller = SupplierController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Suppliers Test')));
      await tester.pumpAndSettle();

      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final supp = SupplierModel(
        supplierCode: 'SUPP-MSG-$ts',
        name: 'Msg Supplier $ts',
        phone: '98765$ts',
        email: 'msg$ts@supplier.com',
      );

      // Add
      final addOk = await controller.saveSupplier(supp);
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Supplier added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdSupp = controller.suppliers.firstWhere((s) => s.supplierCode == supp.supplierCode);
      final editSupp = createdSupp.copyWith(name: 'Updated Msg Supp $ts');
      final editOk = await controller.saveSupplier(editSupp);
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Supplier updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deleteSupplier(editSupp);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Supplier deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('4. Products: Add, Edit, Delete success snackbar messages', (tester) async {
      final controller = ProductController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Products Test')));
      await tester.pumpAndSettle();

      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final prod = ProductModel(
        productCode: 'PRD-MSG-$ts',
        name: 'Msg Product $ts',
        unit: 'Pcs',
        purchasePrice: 100.0,
        salesPrice: 150.0,
        taxRate: 18.0,
      );

      // Add
      final addOk = await controller.saveProduct(prod);
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Product added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdProd = controller.products.firstWhere((p) => p.productCode == prod.productCode);
      final editProd = createdProd.copyWith(name: 'Updated Msg Prod $ts');
      final editOk = await controller.saveProduct(editProd);
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Product updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deleteProduct(editProd);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Product deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Category Add, Edit, Delete
      final cat = CategoryModel(name: 'Category $ts');
      await controller.saveCategory(cat);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Category added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      final createdCat = controller.categories.firstWhere((c) => c.name == 'Category $ts');
      await controller.saveCategory(createdCat.copyWith(name: 'Updated Cat $ts'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Category updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      await controller.deleteCategory(createdCat.id!);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Category deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('5. Sales Orders: Add, Edit, Delete success snackbar messages', (tester) async {
      final custRepo = CustomerRepository();
      final prodRepo = ProductRepository();
      final custId = await custRepo.insertCustomer(CustomerModel(customerCode: 'C-SO-1', name: 'SO Cust'));
      final prodId = await prodRepo.insertProduct(ProductModel(productCode: 'P-SO-1', name: 'SO Prod', salesPrice: 100));

      final controller = SalesOrderController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Sales Orders Test')));
      await tester.pumpAndSettle();

      await controller.prepareNewOrderForm();
      controller.formOrderCustomer.value = await custRepo.getCustomerById(custId);
      controller.formOrderItems.add(SalesOrderItemModel(productId: prodId, productName: 'SO Prod', quantity: 2, rate: 100, total: 200));

      // Add
      final addOk = await controller.submitOrder();
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sales Order added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdOrder = controller.orders.first;
      await controller.prepareEditOrderForm(createdOrder);
      controller.formOrderNotes.value = 'Updated order notes';
      final editOk = await controller.submitOrder();
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sales Order updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deleteSalesOrder(createdOrder);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sales Order deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('6. Sales Invoices: Add, Edit, Cancel, Delete success snackbar messages', (tester) async {
      final custRepo = CustomerRepository();
      final prodRepo = ProductRepository();
      final custId = await custRepo.insertCustomer(CustomerModel(customerCode: 'C-SI-1', name: 'SI Cust'));
      final prodId = await prodRepo.insertProduct(ProductModel(productCode: 'P-SI-1', name: 'SI Prod', salesPrice: 100, stockQuantity: 50));

      final controller = SalesController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Sales Invoices Test')));
      await tester.pumpAndSettle();

      await controller.prepareNewInvoiceForm();
      controller.formSelectedCustomer.value = await custRepo.getCustomerById(custId);
      controller.addFormItem(await prodRepo.getProductById(prodId) as ProductModel, 2, 100, 0);

      // Add
      final addOk = await controller.submitInvoice();
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sales Invoice added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdInv = controller.invoices.first;
      await controller.loadInvoiceForEdit(createdInv);
      controller.formNotes.value = 'Updated invoice notes';
      final editOk = await controller.submitInvoice();
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sales Invoice updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Cancel
      await controller.cancelInvoice(createdInv.id!, 'Customer requested cancellation');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Invoice cancelled successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deleteInvoice(createdInv);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sales Invoice deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('7. Purchase Invoices: Add, Edit, Cancel, Delete success snackbar messages', (tester) async {
      final suppRepo = SupplierRepository();
      final prodRepo = ProductRepository();
      final suppId = await suppRepo.insertSupplier(SupplierModel(supplierCode: 'S-PI-1', name: 'PI Supp'));
      final prodId = await prodRepo.insertProduct(ProductModel(productCode: 'P-PI-1', name: 'PI Prod', purchasePrice: 50, stockQuantity: 10));

      final controller = PurchaseController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Purchase Invoices Test')));
      await tester.pumpAndSettle();

      await controller.prepareNewPurchaseForm();
      controller.formSelectedSupplier.value = await suppRepo.getSupplierById(suppId);
      controller.addFormItem(await prodRepo.getProductById(prodId) as ProductModel, 5, 50, 0);

      // Add
      final addOk = await controller.submitPurchase();
      expect(addOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Purchase Invoice added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Edit
      final createdBill = controller.purchases.first;
      await controller.loadPurchaseForEdit(createdBill);
      controller.formNotes.value = 'Updated bill notes';
      final editOk = await controller.submitPurchase();
      expect(editOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Purchase Invoice updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Cancel
      await controller.cancelPurchase(createdBill.id!, 'Defective materials');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Invoice cancelled successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Delete
      final delOk = await controller.deletePurchase(createdBill);
      expect(delOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Purchase Invoice deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('8. Receipts & Payments: Add, Edit, Delete success snackbar messages', (tester) async {
      final custRepo = CustomerRepository();
      final suppRepo = SupplierRepository();
      final accRepo = AccountRepository();
      final custId = await custRepo.insertCustomer(CustomerModel(customerCode: 'C-RCP-1', name: 'Rcp Cust'));
      final suppId = await suppRepo.insertSupplier(SupplierModel(supplierCode: 'S-PMT-1', name: 'Pmt Supp'));
      final cashAccount = (await accRepo.getAllAccounts()).firstWhere((a) => a.accountCode == AccountingConstants.codeCash);

      final rcpController = ReceiptController();
      Get.put(rcpController);

      await tester.pumpWidget(wrapWithApp(const Text('Receipts & Payments Test')));
      await tester.pumpAndSettle();

      // Receipt Add
      await rcpController.prepareNewReceiptForm();
      rcpController.formSelectedCustomer.value = await custRepo.getCustomerById(custId);
      rcpController.formSelectedAccount.value = cashAccount;
      rcpController.formAmount.value = 250.0;
      final addRcpOk = await rcpController.submitReceipt();
      expect(addRcpOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Receipt added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Receipt Edit
      final createdRcp = rcpController.receipts.first;
      await rcpController.prepareEditReceiptForm(createdRcp);
      rcpController.formAmount.value = 300.0;
      final editRcpOk = await rcpController.submitReceipt();
      expect(editRcpOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Receipt updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Receipt Delete
      final delRcpOk = await rcpController.deleteReceipt(createdRcp);
      expect(delRcpOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Receipt deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Payment Controller
      final pmtController = PaymentController();
      Get.put(pmtController);

      // Payment Add
      await pmtController.prepareNewPaymentForm();
      pmtController.formSelectedSupplier.value = await suppRepo.getSupplierById(suppId);
      pmtController.formSelectedAccount.value = cashAccount;
      pmtController.formAmount.value = 400.0;
      final addPmtOk = await pmtController.submitPayment();
      expect(addPmtOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Payment added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Payment Edit
      final createdPmt = pmtController.payments.first;
      await pmtController.prepareEditPaymentForm(createdPmt);
      pmtController.formAmount.value = 450.0;
      final editPmtOk = await pmtController.submitPayment();
      expect(editPmtOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Payment updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Payment Delete
      final delPmtOk = await pmtController.deletePayment(createdPmt);
      expect(delPmtOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Payment deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('9. Expenses & Journals: Add, Edit, Delete success snackbar messages', (tester) async {
      final accRepo = AccountRepository();
      final accounts = await accRepo.getAllAccounts();
      final expAccount = accounts.firstWhere((a) => a.accountType == AccountingConstants.typeExpense);
      final cashAccount = accounts.firstWhere((a) => a.accountCode == AccountingConstants.codeCash);
      final capitalAccount = accounts.firstWhere((a) => a.accountType == AccountingConstants.typeEquity);

      final expController = ExpenseController();
      Get.put(expController);

      await tester.pumpWidget(wrapWithApp(const Text('Expenses & Journals Test')));
      await tester.pumpAndSettle();

      // Expense Add
      await expController.prepareNewExpenseForm();
      expController.formSelectedExpenseAccount.value = expAccount;
      expController.formSelectedPaymentAccount.value = cashAccount;
      expController.formAmount.value = 120.0;
      expController.formDescription.value = 'Office Stationery';
      final addExpOk = await expController.submitExpense();
      expect(addExpOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Expense added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Expense Edit
      final createdExp = expController.expenses.first;
      await expController.prepareEditExpenseForm(createdExp);
      expController.formDescription.value = 'Office Stationery & Pens';
      final editExpOk = await expController.submitExpense();
      expect(editExpOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Expense updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Expense Delete
      final delExpOk = await expController.deleteExpense(createdExp);
      expect(delExpOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Expense deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Journal Controller
      final jnlController = JournalController();
      Get.put(jnlController);

      // Journal Add
      await jnlController.prepareNewJournalForm();
      jnlController.formDescription.value = 'Initial Capital Investment';
      jnlController.formLines[0].account = cashAccount;
      jnlController.formLines[0].debit = 1000.0;
      jnlController.formLines[0].credit = 0.0;
      jnlController.formLines[1].account = capitalAccount;
      jnlController.formLines[1].debit = 0.0;
      jnlController.formLines[1].credit = 1000.0;
      final addJnlOk = await jnlController.submitJournalEntry();
      expect(addJnlOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Journal added successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Journal Edit
      final createdJnl = jnlController.journalEntries.first;
      await jnlController.prepareEditJournalForm(createdJnl);
      jnlController.formDescription.value = 'Capital Investment Updated';
      final editJnlOk = await jnlController.submitJournalEntry();
      expect(editJnlOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Journal updated successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Journal Delete
      final delJnlOk = await jnlController.deleteJournal(createdJnl);
      expect(delJnlOk, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Journal deleted successfully'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('10. Validation failure: Shows error snackbar and NEVER displays success message', (tester) async {
      final controller = SalesController();
      Get.put(controller);

      await tester.pumpWidget(wrapWithApp(const Text('Validation Failure Test')));
      await tester.pumpAndSettle();

      // Submit without customer or items -> validation error
      final ok = await controller.submitInvoice();
      expect(ok, isFalse);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Sales Invoice added successfully'), findsNothing);
      expect(find.text('Please select a customer'), findsOneWidget);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });
  });
}
