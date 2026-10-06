import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';
import 'purchase_return_item_model.dart';

class PurchaseReturnModel {
  final int? id;
  final String returnNumber;
  final DateTime returnDate;
  final int supplierId;
  final int? referenceInvoiceId;
  final String? referenceInvoiceNumber;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final String? reason;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient fields
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final List<PurchaseReturnItemModel> items;

  PurchaseReturnModel({
    this.id,
    required this.returnNumber,
    required this.returnDate,
    required this.supplierId,
    this.referenceInvoiceId,
    this.referenceInvoiceNumber,
    required this.subtotal,
    this.discount = 0.0,
    required this.taxAmount,
    required this.grandTotal,
    this.reason,
    this.status = AccountingConstants.statusCompleted,
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
      'return_number': returnNumber,
      'return_date': AppDateUtils.formatDb(returnDate),
      'supplier_id': supplierId,
      'reference_invoice_id': referenceInvoiceId,
      'reference_invoice_number': referenceInvoiceNumber,
      'subtotal': subtotal,
      'discount': discount,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'reason': reason,
      'status': status,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory PurchaseReturnModel.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseReturnItemModel> items = const [],
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
  }) {
    return PurchaseReturnModel(
      id: map['id'] as int?,
      returnNumber: map['return_number'] as String,
      returnDate: AppDateUtils.parseDb(map['return_date']),
      supplierId: map['supplier_id'] as int,
      referenceInvoiceId: map['reference_invoice_id'] as int?,
      referenceInvoiceNumber: map['reference_invoice_number'] as String?,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      reason: map['reason'] as String?,
      status: (map['status'] as String?) ?? AccountingConstants.statusCompleted,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      items: items,
      supplierName: supplierName ?? map['supplier_name'] as String?,
      supplierPhone: supplierPhone ?? map['supplier_phone'] as String?,
      supplierAddress: supplierAddress ?? map['supplier_address'] as String?,
    );
  }

  PurchaseReturnModel copyWith({
    int? id,
    String? returnNumber,
    DateTime? returnDate,
    int? supplierId,
    int? referenceInvoiceId,
    String? referenceInvoiceNumber,
    double? subtotal,
    double? discount,
    double? taxAmount,
    double? grandTotal,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
    List<PurchaseReturnItemModel>? items,
  }) {
    return PurchaseReturnModel(
      id: id ?? this.id,
      returnNumber: returnNumber ?? this.returnNumber,
      returnDate: returnDate ?? this.returnDate,
      supplierId: supplierId ?? this.supplierId,
      referenceInvoiceId: referenceInvoiceId ?? this.referenceInvoiceId,
      referenceInvoiceNumber: referenceInvoiceNumber ?? this.referenceInvoiceNumber,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      supplierAddress: supplierAddress ?? this.supplierAddress,
      items: items ?? this.items,
    );
  }
}
