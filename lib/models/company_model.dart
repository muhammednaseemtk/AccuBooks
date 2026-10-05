import '../core/utils/date_utils.dart';

class CompanyModel {
  final int? id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxNumber;
  final String currency;
  final DateTime? financialYearStart;
  final DateTime? financialYearEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyModel({
    this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.taxNumber,
    this.currency = '₹',
    this.financialYearStart,
    this.financialYearEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'tax_number': taxNumber,
      'currency': currency,
      'financial_year_start': financialYearStart != null ? AppDateUtils.formatDb(financialYearStart) : null,
      'financial_year_end': financialYearEnd != null ? AppDateUtils.formatDb(financialYearEnd) : null,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      taxNumber: map['tax_number'] as String?,
      currency: (map['currency'] as String?) ?? '₹',
      financialYearStart: map['financial_year_start'] != null ? AppDateUtils.parseDb(map['financial_year_start']) : null,
      financialYearEnd: map['financial_year_end'] != null ? AppDateUtils.parseDb(map['financial_year_end']) : null,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
    );
  }

  CompanyModel copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? taxNumber,
    String? currency,
    DateTime? financialYearStart,
    DateTime? financialYearEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      currency: currency ?? this.currency,
      financialYearStart: financialYearStart ?? this.financialYearStart,
      financialYearEnd: financialYearEnd ?? this.financialYearEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
