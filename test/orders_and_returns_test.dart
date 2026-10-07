import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/purchase_invoice_item_model.dart';
import 'package:accubooks/models/purchase_invoice_model.dart';
import 'package:accubooks/models/purchase_order_item_model.dart';
import 'package:accubooks/models/purchase_order_model.dart';
import 'package:accubooks/models/purchase_return_item_model.dart';
import 'package:accubooks/models/purchase_return_model.dart';
import 'package:accubooks/models/sales_invoice_item_model.dart';
import 'package:accubooks/models/sales_invoice_model.dart';
import 'package:accubooks/models/sales_order_item_model.dart';
import 'package:accubooks/models/sales_order_model.dart';
import 'package:accubooks/models/sales_return_item_model.dart';
import 'package:accubooks/models/sales_return_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/journal_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/purchase_repository.dart';
import 'package:accubooks/repositories/sales_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/services/purchase_order_service.dart';
import 'package:accubooks/services/purchase_service.dart';
import 'package:accubooks/services/sales_order_service.dart';
import 'package:accubooks/services/sales_service.dart';
import 'package:accubooks/controllers/purchase_order_controller.dart';
import 'package:accubooks/controllers/sales_order_controller.dart';

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

  group('Orders & Returns Complete End-to-End Tests', () {
    final customerRepo = CustomerRepository();
    final supplierRepo = SupplierRepository();
    final productRepo = ProductRepository();
    final salesRepo = SalesRepository();
    final salesService = SalesService();
    final purchaseRepo = PurchaseRepository();
    final purchaseService = PurchaseService();
    final salesOrderService = SalesOrderService();
    final purchaseOrderService = PurchaseOrderService();
    final journalRepo = JournalRepository();

    // =========================================================================
    // 1. SALES ORDER (NON-POSTING)
    // =========================================================================
    test('Sales Order: Persisted, Items Saved, Correct Totals, Non-Posting (Stock & Journal Unchanged)', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-SO-$ts',
        name: 'Order Customer $ts',
        phone: '9811223344',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-SO-$ts',
        name: 'Widget SO $ts',
        salesPrice: 500.0,
        stockQuantity: 50.0,
        taxRate: 18.0,
        unit: 'Nos',
      ));

      final initialStock = (await productRepo.getProductById(prodId))!.stockQuantity;
      final initialJournalCount = (await journalRepo.getAllJournalEntries()).length;

      final orderNumber = await salesOrderService.getNextOrderNumber();
      expect(orderNumber, startsWith('SO-'));

      final item = SalesOrderItemModel(
        productId: prodId,
        productName: 'Widget SO $ts',
        quantity: 10.0,
        rate: 500.0,
        discount: 200.0, // Subtotal = (10 * 500) - 200 = 4800
        taxRate: 18.0, // Tax = 4800 * 0.18 = 864
      );

      final order = SalesOrderModel(
        orderNumber: orderNumber,
        orderDate: DateTime.now(),
        expectedDeliveryDate: DateTime.now().add(const Duration(days: 3)),
        customerId: custId,
        subtotal: 4800.0,
        discount: 0.0,
        taxAmount: 864.0,
        grandTotal: 5664.0,
        status: AccountingConstants.statusPending,
        notes: 'Priority customer delivery',
      );

      final orderId = await salesOrderService.createSalesOrder(
        order: order,
        items: [item],
      );
      expect(orderId, isPositive);

      // Verify persisted record
      final fetchedOrder = await salesOrderService.getOrderById(orderId);
      expect(fetchedOrder, isNotNull);
      expect(fetchedOrder!.orderNumber, equals(orderNumber));
      expect(fetchedOrder.subtotal, equals(4800.0));
      expect(fetchedOrder.taxAmount, equals(864.0));
      expect(fetchedOrder.grandTotal, equals(5664.0));
      expect(fetchedOrder.customerId, equals(custId));
      expect(fetchedOrder.items.length, equals(1));
      expect(fetchedOrder.items.first.quantity, equals(10.0));
      expect(fetchedOrder.items.first.rate, equals(500.0));
      expect(fetchedOrder.items.first.discount, equals(200.0));
      expect(fetchedOrder.items.first.total, equals(5664.0));

      // Verify Non-Posting: Stock is NOT reduced
      final currentStock = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(currentStock, equals(initialStock));

      // Verify Non-Posting: NO journal entry created
      final currentJournalCount = (await journalRepo.getAllJournalEntries()).length;
      expect(currentJournalCount, equals(initialJournalCount));

      // Test Controller Flow
      final controller = SalesOrderController(
        service: salesOrderService,
        customerRepo: customerRepo,
        productRepo: productRepo,
        salesRepo: salesRepo,
      );
      await controller.loadMetadata();
      await controller.prepareNewOrderForm();
      final prod = (await productRepo.getProductById(prodId))!;
      final cust = (await customerRepo.getCustomerById(custId))!;

      controller.formOrderCustomer.value = cust;
      controller.addOrderItem(prod, 2.0, 500.0, 0.0);
      expect(controller.formOrderSubtotal, equals(1000.0));
      expect(controller.formOrderTaxTotal, equals(180.0));
      expect(controller.formOrderGrandTotal, equals(1180.0));

      final success = await controller.submitOrder();
      expect(success, isTrue);
      // Form should reset after success
      expect(controller.formOrderItems, isEmpty);
      expect(controller.formOrderCustomer.value, isNull);
    });

    // =========================================================================
    // 2. SALES RETURN (POSTING: RESTORES STOCK & BALANCED REVERSAL JOURNAL)
    // =========================================================================
    test('Sales Return: Validates Qty, Restores Stock, Balanced Reversal Journal, Updates Customer Balance', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      // 1. Customer & Product
      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-SR-$ts',
        name: 'Return Customer $ts',
        phone: '9822334455',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-SR-$ts',
        name: 'Gadget SR $ts',
        salesPrice: 1000.0,
        stockQuantity: 50.0,
        taxRate: 18.0,
        unit: 'Nos',
      ));

      // 2. First create a Sales Invoice for 10 items
      // Stock before invoice = 50. After invoice = 40.
      final invNumber = await salesService.getNextInvoiceNumber();
      final invItem = SalesInvoiceItemModel(
        productId: prodId,
        productName: 'Gadget SR $ts',
        quantity: 10.0,
        rate: 1000.0,
        discount: 0.0,
        taxRate: 18.0,
      );
      final invId = await salesService.createSalesInvoice(
        invoice: SalesInvoiceModel(
          invoiceNumber: invNumber,
          invoiceDate: DateTime.now(),
          customerId: custId,
          subtotal: 10000.0,
          discount: 0.0,
          taxAmount: 1800.0,
          grandTotal: 11800.0,
        ),
        items: [invItem],
      );

      final stockAfterSale = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(stockAfterSale, equals(40.0));

      final custSummaryAfterSale = await customerRepo.getCustomerFinancialSummary(custId);
      expect(custSummaryAfterSale.outstanding, equals(11800.0));

      // 3. Prevent invalid return: Qty > 10 (invoice qty)
      final invalidReturnItem = SalesReturnItemModel(
        productId: prodId,
        productName: 'Gadget SR $ts',
        quantity: 15.0, // Cannot return 15 when only 10 purchased
        rate: 1000.0,
        discount: 0.0,
        taxRate: 18.0,
      );
      expect(
        () => salesOrderService.createSalesReturn(
          returnModel: SalesReturnModel(
            returnNumber: 'SR-INVALID',
            returnDate: DateTime.now(),
            customerId: custId,
            referenceInvoiceId: invId,
            subtotal: 15000.0,
            taxAmount: 2700.0,
            grandTotal: 17700.0,
          ),
          items: [invalidReturnItem],
        ),
        throwsA(isA<Exception>()),
      );

      // Prevent negative / zero quantity
      expect(
        () => salesOrderService.createSalesReturn(
          returnModel: SalesReturnModel(
            returnNumber: 'SR-NEG',
            returnDate: DateTime.now(),
            customerId: custId,
            subtotal: 0.0,
            taxAmount: 0.0,
            grandTotal: 0.0,
          ),
          items: [
            SalesReturnItemModel(
              productId: prodId,
              quantity: -2.0,
              rate: 1000.0,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );

      // 4. Create VALID Sales Return for 4 items
      // Rate = 1000, Subtotal = 4000, Tax = 720, Grand Total = 4720
      final returnNumber = await salesOrderService.getNextReturnNumber();
      expect(returnNumber, startsWith('SR-'));

      final validItem = SalesReturnItemModel(
        productId: prodId,
        productName: 'Gadget SR $ts',
        quantity: 4.0,
        rate: 1000.0,
        discount: 0.0,
        taxRate: 18.0,
      );

      final returnId = await salesOrderService.createSalesReturn(
        returnModel: SalesReturnModel(
          returnNumber: returnNumber,
          returnDate: DateTime.now(),
          customerId: custId,
          referenceInvoiceId: invId,
          referenceInvoiceNumber: invNumber,
          subtotal: 4000.0,
          discount: 0.0,
          taxAmount: 720.0,
          grandTotal: 4720.0,
          reason: 'Customer ordered excess',
        ),
        items: [validItem],
      );
      expect(returnId, isPositive);

      // Verify Stock Increased (+4)
      final stockAfterReturn = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(stockAfterReturn, equals(44.0)); // 40 + 4 = 44

      // Verify Double-Entry Accounting
      final returnEntry = (await journalRepo.getAllJournalEntries())
          .firstWhere((e) => e.transactionType == AccountingConstants.transTypeSalesReturn && e.referenceId == returnId);
      expect(returnEntry, isNotNull);
      expect(returnEntry.totalDebit, equals(returnEntry.totalCredit));
      expect(returnEntry.totalDebit, equals(4720.0));

      // Verify Customer Outstanding reduced by 4720
      // 11800 - 4720 = 7080
      final custSummaryAfterReturn = await customerRepo.getCustomerFinancialSummary(custId);
      expect(custSummaryAfterReturn.outstanding, equals(7080.0));

      // Verify duplicate prevention on reference invoice:
      // Can return at most 6 more. Trying to return 7 should throw!
      expect(
        () => salesOrderService.createSalesReturn(
          returnModel: SalesReturnModel(
            returnNumber: 'SR-EXCEED',
            returnDate: DateTime.now(),
            customerId: custId,
            referenceInvoiceId: invId,
            subtotal: 7000.0,
            taxAmount: 1260.0,
            grandTotal: 8260.0,
          ),
          items: [
            SalesReturnItemModel(
              productId: prodId,
              quantity: 7.0, // 4 + 7 = 11 > 10!
              rate: 1000.0,
              taxRate: 18.0,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    // =========================================================================
    // 3. PURCHASE ORDER (NON-POSTING)
    // =========================================================================
    test('Purchase Order: Persisted, Items Saved, Correct Totals, Non-Posting (Stock & Journal Unchanged)', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-PO-$ts',
        name: 'Order Supplier $ts',
        phone: '9833445566',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-PO-$ts',
        name: 'Material PO $ts',
        purchasePrice: 300.0,
        stockQuantity: 20.0,
        taxRate: 12.0,
        unit: 'Kg',
      ));

      final initialStock = (await productRepo.getProductById(prodId))!.stockQuantity;
      final initialJournalCount = (await journalRepo.getAllJournalEntries()).length;

      final poNumber = await purchaseOrderService.getNextOrderNumber();
      expect(poNumber, startsWith('PO-'));

      final item = PurchaseOrderItemModel(
        productId: prodId,
        productName: 'Material PO $ts',
        quantity: 15.0,
        rate: 300.0,
        discount: 100.0, // Subtotal = (15 * 300) - 100 = 4400
        taxRate: 12.0, // Tax = 4400 * 0.12 = 528
      );

      final po = PurchaseOrderModel(
        orderNumber: poNumber,
        orderDate: DateTime.now(),
        expectedDeliveryDate: DateTime.now().add(const Duration(days: 5)),
        supplierId: supId,
        subtotal: 4400.0,
        discount: 0.0,
        taxAmount: 528.0,
        grandTotal: 4928.0,
        status: AccountingConstants.statusPending,
        notes: 'Delivery before weekend',
      );

      final poId = await purchaseOrderService.createPurchaseOrder(
        order: po,
        items: [item],
      );
      expect(poId, isPositive);

      // Verify persisted
      final fetchedPO = await purchaseOrderService.getOrderById(poId);
      expect(fetchedPO, isNotNull);
      expect(fetchedPO!.orderNumber, equals(poNumber));
      expect(fetchedPO.subtotal, equals(4400.0));
      expect(fetchedPO.taxAmount, equals(528.0));
      expect(fetchedPO.grandTotal, equals(4928.0));
      expect(fetchedPO.supplierId, equals(supId));
      expect(fetchedPO.items.length, equals(1));
      expect(fetchedPO.items.first.quantity, equals(15.0));

      // Verify Non-Posting: Stock is NOT increased
      final currentStock = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(currentStock, equals(initialStock));

      // Verify Non-Posting: NO journal entry
      final currentJournalCount = (await journalRepo.getAllJournalEntries()).length;
      expect(currentJournalCount, equals(initialJournalCount));

      // Test Controller Flow
      final controller = PurchaseOrderController(
        service: purchaseOrderService,
        supplierRepo: supplierRepo,
        productRepo: productRepo,
        purchaseRepo: purchaseRepo,
      );
      await controller.loadMetadata();
      await controller.prepareNewOrderForm();
      final prod = (await productRepo.getProductById(prodId))!;
      final sup = (await supplierRepo.getSupplierById(supId))!;

      controller.formOrderSupplier.value = sup;
      controller.addOrderItem(prod, 5.0, 300.0, 0.0);
      expect(controller.formOrderSubtotal, equals(1500.0));
      expect(controller.formOrderTaxTotal, equals(180.0)); // 1500 * 0.12 = 180
      expect(controller.formOrderGrandTotal, equals(1680.0));

      final success = await controller.submitOrder();
      expect(success, isTrue);
      // Form should reset after success
      expect(controller.formOrderItems, isEmpty);
      expect(controller.formOrderSupplier.value, isNull);
    });

    // =========================================================================
    // 4. PURCHASE RETURN (POSTING: DEDUCTS STOCK & BALANCED REVERSAL JOURNAL)
    // =========================================================================
    test('Purchase Return: Validates Stock, Deducts Stock, Balanced Reversal Journal, Updates Supplier Balance', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-PR-$ts',
        name: 'Return Supplier $ts',
        phone: '9844556677',
      ));

      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-PR-$ts',
        name: 'Item PR $ts',
        purchasePrice: 400.0,
        stockQuantity: 10.0,
        taxRate: 18.0,
        unit: 'Pcs',
      ));

      // 1. First record purchase invoice for 20 items => Stock becomes 10 + 20 = 30
      final purNumber = await purchaseService.getNextPurchaseNumber();
      final purItem = PurchaseInvoiceItemModel(
        productId: prodId,
        productName: 'Item PR $ts',
        quantity: 20.0,
        rate: 400.0,
        discount: 0.0,
        taxRate: 18.0,
      );
      final purId = await purchaseService.createPurchaseInvoice(
        invoice: PurchaseInvoiceModel(
          invoiceNumber: purNumber,
          invoiceDate: DateTime.now(),
          supplierId: supId,
          subtotal: 8000.0,
          discount: 0.0,
          taxAmount: 1440.0,
          grandTotal: 9440.0,
        ),
        items: [purItem],
      );

      final stockAfterPurchase = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(stockAfterPurchase, equals(30.0));

      final supSummaryAfterPur = await supplierRepo.getSupplierFinancialSummary(supId);
      expect(supSummaryAfterPur.outstanding, equals(9440.0));

      // 2. Prevent invalid return: Qty > Purchased (25 > 20)
      expect(
        () => purchaseOrderService.createPurchaseReturn(
          returnModel: PurchaseReturnModel(
            returnNumber: 'PR-INVALID',
            returnDate: DateTime.now(),
            supplierId: supId,
            referenceInvoiceId: purId,
            subtotal: 10000.0,
            taxAmount: 1800.0,
            grandTotal: 11800.0,
          ),
          items: [
            PurchaseReturnItemModel(
              productId: prodId,
              quantity: 25.0,
              rate: 400.0,
              taxRate: 18.0,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );

      // Prevent negative / zero quantity
      expect(
        () => purchaseOrderService.createPurchaseReturn(
          returnModel: PurchaseReturnModel(
            returnNumber: 'PR-NEG',
            returnDate: DateTime.now(),
            supplierId: supId,
            subtotal: 0.0,
            taxAmount: 0.0,
            grandTotal: 0.0,
          ),
          items: [
            PurchaseReturnItemModel(
              productId: prodId,
              quantity: -5.0,
              rate: 400.0,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );

      // 3. Create VALID Purchase Return for 6 items
      // Rate = 400, Subtotal = 2400, Tax = 432, Grand Total = 2832
      final prNumber = await purchaseOrderService.getNextReturnNumber();
      expect(prNumber, startsWith('PR-'));

      final validItem = PurchaseReturnItemModel(
        productId: prodId,
        productName: 'Item PR $ts',
        quantity: 6.0,
        rate: 400.0,
        discount: 0.0,
        taxRate: 18.0,
      );

      final prId = await purchaseOrderService.createPurchaseReturn(
        returnModel: PurchaseReturnModel(
          returnNumber: prNumber,
          returnDate: DateTime.now(),
          supplierId: supId,
          referenceInvoiceId: purId,
          referenceInvoiceNumber: purNumber,
          subtotal: 2400.0,
          discount: 0.0,
          taxAmount: 432.0,
          grandTotal: 2832.0,
          reason: 'Defective raw materials returned',
        ),
        items: [validItem],
      );
      expect(prId, isPositive);

      // Verify Stock Decreased (-6)
      final stockAfterReturn = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(stockAfterReturn, equals(24.0)); // 30 - 6 = 24

      // Verify Double-Entry Accounting
      final returnEntry = (await journalRepo.getAllJournalEntries())
          .firstWhere((e) => e.transactionType == AccountingConstants.transTypePurchaseReturn && e.referenceId == prId);
      expect(returnEntry, isNotNull);
      expect(returnEntry.totalDebit, equals(returnEntry.totalCredit));
      expect(returnEntry.totalDebit, equals(2832.0));

      // Verify Supplier Outstanding reduced by 2832
      // 9440 - 2832 = 6608
      final supSummaryAfterReturn = await supplierRepo.getSupplierFinancialSummary(supId);
      expect(supSummaryAfterReturn.outstanding, equals(6608.0));
    });

    // =========================================================================
    // 5. EXISTING FUNCTIONALITY INTEGRITY CHECK
    // =========================================================================
    test('Existing Sales & Purchase Invoicing Functions Perfectly & Unchanged', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-REG-$ts',
        name: 'Regular Customer $ts',
      ));
      final prodId = await productRepo.insertProduct(ProductModel(
        productCode: 'PROD-REG-$ts',
        name: 'Regular Product $ts',
        salesPrice: 100.0,
        stockQuantity: 20.0,
        taxRate: 0.0,
      ));

      // Create regular sales invoice
      final invNumber = await salesService.getNextInvoiceNumber();
      final invoiceId = await salesService.createSalesInvoice(
        invoice: SalesInvoiceModel(
          invoiceNumber: invNumber,
          invoiceDate: DateTime.now(),
          customerId: custId,
          subtotal: 500.0,
          taxAmount: 0.0,
          grandTotal: 500.0,
        ),
        items: [
          SalesInvoiceItemModel(
            productId: prodId,
            quantity: 5.0,
            rate: 100.0,
          ),
        ],
      );
      expect(invoiceId, isPositive);

      final stock = (await productRepo.getProductById(prodId))!.stockQuantity;
      expect(stock, equals(15.0)); // 20 - 5 = 15
    });
  });
}
