import '../core/utils/date_utils.dart';

class StockTransactionModel {
  final int? id;
  final int productId;
  final String transactionType; // Purchase, Sale, Sales Return, Purchase Return, Adjustment, Opening Stock
  final int? referenceId;
  final double quantityIn;
  final double quantityOut;
  final double rate;
  final double balanceQuantity;
  final DateTime transactionDate;
  final DateTime createdAt;

  // Transient
  final String? productName;
  final String? productCode;
  final String? unit;

  StockTransactionModel({
    this.id,
    required this.productId,
    required this.transactionType,
    this.referenceId,
    this.quantityIn = 0.0,
    this.quantityOut = 0.0,
    this.rate = 0.0,
    required this.balanceQuantity,
    required this.transactionDate,
    DateTime? createdAt,
    this.productName,
    this.productCode,
    this.unit,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'transaction_type': transactionType,
      'reference_id': referenceId,
      'quantity_in': quantityIn,
      'quantity_out': quantityOut,
      'rate': rate,
      'balance_quantity': balanceQuantity,
      'transaction_date': AppDateUtils.formatDb(transactionDate),
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory StockTransactionModel.fromMap(
    Map<String, dynamic> map, {
    String? productName,
    String? productCode,
    String? unit,
  }) {
    return StockTransactionModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      transactionType: map['transaction_type'] as String,
      referenceId: map['reference_id'] as int?,
      quantityIn: (map['quantity_in'] as num?)?.toDouble() ?? 0.0,
      quantityOut: (map['quantity_out'] as num?)?.toDouble() ?? 0.0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      balanceQuantity: (map['balance_quantity'] as num).toDouble(),
      transactionDate: AppDateUtils.parseDb(map['transaction_date']),
      createdAt: AppDateUtils.parseDb(map['created_at']),
      productName: productName ?? map['product_name'] as String?,
      productCode: productCode ?? map['product_code'] as String?,
      unit: unit ?? map['unit'] as String?,
    );
  }

  StockTransactionModel copyWith({
    int? id,
    int? productId,
    String? transactionType,
    int? referenceId,
    double? quantityIn,
    double? quantityOut,
    double? rate,
    double? balanceQuantity,
    DateTime? transactionDate,
    DateTime? createdAt,
    String? productName,
    String? productCode,
    String? unit,
  }) {
    return StockTransactionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      transactionType: transactionType ?? this.transactionType,
      referenceId: referenceId ?? this.referenceId,
      quantityIn: quantityIn ?? this.quantityIn,
      quantityOut: quantityOut ?? this.quantityOut,
      rate: rate ?? this.rate,
      balanceQuantity: balanceQuantity ?? this.balanceQuantity,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      unit: unit ?? this.unit,
    );
  }
}
