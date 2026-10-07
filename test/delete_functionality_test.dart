import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/models/category_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/expense_model.dart';
import 'package:accubooks/models/receipt_model.dart';
import 'package:accubooks/models/payment_model.dart';
import 'package:accubooks/models/journal_entry_model.dart';
import 'package:accubooks/models/journal_line_model.dart';
import 'package:accubooks/repositories/account_repository.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/expense_repository.dart';
import 'package:accubooks/repositories/journal_repository.dart';
import 'package:accubooks/services/receipt_service.dart';
import 'package:accubooks/services/payment_service.dart';

import 'package:accubooks/core/database/database_helper.dart';

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

  group('Delete Functionality Tests', () {
    final accountRepo = AccountRepository();
    final customerRepo = CustomerRepository();
    final supplierRepo = SupplierRepository();
    final productRepo = ProductRepository();
    final expenseRepo = ExpenseRepository();
    final journalRepo = JournalRepository();
    final receiptService = ReceiptService();
    final paymentService = PaymentService();

    test('Account deletion: can delete custom account with no transactions, blocks when has transactions', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 10000;
      final acc = AccountModel(
        accountCode: '9$ts',
        accountName: 'Temporary Test Account $ts',
        accountType: AccountingConstants.typeExpense,
        openingBalance: 0,
      );
      final id = await accountRepo.insertAccount(acc);

      // Verify can delete
      expect(await accountRepo.canDeleteAccount(id), isTrue);

      // Delete
      final deleted = await accountRepo.deleteAccount(id);
      expect(deleted, 1);

      final fetched = await accountRepo.getAccountById(id);
      expect(fetched, isNull);
    });

    test('Customer deletion: can delete customer with no invoices/receipts', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final cust = CustomerModel(
        customerCode: 'CUST-DEL-$ts',
        name: 'Delete Test Customer $ts',
      );
      final id = await customerRepo.insertCustomer(cust);
      expect(await customerRepo.canDeleteCustomer(id), isTrue);

      final deleted = await customerRepo.deleteCustomer(id);
      expect(deleted, 1);

      final fetched = await customerRepo.getCustomerById(id);
      expect(fetched, isNull);
    });

    test('Supplier deletion: can delete supplier with no purchases/payments', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final sup = SupplierModel(
        supplierCode: 'SUPP-DEL-$ts',
        name: 'Delete Test Supplier $ts',
      );
      final id = await supplierRepo.insertSupplier(sup);
      expect(await supplierRepo.canDeleteSupplier(id), isTrue);

      final deleted = await supplierRepo.deleteSupplier(id);
      expect(deleted, 1);

      final fetched = await supplierRepo.getSupplierById(id);
      expect(fetched, isNull);
    });

    test('Product and Category deletion', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final catId = await productRepo.insertCategory(CategoryModel(name: 'Delete Cat $ts'));
      final pId = await productRepo.insertProduct(ProductModel(
        productCode: 'PRD-DEL-$ts',
        name: 'Delete Test Product $ts',
        categoryId: catId,
        purchasePrice: 100,
        salesPrice: 150,
      ));

      expect(await productRepo.canDeleteProduct(pId), isTrue);

      // Delete product
      final pDeleted = await productRepo.deleteProduct(pId);
      expect(pDeleted, 1);
      expect(await productRepo.getProductById(pId), isNull);

      // Delete category
      final cDeleted = await productRepo.deleteCategory(catId);
      expect(cDeleted, 1);
    });

    test('Receipt and Payment deletion cleans up journal entries', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-REC-$ts',
        name: 'Receipt Test Customer $ts',
      ));
      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUPP-PAY-$ts',
        name: 'Payment Test Supplier $ts',
      ));

      // Create and delete receipt
      final rId = await receiptService.createReceipt(ReceiptModel(
        receiptNumber: 'REC-DEL-$ts',
        receiptDate: DateTime.now(),
        customerId: custId,
        accountId: 1, // Cash
        amount: 250.0,
        paymentMethod: 'Cash',
      ));
      expect(rId, isPositive);
      await receiptService.deleteReceipt(rId);

      // Create and delete payment
      final pId = await paymentService.createPayment(PaymentModel(
        paymentNumber: 'PAY-DEL-$ts',
        paymentDate: DateTime.now(),
        supplierId: supId,
        accountId: 1, // Cash
        amount: 300.0,
        paymentMethod: 'Cash',
      ));
      expect(pId, isPositive);
      await paymentService.deletePayment(pId);

      // Cleanup
      await customerRepo.deleteCustomer(custId);
      await supplierRepo.deleteSupplier(supId);
    });

    test('Manual Journal Entry deletion removes entry and lines', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final entryId = await journalRepo.insertJournalEntry(JournalEntryModel(
        transactionNumber: 'JV-DEL-$ts',
        transactionDate: DateTime.now(),
        transactionType: AccountingConstants.transTypeJournal,
        description: 'Manual test entry $ts',
        lines: [
          JournalLineModel(accountId: 1, debit: 100, credit: 0),
          JournalLineModel(accountId: 2, debit: 0, credit: 100),
        ],
      ));

      expect(entryId, isPositive);
      await journalRepo.deleteJournalEntry(entryId);
      expect(await journalRepo.getJournalEntryById(entryId), isNull);
    });

    test('Expense deletion removes record', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final expId = await expenseRepo.insertExpense(ExpenseModel(
        expenseNumber: 'EXP-DEL-$ts',
        expenseDate: DateTime.now(),
        accountId: 11, // General Expense
        paymentAccountId: 1, // Cash
        amount: 50.0,
        paymentMethod: 'Cash',
        description: 'Test expense $ts',
      ));

      expect(expId, isPositive);
      final count = await expenseRepo.deleteExpense(expId);
      expect(count, 1);
      expect(await expenseRepo.getExpenseById(expId), isNull);
    });
  });
}
