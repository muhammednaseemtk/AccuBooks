import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/currency_utils.dart';
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
    final grandTotal = CurrencyUtils.round(subtotal + taxAmount);
    final paidAmount = CurrencyUtils.round(invoice.paidAmount);
    final balanceAmount = CurrencyUtils.round(grandTotal - paidAmount);

    final finalInvoice = invoice.copyWith(
      subtotal: subtotal,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      paymentStatus: PurchaseInvoiceModel.determineStatus(grandTotal, paidAmount),
    );

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

      // Step D: Accounts mapping
      final supplier = await _supplierRepo.getSupplierById(finalInvoice.supplierId);
      if (supplier == null) throw Exception('Supplier not found: ${finalInvoice.supplierId}');

      // Payable Account
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

      // Step E: Create Journal Lines
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

      // Step F: Post balanced Journal Entry
      await _accountingService.createJournalEntry(
        date: finalInvoice.invoiceDate,
        type: AccountingConstants.transTypePurchase,
        description: 'Purchase Invoice #${finalInvoice.invoiceNumber} from ${supplier.name}',
        referenceId: invoiceId,
        transactionNumber: 'JV-PUR-$invoiceId',
        lines: journalLines,
        txn: txn,
      );

      // Step G: If payment is disbursed immediately
      if (paidAmount > 0 && paymentAccountId != null) {
        final payLines = [
          JournalLineModel(
            accountId: payableAccountId,
            debit: paidAmount,
            credit: 0.0,
            description: 'Payment made on Purchase #${finalInvoice.invoiceNumber}',
          ),
          JournalLineModel(
            accountId: paymentAccountId,
            debit: 0.0,
            credit: paidAmount,
            description: 'Bank/Cash disbursement for Purchase #${finalInvoice.invoiceNumber}',
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
  }

  /// Cancel purchase invoice
  Future<void> cancelPurchaseInvoice(int invoiceId, {required String reason}) async {
    final invoice = await _purchaseRepo.getPurchaseInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Purchase invoice not found: $invoiceId');
    if (invoice.isCancelled) throw Exception('Purchase is already cancelled');

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
      final supplier = await _supplierRepo.getSupplierById(invoice.supplierId);
      final payableAccountId = supplier?.accountId ?? (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsPayable))?.id ?? 5;
      final purchasesAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codePurchases))?.id ?? 13;
      final gstInputAccountId = (await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit))?.id ?? 7;

      final reverseLines = <JournalLineModel>[
        JournalLineModel(
          accountId: payableAccountId,
          debit: invoice.grandTotal,
          credit: 0.0,
          description: 'Cancellation reversal: ${invoice.invoiceNumber}',
        ),
        JournalLineModel(
          accountId: purchasesAccountId,
          debit: 0.0,
          credit: invoice.subtotal,
          description: 'Purchases reversal: ${invoice.invoiceNumber}',
        ),
      ];

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
}
