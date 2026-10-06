import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
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
    double totalDiscount = invoice.discount;

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
    final grandTotal = CurrencyUtils.round(subtotal + taxAmount);
    final paidAmount = CurrencyUtils.round(invoice.paidAmount);
    final balanceAmount = CurrencyUtils.round(grandTotal - paidAmount);

    final finalInvoice = invoice.copyWith(
      subtotal: subtotal,
      discount: totalDiscount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      paymentStatus: SalesInvoiceModel.determineStatus(grandTotal, paidAmount),
    );

    // 2. Atomic SQLite Transaction
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

      // Step D: Fetch Accounts for Journal Entry
      final customer = await _customerRepo.getCustomerById(finalInvoice.customerId);
      if (customer == null) throw Exception('Customer not found: ${finalInvoice.customerId}');

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

      // Step E: Create Journal Lines
      final journalLines = <JournalLineModel>[];

      // Customer A/C (Receivable) Debit = Grand Total
      journalLines.add(JournalLineModel(
        accountId: receivableAccountId,
        debit: grandTotal,
        credit: 0.0,
        description: 'Sales Invoice #${finalInvoice.invoiceNumber} - ${customer.name}',
      ));

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

      // Step F: Post balanced Journal Entry
      await _accountingService.createJournalEntry(
        date: finalInvoice.invoiceDate,
        type: AccountingConstants.transTypeSales,
        description: 'Sales Invoice #${finalInvoice.invoiceNumber} to ${customer.name}',
        referenceId: invoiceId,
        transactionNumber: 'JV-SALES-$invoiceId',
        lines: journalLines,
        txn: txn,
      );

      // Step G: If payment is received on invoice, record immediate receipt
      if (paidAmount > 0 && paymentAccountId != null) {
        final recLines = [
          JournalLineModel(
            accountId: paymentAccountId,
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
  }

  /// Cancel invoice: restores inventory, cancels journal entry, and marks cancelled
  Future<void> cancelSalesInvoice(int invoiceId, {required String reason}) async {
    final invoice = await _salesRepo.getSalesInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Invoice not found: $invoiceId');
    if (invoice.isCancelled) throw Exception('Invoice is already cancelled');

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
      final customer = await _customerRepo.getCustomerById(invoice.customerId);
      final receivableAccountId = customer?.accountId ?? (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsReceivable))?.id ?? 3;
      final salesAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeSales))?.id ?? 10;
      final gstAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeGstPayable))?.id ?? 6;

      final reverseLines = <JournalLineModel>[
        JournalLineModel(
          accountId: receivableAccountId,
          debit: 0.0,
          credit: invoice.grandTotal,
          description: 'Cancellation reversal: ${invoice.invoiceNumber}',
        ),
        JournalLineModel(
          accountId: salesAccountId,
          debit: invoice.subtotal,
          credit: 0.0,
          description: 'Sales reversal: ${invoice.invoiceNumber}',
        ),
      ];

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

      // 4. Delete items and invoice
      await txn.delete(DatabaseTables.tableSalesInvoiceItems, where: 'invoice_id = ?', whereArgs: [invoiceId]);
      await txn.delete(DatabaseTables.tableSalesInvoices, where: 'id = ?', whereArgs: [invoiceId]);
    });
  }
}
