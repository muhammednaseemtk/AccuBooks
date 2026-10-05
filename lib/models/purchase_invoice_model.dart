import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import 'purchase_invoice_item_model.dart';

class PurchaseInvoiceModel {
  final int? id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final int supplierId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final double paidAmount;
  final double balanceAmount;
  final String paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient fields
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final List<PurchaseInvoiceItemModel> items;

  PurchaseInvoiceModel({
    this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.supplierId,
    required this.subtotal,
    this.discount = 0.0,
    required this.taxAmount,
    required this.grandTotal,
    this.paidAmount = 0.0,
    double? balanceAmount,
    String? paymentStatus,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.supplierName,
    this.supplierPhone,
    this.supplierAddress,
    this.items = const [],
  })  : balanceAmount = balanceAmount ?? CurrencyUtils.round(grandTotal - (paidAmount)),
        paymentStatus = paymentStatus ?? determineStatus(grandTotal, paidAmount),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String determineStatus(double total, double paid) {
    if (paid >= total && total > 0) return AccountingConstants.paymentPaid;
    if (paid > 0 && paid < total) return AccountingConstants.paymentPartiallyPaid;
    return AccountingConstants.paymentUnpaid;
  }

  bool get isPaid => paymentStatus == AccountingConstants.paymentPaid;
  bool get isCancelled => paymentStatus == AccountingConstants.paymentCancelled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'invoice_date': AppDateUtils.formatDb(invoiceDate),
      'supplier_id': supplierId,
      'subtotal': subtotal,
      'discount': discount,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'paid_amount': paidAmount,
      'balance_amount': balanceAmount,
      'payment_status': paymentStatus,
      'notes': notes,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory PurchaseInvoiceModel.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseInvoiceItemModel> items = const [],
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
  }) {
    return PurchaseInvoiceModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      invoiceDate: AppDateUtils.parseDb(map['invoice_date']),
      supplierId: map['supplier_id'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (map['balance_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: (map['payment_status'] as String?) ?? AccountingConstants.paymentUnpaid,
      notes: map['notes'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      supplierName: supplierName ?? map['supplier_name'] as String?,
      supplierPhone: supplierPhone ?? map['supplier_phone'] as String?,
      supplierAddress: supplierAddress ?? map['supplier_address'] as String?,
      items: items,
    );
  }

  PurchaseInvoiceModel copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    int? supplierId,
    double? subtotal,
    double? discount,
    double? taxAmount,
    double? grandTotal,
    double? paidAmount,
    double? balanceAmount,
    String? paymentStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
    List<PurchaseInvoiceItemModel>? items,
  }) {
    return PurchaseInvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      supplierId: supplierId ?? this.supplierId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
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
