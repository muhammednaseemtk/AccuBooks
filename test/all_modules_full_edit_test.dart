import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/database/database_tables.dart';
import 'package:accubooks/models/account_model.dart';
import 'package:accubooks/models/company_model.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/repositories/account_repository.dart';
import 'package:accubooks/repositories/company_repository.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/controllers/product_controller.dart';
import 'package:accubooks/controllers/purchase_controller.dart';
import 'package:accubooks/controllers/purchase_order_controller.dart';
import 'package:accubooks/controllers/sales_controller.dart';
import 'package:accubooks/controllers/sales_order_controller.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/services/purchase_order_service.dart';
import 'package:accubooks/services/purchase_service.dart';
import 'package:accubooks/services/sales_order_service.dart';
import 'package:accubooks/services/sales_service.dart';

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

  group('All Modules Comprehensive Field & Line-Item Editing Verification', () {
    final accountRepo = AccountRepository();
    final customerRepo = CustomerRepository();
    final supplierRepo = SupplierRepository();
    final productRepo = ProductRepository();
    final companyRepo = CompanyRepository();
    final salesService = SalesService();
    final salesOrderService = SalesOrderService();
    final purchaseService = PurchaseService();
    final purchaseOrderService = PurchaseOrderService();
    final dbHelper = DatabaseHelper();

    test('1. Account: Opening Balance & Type are fully editable & sync journal entry', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final acc = AccountModel(
        accountCode: 'ACC-EDIT-$ts',
        accountName: 'Editable Account $ts',
        accountType: AccountingConstants.typeAsset,
        openingBalance: 1000.0,
        openingBalanceType: 'Debit',
        isActive: true,
      );

      final id = await accountRepo.insertAccount(acc);
      expect(id, isPositive);

      final created = await accountRepo.getAccountById(id);
      expect(created!.openingBalance, 1000.0);
      expect(created.currentBalance, 1000.0);

      // Verify OB journal entry created
      final db = await dbHelper.database;
      final obEntries = await db.query(
        DatabaseTables.tableJournalEntries,
        where: 'transaction_number = ?',
        whereArgs: ['OB-ACC-EDIT-$ts'],
      );
      expect(obEntries.isNotEmpty, isTrue);

      // Now edit opening balance to 2500 and type to Credit
      final updatedAcc = created.copyWith(
        accountName: 'Renamed Editable Account $ts',
        openingBalance: 2500.0,
        openingBalanceType: 'Credit',
      );
      final ok = await accountRepo.updateAccount(updatedAcc);
      expect(ok > 0, isTrue);

      final reloaded = await accountRepo.getAccountById(id);
      expect(reloaded!.accountName, 'Renamed Editable Account $ts');
      expect(reloaded.openingBalance, 2500.0);
      expect(reloaded.openingBalanceType, 'Credit');
      expect(reloaded.currentBalance, -2500.0);

      // Verify OB journal entry synchronized and still balanced
      final updatedEntries = await db.query(
        DatabaseTables.tableJournalEntries,
        where: 'transaction_number = ?',
        whereArgs: ['OB-ACC-EDIT-$ts'],
      );
      expect(updatedEntries.isNotEmpty, isTrue);
    });

    test('2. Customer & Supplier: Opening Balance & Type are editable', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;

      // Customer
      final cust = CustomerModel(
        customerCode: 'CUST-ED-$ts',
        name: 'Cust Editable $ts',
        phone: '98765$ts',
        email: 'cust$ts@test.com',
        openingBalance: 500.0,
        openingBalanceType: 'Debit',
      );
      final cId = await customerRepo.insertCustomer(cust);
      final createdCust = await customerRepo.getCustomerById(cId);
      expect(createdCust!.openingBalance, 500.0);
      expect(createdCust.outstandingBalance, 500.0);

      final updatedCust = createdCust.copyWith(
        name: 'Cust Updated $ts',
        openingBalance: 1500.0,
        openingBalanceType: 'Credit',
      );
      await customerRepo.updateCustomer(updatedCust);
      final reloadedCust = await customerRepo.getCustomerById(cId);
      expect(reloadedCust!.name, 'Cust Updated $ts');
      expect(reloadedCust.openingBalance, 1500.0);
      expect(reloadedCust.openingBalanceType, 'Credit');
      expect(reloadedCust.outstandingBalance, -1500.0);

      // Supplier
      final sup = SupplierModel(
        supplierCode: 'SUP-ED-$ts',
        name: 'Sup Editable $ts',
        phone: '87654$ts',
        email: 'sup$ts@test.com',
        openingBalance: 800.0,
        openingBalanceType: 'Credit',
      );
      final sId = await supplierRepo.insertSupplier(sup);
      final createdSup = await supplierRepo.getSupplierById(sId);
      expect(createdSup!.openingBalance, 800.0);
      expect(createdSup.outstandingBalance, 800.0);

      final updatedSup = createdSup.copyWith(
        name: 'Sup Updated $ts',
        openingBalance: 2000.0,
        openingBalanceType: 'Debit',
      );
      await supplierRepo.updateSupplier(updatedSup);
      final reloadedSup = await supplierRepo.getSupplierById(sId);
      expect(reloadedSup!.name, 'Sup Updated $ts');
      expect(reloadedSup.openingBalance, 2000.0);
      expect(reloadedSup.openingBalanceType, 'Debit');
      expect(reloadedSup.outstandingBalance, -2000.0);
    });

    test('3. Product: Stock quantity edit logs stock adjustment transaction', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final prod = ProductModel(
        productCode: 'PRD-STK-$ts',
        name: 'Stock Track Product $ts',
        salesPrice: 200.0,
        purchasePrice: 120.0,
        stockQuantity: 10.0,
        minimumStock: 2.0,
      );
      final pId = await productRepo.insertProduct(prod);
      final createdProd = await productRepo.getProductById(pId);
      expect(createdProd!.stockQuantity, 10.0);

      final prodCtrl = ProductController(productRepo: productRepo);
      await prodCtrl.loadProducts();

      // Edit product with new stock quantity = 25.0
      final editedProd = createdProd.copyWith(
        name: 'Stock Track Product Updated $ts',
        stockQuantity: 25.0,
      );
      final saved = await prodCtrl.saveProduct(editedProd);
      expect(saved, isTrue);

      final reloaded = await productRepo.getProductById(pId);
      expect(reloaded!.stockQuantity, 25.0);

      // Verify stock movement logged (+15)
      final history = await productRepo.getStockTransactions(pId);
      expect(history.any((t) => t.quantityIn == 15.0 && t.transactionType == AccountingConstants.stockAdjustment), isTrue);
    });

    test('4. Sales Order: Items editing and order discount persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final cId = await customerRepo.insertCustomer(CustomerModel(customerCode: 'CUST-SO-$ts', name: 'SO Customer $ts'));
      final pId = await productRepo.insertProduct(ProductModel(
        productCode: 'SO-P-$ts',
        name: 'SO Product $ts',
        salesPrice: 100.0,
        purchasePrice: 60.0,
      ));

      final orderCtrl = SalesOrderController(service: salesOrderService, customerRepo: customerRepo, productRepo: productRepo);
      await orderCtrl.loadMetadata();
      await orderCtrl.prepareNewOrderForm();

      orderCtrl.formOrderCustomer.value = orderCtrl.customers.firstWhere((c) => c.id == cId);
      orderCtrl.addOrderItem(orderCtrl.products.firstWhere((p) => p.id == pId), 2.0, 100.0, 10.0);
      orderCtrl.formOrderDiscount.value = 20.0;

      final ok = await orderCtrl.submitOrder();
      expect(ok, isTrue);

      final orderId = orderCtrl.selectedOrder.value!.id!;
      final fullOrder = await salesOrderService.getOrderById(orderId);
      expect(fullOrder!.discount, 20.0);
      expect(fullOrder.items.length, 1);
      expect(fullOrder.items[0].quantity, 2.0);

      // Now edit order: change item qty to 5, rate to 120, discount to 30, and order discount to 50
      await orderCtrl.prepareEditOrderForm(fullOrder);
      expect(orderCtrl.formOrderDiscount.value, 20.0);
      orderCtrl.updateOrderItem(0, 5.0, 120.0, 30.0);
      orderCtrl.formOrderDiscount.value = 50.0;

      final updatedOk = await orderCtrl.submitOrder();
      expect(updatedOk, isTrue);

      final reloadedOrder = await salesOrderService.getOrderById(orderId);
      expect(reloadedOrder!.discount, 50.0);
      expect(reloadedOrder.items[0].quantity, 5.0);
      expect(reloadedOrder.items[0].rate, 120.0);
      expect(reloadedOrder.items[0].discount, 30.0);
    });

    test('5. Sales Return: Items editing and extra discount persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final cId = await customerRepo.insertCustomer(CustomerModel(customerCode: 'CUST-SR-$ts', name: 'SR Customer $ts'));
      final pId = await productRepo.insertProduct(ProductModel(
        productCode: 'SR-P-$ts',
        name: 'SR Product $ts',
        salesPrice: 150.0,
        purchasePrice: 90.0,
      ));

      final orderCtrl = SalesOrderController(service: salesOrderService, customerRepo: customerRepo, productRepo: productRepo);
      await orderCtrl.loadMetadata();
      await orderCtrl.prepareNewReturnForm();

      orderCtrl.formReturnCustomer.value = orderCtrl.customers.firstWhere((c) => c.id == cId);
      orderCtrl.addReturnItem(orderCtrl.products.firstWhere((p) => p.id == pId), 3.0, 150.0, 15.0);
      orderCtrl.formReturnDiscount.value = 25.0;

      final ok = await orderCtrl.submitReturn();
      expect(ok, isTrue);

      final returnId = orderCtrl.selectedReturn.value!.id!;
      final fullReturn = await salesOrderService.getReturnById(returnId);
      expect(fullReturn!.discount, 25.0);
      expect(fullReturn.items[0].quantity, 3.0);

      // Edit return: update item qty to 6 and discount to 40
      await orderCtrl.prepareEditReturnForm(fullReturn);
      orderCtrl.updateReturnItem(0, 6.0, 150.0, 20.0);
      orderCtrl.formReturnDiscount.value = 40.0;

      final updatedOk = await orderCtrl.submitReturn();
      expect(updatedOk, isTrue);

      final reloadedReturn = await salesOrderService.getReturnById(returnId);
      expect(reloadedReturn!.discount, 40.0);
      expect(reloadedReturn.items[0].quantity, 6.0);
    });

    test('6. Purchase Order: Items editing and order discount persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final sId = await supplierRepo.insertSupplier(SupplierModel(supplierCode: 'SUP-PO-$ts', name: 'PO Supplier $ts'));
      final pId = await productRepo.insertProduct(ProductModel(
        productCode: 'PO-P-$ts',
        name: 'PO Product $ts',
        salesPrice: 80.0,
        purchasePrice: 50.0,
      ));

      final poCtrl = PurchaseOrderController(service: purchaseOrderService, supplierRepo: supplierRepo, productRepo: productRepo);
      await poCtrl.loadMetadata();
      await poCtrl.prepareNewOrderForm();

      poCtrl.formOrderSupplier.value = poCtrl.suppliers.firstWhere((s) => s.id == sId);
      poCtrl.addOrderItem(poCtrl.products.firstWhere((p) => p.id == pId), 4.0, 50.0, 5.0);
      poCtrl.formOrderDiscount.value = 15.0;

      final ok = await poCtrl.submitOrder();
      expect(ok, isTrue);

      final orderId = poCtrl.selectedOrder.value!.id!;
      final fullOrder = await purchaseOrderService.getOrderById(orderId);
      expect(fullOrder!.discount, 15.0);
      expect(fullOrder.items[0].quantity, 4.0);

      // Edit purchase order: update item qty to 8, rate to 55, discount to 30
      await poCtrl.prepareEditOrderForm(fullOrder);
      poCtrl.updateOrderItem(0, 8.0, 55.0, 10.0);
      poCtrl.formOrderDiscount.value = 30.0;

      final updatedOk = await poCtrl.submitOrder();
      expect(updatedOk, isTrue);

      final reloadedOrder = await purchaseOrderService.getOrderById(orderId);
      expect(reloadedOrder!.discount, 30.0);
      expect(reloadedOrder.items[0].quantity, 8.0);
      expect(reloadedOrder.items[0].rate, 55.0);
    });

    test('7. Purchase Return: Items editing and extra discount persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final sId = await supplierRepo.insertSupplier(SupplierModel(supplierCode: 'SUP-PR-$ts', name: 'PR Supplier $ts'));
      final pId = await productRepo.insertProduct(ProductModel(
        productCode: 'PR-P-$ts',
        name: 'PR Product $ts',
        salesPrice: 120.0,
        purchasePrice: 70.0,
        stockQuantity: 100.0,
      ));

      final poCtrl = PurchaseOrderController(service: purchaseOrderService, supplierRepo: supplierRepo, productRepo: productRepo);
      await poCtrl.loadMetadata();
      await poCtrl.prepareNewReturnForm();

      poCtrl.formReturnSupplier.value = poCtrl.suppliers.firstWhere((s) => s.id == sId);
      poCtrl.addReturnItem(poCtrl.products.firstWhere((p) => p.id == pId), 5.0, 70.0, 10.0);
      poCtrl.formReturnDiscount.value = 20.0;

      final ok = await poCtrl.submitReturn();
      expect(ok, isTrue);

      final returnId = poCtrl.selectedReturn.value!.id!;
      final fullReturn = await purchaseOrderService.getReturnById(returnId);
      expect(fullReturn!.discount, 20.0);
      expect(fullReturn.items[0].quantity, 5.0);

      // Edit return: update item qty to 7, discount to 35
      await poCtrl.prepareEditReturnForm(fullReturn);
      poCtrl.updateReturnItem(0, 7.0, 70.0, 15.0);
      poCtrl.formReturnDiscount.value = 35.0;

      final updatedOk = await poCtrl.submitReturn();
      expect(updatedOk, isTrue);

      final reloadedReturn = await purchaseOrderService.getReturnById(returnId);
      expect(reloadedReturn!.discount, 35.0);
      expect(reloadedReturn.items[0].quantity, 7.0);
    });

    test('8. Sales & Purchase Invoices: updateFormItem and discount persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch % 100000;
      final cId = await customerRepo.insertCustomer(CustomerModel(customerCode: 'CUST-INV-$ts', name: 'Inv Customer $ts'));
      final sId = await supplierRepo.insertSupplier(SupplierModel(supplierCode: 'SUP-BILL-$ts', name: 'Bill Supplier $ts'));
      final pId = await productRepo.insertProduct(ProductModel(
        productCode: 'INV-P-$ts',
        name: 'Invoice Product $ts',
        salesPrice: 200.0,
        purchasePrice: 100.0,
        stockQuantity: 50.0,
      ));

      // Sales Invoice line item update
      final salesCtrl = SalesController(salesService: salesService, customerRepo: customerRepo, productRepo: productRepo);
      await salesCtrl.loadMetadata();
      await salesCtrl.prepareNewInvoiceForm();
      final prod = salesCtrl.products.firstWhere((p) => p.id == pId);

      salesCtrl.formSelectedCustomer.value = salesCtrl.customers.firstWhere((c) => c.id == cId);
      salesCtrl.addFormItem(prod, 1.0, 200.0, 0.0);
      salesCtrl.formDiscount.value = 10.0;

      // Update the line item using updateFormItem
      salesCtrl.updateFormItem(0, prod, 3.0, 210.0, 15.0);
      expect(salesCtrl.formItems[0].quantity, 3.0);
      expect(salesCtrl.formItems[0].rate, 210.0);
      expect(salesCtrl.formItems[0].discount, 15.0);

      final salesOk = await salesCtrl.submitInvoice();
      expect(salesOk, isTrue);

      // Purchase Invoice line item update
      final purchCtrl = PurchaseController(purchaseService: purchaseService, supplierRepo: supplierRepo, productRepo: productRepo);
      await purchCtrl.loadMetadata();
      await purchCtrl.prepareNewPurchaseForm();

      purchCtrl.formSelectedSupplier.value = purchCtrl.suppliers.firstWhere((s) => s.id == sId);
      purchCtrl.addFormItem(prod, 2.0, 100.0, 0.0);
      purchCtrl.formDiscount.value = 12.0;

      // Update the line item using updateFormItem
      purchCtrl.updateFormItem(0, prod, 5.0, 105.0, 20.0);
      expect(purchCtrl.formItems[0].quantity, 5.0);
      expect(purchCtrl.formItems[0].rate, 105.0);
      expect(purchCtrl.formItems[0].discount, 20.0);

      final purchOk = await purchCtrl.submitPurchase();
      expect(purchOk, isTrue);
    });

    test('9. Company Settings: updateCompany persists all modified company fields', () async {
      final settingsCtrl = SettingsController(companyRepo: companyRepo);
      await settingsCtrl.loadSettings();

      final current = settingsCtrl.company.value ?? CompanyModel(name: 'Default Corp');
      final updated = current.copyWith(
        name: 'AccuBooks Enterprise Pvt Ltd',
        address: '100 Financial District, Tech Park',
        phone: '+91 9998887776',
        email: 'billing@accubooks.local',
        taxNumber: 'GSTIN29ABCDE1234F1Z5',
        currency: '₹',
        updatedAt: DateTime.now(),
      );

      final ok = await settingsCtrl.updateCompany(updated);
      expect(ok, isTrue);

      final reloadedComp = await companyRepo.getCompany();
      expect(reloadedComp!.name, 'AccuBooks Enterprise Pvt Ltd');
      expect(reloadedComp.address, '100 Financial District, Tech Park');
      expect(reloadedComp.phone, '+91 9998887776');
      expect(reloadedComp.email, 'billing@accubooks.local');
      expect(reloadedComp.taxNumber, 'GSTIN29ABCDE1234F1Z5');
      expect(reloadedComp.currency, '₹');
    });
  });
}
