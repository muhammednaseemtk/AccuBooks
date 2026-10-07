import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../models/journal_line_model.dart';
import '../models/sales_order_item_model.dart';
import '../models/sales_order_model.dart';
import '../models/sales_return_item_model.dart';
import '../models/sales_return_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sales_order_repository.dart';
import '../repositories/sales_repository.dart';
import 'accounting_service.dart';

class SalesOrderService {
  final SalesOrderRepository _orderRepo;
  final SalesRepository _salesRepo;
  final ProductRepository _productRepo;
  final CustomerRepository _customerRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  SalesOrderService({
    SalesOrderRepository? orderRepo,
    SalesRepository? salesRepo,
    ProductRepository? productRepo,
    CustomerRepository? customerRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _orderRepo = orderRepo ?? SalesOrderRepository(),
        _salesRepo = salesRepo ?? SalesRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _customerRepo = customerRepo ?? CustomerRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  Future<String> getNextOrderNumber() async {
    return await _orderRepo.getNextOrderNumber();
  }

  Future<String> getNextReturnNumber() async {
    return await _orderRepo.getNextReturnNumber();
  }

  Future<List<SalesOrderModel>> getAllOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? status,
    String? search,
  }) async {
    return await _orderRepo.getAllSalesOrders(
      fromDate: fromDate,
      toDate: toDate,
      customerId: customerId,
      status: status,
      search: search,
    );
  }

  Future<SalesOrderModel?> getOrderById(int id) async {
    return await _orderRepo.getSalesOrderById(id);
  }

  Future<List<SalesReturnModel>> getAllReturns({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? search,
  }) async {
    return await _orderRepo.getAllSalesReturns(
      fromDate: fromDate,
      toDate: toDate,
      customerId: customerId,
      search: search,
    );
  }

  Future<SalesReturnModel?> getReturnById(int id) async {
    return await _orderRepo.getSalesReturnById(id);
  }

  /// Create Sales Order (Non-posting: no inventory deduction, no journal entries)
  Future<int> createSalesOrder({
    required SalesOrderModel order,
    required List<SalesOrderItemModel> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('Sales Order must contain at least one product item.');
    }

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(order.discount);

    final processedItems = <SalesOrderItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }
      final itemTax = SalesOrderItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = SalesOrderItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
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

    final customer = await _customerRepo.getCustomerById(order.customerId);
    if (customer == null) {
      throw Exception('Customer not found with ID: ${order.customerId}');
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
      final orderId = await _orderRepo.insertSalesOrder(finalOrder, txn: txn);
      await _orderRepo.insertSalesOrderItems(orderId, processedItems, txn: txn);
      return orderId;
    });
  }

  /// Create Sales Return (Financial & stock posting: increases inventory, reverses sales journal)
  Future<int> createSalesReturn({
    required SalesReturnModel returnModel,
    required List<SalesReturnItemModel> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('Sales Return must contain at least one product item.');
    }

    // 1. Validation & recalculation
    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(returnModel.discount);

    final processedItems = <SalesReturnItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }

      final itemTax = SalesReturnItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = SalesReturnItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
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

    final customer = await _customerRepo.getCustomerById(returnModel.customerId);
    if (customer == null) {
      throw Exception('Customer not found with ID: ${returnModel.customerId}');
    }

    // If reference invoice is provided, validate return quantities against invoice
    if (returnModel.referenceInvoiceId != null) {
      final invoice = await _salesRepo.getSalesInvoiceById(returnModel.referenceInvoiceId!);
      if (invoice != null) {
        final db = await _dbHelper.database;
        for (final item in processedItems) {
          final invoiceItem = invoice.items.firstWhere(
            (invItem) => invItem.productId == item.productId,
            orElse: () => throw Exception('Product ID ${item.productId} was not part of invoice #${invoice.invoiceNumber}.'),
          );

          // Calculate already returned quantity for this invoice and product
          final prevReturnsRes = await db.rawQuery('''
            SELECT COALESCE(SUM(sri.quantity), 0.0) as already_returned
            FROM ${DatabaseTables.tableSalesReturnItems} sri
            JOIN ${DatabaseTables.tableSalesReturns} sr ON sri.return_id = sr.id
            WHERE sr.reference_invoice_id = ? AND sri.product_id = ? AND sr.status != ?
          ''', [returnModel.referenceInvoiceId, item.productId, AccountingConstants.statusCancelled]);
          final alreadyReturned = (prevReturnsRes.first['already_returned'] as num?)?.toDouble() ?? 0.0;

          final maxAllowed = invoiceItem.quantity - alreadyReturned;
          if (item.quantity > maxAllowed) {
            throw Exception('Cannot return ${item.quantity} for "${invoiceItem.productName ?? 'Product'}". Maximum returnable quantity is $maxAllowed.');
          }
        }
      }
    }

    // Account lookups for reversal journal
    int receivableAccountId;
    if (customer.accountId != null) {
      receivableAccountId = customer.accountId!;
    } else {
      final recvAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsReceivable);
      receivableAccountId = recvAcc?.id ?? 3;
    }

    final salesAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeSales);
    final salesAccountId = salesAcc?.id ?? 10;

    final gstAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeGstPayable);
    final gstAccountId = gstAcc?.id ?? 6;

    int discountAccountId = 16;
    if (totalDiscount > 0) {
      final discAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountAllowed);
      discountAccountId = discAcc?.id ?? 16;
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
      final returnId = await _orderRepo.insertSalesReturn(finalReturn, txn: txn);

      // Step B: Save return items
      await _orderRepo.insertSalesReturnItems(returnId, processedItems, txn: txn);

      // Step C: Increase stock by returned quantity
      for (final item in processedItems) {
        await _productRepo.updateStock(
          item.productId,
          item.quantity, // Positive delta increases stock
          transactionType: AccountingConstants.stockSalesReturn,
          referenceId: returnId,
          rate: item.rate,
          txn: txn,
        );
      }

      // Step D: Balanced Reversal Journal Lines
      // Sales Revenue Debit = subtotal
      // GST Output Tax Debit = taxAmount (if > 0)
      // Customer Receivable Credit = grandTotal
      // Discount Allowed Credit = totalDiscount (if > 0)
      // Total Debit = subtotal + taxAmount
      // Total Credit = grandTotal + totalDiscount = (subtotal - totalDiscount + taxAmount) + totalDiscount = subtotal + taxAmount
      final journalLines = <JournalLineModel>[];

      journalLines.add(JournalLineModel(
        accountId: salesAccountId,
        debit: subtotal,
        credit: 0.0,
        description: 'Sales Return #${finalReturn.returnNumber} - Revenue Reversal',
      ));

      if (taxAmount > 0) {
        journalLines.add(JournalLineModel(
          accountId: gstAccountId,
          debit: taxAmount,
          credit: 0.0,
          description: 'GST Output Tax Reversal on Return #${finalReturn.returnNumber}',
        ));
      }

      journalLines.add(JournalLineModel(
        accountId: receivableAccountId,
        debit: 0.0,
        credit: grandTotal,
        description: 'Sales Return #${finalReturn.returnNumber} - Customer Credit: ${customer.name}',
      ));

      if (totalDiscount > 0) {
        journalLines.add(JournalLineModel(
          accountId: discountAccountId,
          debit: 0.0,
          credit: totalDiscount,
          description: 'Discount Allowed Reversal on Return #${finalReturn.returnNumber}',
        ));
      }

      // Step E: Post Balanced Journal Entry
      await _accountingService.createJournalEntry(
        date: finalReturn.returnDate,
        type: AccountingConstants.transTypeSalesReturn,
        description: 'Sales Return #${finalReturn.returnNumber} from ${customer.name}',
        referenceId: returnId,
        transactionNumber: 'JV-SR-$returnId',
        lines: journalLines,
        txn: txn,
      );

      return returnId;
    });
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _orderRepo.updateSalesOrderStatus(orderId, status);
  }
}
