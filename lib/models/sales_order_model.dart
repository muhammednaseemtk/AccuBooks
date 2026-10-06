import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';
import 'sales_order_item_model.dart';

class SalesOrderModel {
  final int? id;
  final String orderNumber;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final int customerId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient fields
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<SalesOrderItemModel> items;

  SalesOrderModel({
    this.id,
    required this.orderNumber,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.customerId,
    required this.subtotal,
    this.discount = 0.0,
    required this.taxAmount,
    required this.grandTotal,
    this.status = AccountingConstants.statusPending,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.items = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'order_date': AppDateUtils.formatDb(orderDate),
      'expected_delivery_date': expectedDeliveryDate != null ? AppDateUtils.formatDb(expectedDeliveryDate!) : null,
      'customer_id': customerId,
      'subtotal': subtotal,
      'discount': discount,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'status': status,
      'notes': notes,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory SalesOrderModel.fromMap(
    Map<String, dynamic> map, {
    List<SalesOrderItemModel> items = const [],
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    return SalesOrderModel(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String,
      orderDate: AppDateUtils.parseDb(map['order_date']),
      expectedDeliveryDate: map['expected_delivery_date'] != null ? AppDateUtils.parseDb(map['expected_delivery_date']) : null,
      customerId: map['customer_id'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      status: (map['status'] as String?) ?? AccountingConstants.statusPending,
      notes: map['notes'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      items: items,
      customerName: customerName ?? map['customer_name'] as String?,
      customerPhone: customerPhone ?? map['customer_phone'] as String?,
      customerAddress: customerAddress ?? map['customer_address'] as String?,
    );
  }

  SalesOrderModel copyWith({
    int? id,
    String? orderNumber,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    int? customerId,
    double? subtotal,
    double? discount,
    double? taxAmount,
    double? grandTotal,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<SalesOrderItemModel>? items,
  }) {
    return SalesOrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      customerId: customerId ?? this.customerId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
    );
  }
}
