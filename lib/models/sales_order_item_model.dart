import '../core/utils/currency_utils.dart';

class SalesOrderItemModel {
  final int? id;
  final int? orderId;
  final int productId;
  final String? description;
  final double quantity;
  final double rate;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double total;

  // Transient product fields
  final String? productName;
  final String? productCode;
  final String? unit;

  SalesOrderItemModel({
    this.id,
    this.orderId,
    required this.productId,
    this.description,
    required this.quantity,
    required this.rate,
    this.discount = 0.0,
    this.taxRate = 0.0,
    double? taxAmount,
    double? total,
    this.productName,
    this.productCode,
    this.unit,
  })  : taxAmount = taxAmount ?? calculateTax(quantity, rate, discount, taxRate),
        total = total ?? calculateTotal(quantity, rate, discount, taxRate);

  static double calculateTax(double qty, double rate, double discount, double taxRate) {
    final base = (qty * rate) - discount;
    if (base <= 0) return 0.0;
    return CurrencyUtils.round(base * (taxRate / 100));
  }

  static double calculateTotal(double qty, double rate, double discount, double taxRate) {
    final base = (qty * rate) - discount;
    final tax = calculateTax(qty, rate, discount, taxRate);
    return CurrencyUtils.round(base + tax);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'discount': discount,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total': total,
    };
  }

  factory SalesOrderItemModel.fromMap(
    Map<String, dynamic> map, {
    String? productName,
    String? productCode,
    String? unit,
  }) {
    return SalesOrderItemModel(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      description: map['description'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      rate: (map['rate'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      productName: productName ?? map['product_name'] as String?,
      productCode: productCode ?? map['product_code'] as String?,
      unit: unit ?? map['unit'] as String?,
    );
  }

  SalesOrderItemModel copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? description,
    double? quantity,
    double? rate,
    double? discount,
    double? taxRate,
    double? taxAmount,
    double? total,
    String? productName,
    String? productCode,
    String? unit,
  }) {
    return SalesOrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      unit: unit ?? this.unit,
    );
  }
}
