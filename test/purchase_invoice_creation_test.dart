import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/purchase_invoice_model.dart';
import 'package:accubooks/models/purchase_invoice_item_model.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/purchase_repository.dart';
import 'package:accubooks/repositories/journal_repository.dart';
import 'package:accubooks/services/purchase_service.dart';
import 'package:accubooks/controllers/purchase_controller.dart';

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

  group('Purchase Invoice Creation & Double-Entry Accounting Tests', () {
    final supplierRepo = SupplierRepository();
    final productRepo = ProductRepository();
    final purchaseRepo = PurchaseRepository();
    final purchaseService = PurchaseService();
    final journalRepo = JournalRepository();

    test('Full End-to-End Purchase Invoice Creation: Persisted, Stock Increased, Balanced Journal, Payables Updated', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      // 1. Create a supplier
      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-$ts',
        name: 'Acme Supplies $ts',
        phone: '9876500001',
      ));
      expect(supId, isPositive);

      // 2. Create a product with initial stock = 20
      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-P-$ts',
        name: 'Industrial Widget $ts',
        purchasePrice: 150.0,
        salesPrice: 250.0,
        stockQuantity: 20.0,
        taxRate: 18.0,
        unit: 'Pcs',
      ));
      expect(prodId, isPositive);

      final nextPurNumber = await purchaseService.getNextPurchaseNumber();
      expect(nextPurNumber, isNotEmpty);

      // 3. Purchase Item: 10 pcs @ 150 = 1500 base. Tax 18% = 270. Total = 1770
      final item = PurchaseInvoiceItemModel(
        productId: prodId,
        productName: 'Industrial Widget $ts',
        quantity: 10.0,
        rate: 150.0,
        discount: 0.0,
        taxRate: 18.0,
      );

      final invoice = PurchaseInvoiceModel(
        invoiceNumber: nextPurNumber,
        invoiceDate: DateTime.now(),
        supplierId: supId,
        subtotal: 1500.0,
        discount: 0.0,
        taxAmount: 270.0,
        grandTotal: 1770.0,
        paidAmount: 0.0,
      );

      // 4. Create purchase invoice
      final invoiceId = await purchaseService.createPurchaseInvoice(
        invoice: invoice,
        items: [item],
      );
      expect(invoiceId, isPositive);

      // 5. Verify purchase invoice header persisted
      final savedInvoice = await purchaseRepo.getPurchaseInvoiceById(invoiceId);
      expect(savedInvoice, isNotNull);
      expect(savedInvoice!.invoiceNumber, equals(nextPurNumber));
      expect(savedInvoice.supplierId, equals(supId));
      expect(savedInvoice.subtotal, equals(1500.0));
      expect(savedInvoice.taxAmount, equals(270.0));
      expect(savedInvoice.grandTotal, equals(1770.0));
      expect(savedInvoice.balanceAmount, equals(1770.0));
      expect(savedInvoice.paymentStatus, equals(AccountingConstants.paymentUnpaid));

      // 6. Verify purchase invoice items persisted
      expect(savedInvoice.items.length, equals(1));
      expect(savedInvoice.items.first.productId, equals(prodId));
      expect(savedInvoice.items.first.quantity, equals(10.0));
      expect(savedInvoice.items.first.rate, equals(150.0));
      expect(savedInvoice.items.first.taxAmount, equals(270.0));
      expect(savedInvoice.items.first.total, equals(1770.0));

      // 7. Verify stock increased in product (20 + 10 = 30)
      final updatedProduct = await productRepo.getProductById(prodId);
      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.stockQuantity, equals(30.0));

      // 8. Verify stock transaction record
      final stockTxns = await productRepo.getStockTransactions(prodId);
      expect(stockTxns.any((st) => st.referenceId == invoiceId && st.quantityIn == 10.0), isTrue);

      // 9. Verify Double-Entry Accounting Journal
      final journals = await journalRepo.getAllJournalEntries(type: AccountingConstants.transTypePurchase);
      final purJournal = journals.firstWhere((j) => j.referenceId == invoiceId);
      expect(purJournal, isNotNull);

      final totalDebit = purJournal.lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = purJournal.lines.fold(0.0, (sum, l) => sum + l.credit);
      expect((totalDebit - totalCredit).abs() < 0.01, isTrue);
      expect(totalDebit, equals(1770.0));
      expect(totalCredit, equals(1770.0));

      // DR Purchases: 1500
      final purchasesLine = purJournal.lines.firstWhere((l) => l.debit == 1500.0);
      expect(purchasesLine, isNotNull);

      // DR GST Input Credit: 270
      final gstLine = purJournal.lines.firstWhere((l) => l.debit == 270.0);
      expect(gstLine, isNotNull);

      // CR Supplier Payable: 1770
      final payableLine = purJournal.lines.firstWhere((l) => l.credit == 1770.0);
      expect(payableLine, isNotNull);

      // 10. Verify Supplier Financial Balance Updated
      final updatedSupplier = await supplierRepo.getSupplierById(supId);
      expect(updatedSupplier, isNotNull);
      expect(updatedSupplier!.outstandingBalance, equals(1770.0));
      expect(updatedSupplier.totalPurchases, equals(1770.0));

      // 11. Verify getAllPurchaseInvoices succeeds without column errors and includes new invoice
      final allPurchases = await purchaseService.getAllPurchases();
      expect(allPurchases.any((pur) => pur.id == invoiceId), isTrue);
    });

    test('Purchase Invoice with Discount: Balanced Double-Entry with Discount Received', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 20;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-DISC-$ts',
        name: 'Discount Vendor $ts',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-DISC-$ts',
        name: 'Bulk Raw Material $ts',
        purchasePrice: 400.0,
        stockQuantity: 5.0,
        taxRate: 18.0,
      ));

      // 5 units @ 400 = 2000. Item discount = 100 => Net base = 1900.
      // Tax 18% of 1900 = 342.
      // Subtotal = 1900, Invoice level discount = 200.
      // Grand Total = (1900 - 200) + 342 = 2042.
      final item = PurchaseInvoiceItemModel(
        productId: prodId,
        productName: 'Bulk Raw Material $ts',
        quantity: 5.0,
        rate: 400.0,
        discount: 100.0,
        taxRate: 18.0,
      );

      final nextPurNum = await purchaseService.getNextPurchaseNumber();
      final invoice = PurchaseInvoiceModel(
        invoiceNumber: nextPurNum,
        invoiceDate: DateTime.now(),
        supplierId: supId,
        subtotal: 1900.0,
        discount: 200.0,
        taxAmount: 342.0,
        grandTotal: 2042.0,
      );

      final invoiceId = await purchaseService.createPurchaseInvoice(
        invoice: invoice,
        items: [item],
      );
      expect(invoiceId, isPositive);

      // Verify double-entry journal balance:
      // DR Purchases: 1900.0
      // DR GST Input Credit: 342.0
      // Total Debit = 2242.0
      // CR Supplier Payable: 2042.0
      // CR Discount Received: 200.0
      // Total Credit = 2242.0
      final journals = await journalRepo.getAllJournalEntries(type: AccountingConstants.transTypePurchase);
      final purJournal = journals.firstWhere((j) => j.referenceId == invoiceId);

      final totalDebit = purJournal.lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = purJournal.lines.fold(0.0, (sum, l) => sum + l.credit);
      expect((totalDebit - totalCredit).abs() < 0.01, isTrue);
      expect(totalDebit, equals(2242.0));
      expect(totalCredit, equals(2242.0));

      final discLine = purJournal.lines.firstWhere((l) => l.credit == 200.0);
      expect(discLine, isNotNull);

      // Verify supplier outstanding balance equals grand total (2042.0)
      final updatedSupplier = await supplierRepo.getSupplierById(supId);
      expect(updatedSupplier!.outstandingBalance, equals(2042.0));
    });

    test('Purchase Invoice with Immediate Payment: Payment Recorded, Balanced Journal, Balance Due Reduced', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 40;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-PAID-$ts',
        name: 'Spot Cash Vendor $ts',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-PAID-$ts',
        name: 'Fast Hardware $ts',
        purchasePrice: 100.0,
        stockQuantity: 10.0,
        taxRate: 18.0,
      ));

      // 10 units @ 100 = 1000. Tax 18% = 180. Grand total = 1180.
      // Immediate Payment = 600. Balance due = 580.
      final item = PurchaseInvoiceItemModel(
        productId: prodId,
        productName: 'Fast Hardware $ts',
        quantity: 10.0,
        rate: 100.0,
        discount: 0.0,
        taxRate: 18.0,
      );

      final nextPurNum = await purchaseService.getNextPurchaseNumber();
      final invoice = PurchaseInvoiceModel(
        invoiceNumber: nextPurNum,
        invoiceDate: DateTime.now(),
        supplierId: supId,
        subtotal: 1000.0,
        discount: 0.0,
        taxAmount: 180.0,
        grandTotal: 1180.0,
        paidAmount: 600.0,
      );

      final invoiceId = await purchaseService.createPurchaseInvoice(
        invoice: invoice,
        items: [item],
      );
      expect(invoiceId, isPositive);

      final savedInvoice = await purchaseRepo.getPurchaseInvoiceById(invoiceId);
      expect(savedInvoice!.paidAmount, equals(600.0));
      expect(savedInvoice.balanceAmount, equals(580.0));
      expect(savedInvoice.paymentStatus, equals(AccountingConstants.paymentPartiallyPaid));

      // Verify payment journal entry
      final payJournals = await journalRepo.getAllJournalEntries(type: AccountingConstants.transTypePayment);
      final purPayment = payJournals.firstWhere((j) => j.referenceId == invoiceId);
      expect(purPayment, isNotNull);

      // DR Supplier Payable: 600.0, CR Cash: 600.0
      final totalDebit = purPayment.lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = purPayment.lines.fold(0.0, (sum, l) => sum + l.credit);
      expect((totalDebit - totalCredit).abs() < 0.01, isTrue);
      expect(totalDebit, equals(600.0));

      // Net Supplier Outstanding Balance = 1180 - 600 = 580.0
      final updatedSupplier = await supplierRepo.getSupplierById(supId);
      expect(updatedSupplier!.outstandingBalance, equals(580.0));
    });

    test('Atomic Rollback: Invalid Product ID Rolls Back Purchase Invoice and Journal Entry', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 60;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-FAIL-$ts',
        name: 'Fail Test Vendor $ts',
      ));

      final invalidItem = PurchaseInvoiceItemModel(
        productId: 99999999, // Non-existent product
        quantity: 5.0,
        rate: 100.0,
      );

      final invoice = PurchaseInvoiceModel(
        invoiceNumber: 'PUR-FAIL-$ts',
        invoiceDate: DateTime.now(),
        supplierId: supId,
        subtotal: 500.0,
        taxAmount: 0.0,
        grandTotal: 500.0,
      );

      expect(
        () async => await purchaseService.createPurchaseInvoice(
          invoice: invoice,
          items: [invalidItem],
        ),
        throwsException,
      );

      // Verify invoice was not inserted
      final allPurchases = await purchaseService.getAllPurchases();
      expect(allPurchases.any((pur) => pur.invoiceNumber == 'PUR-FAIL-$ts'), isFalse);
    });

    test('PurchaseController Flow: Validation, Calculation, Submission, Reset, and Duplicate Guard', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 80;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-CTRL-$ts',
        name: 'Controller Vendor $ts',
      ));
      final supplier = (await supplierRepo.getSupplierById(supId))!;

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-CTRL-$ts',
        name: 'Controller Material $ts',
        purchasePrice: 200.0,
        stockQuantity: 15.0,
        taxRate: 12.0,
        unit: 'Kg',
      ));
      final product = (await productRepo.getProductById(prodId))!;

      final controller = PurchaseController(
        purchaseService: purchaseService,
        supplierRepo: supplierRepo,
        productRepo: productRepo,
      );

      await controller.prepareNewPurchaseForm();
      expect(controller.formNextPurchaseNumber.value, isNotEmpty);

      // 1. Validation: no supplier
      final failNoSupplier = await controller.submitPurchase();
      expect(failNoSupplier, isFalse);

      controller.formSelectedSupplier.value = supplier;

      // 2. Validation: no items
      final failNoItems = await controller.submitPurchase();
      expect(failNoItems, isFalse);

      // 3. Add item: 4 Kg @ 200 = 800 base. Tax 12% = 96. Total = 896
      controller.addFormItem(product, 4.0, 200.0, 0.0);
      expect(controller.formItems.length, equals(1));
      expect(controller.formSubtotal, equals(800.0));
      expect(controller.formTaxTotal, equals(96.0));
      expect(controller.formGrandTotal, equals(896.0));
      expect(controller.formBalanceAmount, equals(896.0));

      // 4. Submit purchase
      final success = await controller.submitPurchase();
      expect(success, isTrue);

      // 5. Verify controller purchases list refreshed
      expect(controller.purchases.any((p) => p.supplierId == supId), isTrue);

      // 6. Verify form was reset
      expect(controller.formSelectedSupplier.value, isNull);
      expect(controller.formItems.isEmpty, isTrue);
      expect(controller.formDiscount.value, equals(0.0));
      expect(controller.formPaidAmount.value, equals(0.0));

      // 7. Test duplicate submission protection
      controller.isSubmitting.value = true;
      final duplicateBlocked = await controller.submitPurchase();
      expect(duplicateBlocked, isFalse);
      controller.isSubmitting.value = false;
    });

    test('Purchase Cancellation: Status Cancelled, Stock Reverted, Reversing Journal Posted', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 90;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-CANCEL-$ts',
        name: 'Cancel Vendor $ts',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-CANCEL-$ts',
        name: 'Cancel Tool $ts',
        purchasePrice: 300.0,
        stockQuantity: 10.0,
        taxRate: 18.0,
      ));

      // Buy 5 tools @ 300 = 1500 + tax 270 = 1770
      final item = PurchaseInvoiceItemModel(
        productId: prodId,
        quantity: 5.0,
        rate: 300.0,
        taxRate: 18.0,
      );

      final nextPurNum = await purchaseService.getNextPurchaseNumber();
      final invoice = PurchaseInvoiceModel(
        invoiceNumber: nextPurNum,
        invoiceDate: DateTime.now(),
        supplierId: supId,
        subtotal: 1500.0,
        taxAmount: 270.0,
        grandTotal: 1770.0,
      );

      final invoiceId = await purchaseService.createPurchaseInvoice(
        invoice: invoice,
        items: [item],
      );

      // Verify stock was increased to 15 (10 + 5)
      var prod = await productRepo.getProductById(prodId);
      expect(prod!.stockQuantity, equals(15.0));

      // Cancel the purchase
      await purchaseService.cancelPurchaseInvoice(invoiceId, reason: 'Damaged shipment received');

      // Verify invoice status is Cancelled
      final cancelledInvoice = await purchaseRepo.getPurchaseInvoiceById(invoiceId);
      expect(cancelledInvoice!.paymentStatus, equals(AccountingConstants.paymentCancelled));

      // Verify stock is reverted back to 10 (15 - 5)
      prod = await productRepo.getProductById(prodId);
      expect(prod!.stockQuantity, equals(10.0));

      // Verify reversing journal entry posted
      final journals = await journalRepo.getAllJournalEntries();
      final revJournal = journals.firstWhere((j) => j.referenceId == invoiceId && (j.description?.contains('Reversal') ?? false));
      expect(revJournal, isNotNull);

      // Verify supplier outstanding balance reverted to 0
      final updatedSupplier = await supplierRepo.getSupplierById(supId);
      expect(updatedSupplier!.outstandingBalance, equals(0.0));
    });
  });
}
