import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';
import 'purchase_order_item_model.dart';

class PurchaseOrderModel {
  final int? id;
  final String orderNumber;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final int supplierId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient fields
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    this.id,
    required this.orderNumber,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.supplierId,
    required this.subtotal,
    this.discount = 0.0,
    required this.taxAmount,
    required this.grandTotal,
    this.status = AccountingConstants.statusPending,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.supplierName,
    this.supplierPhone,
    this.supplierAddress,
    this.items = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'order_date': AppDateUtils.formatDb(orderDate),
      'expected_delivery_date': expectedDeliveryDate != null ? AppDateUtils.formatDb(expectedDeliveryDate!) : null,
      'supplier_id': supplierId,
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

  factory PurchaseOrderModel.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseOrderItemModel> items = const [],
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
  }) {
    return PurchaseOrderModel(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String,
      orderDate: AppDateUtils.parseDb(map['order_date']),
      expectedDeliveryDate: map['expected_delivery_date'] != null ? AppDateUtils.parseDb(map['expected_delivery_date']) : null,
      supplierId: map['supplier_id'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      status: (map['status'] as String?) ?? AccountingConstants.statusPending,
      notes: map['notes'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      items: items,
      supplierName: supplierName ?? map['supplier_name'] as String?,
      supplierPhone: supplierPhone ?? map['supplier_phone'] as String?,
      supplierAddress: supplierAddress ?? map['supplier_address'] as String?,
    );
  }

  PurchaseOrderModel copyWith({
    int? id,
    String? orderNumber,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    int? supplierId,
    double? subtotal,
    double? discount,
    double? taxAmount,
    double? grandTotal,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
    List<PurchaseOrderItemModel>? items,
  }) {
    return PurchaseOrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      supplierId: supplierId ?? this.supplierId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      supplierAddress: supplierAddress ?? this.supplierAddress,
      items: items ?? this.items,
    );
  }
}
