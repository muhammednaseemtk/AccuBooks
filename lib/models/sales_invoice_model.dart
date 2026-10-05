import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import 'sales_invoice_item_model.dart';

class SalesInvoiceModel {
  final int? id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final int customerId;
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
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<SalesInvoiceItemModel> items;

  SalesInvoiceModel({
    this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerId,
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
    this.customerName,
    this.customerPhone,
    this.customerAddress,
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
      'customer_id': customerId,
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

  factory SalesInvoiceModel.fromMap(
    Map<String, dynamic> map, {
    List<SalesInvoiceItemModel> items = const [],
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    return SalesInvoiceModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      invoiceDate: AppDateUtils.parseDb(map['invoice_date']),
      customerId: map['customer_id'] as int,
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
      customerName: customerName ?? map['customer_name'] as String?,
      customerPhone: customerPhone ?? map['customer_phone'] as String?,
      customerAddress: customerAddress ?? map['customer_address'] as String?,
      items: items,
    );
  }

  SalesInvoiceModel copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    int? customerId,
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
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<SalesInvoiceItemModel>? items,
  }) {
    return SalesInvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      customerId: customerId ?? this.customerId,
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
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
    );
  }
}
