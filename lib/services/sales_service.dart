import 'package:flutter/foundation.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/journal_line_model.dart';
import '../models/sales_invoice_item_model.dart';
import '../models/sales_invoice_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sales_repository.dart';
import 'accounting_service.dart';

class SalesService {
  final SalesRepository _salesRepo;
  final ProductRepository _productRepo;
  final CustomerRepository _customerRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  SalesService({
    SalesRepository? salesRepo,
    ProductRepository? productRepo,
    CustomerRepository? customerRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _salesRepo = salesRepo ?? SalesRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _customerRepo = customerRepo ?? CustomerRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  Future<String> getNextInvoiceNumber() async {
    return await _salesRepo.getNextInvoiceNumber();
  }

  Future<List<SalesInvoiceModel>> getAllInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? paymentStatus,
    String? search,
  }) async {
    return await _salesRepo.getAllSalesInvoices(
      fromDate: fromDate,
      toDate: toDate,
      customerId: customerId,
      paymentStatus: paymentStatus,
      search: search,
    );
  }

  Future<SalesInvoiceModel?> getInvoiceById(int id) async {
    return await _salesRepo.getSalesInvoiceById(id);
  }

  /// Create and post a complete sales invoice inside an atomic SQLite transaction
  Future<int> createSalesInvoice({
    required SalesInvoiceModel invoice,
    required List<SalesInvoiceItemModel> items,
    int? paymentAccountId, // If paid immediately (Cash or Bank)
  }) async {
    if (items.isEmpty) {
      throw Exception('Invoice must contain at least one item.');
    }

    // 1. Validation & recalculation
    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(invoice.discount);

    final processedItems = <SalesInvoiceItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }
      final itemTax = SalesInvoiceItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = SalesInvoiceItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
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
    final paidAmount = CurrencyUtils.round(invoice.paidAmount);
    final balanceAmount = CurrencyUtils.round(grandTotal - paidAmount);

    String invoiceNumber = invoice.invoiceNumber.trim();
    if (invoiceNumber.isEmpty) {
      invoiceNumber = await getNextInvoiceNumber();
    }

    final finalInvoice = invoice.copyWith(
      invoiceNumber: invoiceNumber,
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      paymentStatus: SalesInvoiceModel.determineStatus(grandTotal, paidAmount),
    );

    // 2. Pre-transaction validation and account lookups to eliminate SQLite deadlocks
    final customer = await _customerRepo.getCustomerById(finalInvoice.customerId);
    if (customer == null) {
      throw Exception('Customer not found with ID: ${finalInvoice.customerId}');
    }

    for (final item in processedItems) {
      final p = await _productRepo.getProductById(item.productId);
      if (p == null) {
        throw Exception('Product not found with ID: ${item.productId}');
      }
    }

    // Receivable Account (Use customer linked account or default 1020)
    int receivableAccountId;
    if (customer.accountId != null) {
      receivableAccountId = customer.accountId!;
    } else {
      final recvAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsReceivable);
      receivableAccountId = recvAcc?.id ?? 3;
    }

    // Sales Revenue Account (4000)
    final salesAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeSales);
    final salesAccountId = salesAcc?.id ?? 10;

    // GST Payable Account (2010)
    final gstAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeGstPayable);
    final gstAccountId = gstAcc?.id ?? 6;

    // Discount Allowed Account (5060)
    int discountAccountId = 16;
    if (totalDiscount > 0) {
      final discAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountAllowed);
      discountAccountId = discAcc?.id ?? 16;
    }

    // Immediate payment account (default to Cash 1000 if not specified)
    int effectivePaymentAccountId = 1;
    if (paidAmount > 0) {
      if (paymentAccountId != null) {
        effectivePaymentAccountId = paymentAccountId;
      } else {
        final cashAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeCash);
        effectivePaymentAccountId = cashAcc?.id ?? 1;
      }
    }

    try {
      // 3. Atomic SQLite Transaction
      return await _dbHelper.transaction<int>((txn) async {
        // Step A: Save invoice header
        final invoiceId = await _salesRepo.insertSalesInvoice(finalInvoice, txn: txn);

        // Step B: Save invoice items
        await _salesRepo.insertSalesInvoiceItems(invoiceId, processedItems, txn: txn);

        // Step C: Deduct stock for each item
        for (final item in processedItems) {
          await _productRepo.updateStock(
            item.productId,
            -item.quantity, // negative delta
            transactionType: AccountingConstants.stockSale,
            referenceId: invoiceId,
            rate: item.rate,
            txn: txn,
          );
        }

        // Step D: Create double-entry journal lines
        final journalLines = <JournalLineModel>[];

        // Customer A/C (Receivable) Debit = Grand Total
        journalLines.add(JournalLineModel(
          accountId: receivableAccountId,
          debit: grandTotal,
          credit: 0.0,
          description: 'Sales Invoice #${finalInvoice.invoiceNumber} - ${customer.name}',
        ));

        // Discount Allowed A/C Debit = Total Discount (if > 0)
        if (totalDiscount > 0) {
          journalLines.add(JournalLineModel(
            accountId: discountAccountId,
            debit: totalDiscount,
            credit: 0.0,
            description: 'Discount allowed on Invoice #${finalInvoice.invoiceNumber}',
          ));
        }

        // Sales A/C Credit = Net Subtotal
        journalLines.add(JournalLineModel(
          accountId: salesAccountId,
          debit: 0.0,
          credit: subtotal,
          description: 'Sales Revenue from Invoice #${finalInvoice.invoiceNumber}',
        ));

        // Tax A/C Credit = Tax Amount (if > 0)
        if (taxAmount > 0) {
          journalLines.add(JournalLineModel(
            accountId: gstAccountId,
            debit: 0.0,
            credit: taxAmount,
            description: 'GST Output Tax on Invoice #${finalInvoice.invoiceNumber}',
          ));
        }

        // Step E: Post balanced Journal Entry
        await _accountingService.createJournalEntry(
          date: finalInvoice.invoiceDate,
          type: AccountingConstants.transTypeSales,
          description: 'Sales Invoice #${finalInvoice.invoiceNumber} to ${customer.name}',
          referenceId: invoiceId,
          transactionNumber: 'JV-SALES-$invoiceId',
          lines: journalLines,
          txn: txn,
        );

        // Step F: If payment is received on invoice, record immediate receipt in tableReceipts and journal
        if (paidAmount > 0) {
          final receiptNumber = 'REC-SALES-$invoiceId';
          await txn.insert(DatabaseTables.tableReceipts, {
            'receipt_number': receiptNumber,
            'receipt_date': AppDateUtils.formatDb(finalInvoice.invoiceDate),
            'customer_id': finalInvoice.customerId,
            'account_id': effectivePaymentAccountId,
            'amount': paidAmount,
            'payment_method': AccountingConstants.methodCash,
            'reference': finalInvoice.invoiceNumber,
            'notes': 'Payment on Invoice #${finalInvoice.invoiceNumber}',
            'created_at': AppDateUtils.formatDb(DateTime.now()),
          });

          final recLines = [
            JournalLineModel(
              accountId: effectivePaymentAccountId,
              debit: paidAmount,
              credit: 0.0,
              description: 'Payment received on Invoice #${finalInvoice.invoiceNumber}',
            ),
            JournalLineModel(
              accountId: receivableAccountId,
              debit: 0.0,
              credit: paidAmount,
              description: 'Customer credit for payment on Invoice #${finalInvoice.invoiceNumber}',
            ),
          ];

          await _accountingService.createJournalEntry(
            date: finalInvoice.invoiceDate,
            type: AccountingConstants.transTypeReceipt,
            description: 'Payment on Invoice #${finalInvoice.invoiceNumber}',
            referenceId: invoiceId,
            transactionNumber: 'JV-REC-SALES-$invoiceId',
            lines: recLines,
            txn: txn,
          );
        }

        return invoiceId;
      });
    } catch (e, stackTrace) {
      debugPrint('================= SALE INVOICE CREATION ERROR =================');
      debugPrint('Location: SalesService.createSalesInvoice');
      debugPrint('Invoice Number: ${finalInvoice.invoiceNumber}');
      debugPrint('Customer ID: ${finalInvoice.customerId} (${customer.name})');
      debugPrint('Item Count: ${processedItems.length}');
      for (int i = 0; i < processedItems.length; i++) {
        final it = processedItems[i];
        debugPrint('  Item #$i: Product ID=${it.productId}, Qty=${it.quantity}, Rate=${it.rate}, Discount=${it.discount}, TaxAmount=${it.taxAmount}, Total=${it.total}');
      }
      debugPrint('Subtotal: $subtotal');
      debugPrint('Discount: $totalDiscount');
      debugPrint('Tax Amount: $taxAmount');
      debugPrint('Grand Total: $grandTotal');
      debugPrint('Paid Amount: $paidAmount');
      debugPrint('Balance Amount: $balanceAmount');
      debugPrint('DB Error / Exception: $e');
      debugPrint('Stack Trace:\n$stackTrace');
      debugPrint('================================================================');
      rethrow;
    }
  }

  /// Cancel invoice: restores inventory, cancels journal entry, and marks cancelled
  Future<void> cancelSalesInvoice(int invoiceId, {required String reason}) async {
    final invoice = await _salesRepo.getSalesInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Invoice not found: $invoiceId');
    if (invoice.isCancelled) throw Exception('Invoice is already cancelled');

    final customer = await _customerRepo.getCustomerById(invoice.customerId);
    final receivableAccountId = customer?.accountId ??
        (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsReceivable))?.id ??
        3;
    final salesAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeSales))?.id ?? 10;
    final gstAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeGstPayable))?.id ?? 6;
    final discountAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountAllowed))?.id ?? 16;

    await _dbHelper.transaction((txn) async {
      // 1. Mark as cancelled
      await _salesRepo.cancelSalesInvoice(invoiceId, txn: txn);

      // 2. Restore inventory stock
      for (final item in invoice.items) {
        await _productRepo.updateStock(
          item.productId,
          item.quantity, // restore positive delta
          transactionType: AccountingConstants.stockSalesReturn,
          referenceId: invoiceId,
          rate: item.rate,
          txn: txn,
        );
      }

      // 3. Post reversal journal entry
      final reverseLines = <JournalLineModel>[
        JournalLineModel(
          accountId: receivableAccountId,
          debit: 0.0,
          credit: invoice.grandTotal,
          description: 'Cancellation reversal: ${invoice.invoiceNumber}',
        ),
      ];

      if (invoice.discount > 0) {
        reverseLines.add(JournalLineModel(
          accountId: discountAccountId,
          debit: 0.0,
          credit: invoice.discount,
          description: 'Discount reversal: ${invoice.invoiceNumber}',
        ));
      }

      reverseLines.add(JournalLineModel(
        accountId: salesAccountId,
        debit: invoice.subtotal,
        credit: 0.0,
        description: 'Sales reversal: ${invoice.invoiceNumber}',
      ));

      if (invoice.taxAmount > 0) {
        reverseLines.add(JournalLineModel(
          accountId: gstAccountId,
          debit: invoice.taxAmount,
          credit: 0.0,
          description: 'Tax output reversal: ${invoice.invoiceNumber}',
        ));
      }

      await _accountingService.createJournalEntry(
        date: DateTime.now(),
        type: AccountingConstants.transTypeSales,
        description: 'Reversal of Cancelled Invoice #${invoice.invoiceNumber}: $reason',
        referenceId: invoiceId,
        lines: reverseLines,
        txn: txn,
      );
    });
  }

  /// Delete sales invoice: reverses stock, removes associated journal entries and invoice
  Future<void> deleteSalesInvoice(int invoiceId) async {
    final invoice = await _salesRepo.getSalesInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Invoice not found: $invoiceId');

    await _dbHelper.transaction((txn) async {
      // 1. If invoice was not cancelled, restore inventory
      if (!invoice.isCancelled) {
        for (final item in invoice.items) {
          await _productRepo.updateStock(
            item.productId,
            item.quantity,
            transactionType: AccountingConstants.stockSalesReturn,
            referenceId: invoiceId,
            rate: item.rate,
            txn: txn,
          );
        }
      }

      // 2. Remove stock transactions directly linked to this sales invoice
      await txn.delete(
        DatabaseTables.tableStockTransactions,
        where: 'reference_id = ? AND transaction_type IN (?, ?)',
        whereArgs: [invoiceId, AccountingConstants.stockSale, AccountingConstants.stockSalesReturn],
      );

      // 3. Remove all journal entries (and cascading lines) linked to this sales invoice
      final entries = await txn.query(
        DatabaseTables.tableJournalEntries,
        columns: ['id'],
        where: '(reference_id = ? AND transaction_type IN (?, ?)) OR transaction_number LIKE ?',
        whereArgs: [invoiceId, AccountingConstants.transTypeSales, AccountingConstants.transTypeReceipt, '%-$invoiceId%'],
      );
      for (final e in entries) {
        final eId = e['id'] as int;
        await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
        await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
      }

      // 4. Remove immediate receipts linked to this invoice
      await txn.delete(
        DatabaseTables.tableReceipts,
        where: "reference = ? OR notes LIKE ?",
        whereArgs: [invoice.invoiceNumber, '%#${invoice.invoiceNumber}%'],
      );

      // 5. Delete items and invoice
      await txn.delete(DatabaseTables.tableSalesInvoiceItems, where: 'invoice_id = ?', whereArgs: [invoiceId]);
      await txn.delete(DatabaseTables.tableSalesInvoices, where: 'id = ?', whereArgs: [invoiceId]);
    });
  }

  /// Update existing sales invoice: atomically reverses previous stock/journals and applies new invoice values
  Future<int> updateSalesInvoice({
    required SalesInvoiceModel invoice,
    required List<SalesInvoiceItemModel> items,
    int? paymentAccountId,
  }) async {
    if (invoice.id == null) {
      throw Exception('Invoice ID is required for update.');
    }
    final oldInvoice = await _salesRepo.getSalesInvoiceById(invoice.id!);
    if (oldInvoice == null) {
      throw Exception('Invoice not found with ID: ${invoice.id}');
    }
    if (oldInvoice.isCancelled) {
      throw Exception('Cancelled invoices cannot be modified.');
    }
    if (items.isEmpty) {
      throw Exception('Sales Invoice must contain at least one item.');
    }

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(invoice.discount);

    final processedItems = <SalesInvoiceItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }

      final itemTax = SalesInvoiceItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = SalesInvoiceItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
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
    final paidAmount = CurrencyUtils.round(invoice.paidAmount);
    final balanceAmount = CurrencyUtils.round(grandTotal - paidAmount);

    String paymentStatus;
    if (paidAmount <= 0) {
      paymentStatus = AccountingConstants.paymentUnpaid;
    } else if (balanceAmount <= 0) {
      paymentStatus = AccountingConstants.paymentPaid;
    } else {
      paymentStatus = AccountingConstants.paymentPartiallyPaid;
    }

    final customer = await _customerRepo.getCustomerById(invoice.customerId);
    if (customer == null) throw Exception('Customer not found: ${invoice.customerId}');

    final finalInvoice = invoice.copyWith(
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      paymentStatus: paymentStatus,
      updatedAt: DateTime.now(),
    );

    int receivableAccountId = customer.accountId ??
        (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsReceivable))?.id ??
        3;
    final salesAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeSales))?.id ?? 10;
    final gstAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeGstPayable))?.id ?? 6;
    final discountAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountAllowed))?.id ?? 16;

    int effectivePaymentAccountId = 1;
    if (paidAmount > 0) {
      if (paymentAccountId != null) {
        effectivePaymentAccountId = paymentAccountId;
      } else {
        final cashAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeCash);
        effectivePaymentAccountId = cashAcc?.id ?? 1;
      }
    }

    await _dbHelper.transaction((txn) async {
      // 1. Revert previous stock movements
      for (final oldItem in oldInvoice.items) {
        await _productRepo.updateStock(
          oldItem.productId,
          oldItem.quantity, // restore stock
          transactionType: AccountingConstants.stockSalesReturn,
          referenceId: invoice.id!,
          rate: oldItem.rate,
          txn: txn,
        );
      }

      // 2. Remove stock transactions directly linked to this sales invoice
      await txn.delete(
        DatabaseTables.tableStockTransactions,
        where: 'reference_id = ? AND transaction_type IN (?, ?)',
        whereArgs: [invoice.id!, AccountingConstants.stockSale, AccountingConstants.stockSalesReturn],
      );

      // 3. Apply new stock movements
      for (final newItem in processedItems) {
        await _productRepo.updateStock(
          newItem.productId,
          -newItem.quantity, // deduct stock
          transactionType: AccountingConstants.stockSale,
          referenceId: invoice.id!,
          rate: newItem.rate,
          txn: txn,
        );
      }

      // 4. Update items table
      await _salesRepo.deleteSalesInvoiceItems(invoice.id!, txn: txn);
      await _salesRepo.insertSalesInvoiceItems(invoice.id!, processedItems, txn: txn);

      // 5. Update invoice header
      await _salesRepo.updateSalesInvoice(finalInvoice, txn: txn);

      // 6. Remove existing journal entries & receipts
      final entries = await txn.query(
        DatabaseTables.tableJournalEntries,
        columns: ['id'],
        where: '(reference_id = ? AND transaction_type IN (?, ?)) OR transaction_number LIKE ?',
        whereArgs: [invoice.id!, AccountingConstants.transTypeSales, AccountingConstants.transTypeReceipt, '%-${invoice.id!}%'],
      );
      for (final e in entries) {
        final eId = e['id'] as int;
        await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
        await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
      }
      await txn.delete(
        DatabaseTables.tableReceipts,
        where: "reference = ? OR notes LIKE ?",
        whereArgs: [oldInvoice.invoiceNumber, '%#${oldInvoice.invoiceNumber}%'],
      );

      // 7. Post updated balanced journal entry
      final journalLines = <JournalLineModel>[
        JournalLineModel(
          accountId: receivableAccountId,
          debit: grandTotal,
          credit: 0.0,
          description: 'Sales Invoice #${finalInvoice.invoiceNumber} - ${customer.name}',
        ),
      ];

      if (totalDiscount > 0) {
        journalLines.add(JournalLineModel(
          accountId: discountAccountId,
          debit: totalDiscount,
          credit: 0.0,
          description: 'Discount allowed on Invoice #${finalInvoice.invoiceNumber}',
        ));
      }

      journalLines.add(JournalLineModel(
        accountId: salesAccountId,
        debit: 0.0,
        credit: subtotal,
        description: 'Sales Revenue from Invoice #${finalInvoice.invoiceNumber}',
      ));

      if (taxAmount > 0) {
        journalLines.add(JournalLineModel(
          accountId: gstAccountId,
          debit: 0.0,
          credit: taxAmount,
          description: 'GST Output Tax on Invoice #${finalInvoice.invoiceNumber}',
        ));
      }

      await _accountingService.createJournalEntry(
        date: finalInvoice.invoiceDate,
        type: AccountingConstants.transTypeSales,
        description: 'Sales Invoice #${finalInvoice.invoiceNumber} to ${customer.name}',
        referenceId: invoice.id!,
        transactionNumber: 'JV-SALES-${invoice.id!}',
        lines: journalLines,
        txn: txn,
      );

      // 8. If paidAmount > 0, insert receipt and receipt journal
      if (paidAmount > 0) {
        final receiptNumber = 'REC-SALES-${invoice.id!}';
        await txn.insert(DatabaseTables.tableReceipts, {
          'receipt_number': receiptNumber,
          'receipt_date': AppDateUtils.formatDb(finalInvoice.invoiceDate),
          'customer_id': finalInvoice.customerId,
          'account_id': effectivePaymentAccountId,
          'amount': paidAmount,
          'payment_method': AccountingConstants.methodCash,
          'reference': finalInvoice.invoiceNumber,
          'notes': 'Payment on Invoice #${finalInvoice.invoiceNumber}',
          'created_at': AppDateUtils.formatDb(DateTime.now()),
        });

        final recLines = [
          JournalLineModel(
            accountId: effectivePaymentAccountId,
            debit: paidAmount,
            credit: 0.0,
            description: 'Payment received on Invoice #${finalInvoice.invoiceNumber}',
          ),
          JournalLineModel(
            accountId: receivableAccountId,
            debit: 0.0,
            credit: paidAmount,
            description: 'Customer credit for payment on Invoice #${finalInvoice.invoiceNumber}',
          ),
        ];

        await _accountingService.createJournalEntry(
          date: finalInvoice.invoiceDate,
          type: AccountingConstants.transTypeReceipt,
          description: 'Payment on Invoice #${finalInvoice.invoiceNumber}',
          referenceId: invoice.id!,
          transactionNumber: 'JV-REC-SALES-${invoice.id!}',
          lines: recLines,
          txn: txn,
        );
      }
    });

    return invoice.id!;
  }
}

