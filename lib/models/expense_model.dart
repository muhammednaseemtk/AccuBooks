import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';

class ExpenseModel {
  final int? id;
  final String expenseNumber;
  final DateTime expenseDate;
  final int accountId; // Expense account
  final int paymentAccountId; // Cash or Bank account
  final double amount;
  final double taxAmount;
  final String paymentMethod;
  final String? description;
  final String? reference;
  final DateTime createdAt;

  // Transient
  final String? expenseAccountName;
  final String? paymentAccountName;

  ExpenseModel({
    this.id,
    required this.expenseNumber,
    required this.expenseDate,
    required this.accountId,
    required this.paymentAccountId,
    required this.amount,
    this.taxAmount = 0.0,
    this.paymentMethod = AccountingConstants.methodCash,
    this.description,
    this.reference,
    DateTime? createdAt,
    this.expenseAccountName,
    this.paymentAccountName,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalExpense => amount + taxAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_number': expenseNumber,
      'expense_date': AppDateUtils.formatDb(expenseDate),
      'account_id': accountId,
      'payment_account_id': paymentAccountId,
      'amount': amount,
      'tax_amount': taxAmount,
      'payment_method': paymentMethod,
      'description': description,
      'reference': reference,
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, {String? expenseAccountName, String? paymentAccountName}) {
    return ExpenseModel(
      id: map['id'] as int?,
      expenseNumber: map['expense_number'] as String,
      expenseDate: AppDateUtils.parseDb(map['expense_date']),
      accountId: map['account_id'] as int,
      paymentAccountId: map['payment_account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (map['payment_method'] as String?) ?? AccountingConstants.methodCash,
      description: map['description'] as String?,
      reference: map['reference'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      expenseAccountName: expenseAccountName ?? map['expense_account_name'] as String?,
      paymentAccountName: paymentAccountName ?? map['payment_account_name'] as String?,
    );
  }

  ExpenseModel copyWith({
    int? id,
    String? expenseNumber,
    DateTime? expenseDate,
    int? accountId,
    int? paymentAccountId,
    double? amount,
    double? taxAmount,
    String? paymentMethod,
    String? description,
    String? reference,
    DateTime? createdAt,
    String? expenseAccountName,
    String? paymentAccountName,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      expenseNumber: expenseNumber ?? this.expenseNumber,
      expenseDate: expenseDate ?? this.expenseDate,
      accountId: accountId ?? this.accountId,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      amount: amount ?? this.amount,
      taxAmount: taxAmount ?? this.taxAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      expenseAccountName: expenseAccountName ?? this.expenseAccountName,
      paymentAccountName: paymentAccountName ?? this.paymentAccountName,
    );
  }
}
