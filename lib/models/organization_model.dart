import '../core/utils/date_utils.dart';

class OrganizationModel {
  final int? id;
  final String name;
  final int? ownerId;
  final String currency;
  final String? taxNumber;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrganizationModel({
    this.id,
    required this.name,
    this.ownerId,
    this.currency = '₹',
    this.taxNumber,
    this.phone,
    this.email,
    this.address,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'owner_id': ownerId,
      'currency': currency,
      'tax_number': taxNumber?.trim(),
      'phone': phone?.trim(),
      'email': email?.trim(),
      'address': address?.trim(),
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory OrganizationModel.fromMap(Map<String, dynamic> map) {
    return OrganizationModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'AccuBooks Enterprise',
      ownerId: map['owner_id'] as int?,
      currency: map['currency'] as String? ?? '₹',
      taxNumber: map['tax_number'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      createdAt: AppDateUtils.parseDb(map['created_at'] as String?),
      updatedAt: AppDateUtils.parseDb(map['updated_at'] as String?),
    );
  }

  OrganizationModel copyWith({
    int? id,
    String? name,
    int? ownerId,
    String? currency,
    String? taxNumber,
    String? phone,
    String? email,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      currency: currency ?? this.currency,
      taxNumber: taxNumber ?? this.taxNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
