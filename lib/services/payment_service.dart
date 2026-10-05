import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/currency_utils.dart';
import '../models/journal_line_model.dart';
import '../models/payment_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/supplier_repository.dart';
import 'accounting_service.dart';

class PaymentService {
  final PaymentRepository _paymentRepo;
  final SupplierRepository _supplierRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  PaymentService({
    PaymentRepository? paymentRepo,
    SupplierRepository? supplierRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _paymentRepo = paymentRepo ?? PaymentRepository(),
        _supplierRepo = supplierRepo ?? SupplierRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  Future<String> getNextPaymentNumber() async {
    return await _paymentRepo.getNextPaymentNumber();
  }

  Future<List<PaymentModel>> getAllPayments({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? search,
  }) async {
    return await _paymentRepo.getAllPayments(
      fromDate: fromDate,
      toDate: toDate,
      supplierId: supplierId,
      search: search,
    );
  }

  Future<int> createPayment(PaymentModel payment) async {
    if (payment.amount <= 0) {
      throw Exception('Payment amount must be greater than zero.');
    }

    final roundedAmount = CurrencyUtils.round(payment.amount);
    final finalPayment = payment.copyWith(amount: roundedAmount);

    return await _dbHelper.transaction<int>((txn) async {
      // 1. Save payment
      final paymentId = await _paymentRepo.insertPayment(finalPayment, txn: txn);

      // 2. Fetch Supplier & Accounts
      final supplier = await _supplierRepo.getSupplierById(finalPayment.supplierId);
      if (supplier == null) throw Exception('Supplier not found: ${finalPayment.supplierId}');

      final payableAccountId = supplier.accountId ??
          (await _accountRepo.getAccountByCode(AccountingConstants.codeAccountsPayable))?.id ??
          5;

      // 3. Double-entry Journal Lines
      // Debit: Supplier (Payable) Account
      // Credit: Cash/Bank Account
      final lines = [
        JournalLineModel(
          accountId: payableAccountId,
          debit: roundedAmount,
          credit: 0.0,
          description: 'Payment to ${supplier.name} via ${finalPayment.paymentMethod}',
        ),
        JournalLineModel(
          accountId: finalPayment.accountId,
          debit: 0.0,
          credit: roundedAmount,
          description: 'Payment disbursement #${finalPayment.paymentNumber} to ${supplier.name}',
        ),
      ];

      // 4. Post balanced Journal Entry
      await _accountingService.createJournalEntry(
        date: finalPayment.paymentDate,
        type: AccountingConstants.transTypePayment,
        description: 'Supplier Payment #${finalPayment.paymentNumber} - ${supplier.name}',
        referenceId: paymentId,
        transactionNumber: 'JV-PAY-$paymentId',
        lines: lines,
        txn: txn,
      );

      return paymentId;
    });
  }
}
