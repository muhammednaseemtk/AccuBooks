import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';

class AccountModel {
  final int? id;
  final String accountCode;
  final String accountName;
  final String accountType; // Asset, Liability, Equity, Income, Expense
  final int? parentId;
  final double openingBalance;
  final String openingBalanceType; // Debit, Credit
  final bool isSystemAccount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient calculated balance
  final double? currentBalance;

  AccountModel({
    this.id,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    this.parentId,
    this.openingBalance = 0.0,
    this.openingBalanceType = AccountingConstants.balanceDebit,
    this.isSystemAccount = false,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.currentBalance,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isAsset => accountType == AccountingConstants.typeAsset;
  bool get isLiability => accountType == AccountingConstants.typeLiability;
  bool get isEquity => accountType == AccountingConstants.typeEquity;
  bool get isIncome => accountType == AccountingConstants.typeIncome;
  bool get isExpense => accountType == AccountingConstants.typeExpense;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_code': accountCode,
      'account_name': accountName,
      'account_type': accountType,
      'parent_id': parentId,
      'opening_balance': openingBalance,
      'opening_balance_type': openingBalanceType,
      'is_system_account': isSystemAccount ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map, {double? calculatedBalance}) {
    return AccountModel(
      id: map['id'] as int?,
      accountCode: map['account_code'] as String,
      accountName: map['account_name'] as String,
      accountType: map['account_type'] as String,
      parentId: map['parent_id'] as int?,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      openingBalanceType: (map['opening_balance_type'] as String?) ?? AccountingConstants.balanceDebit,
      isSystemAccount: (map['is_system_account'] as int?) == 1,
      isActive: (map['is_active'] as int?) != 0,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      currentBalance: calculatedBalance ?? (map['current_balance'] as num?)?.toDouble(),
    );
  }

  AccountModel copyWith({
    int? id,
    String? accountCode,
    String? accountName,
    String? accountType,
    int? parentId,
    double? openingBalance,
    String? openingBalanceType,
    bool? isSystemAccount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? currentBalance,
  }) {
    return AccountModel(
      id: id ?? this.id,
      accountCode: accountCode ?? this.accountCode,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      parentId: parentId ?? this.parentId,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceType: openingBalanceType ?? this.openingBalanceType,
      isSystemAccount: isSystemAccount ?? this.isSystemAccount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }
}
