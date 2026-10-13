import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/utils/sequence_utils.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/sales_order_model.dart';
import 'package:accubooks/models/sales_invoice_model.dart';
import 'package:accubooks/models/sales_return_model.dart';
import 'package:accubooks/models/purchase_order_model.dart';
import 'package:accubooks/models/purchase_invoice_model.dart';
import 'package:accubooks/models/purchase_return_model.dart';
import 'package:accubooks/models/receipt_model.dart';
import 'package:accubooks/models/payment_model.dart';
import 'package:accubooks/models/expense_model.dart';
import 'package:accubooks/models/journal_entry_model.dart';
import 'package:accubooks/models/journal_line_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/sales_order_repository.dart';
import 'package:accubooks/repositories/sales_repository.dart';
import 'package:accubooks/repositories/purchase_order_repository.dart';
import 'package:accubooks/repositories/purchase_repository.dart';
import 'package:accubooks/repositories/receipt_repository.dart';
import 'package:accubooks/repositories/payment_repository.dart';
import 'package:accubooks/repositories/expense_repository.dart';
import 'package:accubooks/repositories/journal_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseHelper dbHelper;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('accubooks_seq_test_');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    DatabaseHelper.initializeFfi();
    dbHelper = DatabaseHelper();
    await dbHelper.setActiveUser(999);
    // Force open database and ensure schema is created
    await dbHelper.database;
  });

  tearDownAll(() async {
    await dbHelper.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SequenceUtils.clearReservedForTesting();
  });

  group('Module 1: Supplier Code', () {
    final repo = SupplierRepository();

    test('Auto-generates sequential codes, rejects duplicates, preserves on edit, reserves on delete', () async {
      final code1 = await repo.getNextSupplierCode();
      expect(code1, startsWith('SUP-'));
      expect(code1.length, 7); // SUP-001

      final s1 = SupplierModel(supplierCode: code1, name: 'Supplier One');
      final id1 = await repo.insertSupplier(s1);

      final code2 = await repo.getNextSupplierCode();
      expect(code2, isNot(equals(code1)));
      expect(code2, 'SUP-002');

      // Duplicate rejection for new record
      expect(() async => await repo.insertSupplier(SupplierModel(supplierCode: code1, name: 'Duplicate Sup')),
          throwsA(isA<Exception>()));

      // Editing with same code succeeds
      final currentS1 = (await repo.getSupplierById(id1))!;
      await repo.updateSupplier(currentS1.copyWith(name: 'Supplier One Renamed'));
      final updatedS1 = (await repo.getSupplierById(id1))!;
      expect(updatedS1.supplierCode, code1);
      expect(updatedS1.name, 'Supplier One Renamed');

      // Insert s2
      final s2 = SupplierModel(supplierCode: code2, name: 'Supplier Two');
      final id2 = await repo.insertSupplier(s2);

      // Editing s2 to use s1 code is rejected
      expect(() async => await repo.updateSupplier(s2.copyWith(id: id2, supplierCode: code1)),
          throwsA(isA<Exception>()));

      // Delete s2 reserves its code
      await repo.deleteSupplier(id2);
      final codeAfterDelete = await repo.getNextSupplierCode();
      expect(codeAfterDelete, 'SUP-003'); // Does not reuse SUP-002
    });
  });

  group('Module 2: Product Code', () {
    final repo = ProductRepository();

    test('Auto-generates sequential codes, rejects duplicates, preserves on edit, reserves on delete', () async {
      final code1 = await repo.getNextProductCode();
      expect(code1, startsWith('PRD-'));
      expect(code1.length, 7); // PRD-001

      final p1 = ProductModel(productCode: code1, name: 'Product One', salesPrice: 100);
      final id1 = await repo.insertProduct(p1);

      final code2 = await repo.getNextProductCode();
      expect(code2, 'PRD-002');

      // Duplicate rejection
      expect(() async => await repo.insertProduct(ProductModel(productCode: code1, name: 'Duplicate Prod', salesPrice: 50)),
          throwsA(isA<Exception>()));

      // Editing with same code succeeds
      final currentP1 = (await repo.getProductById(id1))!;
      await repo.updateProduct(currentP1.copyWith(name: 'Product One Renamed'));
      final updatedP1 = (await repo.getProductById(id1))!;
      expect(updatedP1.productCode, code1);
      expect(updatedP1.name, 'Product One Renamed');

      // Insert p2
      final p2 = ProductModel(productCode: code2, name: 'Product Two', salesPrice: 200);
      final id2 = await repo.insertProduct(p2);

      // Editing p2 to use p1 code is rejected
      expect(() async => await repo.updateProduct(p2.copyWith(id: id2, productCode: code1)),
          throwsA(isA<Exception>()));

      // Delete p2 reserves its code
      await repo.deleteProduct(id2);
      final codeAfterDelete = await repo.getNextProductCode();
      expect(codeAfterDelete, 'PRD-003');
    });
  });

  group('Module 13: Customer Code (Verification)', () {
    final repo = CustomerRepository();

    test('Auto-generates sequential codes, rejects duplicates, preserves on edit, reserves on delete', () async {
      final code1 = await repo.getNextCustomerCode();
      expect(code1, startsWith('CUST-'));
      expect(code1.length, 8); // CUST-001

      final c1 = CustomerModel(customerCode: code1, name: 'Customer One');
      final id1 = await repo.insertCustomer(c1);

      final code2 = await repo.getNextCustomerCode();
      expect(code2, 'CUST-002');

      // Duplicate rejection
      expect(() async => await repo.insertCustomer(CustomerModel(customerCode: code1, name: 'Duplicate Cust')),
          throwsA(isA<Exception>()));

      // Editing with same code succeeds
      final currentC1 = (await repo.getCustomerById(id1))!;
      await repo.updateCustomer(currentC1.copyWith(name: 'Customer One Renamed'));
      final updatedC1 = (await repo.getCustomerById(id1))!;
      expect(updatedC1.customerCode, code1);
      expect(updatedC1.name, 'Customer One Renamed');

      // Insert c2
      final c2 = CustomerModel(customerCode: code2, name: 'Customer Two');
      final id2 = await repo.insertCustomer(c2);

      // Editing c2 to use c1 code is rejected
      expect(() async => await repo.updateCustomer(c2.copyWith(id: id2, customerCode: code1)),
          throwsA(isA<Exception>()));

      // Delete c2 reserves its code
      await repo.deleteCustomer(id2);
      final codeAfterDelete = await repo.getNextCustomerCode();
      expect(codeAfterDelete, 'CUST-003');
    });
  });

  group('Module 3: Sales Order Number', () {
    final repo = SalesOrderRepository();

    test('Auto-generates sequential order numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextOrderNumber();
      expect(num1, startsWith('SO-'));
      expect(num1.length, 9); // SO-000001

      final so1 = SalesOrderModel(
        orderNumber: num1,
        orderDate: DateTime.now(),
        customerId: 1,
        subtotal: 500,
        taxAmount: 0.0,
        grandTotal: 500,
      );
      final id1 = await repo.insertSalesOrder(so1);

      final num2 = await repo.getNextOrderNumber();
      expect(num2, 'SO-000002');

      // Duplicate rejection
      expect(() async => await repo.insertSalesOrder(so1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentSo1 = (await repo.getSalesOrderById(id1))!;
      await repo.updateSalesOrder(currentSo1.copyWith(notes: 'Updated notes'));
      final updatedSo1 = (await repo.getSalesOrderById(id1))!;
      expect(updatedSo1.orderNumber, num1);
      expect(updatedSo1.notes, 'Updated notes');

      // Insert so2
      final so2 = SalesOrderModel(
        orderNumber: num2,
        orderDate: DateTime.now(),
        customerId: 1,
        subtotal: 750,
        taxAmount: 0.0,
        grandTotal: 750,
      );
      final id2 = await repo.insertSalesOrder(so2);

      // Editing so2 to use so1 number is rejected
      expect(() async => await repo.updateSalesOrder(so2.copyWith(id: id2, orderNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete so2 reserves its number
      await repo.deleteSalesOrder(id2);
      final numAfterDelete = await repo.getNextOrderNumber();
      expect(numAfterDelete, 'SO-000003');
    });
  });

  group('Module 4: Sales Invoice Number', () {
    final repo = SalesRepository();

    test('Auto-generates sequential invoice numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextInvoiceNumber();
      expect(num1, startsWith('INV-'));
      expect(num1.length, 10); // INV-000001

      final inv1 = SalesInvoiceModel(
        invoiceNumber: num1,
        invoiceDate: DateTime.now(),
        customerId: 1,
        subtotal: 1000,
        taxAmount: 0.0,
        grandTotal: 1000,
      );
      final id1 = await repo.insertSalesInvoice(inv1);

      final num2 = await repo.getNextInvoiceNumber();
      expect(num2, 'INV-000002');

      // Duplicate rejection
      expect(() async => await repo.insertSalesInvoice(inv1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentInv1 = (await repo.getSalesInvoiceById(id1))!;
      await repo.updateSalesInvoice(currentInv1.copyWith(notes: 'Invoice updated'));
      final updatedInv1 = (await repo.getSalesInvoiceById(id1))!;
      expect(updatedInv1.invoiceNumber, num1);
      expect(updatedInv1.notes, 'Invoice updated');

      // Insert inv2
      final inv2 = SalesInvoiceModel(
        invoiceNumber: num2,
        invoiceDate: DateTime.now(),
        customerId: 1,
        subtotal: 1200,
        taxAmount: 0.0,
        grandTotal: 1200,
      );
      final id2 = await repo.insertSalesInvoice(inv2);

      // Editing inv2 to use inv1 number is rejected
      expect(() async => await repo.updateSalesInvoice(inv2.copyWith(id: id2, invoiceNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete inv2 reserves its number
      await repo.deleteSalesInvoice(id2);
      final numAfterDelete = await repo.getNextInvoiceNumber();
      expect(numAfterDelete, 'INV-000003');
    });
  });

  group('Module 5: Sales Return Number', () {
    final repo = SalesOrderRepository();

    test('Auto-generates sequential return numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextReturnNumber();
      expect(num1, startsWith('SR-'));
      expect(num1.length, 9); // SR-000001

      final sr1 = SalesReturnModel(
        returnNumber: num1,
        returnDate: DateTime.now(),
        customerId: 1,
        subtotal: 200,
        taxAmount: 0.0,
        grandTotal: 200,
      );
      final id1 = await repo.insertSalesReturn(sr1);

      final num2 = await repo.getNextReturnNumber();
      expect(num2, 'SR-000002');

      // Duplicate rejection
      expect(() async => await repo.insertSalesReturn(sr1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentSr1 = (await repo.getSalesReturnById(id1))!;
      await repo.updateSalesReturn(currentSr1.copyWith(reason: 'Defective item'));
      final updatedSr1 = (await repo.getSalesReturnById(id1))!;
      expect(updatedSr1.returnNumber, num1);
      expect(updatedSr1.reason, 'Defective item');

      // Insert sr2
      final sr2 = SalesReturnModel(
        returnNumber: num2,
        returnDate: DateTime.now(),
        customerId: 1,
        subtotal: 300,
        taxAmount: 0.0,
        grandTotal: 300,
      );
      final id2 = await repo.insertSalesReturn(sr2);

      // Editing sr2 to use sr1 number is rejected
      expect(() async => await repo.updateSalesReturn(sr2.copyWith(id: id2, returnNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete sr2 reserves its number
      await repo.deleteSalesReturn(id2);
      final numAfterDelete = await repo.getNextReturnNumber();
      expect(numAfterDelete, 'SR-000003');
    });
  });

  group('Module 6: Purchase Order Number', () {
    final repo = PurchaseOrderRepository();

    test('Auto-generates sequential order numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextOrderNumber();
      expect(num1, startsWith('PO-'));
      expect(num1.length, 9); // PO-000001

      final po1 = PurchaseOrderModel(
        orderNumber: num1,
        orderDate: DateTime.now(),
        supplierId: 1,
        subtotal: 600,
        taxAmount: 0.0,
        grandTotal: 600,
      );
      final id1 = await repo.insertPurchaseOrder(po1);

      final num2 = await repo.getNextOrderNumber();
      expect(num2, 'PO-000002');

      // Duplicate rejection
      expect(() async => await repo.insertPurchaseOrder(po1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentPo1 = (await repo.getPurchaseOrderById(id1))!;
      await repo.updatePurchaseOrder(currentPo1.copyWith(notes: 'Updated PO notes'));
      final updatedPo1 = (await repo.getPurchaseOrderById(id1))!;
      expect(updatedPo1.orderNumber, num1);
      expect(updatedPo1.notes, 'Updated PO notes');

      // Insert po2
      final po2 = PurchaseOrderModel(
        orderNumber: num2,
        orderDate: DateTime.now(),
        supplierId: 1,
        subtotal: 800,
        taxAmount: 0.0,
        grandTotal: 800,
      );
      final id2 = await repo.insertPurchaseOrder(po2);

      // Editing po2 to use po1 number is rejected
      expect(() async => await repo.updatePurchaseOrder(po2.copyWith(id: id2, orderNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete po2 reserves its number
      await repo.deletePurchaseOrder(id2);
      final numAfterDelete = await repo.getNextOrderNumber();
      expect(numAfterDelete, 'PO-000003');
    });
  });

  group('Module 7: Purchase Bill / Purchase Invoice Number', () {
    final repo = PurchaseRepository();

    test('Auto-generates sequential invoice numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextPurchaseNumber();
      expect(num1, startsWith('PUR-'));
      expect(num1.length, 10); // PUR-000001

      final pi1 = PurchaseInvoiceModel(
        invoiceNumber: num1,
        invoiceDate: DateTime.now(),
        supplierId: 1,
        subtotal: 1500,
        taxAmount: 0.0,
        grandTotal: 1500,
      );
      final id1 = await repo.insertPurchaseInvoice(pi1);

      final num2 = await repo.getNextPurchaseNumber();
      expect(num2, 'PUR-000002');

      // Duplicate rejection
      expect(() async => await repo.insertPurchaseInvoice(pi1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentPi1 = (await repo.getPurchaseInvoiceById(id1))!;
      await repo.updatePurchaseInvoice(currentPi1.copyWith(notes: 'Updated PUR notes'));
      final updatedPi1 = (await repo.getPurchaseInvoiceById(id1))!;
      expect(updatedPi1.invoiceNumber, num1);
      expect(updatedPi1.notes, 'Updated PUR notes');

      // Insert pi2
      final pi2 = PurchaseInvoiceModel(
        invoiceNumber: num2,
        invoiceDate: DateTime.now(),
        supplierId: 1,
        subtotal: 2500,
        taxAmount: 0.0,
        grandTotal: 2500,
      );
      final id2 = await repo.insertPurchaseInvoice(pi2);

      // Editing pi2 to use pi1 number is rejected
      expect(() async => await repo.updatePurchaseInvoice(pi2.copyWith(id: id2, invoiceNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete pi2 reserves its number
      await repo.deletePurchaseInvoice(id2);
      final numAfterDelete = await repo.getNextPurchaseNumber();
      expect(numAfterDelete, 'PUR-000003');
    });
  });

  group('Module 8: Purchase Return Number', () {
    final repo = PurchaseOrderRepository();

    test('Auto-generates sequential return numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextReturnNumber();
      expect(num1, startsWith('PR-'));
      expect(num1.length, 9); // PR-000001

      final pr1 = PurchaseReturnModel(
        returnNumber: num1,
        returnDate: DateTime.now(),
        supplierId: 1,
        subtotal: 250,
        taxAmount: 0.0,
        grandTotal: 250,
      );
      final id1 = await repo.insertPurchaseReturn(pr1);

      final num2 = await repo.getNextReturnNumber();
      expect(num2, 'PR-000002');

      // Duplicate rejection
      expect(() async => await repo.insertPurchaseReturn(pr1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentPr1 = (await repo.getPurchaseReturnById(id1))!;
      await repo.updatePurchaseReturn(currentPr1.copyWith(reason: 'Damaged packaging'));
      final updatedPr1 = (await repo.getPurchaseReturnById(id1))!;
      expect(updatedPr1.returnNumber, num1);
      expect(updatedPr1.reason, 'Damaged packaging');

      // Insert pr2
      final pr2 = PurchaseReturnModel(
        returnNumber: num2,
        returnDate: DateTime.now(),
        supplierId: 1,
        subtotal: 350,
        taxAmount: 0.0,
        grandTotal: 350,
      );
      final id2 = await repo.insertPurchaseReturn(pr2);

      // Editing pr2 to use pr1 number is rejected
      expect(() async => await repo.updatePurchaseReturn(pr2.copyWith(id: id2, returnNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete pr2 reserves its number
      await repo.deletePurchaseReturn(id2);
      final numAfterDelete = await repo.getNextReturnNumber();
      expect(numAfterDelete, 'PR-000003');
    });
  });

  group('Module 9: Receipt Number', () {
    final repo = ReceiptRepository();

    test('Auto-generates sequential receipt numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextReceiptNumber();
      expect(num1, startsWith('REC-'));
      expect(num1.length, 10); // REC-000001

      final r1 = ReceiptModel(
        receiptNumber: num1,
        receiptDate: DateTime.now(),
        customerId: 1,
        accountId: 1,
        amount: 500,
        paymentMethod: 'Cash',
      );
      final id1 = await repo.insertReceipt(r1);

      final num2 = await repo.getNextReceiptNumber();
      expect(num2, 'REC-000002');

      // Duplicate rejection
      expect(() async => await repo.insertReceipt(r1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentR1 = (await repo.getReceiptById(id1))!;
      await repo.updateReceipt(currentR1.copyWith(reference: 'REF-123'));
      final updatedR1 = (await repo.getReceiptById(id1))!;
      expect(updatedR1.receiptNumber, num1);
      expect(updatedR1.reference, 'REF-123');

      // Insert r2
      final r2 = ReceiptModel(
        receiptNumber: num2,
        receiptDate: DateTime.now(),
        customerId: 1,
        accountId: 1,
        amount: 800,
        paymentMethod: 'Bank Transfer',
      );
      final id2 = await repo.insertReceipt(r2);

      // Editing r2 to use r1 number is rejected
      expect(() async => await repo.updateReceipt(r2.copyWith(id: id2, receiptNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete r2 reserves its number
      await repo.deleteReceipt(id2);
      final numAfterDelete = await repo.getNextReceiptNumber();
      expect(numAfterDelete, 'REC-000003');
    });
  });

  group('Module 10: Payment Number', () {
    final repo = PaymentRepository();

    test('Auto-generates sequential payment numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextPaymentNumber();
      expect(num1, startsWith('PAY-'));
      expect(num1.length, 10); // PAY-000001

      final p1 = PaymentModel(
        paymentNumber: num1,
        paymentDate: DateTime.now(),
        supplierId: 1,
        accountId: 1,
        amount: 400,
        paymentMethod: 'Cash',
      );
      final id1 = await repo.insertPayment(p1);

      final num2 = await repo.getNextPaymentNumber();
      expect(num2, 'PAY-000002');

      // Duplicate rejection
      expect(() async => await repo.insertPayment(p1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentP1 = (await repo.getPaymentById(id1))!;
      await repo.updatePayment(currentP1.copyWith(reference: 'CHQ-999'));
      final updatedP1 = (await repo.getPaymentById(id1))!;
      expect(updatedP1.paymentNumber, num1);
      expect(updatedP1.reference, 'CHQ-999');

      // Insert p2
      final p2 = PaymentModel(
        paymentNumber: num2,
        paymentDate: DateTime.now(),
        supplierId: 1,
        accountId: 1,
        amount: 600,
        paymentMethod: 'Bank Transfer',
      );
      final id2 = await repo.insertPayment(p2);

      // Editing p2 to use p1 number is rejected
      expect(() async => await repo.updatePayment(p2.copyWith(id: id2, paymentNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete p2 reserves its number
      await repo.deletePayment(id2);
      final numAfterDelete = await repo.getNextPaymentNumber();
      expect(numAfterDelete, 'PAY-000003');
    });
  });

  group('Module 11: Expense Number', () {
    final repo = ExpenseRepository();

    test('Auto-generates sequential expense numbers, rejects duplicates, preserves on edit, reserves on delete', () async {
      final num1 = await repo.getNextExpenseNumber();
      expect(num1, startsWith('EXP-'));
      expect(num1.length, 10); // EXP-000001

      final e1 = ExpenseModel(
        expenseNumber: num1,
        expenseDate: DateTime.now(),
        accountId: 1,
        paymentAccountId: 1,
        amount: 150,
        paymentMethod: 'Cash',
      );
      final id1 = await repo.insertExpense(e1);

      final num2 = await repo.getNextExpenseNumber();
      expect(num2, 'EXP-000002');

      // Duplicate rejection
      expect(() async => await repo.insertExpense(e1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentE1 = (await repo.getExpenseById(id1))!;
      await repo.updateExpense(currentE1.copyWith(description: 'Office tea and coffee'));
      final updatedE1 = (await repo.getExpenseById(id1))!;
      expect(updatedE1.expenseNumber, num1);
      expect(updatedE1.description, 'Office tea and coffee');

      // Insert e2
      final e2 = ExpenseModel(
        expenseNumber: num2,
        expenseDate: DateTime.now(),
        accountId: 1,
        paymentAccountId: 1,
        amount: 250,
        paymentMethod: 'Cash',
      );
      final id2 = await repo.insertExpense(e2);

      // Editing e2 to use e1 number is rejected
      expect(() async => await repo.updateExpense(e2.copyWith(id: id2, expenseNumber: num1)),
          throwsA(isA<Exception>()));

      // Delete e2 reserves its number
      await repo.deleteExpense(id2);
      final numAfterDelete = await repo.getNextExpenseNumber();
      expect(numAfterDelete, 'EXP-000003');
    });
  });

  group('Module 12: Voucher Number (Journal Entry)', () {
    final repo = JournalRepository();

    test('Auto-generates sequential voucher numbers without being inflated by internal system entries', () async {
      final num1 = await repo.getNextJournalNumber();
      expect(num1, startsWith('JV-'));
      expect(num1.length, 9); // JV-000001

      final jv1 = JournalEntryModel(
        transactionNumber: num1,
        transactionDate: DateTime.now(),
        transactionType: AccountingConstants.transTypeJournal,
        description: 'Opening adjustment',
        lines: [
          JournalLineModel(accountId: 1, debit: 100, credit: 0),
          JournalLineModel(accountId: 2, debit: 0, credit: 100),
        ],
      );
      final id1 = await repo.insertJournalEntry(jv1);

      // Insert a foreign/system journal entry like JV-SALES-500
      final systemEntry = JournalEntryModel(
        transactionNumber: 'JV-SALES-500',
        transactionDate: DateTime.now(),
        transactionType: AccountingConstants.transTypeSales,
        description: 'Auto sales journal',
        lines: [
          JournalLineModel(accountId: 1, debit: 500, credit: 0),
          JournalLineModel(accountId: 2, debit: 0, credit: 500),
        ],
      );
      await repo.insertJournalEntry(systemEntry);

      // Manual sequence should be JV-000002, NOT inflated by JV-SALES-500
      final num2 = await repo.getNextJournalNumber();
      expect(num2, 'JV-000002');

      // Duplicate rejection
      expect(() async => await repo.insertJournalEntry(jv1), throwsA(isA<Exception>()));

      // Editing with same number succeeds
      final currentJv1 = (await repo.getJournalEntryById(id1))!;
      await repo.updateJournalEntry(
        currentJv1.copyWith(description: 'Updated adjustment note'),
        currentJv1.lines,
      );
      final updatedJv1 = (await repo.getJournalEntryById(id1))!;
      expect(updatedJv1.transactionNumber, num1);
      expect(updatedJv1.description, 'Updated adjustment note');

      // Insert jv2
      final jv2 = JournalEntryModel(
        transactionNumber: num2,
        transactionDate: DateTime.now(),
        transactionType: AccountingConstants.transTypeJournal,
        description: 'Second manual voucher',
        lines: [
          JournalLineModel(accountId: 1, debit: 200, credit: 0),
          JournalLineModel(accountId: 2, debit: 0, credit: 200),
        ],
      );
      final id2 = await repo.insertJournalEntry(jv2);

      // Editing jv2 to use jv1 number is rejected
      expect(
        () async => await repo.updateJournalEntry(
          jv2.copyWith(id: id2, transactionNumber: num1),
          jv2.lines,
        ),
        throwsA(isA<Exception>()),
      );

      // Delete jv2 reserves its number
      await repo.deleteJournalEntry(id2);
      final numAfterDelete = await repo.getNextJournalNumber();
      expect(numAfterDelete, 'JV-000003');
    });
  });
}
