import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';

class ReceiptModel {
  final int? id;
  final String receiptNumber;
  final DateTime receiptDate;
  final int customerId;
  final int accountId; // Cash or Bank Account
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  // Transient
  final String? customerName;
  final String? accountName;

  ReceiptModel({
    this.id,
    required this.receiptNumber,
    required this.receiptDate,
    required this.customerId,
    required this.accountId,
    required this.amount,
    this.paymentMethod = AccountingConstants.methodCash,
    this.reference,
    this.notes,
    DateTime? createdAt,
    this.customerName,
    this.accountName,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_number': receiptNumber,
      'receipt_date': AppDateUtils.formatDb(receiptDate),
      'customer_id': customerId,
      'account_id': accountId,
      'amount': amount,
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory ReceiptModel.fromMap(Map<String, dynamic> map, {String? customerName, String? accountName}) {
    return ReceiptModel(
      id: map['id'] as int?,
      receiptNumber: map['receipt_number'] as String,
      receiptDate: AppDateUtils.parseDb(map['receipt_date']),
      customerId: map['customer_id'] as int,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? AccountingConstants.methodCash,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      customerName: customerName ?? map['customer_name'] as String?,
      accountName: accountName ?? map['account_name'] as String?,
    );
  }

  ReceiptModel copyWith({
    int? id,
    String? receiptNumber,
    DateTime? receiptDate,
    int? customerId,
    int? accountId,
    double? amount,
    String? paymentMethod,
    String? reference,
    String? notes,
    DateTime? createdAt,
    String? customerName,
    String? accountName,
  }) {
    return ReceiptModel(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      receiptDate: receiptDate ?? this.receiptDate,
      customerId: customerId ?? this.customerId,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      accountName: accountName ?? this.accountName,
    );
  }
}
