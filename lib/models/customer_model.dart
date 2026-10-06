import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';

class CustomerModel {
  final int? id;
  final String customerCode;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final double creditLimit;
  final double openingBalance;
  final String openingBalanceType;
  final int? accountId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient calculated balances
  final double outstandingBalance;
  final double totalSales;
  final double totalReceipts;

  CustomerModel({
    this.id,
    required this.customerCode,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.creditLimit = 0.0,
    this.openingBalance = 0.0,
    this.openingBalanceType = AccountingConstants.balanceDebit,
    this.accountId,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.outstandingBalance = 0.0,
    this.totalSales = 0.0,
    this.totalReceipts = 0.0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_code': customerCode,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'credit_limit': creditLimit,
      'opening_balance': openingBalance,
      'opening_balance_type': openingBalanceType,
      'account_id': accountId,
      'is_active': isActive ? 1 : 0,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory CustomerModel.fromMap(
    Map<String, dynamic> map, {
    double outstanding = 0.0,
    double sales = 0.0,
    double receipts = 0.0,
  }) {
    return CustomerModel(
      id: map['id'] as int?,
      customerCode: map['customer_code'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      taxNumber: map['tax_number'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      openingBalanceType: (map['opening_balance_type'] as String?) ?? AccountingConstants.balanceDebit,
      accountId: map['account_id'] as int?,
      isActive: (map['is_active'] as int?) != 0,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      outstandingBalance: outstanding,
      totalSales: sales,
      totalReceipts: receipts,
    );
  }

  CustomerModel copyWith({
    int? id,
    String? customerCode,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    double? creditLimit,
    double? openingBalance,
    String? openingBalanceType,
    int? accountId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? outstandingBalance,
    double? totalSales,
    double? totalReceipts,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      creditLimit: creditLimit ?? this.creditLimit,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceType: openingBalanceType ?? this.openingBalanceType,
      accountId: accountId ?? this.accountId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      totalSales: totalSales ?? this.totalSales,
      totalReceipts: totalReceipts ?? this.totalReceipts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerModel && runtimeType == other.runtimeType && id != null && id == other.id;

  @override
  int get hashCode => id?.hashCode ?? super.hashCode;
}
