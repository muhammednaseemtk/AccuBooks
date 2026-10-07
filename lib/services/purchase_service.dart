import 'package:flutter/foundation.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/journal_line_model.dart';
import '../models/purchase_invoice_item_model.dart';
import '../models/purchase_invoice_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/supplier_repository.dart';
import 'accounting_service.dart';

class PurchaseService {
  final PurchaseRepository _purchaseRepo;
  final ProductRepository _productRepo;
  final SupplierRepository _supplierRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  PurchaseService({
    PurchaseRepository? purchaseRepo,
    ProductRepository? productRepo,
    SupplierRepository? supplierRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _purchaseRepo = purchaseRepo ?? PurchaseRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _supplierRepo = supplierRepo ?? SupplierRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  Future<String> getNextPurchaseNumber() async {
    return await _purchaseRepo.getNextPurchaseNumber();
  }

  Future<List<PurchaseInvoiceModel>> getAllPurchases({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? paymentStatus,
    String? search,
  }) async {
    return await _purchaseRepo.getAllPurchaseInvoices(
      fromDate: fromDate,
      toDate: toDate,
      supplierId: supplierId,
      paymentStatus: paymentStatus,
      search: search,
    );
  }

  Future<PurchaseInvoiceModel?> getPurchaseById(int id) async {
    return await _purchaseRepo.getPurchaseInvoiceById(id);
  }

  /// Create and post a purchase invoice inside an atomic SQLite transaction
  Future<int> createPurchaseInvoice({
    required PurchaseInvoiceModel invoice,
    required List<PurchaseInvoiceItemModel> items,
    int? paymentAccountId,
  }) async {
    if (items.isEmpty) {
      throw Exception('Purchase must contain at least one item.');
    }

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final totalDiscount = CurrencyUtils.round(invoice.discount);

    final processedItems = <PurchaseInvoiceItemModel>[];
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Quantity must be greater than zero for all items.');
      }
      if (item.rate < 0) {
        throw Exception('Rate cannot be negative.');
      }
      final itemTax = PurchaseInvoiceItemModel.calculateTax(item.quantity, item.rate, item.discount, item.taxRate);
      final itemTotal = PurchaseInvoiceItemModel.calculateTotal(item.quantity, item.rate, item.discount, item.taxRate);
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
      invoiceNumber = await getNextPurchaseNumber();
    }

    final finalInvoice = invoice.copyWith(
      invoiceNumber: invoiceNumber,
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      paymentStatus: PurchaseInvoiceModel.determineStatus(grandTotal, paidAmount),
    );

    // 2. Pre-transaction validation and account lookups to eliminate SQLite deadlocks
    final supplier = await _supplierRepo.getSupplierById(finalInvoice.supplierId);
    if (supplier == null) {
      throw Exception('Supplier not found with ID: ${finalInvoice.supplierId}');
    }

    for (final item in processedItems) {
      final p = await _productRepo.getProductById(item.productId);
      if (p == null) {
        throw Exception('Product not found with ID: ${item.productId}');
      }
    }

    // Accounts mapping
    int payableAccountId;
    if (supplier.accountId != null) {
      payableAccountId = supplier.accountId!;
    } else {
      final payAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsPayable);
      payableAccountId = payAcc?.id ?? 5;
    }

    // Purchases Account (5000)
    final purchasesAcc = await _accountRepo.getAccountByCode(AccountingConstants.codePurchases);
    final purchasesAccountId = purchasesAcc?.id ?? 13;

    // GST Input Credit Account (2020)
    final gstInputAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit);
    final gstInputAccountId = gstInputAcc?.id ?? 7;

    // Discount Received Account (4020)
    int discountReceivedAccountId = 12;
    if (totalDiscount > 0) {
      final discAcc = await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountReceived);
      discountReceivedAccountId = discAcc?.id ?? 12;
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
      return await _dbHelper.transaction<int>((txn) async {
        // Step A: Save purchase invoice
        final invoiceId = await _purchaseRepo.insertPurchaseInvoice(finalInvoice, txn: txn);

        // Step B: Save items
        await _purchaseRepo.insertPurchaseInvoiceItems(invoiceId, processedItems, txn: txn);

        // Step C: Increase stock for each item
        for (final item in processedItems) {
          await _productRepo.updateStock(
            item.productId,
            item.quantity, // positive delta increases inventory
            transactionType: AccountingConstants.stockPurchase,
            referenceId: invoiceId,
            rate: item.rate,
            txn: txn,
          );
        }

        // Step D: Create Journal Lines
        final journalLines = <JournalLineModel>[];

        // Purchases A/C Debit = Net Subtotal
        journalLines.add(JournalLineModel(
          accountId: purchasesAccountId,
          debit: subtotal,
          credit: 0.0,
          description: 'Purchases from #${finalInvoice.invoiceNumber}',
        ));

        // GST Input Credit A/C Debit = Tax Amount
        if (taxAmount > 0) {
          journalLines.add(JournalLineModel(
            accountId: gstInputAccountId,
            debit: taxAmount,
            credit: 0.0,
            description: 'GST Input Tax Credit on #${finalInvoice.invoiceNumber}',
          ));
        }

        // Supplier A/C (Payables) Credit = Grand Total
        journalLines.add(JournalLineModel(
          accountId: payableAccountId,
          debit: 0.0,
          credit: grandTotal,
          description: 'Purchase Invoice #${finalInvoice.invoiceNumber} from ${supplier.name}',
        ));

        // Discount Received A/C Credit = Total Discount (if > 0)
        if (totalDiscount > 0) {
          journalLines.add(JournalLineModel(
            accountId: discountReceivedAccountId,
            debit: 0.0,
            credit: totalDiscount,
            description: 'Discount received on Purchase #${finalInvoice.invoiceNumber}',
          ));
        }

        // Step E: Post balanced Journal Entry
        await _accountingService.createJournalEntry(
          date: finalInvoice.invoiceDate,
          type: AccountingConstants.transTypePurchase,
          description: 'Purchase Invoice #${finalInvoice.invoiceNumber} from ${supplier.name}',
          referenceId: invoiceId,
          transactionNumber: 'JV-PUR-$invoiceId',
          lines: journalLines,
          txn: txn,
        );

        // Step F: If payment is disbursed immediately
        if (paidAmount > 0) {
          final paymentNumber = 'PAY-PUR-$invoiceId';
          await txn.insert(DatabaseTables.tablePayments, {
            'payment_number': paymentNumber,
            'payment_date': AppDateUtils.formatDb(finalInvoice.invoiceDate),
            'supplier_id': finalInvoice.supplierId,
            'account_id': effectivePaymentAccountId,
            'amount': paidAmount,
            'payment_method': AccountingConstants.methodCash,
            'reference': finalInvoice.invoiceNumber,
            'notes': 'Payment on Purchase #${finalInvoice.invoiceNumber}',
            'created_at': AppDateUtils.formatDb(DateTime.now()),
          });

          final payLines = [
            JournalLineModel(
              accountId: payableAccountId,
              debit: paidAmount,
              credit: 0.0,
              description: 'Payment made on Purchase #${finalInvoice.invoiceNumber}',
            ),
            JournalLineModel(
              accountId: effectivePaymentAccountId,
              debit: 0.0,
              credit: paidAmount,
              description: 'Disbursement for Purchase #${finalInvoice.invoiceNumber}',
            ),
          ];

          await _accountingService.createJournalEntry(
            date: finalInvoice.invoiceDate,
            type: AccountingConstants.transTypePayment,
            description: 'Payment on Purchase #${finalInvoice.invoiceNumber}',
            referenceId: invoiceId,
            transactionNumber: 'JV-PAY-PUR-$invoiceId',
            lines: payLines,
            txn: txn,
          );
        }

        return invoiceId;
      });
    } catch (e, stackTrace) {
      debugPrint('================= PURCHASE INVOICE CREATION ERROR =================');
      debugPrint('Location: PurchaseService.createPurchaseInvoice');
      debugPrint('Invoice Number: ${finalInvoice.invoiceNumber}');
      debugPrint('Supplier ID: ${finalInvoice.supplierId} (${supplier.name})');
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
      debugPrint('===================================================================');
      rethrow;
    }
  }

  /// Cancel purchase invoice
  Future<void> cancelPurchaseInvoice(int invoiceId, {required String reason}) async {
    final invoice = await _purchaseRepo.getPurchaseInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Purchase invoice not found: $invoiceId');
    if (invoice.isCancelled) throw Exception('Purchase is already cancelled');

    final supplier = await _supplierRepo.getSupplierById(invoice.supplierId);
    final payableAccountId = supplier?.accountId ??
        (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsPayable))?.id ??
        5;
    final purchasesAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codePurchases))?.id ?? 13;
    final gstInputAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit))?.id ?? 7;
    final discountReceivedAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeDiscountReceived))?.id ?? 12;

    await _dbHelper.transaction((txn) async {
      await _purchaseRepo.cancelPurchaseInvoice(invoiceId, txn: txn);

      // Reverse stock
      for (final item in invoice.items) {
        await _productRepo.updateStock(
          item.productId,
          -item.quantity, // deduct back
          transactionType: AccountingConstants.stockPurchaseReturn,
          referenceId: invoiceId,
          rate: item.rate,
          txn: txn,
        );
      }

      // Reverse journal
      final reverseLines = <JournalLineModel>[
        JournalLineModel(
          accountId: payableAccountId,
          debit: invoice.grandTotal,
          credit: 0.0,
          description: 'Cancellation reversal: ${invoice.invoiceNumber}',
        ),
      ];

      if (invoice.discount > 0) {
        reverseLines.add(JournalLineModel(
          accountId: discountReceivedAccountId,
          debit: invoice.discount,
          credit: 0.0,
          description: 'Discount reversal: ${invoice.invoiceNumber}',
        ));
      }

      reverseLines.add(JournalLineModel(
        accountId: purchasesAccountId,
        debit: 0.0,
        credit: invoice.subtotal,
        description: 'Purchases reversal: ${invoice.invoiceNumber}',
      ));

      if (invoice.taxAmount > 0) {
        reverseLines.add(JournalLineModel(
          accountId: gstInputAccountId,
          debit: 0.0,
          credit: invoice.taxAmount,
          description: 'GST input credit reversal: ${invoice.invoiceNumber}',
        ));
      }

      await _accountingService.createJournalEntry(
        date: DateTime.now(),
        type: AccountingConstants.transTypePurchase,
        description: 'Reversal of Purchase #${invoice.invoiceNumber}: $reason',
        referenceId: invoiceId,
        lines: reverseLines,
        txn: txn,
      );
    });
  }

  /// Delete purchase invoice: reverses stock, removes associated journal entries and invoice
  Future<void> deletePurchaseInvoice(int invoiceId) async {
    final invoice = await _purchaseRepo.getPurchaseInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Purchase invoice not found: $invoiceId');

    await _dbHelper.transaction((txn) async {
      // 1. If purchase was not cancelled, decrement back the inventory
      if (!invoice.isCancelled) {
        for (final item in invoice.items) {
          await _productRepo.updateStock(
            item.productId,
            -item.quantity,
            transactionType: AccountingConstants.stockPurchaseReturn,
            referenceId: invoiceId,
            rate: item.rate,
            txn: txn,
          );
        }
      }

      // 2. Remove stock transactions directly linked to this purchase
      await txn.delete(
        DatabaseTables.tableStockTransactions,
        where: 'reference_id = ? AND transaction_type IN (?, ?)',
        whereArgs: [invoiceId, AccountingConstants.stockPurchase, AccountingConstants.stockPurchaseReturn],
      );

      // 3. Remove all journal entries (and cascading lines) linked to this purchase
      final entries = await txn.query(
        DatabaseTables.tableJournalEntries,
        columns: ['id'],
        where: '(reference_id = ? AND transaction_type IN (?, ?)) OR transaction_number LIKE ?',
        whereArgs: [invoiceId, AccountingConstants.transTypePurchase, AccountingConstants.transTypePayment, '%-$invoiceId%'],
      );
      for (final e in entries) {
        final eId = e['id'] as int;
        await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
        await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
      }

      // 4. Remove immediate payments linked to this purchase
      await txn.delete(
        DatabaseTables.tablePayments,
        where: "reference = ? OR notes LIKE ?",
        whereArgs: [invoice.invoiceNumber, '%#${invoice.invoiceNumber}%'],
      );

      // 5. Delete items and invoice
      await txn.delete(DatabaseTables.tablePurchaseInvoiceItems, where: 'invoice_id = ?', whereArgs: [invoiceId]);
      await txn.delete(DatabaseTables.tablePurchaseInvoices, where: 'id = ?', whereArgs: [invoiceId]);
    });
  }
}
