import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/currency_utils.dart';
import '../models/journal_line_model.dart';
import '../models/receipt_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/receipt_repository.dart';
import 'accounting_service.dart';

class ReceiptService {
  final ReceiptRepository _receiptRepo;
  final CustomerRepository _customerRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  ReceiptService({
    ReceiptRepository? receiptRepo,
    CustomerRepository? customerRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _receiptRepo = receiptRepo ?? ReceiptRepository(),
        _customerRepo = customerRepo ?? CustomerRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  Future<String> getNextReceiptNumber() async {
    return await _receiptRepo.getNextReceiptNumber();
  }

  Future<List<ReceiptModel>> getAllReceipts({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? search,
  }) async {
    return await _receiptRepo.getAllReceipts(
      fromDate: fromDate,
      toDate: toDate,
      customerId: customerId,
      search: search,
    );
  }

  Future<int> createReceipt(ReceiptModel receipt) async {
    if (receipt.amount <= 0) {
      throw Exception('Receipt amount must be greater than zero.');
    }

    final roundedAmount = CurrencyUtils.round(receipt.amount);
    final finalReceipt = receipt.copyWith(amount: roundedAmount);

    return await _dbHelper.transaction<int>((txn) async {
      // 1. Save receipt
      final receiptId = await _receiptRepo.insertReceipt(finalReceipt, txn: txn);

      // 2. Fetch Customer & Accounts
      final customer = await _customerRepo.getCustomerById(finalReceipt.customerId);
      if (customer == null) throw Exception('Customer not found: ${finalReceipt.customerId}');

      final receivableAccountId = customer.accountId ??
          (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsReceivable))?.id ??
          3;

      // 3. Double-entry Journal Lines
      // Debit: Cash/Bank Account
      // Credit: Customer (Receivables) Account
      final lines = [
        JournalLineModel(
          accountId: finalReceipt.accountId,
          debit: roundedAmount,
          credit: 0.0,
          description: 'Receipt #${finalReceipt.receiptNumber} from ${customer.name}',
        ),
        JournalLineModel(
          accountId: receivableAccountId,
          debit: 0.0,
          credit: roundedAmount,
          description: 'Payment from ${customer.name} via ${finalReceipt.paymentMethod}',
        ),
      ];

      // 4. Post balanced Journal Entry
      await _accountingService.createJournalEntry(
        date: finalReceipt.receiptDate,
        type: AccountingConstants.transTypeReceipt,
        description: 'Customer Receipt #${finalReceipt.receiptNumber} - ${customer.name}',
        referenceId: receiptId,
        transactionNumber: 'JV-REC-$receiptId',
        lines: lines,
        txn: txn,
      );

      return receiptId;
    });
  }
}
