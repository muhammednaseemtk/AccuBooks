import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import 'journal_line_model.dart';

class JournalEntryModel {
  final int? id;
  final String transactionNumber;
  final DateTime transactionDate;
  final String transactionType;
  final int? referenceId;
  final String? description;
  final DateTime createdAt;
  final List<JournalLineModel> lines;

  JournalEntryModel({
    this.id,
    required this.transactionNumber,
    required this.transactionDate,
    this.transactionType = AccountingConstants.transTypeJournal,
    this.referenceId,
    this.description,
    DateTime? createdAt,
    this.lines = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalDebit => CurrencyUtils.round(lines.fold(0.0, (sum, line) => sum + line.debit));
  double get totalCredit => CurrencyUtils.round(lines.fold(0.0, (sum, line) => sum + line.credit));
  double get difference => CurrencyUtils.round((totalDebit - totalCredit).abs());
  bool get isBalanced => difference <= 0.01;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'transaction_date': AppDateUtils.formatDb(transactionDate),
      'transaction_type': transactionType,
      'reference_id': referenceId,
      'description': description,
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory JournalEntryModel.fromMap(Map<String, dynamic> map, {List<JournalLineModel> lines = const []}) {
    return JournalEntryModel(
      id: map['id'] as int?,
      transactionNumber: map['transaction_number'] as String,
      transactionDate: AppDateUtils.parseDb(map['transaction_date']),
      transactionType: (map['transaction_type'] as String?) ?? AccountingConstants.transTypeJournal,
      referenceId: map['reference_id'] as int?,
      description: map['description'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      lines: lines,
    );
  }

  JournalEntryModel copyWith({
    int? id,
    String? transactionNumber,
    DateTime? transactionDate,
    String? transactionType,
    int? referenceId,
    String? description,
    DateTime? createdAt,
    List<JournalLineModel>? lines,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      referenceId: referenceId ?? this.referenceId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      lines: lines ?? this.lines,
    );
  }
}
