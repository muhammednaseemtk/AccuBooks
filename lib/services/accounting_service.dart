import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../repositories/journal_repository.dart';

class AccountingService {
  final JournalRepository _journalRepo;

  AccountingService({
    JournalRepository? journalRepo,
  })  : _journalRepo = journalRepo ?? JournalRepository();

  /// Create balanced Journal Entry with lines.
  /// Throws Exception if sum(Debit) != sum(Credit).
  Future<int> createJournalEntry({
    required DateTime date,
    required String type,
    required String description,
    required List<JournalLineModel> lines,
    int? referenceId,
    String? transactionNumber,
    Transaction? txn,
  }) async {
    if (lines.length < 2) {
      throw Exception('A valid journal entry must contain at least 2 lines.');
    }

    final totalDebit = CurrencyUtils.round(
      lines.fold(0.0, (sum, line) => sum + line.debit),
    );
    final totalCredit = CurrencyUtils.round(
      lines.fold(0.0, (sum, line) => sum + line.credit),
    );

    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception(
        'Unbalanced Journal Entry: Total Debit ($totalDebit) does not equal Total Credit ($totalCredit). Difference: ${(totalDebit - totalCredit).abs()}',
      );
    }

    final txNum = transactionNumber ?? await _journalRepo.getNextJournalNumber(txn: txn);

    final entry = JournalEntryModel(
      transactionNumber: txNum,
      transactionDate: date,
      transactionType: type,
      referenceId: referenceId,
      description: description,
      lines: lines,
    );

    return await _journalRepo.insertJournalEntry(entry, txn: txn);
  }

  /// Create a manual journal entry from the Journal screen
  Future<int> postManualJournal({
    required DateTime date,
    required String description,
    required List<JournalLineModel> lines,
  }) async {
    return await createJournalEntry(
      date: date,
      type: AccountingConstants.transTypeJournal,
      description: description,
      lines: lines,
    );
  }

  /// Reverse an existing journal entry (creates matching entry with flipped debits and credits)
  Future<int> reverseJournalEntry({
    required int originalEntryId,
    required String reason,
    Transaction? txn,
  }) async {
    final original = await _journalRepo.getJournalEntryById(originalEntryId);
    if (original == null) {
      throw Exception('Original journal entry not found: $originalEntryId');
    }

    final reversedLines = original.lines.map((line) {
      return JournalLineModel(
        accountId: line.accountId,
        debit: line.credit, // swap
        credit: line.debit, // swap
        description: 'Reversal: ${line.description ?? reason}',
      );
    }).toList();

    return await createJournalEntry(
      date: DateTime.now(),
      type: AccountingConstants.transTypeJournal,
      description: 'Reversal of ${original.transactionNumber}: $reason',
      lines: reversedLines,
      referenceId: original.id,
      txn: txn,
    );
  }
}
