import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';

class PaymentModel {
  final int? id;
  final String paymentNumber;
  final DateTime paymentDate;
  final int supplierId;
  final int accountId; // Cash or Bank Account
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  // Transient
  final String? supplierName;
  final String? accountName;

  PaymentModel({
    this.id,
    required this.paymentNumber,
    required this.paymentDate,
    required this.supplierId,
    required this.accountId,
    required this.amount,
    this.paymentMethod = AccountingConstants.methodCash,
    this.reference,
    this.notes,
    DateTime? createdAt,
    this.supplierName,
    this.accountName,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payment_number': paymentNumber,
      'payment_date': AppDateUtils.formatDb(paymentDate),
      'supplier_id': supplierId,
      'account_id': accountId,
      'amount': amount,
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map, {String? supplierName, String? accountName}) {
    return PaymentModel(
      id: map['id'] as int?,
      paymentNumber: map['payment_number'] as String,
      paymentDate: AppDateUtils.parseDb(map['payment_date']),
      supplierId: map['supplier_id'] as int,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? AccountingConstants.methodCash,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      supplierName: supplierName ?? map['supplier_name'] as String?,
      accountName: accountName ?? map['account_name'] as String?,
    );
  }

  PaymentModel copyWith({
    int? id,
    String? paymentNumber,
    DateTime? paymentDate,
    int? supplierId,
    int? accountId,
    double? amount,
    String? paymentMethod,
    String? reference,
    String? notes,
    DateTime? createdAt,
    String? supplierName,
    String? accountName,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      paymentDate: paymentDate ?? this.paymentDate,
      supplierId: supplierId ?? this.supplierId,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      supplierName: supplierName ?? this.supplierName,
      accountName: accountName ?? this.accountName,
    );
  }
}
