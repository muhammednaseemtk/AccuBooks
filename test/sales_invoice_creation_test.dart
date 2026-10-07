import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/sales_invoice_model.dart';
import 'package:accubooks/models/sales_invoice_item_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/sales_repository.dart';
import 'package:accubooks/repositories/journal_repository.dart';
import 'package:accubooks/services/sales_service.dart';
import 'package:accubooks/controllers/sales_controller.dart';

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

  group('Sale Invoice Creation & Double-Entry Accounting Tests', () {
    final customerRepo = CustomerRepository();
    final productRepo = ProductRepository();
    final salesRepo = SalesRepository();
    final salesService = SalesService();
    final journalRepo = JournalRepository();

    test('Full End-to-End Sale Invoice Creation: Persisted, Stock Deducted, Balanced Double-Entry Journal, and Listed', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      // 1. Create a customer
      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-$ts',
        name: 'Alpha Customer $ts',
        phone: '9876543210',
      ));
      expect(custId, isPositive);

      // 2. Create a product with stock = 100
      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-$ts',
        name: 'Alpha Gadget $ts',
        salesPrice: 200.0,
        stockQuantity: 100.0,
        taxRate: 18.0,
        unit: 'Nos',
      ));
      expect(prodId, isPositive);

      final nextInvNumber = await salesService.getNextInvoiceNumber();
      expect(nextInvNumber, isNotEmpty);

      // 3. Line Item: Qty 5, Rate 200 => Base 1000, Tax 18% = 180, Total = 1180
      final item = SalesInvoiceItemModel(
        productId: prodId,
        productName: 'Alpha Gadget $ts',
        quantity: 5.0,
        rate: 200.0,
        discount: 0.0,
        taxRate: 18.0,
      );

      final invoice = SalesInvoiceModel(
        invoiceNumber: nextInvNumber,
        invoiceDate: DateTime.now(),
        customerId: custId,
        subtotal: 1000.0,
        discount: 0.0,
        taxAmount: 180.0,
        grandTotal: 1180.0,
        paidAmount: 0.0,
      );

      // 4. Save Invoice
      final invoiceId = await salesService.createSalesInvoice(
        invoice: invoice,
        items: [item],
      );
      expect(invoiceId, isPositive);

      // 5. Verify invoice header in DB
      final savedInvoice = await salesRepo.getSalesInvoiceById(invoiceId);
      expect(savedInvoice, isNotNull);
      expect(savedInvoice!.invoiceNumber, equals(nextInvNumber));
      expect(savedInvoice.customerId, equals(custId));
      expect(savedInvoice.subtotal, equals(1000.0));
      expect(savedInvoice.taxAmount, equals(180.0));
      expect(savedInvoice.grandTotal, equals(1180.0));
      expect(savedInvoice.balanceAmount, equals(1180.0));
      expect(savedInvoice.paymentStatus, equals(AccountingConstants.paymentUnpaid));

      // 6. Verify line items
      expect(savedInvoice.items.length, equals(1));
      expect(savedInvoice.items.first.productId, equals(prodId));
      expect(savedInvoice.items.first.quantity, equals(5.0));
      expect(savedInvoice.items.first.rate, equals(200.0));
      expect(savedInvoice.items.first.total, equals(1180.0));

      // 7. Verify stock deduction
      final updatedProduct = await productRepo.getProductById(prodId);
      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.stockQuantity, equals(95.0)); // 100 - 5

      // 8. Verify stock transaction log
      final stockTxns = await productRepo.getStockTransactions(prodId);
      expect(stockTxns.any((st) => st.referenceId == invoiceId && st.quantityOut == 5.0), isTrue);

      // 9. Verify Double-Entry Journal Entry
      final journals = await journalRepo.getAllJournalEntries(type: AccountingConstants.transTypeSales);
      final invoiceJournal = journals.firstWhere((j) => j.referenceId == invoiceId);
      expect(invoiceJournal, isNotNull);

      final totalDebit = invoiceJournal.lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = invoiceJournal.lines.fold(0.0, (sum, l) => sum + l.credit);
      expect((totalDebit - totalCredit).abs() < 0.01, isTrue);
      expect(totalDebit, equals(1180.0));
      expect(totalCredit, equals(1180.0));

      // Check specific lines: DR Customer (1180), CR Sales (1000), CR GST Output (180)
      final recvLine = invoiceJournal.lines.firstWhere((l) => l.debit == 1180.0);
      expect(recvLine, isNotNull);
      final salesLine = invoiceJournal.lines.firstWhere((l) => l.credit == 1000.0);
      expect(salesLine, isNotNull);
      final gstLine = invoiceJournal.lines.firstWhere((l) => l.credit == 180.0);
      expect(gstLine, isNotNull);

      // 10. Verify Customer Outstanding Balance
      final updatedCustomer = await customerRepo.getCustomerById(custId);
      expect(updatedCustomer, isNotNull);
      expect(updatedCustomer!.outstandingBalance, equals(1180.0));
      expect(updatedCustomer.totalSales, equals(1180.0));

      // 11. Verify getAllSalesInvoices does not throw and includes the invoice
      final allInvoices = await salesService.getAllInvoices();
      expect(allInvoices.any((inv) => inv.id == invoiceId), isTrue);
    });

    test('Sale Invoice with Discount: Balanced Double-Entry Journal with Discount Allowed', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 10;

      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-DISC-$ts',
        name: 'Beta Customer $ts',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-DISC-$ts',
        name: 'Beta Widget $ts',
        salesPrice: 500.0,
        stockQuantity: 50.0,
        taxRate: 18.0,
      ));

      // 2 units @ 500 = 1000. Item discount = 50 => Net item base = 950.
      // Tax 18% of 950 = 171.
      // Subtotal = 950, Invoice extra discount = 150.
      // Grand Total = (950 - 150) + 171 = 971.
      final item = SalesInvoiceItemModel(
        productId: prodId,
        productName: 'Beta Widget $ts',
        quantity: 2.0,
        rate: 500.0,
        discount: 50.0,
        taxRate: 18.0,
      );

      final nextInvNum = await salesService.getNextInvoiceNumber();
      final invoice = SalesInvoiceModel(
        invoiceNumber: nextInvNum,
        invoiceDate: DateTime.now(),
        customerId: custId,
        subtotal: 950.0,
        discount: 150.0,
        taxAmount: 171.0,
        grandTotal: 971.0,
      );

      final invoiceId = await salesService.createSalesInvoice(
        invoice: invoice,
        items: [item],
      );
      expect(invoiceId, isPositive);

      // Verify double-entry journal balance:
      // DR Customer Receivable: 971.0
      // DR Discount Allowed: 150.0
      // CR Sales: 950.0
      // CR GST Output: 171.0
      // Total DR = 1121.0, Total CR = 1121.0
      final journals = await journalRepo.getAllJournalEntries(type: AccountingConstants.transTypeSales);
      final invoiceJournal = journals.firstWhere((j) => j.referenceId == invoiceId);
      final totalDebit = invoiceJournal.lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = invoiceJournal.lines.fold(0.0, (sum, l) => sum + l.credit);

      expect((totalDebit - totalCredit).abs() < 0.01, isTrue);
      expect(totalDebit, equals(1121.0));
      expect(totalCredit, equals(1121.0));

      final discLine = invoiceJournal.lines.firstWhere((l) => l.debit == 150.0);
      expect(discLine, isNotNull);
    });

    test('Sale Invoice with Immediate Payment: Posts Receipt and Updates Balances', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 20;

      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-PAY-$ts',
        name: 'Gamma Customer $ts',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-PAY-$ts',
        name: 'Gamma Item $ts',
        salesPrice: 100.0,
        stockQuantity: 20.0,
        taxRate: 0.0,
      ));

      final item = SalesInvoiceItemModel(
        productId: prodId,
        quantity: 3.0,
        rate: 100.0,
      );

      final nextInvNum = await salesService.getNextInvoiceNumber();
      // Grand Total = 300, Paid = 300 (Fully Paid)
      final invoice = SalesInvoiceModel(
        invoiceNumber: nextInvNum,
        invoiceDate: DateTime.now(),
        customerId: custId,
        subtotal: 300.0,
        taxAmount: 0.0,
        grandTotal: 300.0,
        paidAmount: 300.0,
      );

      final invoiceId = await salesService.createSalesInvoice(
        invoice: invoice,
        items: [item],
      );

      final savedInvoice = await salesRepo.getSalesInvoiceById(invoiceId);
      expect(savedInvoice!.paymentStatus, equals(AccountingConstants.paymentPaid));
      expect(savedInvoice.balanceAmount, equals(0.0));

      // Verify customer outstanding is 0 because receipt was posted
      final custSummary = await customerRepo.getCustomerFinancialSummary(custId);
      expect(custSummary.totalSales, equals(300.0));
      expect(custSummary.totalReceipts, equals(300.0));
      expect(custSummary.outstanding, equals(0.0));
    });

    test('SalesController Form Flow: Add Items, Calculate, Submit, Form Reset', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 30;

      final cust = CustomerModel(
        id: await customerRepo.insertCustomer(CustomerModel(
          customerCode: 'CUST-CTRL-$ts',
          name: 'Delta Customer $ts',
        )),
        customerCode: 'CUST-CTRL-$ts',
        name: 'Delta Customer $ts',
      );

      final prod = ProductModel(
        id: await productRepo.insertProduct(ProductModel(
          productCode: 'PROD-CTRL-$ts',
          name: 'Delta Gadget $ts',
          salesPrice: 400.0,
          stockQuantity: 30.0,
          taxRate: 18.0,
        )),
        productCode: 'PROD-CTRL-$ts',
        name: 'Delta Gadget $ts',
        salesPrice: 400.0,
        stockQuantity: 30.0,
        taxRate: 18.0,
      );

      final controller = SalesController(
        salesService: salesService,
        customerRepo: customerRepo,
        productRepo: productRepo,
      );

      await controller.prepareNewInvoiceForm();
      expect(controller.formNextInvoiceNumber.value, isNotEmpty);

      // Select customer
      controller.formSelectedCustomer.value = cust;

      // Add item: qty 2, rate 400, discount 50 => base 750 + tax 18% (135) = 885
      controller.addFormItem(prod, 2.0, 400.0, 50.0);
      expect(controller.formItems.length, equals(1));
      expect(controller.formSubtotal, equals(750.0));
      expect(controller.formTaxTotal, equals(135.0));
      expect(controller.formGrandTotal, equals(885.0));

      // Extra invoice discount 35 => grand total = 850
      controller.formDiscount.value = 35.0;
      expect(controller.formGrandTotal, equals(850.0));

      // Paid 200 => balance = 650
      controller.formPaidAmount.value = 200.0;
      expect(controller.formBalanceAmount, equals(650.0));

      // Submit
      final ok = await controller.submitInvoice();
      expect(ok, isTrue);

      // Verify form was reset correctly
      expect(controller.formSelectedCustomer.value, isNull);
      expect(controller.formItems.isEmpty, isTrue);
      expect(controller.formDiscount.value, equals(0.0));
      expect(controller.formPaidAmount.value, equals(0.0));

      // Verify invoice exists in controller list
      expect(controller.invoices.any((i) => i.customerId == cust.id), isTrue);
    });

    test('Cancellation restores inventory and reverses journal entry', () async {
      final ts = DateTime.now().microsecondsSinceEpoch + 40;

      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-CAN-$ts',
        name: 'Cancel Test $ts',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-CAN-$ts',
        name: 'Cancel Product $ts',
        salesPrice: 100.0,
        stockQuantity: 50.0,
        taxRate: 18.0,
      ));

      final nextInvNum = await salesService.getNextInvoiceNumber();
      final item = SalesInvoiceItemModel(
        productId: prodId,
        quantity: 10.0,
        rate: 100.0,
        taxRate: 18.0,
      );

      final invId = await salesService.createSalesInvoice(
        invoice: SalesInvoiceModel(
          invoiceNumber: nextInvNum,
          invoiceDate: DateTime.now(),
          customerId: custId,
          subtotal: 1000.0,
          taxAmount: 180.0,
          grandTotal: 1180.0,
        ),
        items: [item],
      );

      // Stock was 50 - 10 = 40
      expect((await productRepo.getProductById(prodId))!.stockQuantity, equals(40.0));

      // Cancel invoice
      await salesService.cancelSalesInvoice(invId, reason: 'Customer cancelled');

      // Check stock restored to 50
      expect((await productRepo.getProductById(prodId))!.stockQuantity, equals(50.0));

      // Check invoice marked cancelled
      final cancelledInv = await salesRepo.getSalesInvoiceById(invId);
      expect(cancelledInv!.paymentStatus, equals(AccountingConstants.paymentCancelled));
    });
  });
}
