import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';
import 'sales_return_item_model.dart';

class SalesReturnModel {
  final int? id;
  final String returnNumber;
  final DateTime returnDate;
  final int customerId;
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
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<SalesReturnItemModel> items;

  SalesReturnModel({
    this.id,
    required this.returnNumber,
    required this.returnDate,
    required this.customerId,
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
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.items = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_number': returnNumber,
      'return_date': AppDateUtils.formatDb(returnDate),
      'customer_id': customerId,
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

  factory SalesReturnModel.fromMap(
    Map<String, dynamic> map, {
    List<SalesReturnItemModel> items = const [],
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    return SalesReturnModel(
      id: map['id'] as int?,
      returnNumber: map['return_number'] as String,
      returnDate: AppDateUtils.parseDb(map['return_date']),
      customerId: map['customer_id'] as int,
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
      customerName: customerName ?? map['customer_name'] as String?,
      customerPhone: customerPhone ?? map['customer_phone'] as String?,
      customerAddress: customerAddress ?? map['customer_address'] as String?,
    );
  }

  SalesReturnModel copyWith({
    int? id,
    String? returnNumber,
    DateTime? returnDate,
    int? customerId,
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
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<SalesReturnItemModel>? items,
  }) {
    return SalesReturnModel(
      id: id ?? this.id,
      returnNumber: returnNumber ?? this.returnNumber,
      returnDate: returnDate ?? this.returnDate,
      customerId: customerId ?? this.customerId,
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
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
    );
  }
}
