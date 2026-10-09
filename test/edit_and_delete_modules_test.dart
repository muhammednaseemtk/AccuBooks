import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/utils/currency_utils.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/models/category_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/sales_order_model.dart';
import 'package:accubooks/models/sales_order_item_model.dart';
import 'package:accubooks/models/sales_invoice_model.dart';
import 'package:accubooks/models/sales_invoice_item_model.dart';
import 'package:accubooks/models/sales_return_model.dart';
import 'package:accubooks/models/sales_return_item_model.dart';
import 'package:accubooks/models/purchase_order_model.dart';
import 'package:accubooks/models/purchase_order_item_model.dart';
import 'package:accubooks/models/purchase_invoice_model.dart';
import 'package:accubooks/models/purchase_invoice_item_model.dart';
import 'package:accubooks/models/purchase_return_model.dart';
import 'package:accubooks/models/purchase_return_item_model.dart';
import 'package:accubooks/models/receipt_model.dart';
import 'package:accubooks/models/payment_model.dart';
import 'package:accubooks/models/expense_model.dart';
import 'package:accubooks/models/journal_entry_model.dart';
import 'package:accubooks/models/journal_line_model.dart';
import 'package:accubooks/repositories/account_repository.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/sales_order_repository.dart';
import 'package:accubooks/repositories/purchase_order_repository.dart';
import 'package:accubooks/repositories/sales_repository.dart';
import 'package:accubooks/repositories/purchase_repository.dart';
import 'package:accubooks/repositories/receipt_repository.dart';
import 'package:accubooks/repositories/payment_repository.dart';
import 'package:accubooks/repositories/expense_repository.dart';
import 'package:accubooks/repositories/journal_repository.dart';
import 'package:accubooks/services/sales_service.dart';
import 'package:accubooks/services/sales_order_service.dart';
import 'package:accubooks/services/purchase_service.dart';
import 'package:accubooks/services/purchase_order_service.dart';
import 'package:accubooks/services/receipt_service.dart';
import 'package:accubooks/services/payment_service.dart';

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

  group('AccuBooks Comprehensive Edit and Delete Across All Modules', () {
    final accountRepo = AccountRepository();
    final customerRepo = CustomerRepository();
    final supplierRepo = SupplierRepository();
    final productRepo = ProductRepository();
    final salesRepo = SalesRepository();
    final salesService = SalesService();
    final salesOrderRepo = SalesOrderRepository();
    final salesOrderService = SalesOrderService();
    final purchaseRepo = PurchaseRepository();
    final purchaseService = PurchaseService();
    final purchaseOrderRepo = PurchaseOrderRepository();
    final purchaseOrderService = PurchaseOrderService();
    final receiptRepo = ReceiptRepository();
    final receiptService = ReceiptService();
    final paymentRepo = PaymentRepository();
    final paymentService = PaymentService();
    final expenseRepo = ExpenseRepository();
    final journalRepo = JournalRepository();

    test('1. Accounts: edit preserves properties & delete safely checks usage', () async {
      final code = '88${DateTime.now().microsecondsSinceEpoch % 1000}';
      final acc = AccountModel(
        accountCode: code,
        accountName: 'Audit Test Account',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 500.0,
        openingBalanceType: AccountingConstants.balanceDebit,
        isSystemAccount: false,
      );
      final id = await accountRepo.insertAccount(acc);
      expect(id, greaterThan(0));

      // Edit account
      final created = await accountRepo.getAccountById(id);
      expect(created, isNotNull);
      final updated = created!.copyWith(
        accountName: 'Audit Test Account - Renamed',
      );
      await accountRepo.updateAccount(updated);

      final reloaded = await accountRepo.getAccountById(id);
      expect(reloaded!.accountName, 'Audit Test Account - Renamed');
      expect(reloaded.openingBalance, 500.0);
      expect(reloaded.accountCode, code);

      // Safe Delete check: accounts with active transactions/opening balance journals cannot be deleted
      final canDeleteWithOB = await accountRepo.canDeleteAccount(id);
      expect(canDeleteWithOB, isFalse);

      // An unused account without transactions or opening balance can be safely deleted
      final code2 = '89${DateTime.now().microsecondsSinceEpoch % 1000}';
      final acc2 = AccountModel(
        accountCode: code2,
        accountName: 'Audit Test Account Unused',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 0.0,
        openingBalanceType: AccountingConstants.balanceDebit,
        isSystemAccount: false,
      );
      final id2 = await accountRepo.insertAccount(acc2);
      expect(await accountRepo.canDeleteAccount(id2), isTrue);
      await accountRepo.deleteAccount(id2);
      expect(await accountRepo.getAccountById(id2), isNull);
    });

    test('2. Customers: edit preserves credit limit and account; delete check works', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final cust = CustomerModel(
        customerCode: 'CUST-ED-$ts',
        name: 'Editable Customer',
        phone: '9988776655',
        creditLimit: 25000.0,
        address: '123 Test Street',
      );
      final id = await customerRepo.insertCustomer(cust);
      expect(id, greaterThan(0));

      final created = await customerRepo.getCustomerById(id);
      final edited = created!.copyWith(
        name: 'Edited Customer Name',
        email: 'customer@example.com',
      );
      await customerRepo.updateCustomer(edited);

      final reloaded = await customerRepo.getCustomerById(id);
      expect(reloaded!.name, 'Edited Customer Name');
      expect(reloaded.creditLimit, 25000.0);
      expect(reloaded.email, 'customer@example.com');

      final canDel = await customerRepo.canDeleteCustomer(id);
      expect(canDel, isTrue);
      await customerRepo.deleteCustomer(id);
      expect(await customerRepo.getCustomerById(id), isNull);
    });

    test('3. Suppliers: edit preserves credit limit and account; delete check works', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final sup = SupplierModel(
        supplierCode: 'SUPP-ED-$ts',
        name: 'Editable Supplier',
        phone: '9988776644',
        creditLimit: 50000.0,
        address: '456 Supplier Street',
      );
      final id = await supplierRepo.insertSupplier(sup);
      expect(id, greaterThan(0));

      final created = await supplierRepo.getSupplierById(id);
      final edited = created!.copyWith(
        name: 'Edited Supplier Name',
        taxNumber: 'GSTIN123456789',
      );
      await supplierRepo.updateSupplier(edited);

      final reloaded = await supplierRepo.getSupplierById(id);
      expect(reloaded!.name, 'Edited Supplier Name');
      expect(reloaded.creditLimit, 50000.0);
      expect(reloaded.taxNumber, 'GSTIN123456789');

      final canDel = await supplierRepo.canDeleteSupplier(id);
      expect(canDel, isTrue);
      await supplierRepo.deleteSupplier(id);
      expect(await supplierRepo.getSupplierById(id), isNull);
    });

    test('4. Products and Categories: edit and safe deletion across all item tables', () async {
      final cat = CategoryModel(name: 'Test Category ${DateTime.now().microsecondsSinceEpoch}');
      final catId = await productRepo.insertCategory(cat);
      expect(catId, greaterThan(0));

      final prod = ProductModel(
        productCode: 'TP-${DateTime.now().microsecondsSinceEpoch % 10000}',
        name: 'Test Product',
        categoryId: catId,
        salesPrice: 150.0,
        purchasePrice: 100.0,
        stockQuantity: 20.0,
        minimumStock: 5.0,
      );
      final prodId = await productRepo.insertProduct(prod);
      expect(prodId, greaterThan(0));

      // Edit product
      final loadedProd = await productRepo.getProductById(prodId);
      final editedProd = loadedProd!.copyWith(
        name: 'Updated Test Product',
        salesPrice: 175.0,
      );
      await productRepo.updateProduct(editedProd);

      final reloadedProd = await productRepo.getProductById(prodId);
      expect(reloadedProd!.name, 'Updated Test Product');
      expect(reloadedProd.salesPrice, 175.0);
      expect(reloadedProd.purchasePrice, 100.0);
      expect(reloadedProd.stockQuantity, 20.0);

      // Verify product deletion permitted when unused
      expect(await productRepo.canDeleteProduct(prodId), isTrue);
      await productRepo.deleteProduct(prodId);
      expect(await productRepo.getProductById(prodId), isNull);

      // Verify category deletion
      final delCatCount = await productRepo.deleteCategory(catId);
      expect(delCatCount, 1);
      final allCats = await productRepo.getAllCategories();
      expect(allCats.any((c) => c.id == catId), isFalse);
    });

    test('5. Sales Orders: edit items/totals and delete order', () async {
      final customers = await customerRepo.getAllCustomers();
      final products = await productRepo.getAllProducts();
      final cust = customers.first;
      final prod = products.first;

      final orderNumber = await salesOrderRepo.getNextOrderNumber();
      final order = SalesOrderModel(
        orderNumber: orderNumber,
        orderDate: DateTime.now(),
        customerId: cust.id!,
        status: AccountingConstants.statusPending,
        subtotal: 200.0,
        taxAmount: 0.0,
        grandTotal: 200.0,
      );
      final items = <SalesOrderItemModel>[
        SalesOrderItemModel(
          productId: prod.id!,
          quantity: 2,
          rate: 100.0,
          total: 200.0,
        ),
      ];

      final orderId = await salesOrderService.createSalesOrder(order: order, items: items);
      expect(orderId, greaterThan(0));

      // Edit sales order
      final loadedOrder = await salesOrderRepo.getSalesOrderById(orderId);
      final updatedOrder = loadedOrder!.copyWith(
        subtotal: 500.0,
        grandTotal: 500.0,
        notes: 'Updated notes',
      );
      final updatedItems = <SalesOrderItemModel>[
        SalesOrderItemModel(
          productId: prod.id!,
          quantity: 5,
          rate: 100.0,
          total: 500.0,
        ),
      ];

      await salesOrderService.updateSalesOrder(order: updatedOrder, items: updatedItems);
      final reloaded = await salesOrderRepo.getSalesOrderById(orderId);
      expect(reloaded!.grandTotal, 500.0);
      expect(reloaded.notes, 'Updated notes');
      expect(reloaded.items.first.quantity, 5);

      // Delete sales order
      await salesOrderService.deleteSalesOrder(orderId);
      expect(await salesOrderRepo.getSalesOrderById(orderId), isNull);
    });

    test('6. Sales Invoices: edit recalculates stock delta & updates balanced journal entry', () async {
      final customers = await customerRepo.getAllCustomers();
      final products = await productRepo.getAllProducts();
      final cust = customers.first;
      final prod = products.first;

      final initialStock = (await productRepo.getProductById(prod.id!))!.stockQuantity;

      final invNumber = await salesRepo.getNextInvoiceNumber();
      final inv = SalesInvoiceModel(
        invoiceNumber: invNumber,
        invoiceDate: DateTime.now(),
        customerId: cust.id!,
        paymentStatus: AccountingConstants.paymentUnpaid,
        subtotal: 200.0,
        taxAmount: 0.0,
        grandTotal: 200.0,
      );
      final items = <SalesInvoiceItemModel>[
        SalesInvoiceItemModel(
          productId: prod.id!,
          quantity: 2,
          rate: 100.0,
          total: 200.0,
        ),
      ];

      final invId = await salesService.createSalesInvoice(invoice: inv, items: items);
      expect(invId, greaterThan(0));

      // Stock reduced by 2
      final stockAfterCreate = (await productRepo.getProductById(prod.id!))!.stockQuantity;
      expect(stockAfterCreate, initialStock - 2);

      // Check JV-SALES-$invId exists and is balanced
      final jvs = await journalRepo.getAllJournalEntries(search: 'JV-SALES-$invId');
      expect(jvs, isNotEmpty);
      expect(jvs.first.isBalanced, isTrue);

      // Now edit: increase quantity from 2 to 5
      final loadedInv = await salesRepo.getSalesInvoiceById(invId);
      final updatedInv = loadedInv!.copyWith(
        subtotal: 500.0,
        grandTotal: 500.0,
      );
      final updatedItems = <SalesInvoiceItemModel>[
        SalesInvoiceItemModel(
          productId: prod.id!,
          quantity: 5,
          rate: 100.0,
          total: 500.0,
        ),
      ];

      await salesService.updateSalesInvoice(invoice: updatedInv, items: updatedItems);

      // Stock should now be initialStock - 5
      final stockAfterUpdate = (await productRepo.getProductById(prod.id!))!.stockQuantity;
      expect(stockAfterUpdate, initialStock - 5);

      // Check updated JV is strictly balanced
      final updatedJvs = await journalRepo.getAllJournalEntries(search: 'JV-SALES-$invId');
      expect(updatedJvs, isNotEmpty);
      final updatedJv = updatedJvs.first;
      expect(updatedJv.totalDebit, 500.0);
      expect(updatedJv.totalCredit, 500.0);
      expect(updatedJv.isBalanced, isTrue);
    });

    test('7. Purchase Orders: edit items/totals and delete order', () async {
      final suppliers = await supplierRepo.getAllSuppliers();
      final products = await productRepo.getAllProducts();
      final sup = suppliers.first;
      final prod = products.first;

      final orderNumber = await purchaseOrderRepo.getNextOrderNumber();
      final order = PurchaseOrderModel(
        orderNumber: orderNumber,
        orderDate: DateTime.now(),
        supplierId: sup.id!,
        status: AccountingConstants.statusPending,
        subtotal: 300.0,
        taxAmount: 0.0,
        grandTotal: 300.0,
      );
      final items = <PurchaseOrderItemModel>[
        PurchaseOrderItemModel(
          productId: prod.id!,
          quantity: 3,
          rate: 100.0,
          total: 300.0,
        ),
      ];

      final orderId = await purchaseOrderService.createPurchaseOrder(order: order, items: items);
      expect(orderId, greaterThan(0));

      final loaded = await purchaseOrderRepo.getPurchaseOrderById(orderId);
      final updated = loaded!.copyWith(
        subtotal: 600.0,
        grandTotal: 600.0,
      );
      final updatedItems = <PurchaseOrderItemModel>[
        PurchaseOrderItemModel(
          productId: prod.id!,
          quantity: 6,
          rate: 100.0,
          total: 600.0,
        ),
      ];
      await purchaseOrderService.updatePurchaseOrder(order: updated, items: updatedItems);

      final reloaded = await purchaseOrderRepo.getPurchaseOrderById(orderId);
      expect(reloaded!.grandTotal, 600.0);
      expect(reloaded.items.first.quantity, 6);

      await purchaseOrderService.deletePurchaseOrder(orderId);
      expect(await purchaseOrderRepo.getPurchaseOrderById(orderId), isNull);
    });

    test('8. Purchase Invoices: edit recalculates stock delta & updates balanced journal entry', () async {
      final suppliers = await supplierRepo.getAllSuppliers();
      final products = await productRepo.getAllProducts();
      final sup = suppliers.first;
      final prod = products.first;

      final initialStock = (await productRepo.getProductById(prod.id!))!.stockQuantity;

      final billNumber = await purchaseRepo.getNextPurchaseNumber();
      final bill = PurchaseInvoiceModel(
        invoiceNumber: billNumber,
        invoiceDate: DateTime.now(),
        supplierId: sup.id!,
        paymentStatus: AccountingConstants.paymentUnpaid,
        subtotal: 400.0,
        taxAmount: 0.0,
        grandTotal: 400.0,
      );
      final items = <PurchaseInvoiceItemModel>[
        PurchaseInvoiceItemModel(
          productId: prod.id!,
          quantity: 4,
          rate: 100.0,
          total: 400.0,
        ),
      ];

      final billId = await purchaseService.createPurchaseInvoice(invoice: bill, items: items);
      expect(billId, greaterThan(0));

      // Stock increased by 4
      final stockAfterCreate = (await productRepo.getProductById(prod.id!))!.stockQuantity;
      expect(stockAfterCreate, initialStock + 4);

      // JV-PURCHASE-$billId
      final jvs = await journalRepo.getAllJournalEntries(search: 'JV-PURCHASE-$billId');
      expect(jvs, isNotEmpty);
      expect(jvs.first.isBalanced, isTrue);

      // Now edit: change quantity from 4 to 10
      final loadedBill = await purchaseRepo.getPurchaseInvoiceById(billId);
      final updatedBill = loadedBill!.copyWith(
        subtotal: 1000.0,
        grandTotal: 1000.0,
      );
      final updatedItems = <PurchaseInvoiceItemModel>[
        PurchaseInvoiceItemModel(
          productId: prod.id!,
          quantity: 10,
          rate: 100.0,
          total: 1000.0,
        ),
      ];

      await purchaseService.updatePurchaseInvoice(invoice: updatedBill, items: updatedItems);

      // Stock should now be initialStock + 10
      final stockAfterUpdate = (await productRepo.getProductById(prod.id!))!.stockQuantity;
      expect(stockAfterUpdate, initialStock + 10);

      // Check updated JV is strictly balanced
      final updatedJvs = await journalRepo.getAllJournalEntries(search: 'JV-PURCHASE-$billId');
      expect(updatedJvs, isNotEmpty);
      final updatedJv = updatedJvs.first;
      expect(updatedJv.totalDebit, 1000.0);
      expect(updatedJv.totalCredit, 1000.0);
      expect(updatedJv.isBalanced, isTrue);
    });

    test('9. Receipts: edit updates customer balance & balanced journal; delete reverses balance', () async {
      final customers = await customerRepo.getAllCustomers();
      final cust = customers.first;
      final accounts = await accountRepo.getAllAccounts();
      final cashAccount = accounts.firstWhere((a) => a.accountCode == AccountingConstants.codeCash);

      final prevCust = await customerRepo.getCustomerById(cust.id!);
      final initialBalance = prevCust!.outstandingBalance;

      final receiptNumber = await receiptService.getNextReceiptNumber();
      final receipt = ReceiptModel(
        receiptNumber: receiptNumber,
        receiptDate: DateTime.now(),
        customerId: cust.id!,
        accountId: cashAccount.id!,
        amount: 250.0,
      );

      final receiptId = await receiptService.createReceipt(receipt);
      expect(receiptId, greaterThan(0));

      final afterCust = await customerRepo.getCustomerById(cust.id!);
      expect(afterCust!.outstandingBalance, CurrencyUtils.round(initialBalance - 250.0));

      // Edit receipt to 400.0
      final createdReceipt = await receiptService.getReceiptById(receiptId);
      final updatedReceipt = createdReceipt!.copyWith(amount: 400.0);
      await receiptService.updateReceipt(updatedReceipt);

      final editedCust = await customerRepo.getCustomerById(cust.id!);
      expect(editedCust!.outstandingBalance, CurrencyUtils.round(initialBalance - 400.0));

      final jvs = await journalRepo.getAllJournalEntries(search: 'JV-REC-$receiptId');
      expect(jvs, isNotEmpty);
      final jv = jvs.first;
      expect(jv.totalDebit, 400.0);
      expect(jv.totalCredit, 400.0);
      expect(jv.isBalanced, isTrue);

      // Delete receipt: should reverse customer balance back to initialBalance
      await receiptService.deleteReceipt(receiptId);
      final finalCust = await customerRepo.getCustomerById(cust.id!);
      expect(finalCust!.outstandingBalance, CurrencyUtils.round(initialBalance));
      expect(await receiptService.getReceiptById(receiptId), isNull);
    });

    test('10. Payments: edit updates supplier balance & balanced journal; delete reverses balance', () async {
      final suppliers = await supplierRepo.getAllSuppliers();
      final sup = suppliers.first;
      final accounts = await accountRepo.getAllAccounts();
      final cashAccount = accounts.firstWhere((a) => a.accountCode == AccountingConstants.codeCash);

      final prevSup = await supplierRepo.getSupplierById(sup.id!);
      final initialBalance = prevSup!.outstandingBalance;

      final pmtNumber = await paymentService.getNextPaymentNumber();
      final pmt = PaymentModel(
        paymentNumber: pmtNumber,
        paymentDate: DateTime.now(),
        supplierId: sup.id!,
        accountId: cashAccount.id!,
        amount: 300.0,
      );

      final pmtId = await paymentService.createPayment(pmt);
      expect(pmtId, greaterThan(0));

      final afterSup = await supplierRepo.getSupplierById(sup.id!);
      expect(afterSup!.outstandingBalance, CurrencyUtils.round(initialBalance - 300.0));

      // Edit payment to 550.0
      final createdPmt = await paymentService.getPaymentById(pmtId);
      final updatedPmt = createdPmt!.copyWith(amount: 550.0);
      await paymentService.updatePayment(updatedPmt);

      final editedSup = await supplierRepo.getSupplierById(sup.id!);
      expect(editedSup!.outstandingBalance, CurrencyUtils.round(initialBalance - 550.0));

      final jvs = await journalRepo.getAllJournalEntries(search: 'JV-PAY-$pmtId');
      expect(jvs, isNotEmpty);
      final jv = jvs.first;
      expect(jv.totalDebit, 550.0);
      expect(jv.totalCredit, 550.0);
      expect(jv.isBalanced, isTrue);

      // Delete payment: should reverse supplier balance back to initialBalance
      await paymentService.deletePayment(pmtId);
      final finalSup = await supplierRepo.getSupplierById(sup.id!);
      expect(finalSup!.outstandingBalance, CurrencyUtils.round(initialBalance));
      expect(await paymentService.getPaymentById(pmtId), isNull);
    });

    test('11. Expenses: edit updates amount & re-balances journal; delete reverses entries', () async {
      final accounts = await accountRepo.getAllAccounts();
      final expAccount = accounts.firstWhere((a) => a.accountType == AccountingConstants.typeExpense);
      final cashAccount = accounts.firstWhere((a) => a.accountCode == AccountingConstants.codeCash);

      final expNumber = await expenseRepo.getNextExpenseNumber();
      final expense = ExpenseModel(
        expenseNumber: expNumber,
        expenseDate: DateTime.now(),
        accountId: expAccount.id!,
        paymentAccountId: cashAccount.id!,
        amount: 150.0,
        taxAmount: 0.0,
        description: 'Office Snacks',
      );

      final expId = await expenseRepo.insertExpense(expense);
      expect(expId, greaterThan(0));

      // Create JV-EXP-$expId
      final jvNum = 'JV-EXP-$expId';
      final jv = JournalEntryModel(
        transactionNumber: jvNum,
        transactionDate: DateTime.now(),
        transactionType: AccountingConstants.transTypeExpense,
        referenceId: expId,
        description: 'Expense - $expNumber',
        lines: [
          JournalLineModel(accountId: expAccount.id!, debit: 150.0, credit: 0.0),
          JournalLineModel(accountId: cashAccount.id!, debit: 0.0, credit: 150.0),
        ],
      );
      final jvId = await journalRepo.insertJournalEntry(jv);

      // Edit expense
      final loadedExp = await expenseRepo.getExpenseById(expId);
      final updatedExp = loadedExp!.copyWith(
        amount: 220.0,
        description: 'Office Snacks & Coffee',
      );
      await expenseRepo.updateExpense(updatedExp);

      // Update journal lines
      final updatedJvLines = [
        JournalLineModel(accountId: expAccount.id!, debit: 220.0, credit: 0.0),
        JournalLineModel(accountId: cashAccount.id!, debit: 0.0, credit: 220.0),
      ];
      final existingJv = await journalRepo.getJournalEntryById(jvId);
      await journalRepo.updateJournalEntry(existingJv!, updatedJvLines);

      final reloadedJv = await journalRepo.getJournalEntryById(jvId);
      expect(reloadedJv!.totalDebit, 220.0);
      expect(reloadedJv.totalCredit, 220.0);
      expect(reloadedJv.isBalanced, isTrue);

      // Delete expense & its journal
      await expenseRepo.deleteExpense(expId);
      await journalRepo.deleteJournalEntry(jvId);

      expect(await expenseRepo.getExpenseById(expId), isNull);
      expect(await journalRepo.getJournalEntryById(jvId), isNull);
    });

    test('12. Journals: edit manual double-entry lines and verify balance enforcement', () async {
      final accounts = await accountRepo.getAllAccounts();
      final cashAccount = accounts.firstWhere((a) => a.accountCode == AccountingConstants.codeCash);
      final capitalAccount = accounts.firstWhere((a) => a.accountCode == AccountingConstants.codeCapital);

      final jvNum = await journalRepo.getNextJournalNumber();
      final initialLines = [
        JournalLineModel(accountId: cashAccount.id!, debit: 5000.0, credit: 0.0),
        JournalLineModel(accountId: capitalAccount.id!, debit: 0.0, credit: 5000.0),
      ];
      final jv = JournalEntryModel(
        transactionNumber: jvNum,
        transactionDate: DateTime.now(),
        transactionType: AccountingConstants.transTypeJournal,
        description: 'Initial Capital Injection',
        lines: initialLines,
      );

      final jvId = await journalRepo.insertJournalEntry(jv);
      expect(jvId, greaterThan(0));

      final loadedJv = await journalRepo.getJournalEntryById(jvId);
      expect(loadedJv, isNotNull);
      expect(loadedJv!.isBalanced, isTrue);

      // Edit manual journal: change amount to 7500.0
      final updatedLines = [
        JournalLineModel(accountId: cashAccount.id!, debit: 7500.0, credit: 0.0),
        JournalLineModel(accountId: capitalAccount.id!, debit: 0.0, credit: 7500.0),
      ];
      final updatedHeader = loadedJv.copyWith(description: 'Updated Capital Injection');

      await journalRepo.updateJournalEntry(updatedHeader, updatedLines);

      final reloadedJv = await journalRepo.getJournalEntryById(jvId);
      expect(reloadedJv!.totalDebit, 7500.0);
      expect(reloadedJv.totalCredit, 7500.0);
      expect(reloadedJv.isBalanced, isTrue);
      expect(reloadedJv.description, 'Updated Capital Injection');

      // Delete manual journal
      await journalRepo.deleteJournalEntry(jvId);
      expect(await journalRepo.getJournalEntryById(jvId), isNull);
    });

    test('13. Sales Returns: edit items & delete return', () async {
      final customers = await customerRepo.getAllCustomers();
      final products = await productRepo.getAllProducts();
      final cust = customers.first;
      final prod = products.first;

      final retNum = await salesOrderRepo.getNextReturnNumber();
      final retModel = SalesReturnModel(
        returnNumber: retNum,
        returnDate: DateTime.now(),
        customerId: cust.id!,
        status: AccountingConstants.statusPending,
        subtotal: 100.0,
        taxAmount: 0.0,
        grandTotal: 100.0,
      );
      final items = <SalesReturnItemModel>[
        SalesReturnItemModel(
          productId: prod.id!,
          quantity: 1,
          rate: 100.0,
          total: 100.0,
        ),
      ];

      final retId = await salesOrderService.createSalesReturn(returnModel: retModel, items: items);
      expect(retId, greaterThan(0));

      final loaded = await salesOrderRepo.getSalesReturnById(retId);
      final updated = loaded!.copyWith(
        subtotal: 200.0,
        grandTotal: 200.0,
      );
      final updatedItems = <SalesReturnItemModel>[
        SalesReturnItemModel(
          productId: prod.id!,
          quantity: 2,
          rate: 100.0,
          total: 200.0,
        ),
      ];
      await salesOrderService.updateSalesReturn(returnModel: updated, items: updatedItems);

      final reloaded = await salesOrderRepo.getSalesReturnById(retId);
      expect(reloaded!.grandTotal, 200.0);
      expect(reloaded.items.first.quantity, 2);

      await salesOrderService.deleteSalesReturn(retId);
      expect(await salesOrderRepo.getSalesReturnById(retId), isNull);
    });

    test('14. Purchase Returns: edit items & delete return', () async {
      final suppliers = await supplierRepo.getAllSuppliers();
      final products = await productRepo.getAllProducts();
      final sup = suppliers.first;
      final prod = products.first;

      final retNum = await purchaseOrderRepo.getNextReturnNumber();
      final retModel = PurchaseReturnModel(
        returnNumber: retNum,
        returnDate: DateTime.now(),
        supplierId: sup.id!,
        status: AccountingConstants.statusPending,
        subtotal: 150.0,
        taxAmount: 0.0,
        grandTotal: 150.0,
      );
      final items = <PurchaseReturnItemModel>[
        PurchaseReturnItemModel(
          productId: prod.id!,
          quantity: 1,
          rate: 150.0,
          total: 150.0,
        ),
      ];

      final retId = await purchaseOrderService.createPurchaseReturn(returnModel: retModel, items: items);
      expect(retId, greaterThan(0));

      final loaded = await purchaseOrderRepo.getPurchaseReturnById(retId);
      final updated = loaded!.copyWith(
        subtotal: 300.0,
        grandTotal: 300.0,
      );
      final updatedItems = <PurchaseReturnItemModel>[
        PurchaseReturnItemModel(
          productId: prod.id!,
          quantity: 2,
          rate: 150.0,
          total: 300.0,
        ),
      ];
      await purchaseOrderService.updatePurchaseReturn(returnModel: updated, items: updatedItems);

      final reloaded = await purchaseOrderRepo.getPurchaseReturnById(retId);
      expect(reloaded!.grandTotal, 300.0);
      expect(reloaded.items.first.quantity, 2);

      await purchaseOrderService.deletePurchaseReturn(retId);
      expect(await purchaseOrderRepo.getPurchaseReturnById(retId), isNull);
    });
  });
}
