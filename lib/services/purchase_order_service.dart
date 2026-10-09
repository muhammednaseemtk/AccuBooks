import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../models/journal_line_model.dart';
import '../models/purchase_order_item_model.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_return_item_model.dart';
import '../models/purchase_return_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/purchase_order_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/supplier_repository.dart';
import 'accounting_service.dart';

class PurchaseOrderService {
  final PurchaseOrderRepository _orderRepo;
  final PurchaseRepository _purchaseRepo;
  final ProductRepository _productRepo;
  final SupplierRepository _supplierRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  PurchaseOrderService({
    PurchaseOrderRepository? orderRepo,
    PurchaseRepository? purchaseRepo,
    ProductRepository? productRepo,
    SupplierRepository? supplierRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _orderRepo = orderRepo ?? PurchaseOrderRepository(),
        _purchaseRepo = purchaseRepo ?? PurchaseRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _supplierRepo = supplierRepo ?? SupplierRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  Future<String> getNextOrderNumber() async {
    return await _orderRepo.getNextOrderNumber();
  }

  Future<String> getNextReturnNumber() async {
    return await _orderRepo.getNextReturnNumber();
  }

  Future<List<PurchaseOrderModel>> getAllOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? status,
    String? search,
  }) async {
    return await _orderRepo.getAllPurchaseOrders(
      fromDate: fromDate,
      toDate: toDate,
      supplierId: supplierId,
      status: status,
      search: search,
    );
  }

  Future<PurchaseOrderModel?> getOrderById(int id) async {
    return await _orderRepo.getPurchaseOrderById(id);
  }

  Future<List<PurchaseReturnModel>> getAllReturns({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? search,
  }) async {
    return await _orderRepo.getAllPurchaseReturns(
      fromDate: fromDate,
      toDate: toDate,
      supplierId: supplierId,
      search: search,
    );
  }

  Future<PurchaseReturnModel?> getReturnById(int id) async {
    return await _orderRepo.getPurchaseReturnById(id);
  }

  /// Create Purchase Order (Non-posting: no inventory change, no journal entries)
  Future<int> createPurchaseOrder({
    required PurchaseOrderModel order,
    required List<PurchaseOrderItemModel> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('Purchase Order must contain at least one product item.');
    }

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(order.discount);

    final processedItems = <PurchaseOrderItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }
      final itemTax = PurchaseOrderItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = PurchaseOrderItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
      subtotal += (item.quantity * item.rate) - item.discount;
      taxAmount += itemTax;

      processedItems.add(item.copyWith(
        taxAmount: itemTax,
        total: itemTotal,
      ));
    }

    subtotal = CurrencyUtils.round(subtotal);
    taxAmount = CurrencyUtils.round(taxAmount);
    final grandTotal = CurrencyUtils.round((subtotal - totalDiscount) + taxAmount);

    String orderNumber = order.orderNumber.trim();
    if (orderNumber.isEmpty) {
      orderNumber = await getNextOrderNumber();
    }

    final supplier = await _supplierRepo.getSupplierById(order.supplierId);
    if (supplier == null) {
      throw Exception('Supplier not found with ID: ${order.supplierId}');
    }

    for (final item in processedItems) {
      final p = await _productRepo.getProductById(item.productId);
      if (p == null) {
        throw Exception('Product not found with ID: ${item.productId}');
      }
    }

    final finalOrder = order.copyWith(
      orderNumber: orderNumber,
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
    );

    return await _dbHelper.transaction<int>((txn) async {
      final orderId = await _orderRepo.insertPurchaseOrder(finalOrder, txn: txn);
      await _orderRepo.insertPurchaseOrderItems(orderId, processedItems, txn: txn);
      return orderId;
    });
  }

  /// Create Purchase Return (Financial & stock posting: decreases inventory, reverses purchase journal)
  Future<int> createPurchaseReturn({
    required PurchaseReturnModel returnModel,
    required List<PurchaseReturnItemModel> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('Purchase Return must contain at least one product item.');
    }

    // 1. Validation & recalculation
    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(returnModel.discount);

    final processedItems = <PurchaseReturnItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }

      final itemTax = PurchaseReturnItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = PurchaseReturnItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
      subtotal += (item.quantity * item.rate) - item.discount;
      taxAmount += itemTax;

      processedItems.add(item.copyWith(
        taxAmount: itemTax,
        total: itemTotal,
      ));
    }

    subtotal = CurrencyUtils.round(subtotal);
    taxAmount = CurrencyUtils.round(taxAmount);
    final grandTotal = CurrencyUtils.round((subtotal - totalDiscount) + taxAmount);

    String returnNumber = returnModel.returnNumber.trim();
    if (returnNumber.isEmpty) {
      returnNumber = await getNextReturnNumber();
    }

    final supplier = await _supplierRepo.getSupplierById(returnModel.supplierId);
    if (supplier == null) {
      throw Exception('Supplier not found with ID: ${returnModel.supplierId}');
    }

    // If reference invoice is provided, validate return quantities against invoice
    if (returnModel.referenceInvoiceId != null) {
      final invoice = await _purchaseRepo.getPurchaseInvoiceById(returnModel.referenceInvoiceId!);
      if (invoice != null) {
        final db = await _dbHelper.database;
        for (final item in processedItems) {
          final invoiceItem = invoice.items.firstWhere(
            (invItem) => invItem.productId == item.productId,
            orElse: () => throw Exception('Product ID ${item.productId} was not part of invoice #${invoice.invoiceNumber}.'),
          );

          // Calculate already returned quantity for this invoice and product
          final prevReturnsRes = await db.rawQuery('''
            SELECT COALESCE(SUM(pri.quantity), 0.0) as already_returned
            FROM ${DatabaseTables.tablePurchaseReturnItems} pri
            JOIN ${DatabaseTables.tablePurchaseReturns} pr ON pri.return_id = pr.id
            WHERE pr.reference_invoice_id = ? AND pri.product_id = ? AND pr.status != ?
          ''', [returnModel.referenceInvoiceId, item.productId, AccountingConstants.statusCancelled]);
          final alreadyReturned = (prevReturnsRes.first['already_returned'] as num?)?.toDouble() ?? 0.0;

          final maxAllowed = invoiceItem.quantity - alreadyReturned;
          if (item.quantity > maxAllowed) {
            throw Exception('Cannot return ${item.quantity} for "${invoiceItem.productName ?? 'Product'}". Maximum returnable quantity is $maxAllowed.');
          }
        }
      }
    }

    // Check inventory availability (cannot return more stock than is on hand)
    for (final item in processedItems) {
      final product = await _productRepo.getProductById(item.productId);
      if (product == null) {
        throw Exception('Product not found with ID: ${item.productId}');
      }
      if (product.stockQuantity < item.quantity) {
        throw Exception('Cannot return ${item.quantity} for "${product.name}". Available stock is only ${product.stockQuantity}.');
      }
    }

    // Accounts mapping for reversal journal
    int payableAccountId;
    if (supplier.accountId != null) {
      payableAccountId = supplier.accountId!;
    } else {
      final payAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsPayable);
      payableAccountId = payAcc?.id ?? 5;
    }

    final purchasesAcc = await _accountRepo.getAccountByCode(AccountingConstants.codePurchases);
    final purchasesAccountId = purchasesAcc?.id ?? 13;

    final gstInputAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit);
    final gstInputAccountId = gstInputAcc?.id ?? 7;

    int discountReceivedAccountId = 12;
    if (totalDiscount > 0) {
      final discAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountReceived);
      discountReceivedAccountId = discAcc?.id ?? 12;
    }

    final finalReturn = returnModel.copyWith(
      returnNumber: returnNumber,
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
    );

    return await _dbHelper.transaction<int>((txn) async {
      // Step A: Save return header
      final returnId = await _orderRepo.insertPurchaseReturn(finalReturn, txn: txn);

      // Step B: Save return items
      await _orderRepo.insertPurchaseReturnItems(returnId, processedItems, txn: txn);

      // Step C: Decrease stock by returned quantity
      for (final item in processedItems) {
        await _productRepo.updateStock(
          item.productId,
          -item.quantity, // Negative delta decreases stock
          transactionType: AccountingConstants.stockPurchaseReturn,
          referenceId: returnId,
          rate: item.rate,
          txn: txn,
        );
      }

      // Step D: Balanced Reversal Journal Lines
      // Supplier Payable Debit = grandTotal
      // Discount Received Debit = totalDiscount (if > 0)
      // Purchases Account Credit = subtotal
      // GST Input Tax Credit Credit = taxAmount (if > 0)
      // Total Debit = grandTotal + totalDiscount = (subtotal - totalDiscount + taxAmount) + totalDiscount = subtotal + taxAmount
      // Total Credit = subtotal + taxAmount
      final journalLines = <JournalLineModel>[];

      journalLines.add(JournalLineModel(
        accountId: payableAccountId,
        debit: grandTotal,
        credit: 0.0,
        description: 'Purchase Return #${finalReturn.returnNumber} - Supplier Debit: ${supplier.name}',
      ));

      if (totalDiscount > 0) {
        journalLines.add(JournalLineModel(
          accountId: discountReceivedAccountId,
          debit: totalDiscount,
          credit: 0.0,
          description: 'Discount Received Reversal on Return #${finalReturn.returnNumber}',
        ));
      }

      journalLines.add(JournalLineModel(
        accountId: purchasesAccountId,
        debit: 0.0,
        credit: subtotal,
        description: 'Purchase Return #${finalReturn.returnNumber} - Purchases Reversal',
      ));

      if (taxAmount > 0) {
        journalLines.add(JournalLineModel(
          accountId: gstInputAccountId,
          debit: 0.0,
          credit: taxAmount,
          description: 'GST Input Tax Credit Reversal on Return #${finalReturn.returnNumber}',
        ));
      }

      // Step E: Post Balanced Journal Entry
      await _accountingService.createJournalEntry(
        date: finalReturn.returnDate,
        type: AccountingConstants.transTypePurchaseReturn,
        description: 'Purchase Return #${finalReturn.returnNumber} to ${supplier.name}',
        referenceId: returnId,
        transactionNumber: 'JV-PR-$returnId',
        lines: journalLines,
        txn: txn,
      );

      return returnId;
    });
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _orderRepo.updatePurchaseOrderStatus(orderId, status);
  }

  Future<int> updatePurchaseOrder({
    required PurchaseOrderModel order,
    required List<PurchaseOrderItemModel> items,
  }) async {
    if (order.id == null) throw Exception('Order ID is required for update.');
    if (items.isEmpty) throw Exception('Purchase Order must contain at least one item.');

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(order.discount);

    final processedItems = <PurchaseOrderItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) throw Exception('Quantity must be greater than zero for all items.');
      if (item.rate < 0) throw Exception('Rate cannot be negative.');

      final itemTax = PurchaseOrderItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = PurchaseOrderItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
      subtotal += (item.quantity * item.rate) - item.discount;
      taxAmount += itemTax;

      processedItems.add(item.copyWith(
        orderId: order.id,
        taxAmount: itemTax,
        total: itemTotal,
      ));
    }

    subtotal = CurrencyUtils.round(subtotal);
    taxAmount = CurrencyUtils.round(taxAmount);
    final grandTotal = CurrencyUtils.round((subtotal - totalDiscount) + taxAmount);

    final finalOrder = order.copyWith(
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      updatedAt: DateTime.now(),
    );

    return await _dbHelper.transaction<int>((txn) async {
      await _orderRepo.updatePurchaseOrder(finalOrder, txn: txn);
      await _orderRepo.deletePurchaseOrderItems(order.id!, txn: txn);
      await _orderRepo.insertPurchaseOrderItems(order.id!, processedItems, txn: txn);
      return order.id!;
    });
  }

  Future<void> deletePurchaseOrder(int orderId) async {
    final order = await _orderRepo.getPurchaseOrderById(orderId);
    if (order == null) throw Exception('Purchase order not found: $orderId');
    if (order.status == AccountingConstants.statusCompleted) {
      throw Exception('Cannot delete purchase order that has already been completed or invoiced.');
    }
    await _orderRepo.deletePurchaseOrder(orderId);
  }

  Future<int> updatePurchaseReturn({
    required PurchaseReturnModel returnModel,
    required List<PurchaseReturnItemModel> items,
  }) async {
    if (returnModel.id == null) throw Exception('Return ID is required for update.');
    final oldReturn = await _orderRepo.getPurchaseReturnById(returnModel.id!);
    if (oldReturn == null) throw Exception('Purchase return not found: ${returnModel.id}');
    if (items.isEmpty) throw Exception('Purchase Return must contain at least one item.');

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(returnModel.discount);

    final processedItems = <PurchaseReturnItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) throw Exception('Quantity must be greater than zero.');
      if (item.rate < 0) throw Exception('Rate cannot be negative.');

      final itemTax = PurchaseReturnItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = PurchaseReturnItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
      subtotal += (item.quantity * item.rate) - item.discount;
      taxAmount += itemTax;

      processedItems.add(item.copyWith(
        returnId: returnModel.id,
        taxAmount: itemTax,
        total: itemTotal,
      ));
    }

    subtotal = CurrencyUtils.round(subtotal);
    taxAmount = CurrencyUtils.round(taxAmount);
    final grandTotal = CurrencyUtils.round((subtotal - totalDiscount) + taxAmount);

    final supplier = await _supplierRepo.getSupplierById(returnModel.supplierId);
    if (supplier == null) throw Exception('Supplier not found: ${returnModel.supplierId}');

    final finalReturn = returnModel.copyWith(
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      updatedAt: DateTime.now(),
    );

    int payableAccountId = supplier.accountId ??
        (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsPayable))?.id ??
        5;
    final purchasesAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codePurchases))?.id ?? 13;
    final gstInputAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit))?.id ?? 7;
    final discountReceivedAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountReceived))?.id ?? 12;

    await _dbHelper.transaction((txn) async {
      // 1. Revert previous stock deduction (add stock back)
      for (final oldItem in oldReturn.items) {
        await _productRepo.updateStock(
          oldItem.productId,
          oldItem.quantity,
          transactionType: AccountingConstants.stockPurchase,
          referenceId: returnModel.id!,
          rate: oldItem.rate,
          txn: txn,
        );
      }

      // 2. Remove old return stock transactions
      await txn.delete(
        DatabaseTables.tableStockTransactions,
        where: 'reference_id = ? AND transaction_type = ?',
        whereArgs: [returnModel.id!, AccountingConstants.stockPurchaseReturn],
      );

      // 3. Apply new stock deduction (negative delta)
      for (final newItem in processedItems) {
        await _productRepo.updateStock(
          newItem.productId,
          -newItem.quantity,
          transactionType: AccountingConstants.stockPurchaseReturn,
          referenceId: returnModel.id!,
          rate: newItem.rate,
          txn: txn,
        );
      }

      // 4. Update items table & return header
      await _orderRepo.deletePurchaseReturnItems(returnModel.id!, txn: txn);
      await _orderRepo.insertPurchaseReturnItems(returnModel.id!, processedItems, txn: txn);
      await _orderRepo.updatePurchaseReturn(finalReturn, txn: txn);

      // 5. Update balanced journal entry
      final journalLines = <JournalLineModel>[
        JournalLineModel(
          accountId: payableAccountId,
          debit: grandTotal,
          credit: 0.0,
          description: 'Purchase Return #${finalReturn.returnNumber} - Supplier Debit',
        ),
      ];

      if (totalDiscount > 0) {
        journalLines.add(JournalLineModel(
          accountId: discountReceivedAccountId,
          debit: totalDiscount,
          credit: 0.0,
          description: 'Discount Reversal on Purchase Return #${finalReturn.returnNumber}',
        ));
      }

      journalLines.add(JournalLineModel(
        accountId: purchasesAccountId,
        debit: 0.0,
        credit: subtotal,
        description: 'Purchase Return #${finalReturn.returnNumber} - Purchases Credit',
      ));

      if (taxAmount > 0) {
        journalLines.add(JournalLineModel(
          accountId: gstInputAccountId,
          debit: 0.0,
          credit: taxAmount,
          description: 'GST Input Tax Credit Reversal on Return #${finalReturn.returnNumber}',
        ));
      }

      // Remove old return journal and post new
      final entries = await txn.query(
        DatabaseTables.tableJournalEntries,
        columns: ['id'],
        where: 'reference_id = ? AND transaction_type = ?',
        whereArgs: [returnModel.id!, AccountingConstants.transTypePurchaseReturn],
      );
      for (final e in entries) {
        final eId = e['id'] as int;
        await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
        await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
      }

      await _accountingService.createJournalEntry(
        date: finalReturn.returnDate,
        type: AccountingConstants.transTypePurchaseReturn,
        description: 'Purchase Return #${finalReturn.returnNumber} to ${supplier.name}',
        referenceId: returnModel.id!,
        transactionNumber: 'JV-PR-${returnModel.id!}',
        lines: journalLines,
        txn: txn,
      );
    });

    return returnModel.id!;
  }

  Future<void> deletePurchaseReturn(int returnId) async {
    final ret = await _orderRepo.getPurchaseReturnById(returnId);
    if (ret == null) throw Exception('Purchase return not found: $returnId');

    await _dbHelper.transaction((txn) async {
      // 1. Restore deducted inventory back (+qty)
      for (final item in ret.items) {
        await _productRepo.updateStock(
          item.productId,
          item.quantity,
          transactionType: AccountingConstants.stockPurchase,
          referenceId: returnId,
          rate: item.rate,
          txn: txn,
        );
      }

      // 2. Remove stock transactions
      await txn.delete(
        DatabaseTables.tableStockTransactions,
        where: 'reference_id = ? AND transaction_type = ?',
        whereArgs: [returnId, AccountingConstants.stockPurchaseReturn],
      );

      // 3. Remove journal entries & lines
      final entries = await txn.query(
        DatabaseTables.tableJournalEntries,
        columns: ['id'],
        where: 'reference_id = ? AND transaction_type = ?',
        whereArgs: [returnId, AccountingConstants.transTypePurchaseReturn],
      );
      for (final e in entries) {
        final eId = e['id'] as int;
        await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
        await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
      }

      // 4. Delete return and items
      await _orderRepo.deletePurchaseReturn(returnId, txn: txn);
    });
  }
}

