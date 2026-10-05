import '../core/constants/accounting_constants.dart';
import '../core/utils/date_utils.dart';

class TaxModel {
  final int? id;
  final String name;
  final double rate;
  final String taxType;
  final bool isActive;
  final DateTime createdAt;

  TaxModel({
    this.id,
    required this.name,
    required this.rate,
    this.taxType = AccountingConstants.taxOther,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'tax_type': taxType,
      'is_active': isActive ? 1 : 0,
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory TaxModel.fromMap(Map<String, dynamic> map) {
    return TaxModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      rate: (map['rate'] as num).toDouble(),
      taxType: (map['tax_type'] as String?) ?? AccountingConstants.taxOther,
      isActive: (map['is_active'] as int?) != 0,
      createdAt: AppDateUtils.parseDb(map['created_at']),
    );
  }

  TaxModel copyWith({
    int? id,
    String? name,
    double? rate,
    String? taxType,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TaxModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rate: rate ?? this.rate,
      taxType: taxType ?? this.taxType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
