import '../core/constants/auth_constants.dart';
import '../core/utils/date_utils.dart';

class UserModel {
  final int? id;
  final int organizationId;
  final String email;
  final String fullName;
  final String? phone;
  final String? profileImage;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    this.id,
    required this.organizationId,
    required this.email,
    required this.fullName,
    this.phone,
    this.profileImage,
    this.role = AuthConstants.roleOwner,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isOwner => role == AuthConstants.roleOwner;
  bool get isAdmin => role == AuthConstants.roleAdmin || isOwner;
  bool get isAccountant => role == AuthConstants.roleAccountant || isAdmin;
  bool get isStaff => role == AuthConstants.roleStaff || isAccountant;
  bool get isViewer => role == AuthConstants.roleViewer;

  String get roleDisplayName {
    switch (role) {
      case AuthConstants.roleOwner:
        return 'Owner';
      case AuthConstants.roleAdmin:
        return 'Administrator';
      case AuthConstants.roleAccountant:
        return 'Accountant';
      case AuthConstants.roleStaff:
        return 'Staff';
      case AuthConstants.roleViewer:
        return 'Viewer';
      default:
        return role;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'organization_id': organizationId,
      'email': email.trim().toLowerCase(),
      'full_name': fullName.trim(),
      'phone': phone?.trim(),
      'profile_image': profileImage?.trim(),
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      organizationId: (map['organization_id'] as int?) ?? 1,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String?,
      profileImage: map['profile_image'] as String?,
      role: map['role'] as String? ?? AuthConstants.roleOwner,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: AppDateUtils.parseDb(map['created_at'] as String?),
      updatedAt: AppDateUtils.parseDb(map['updated_at'] as String?),
    );
  }

  UserModel copyWith({
    int? id,
    int? organizationId,
    String? email,
    String? fullName,
    String? phone,
    String? profileImage,
    bool clearProfileImage = false,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      profileImage: clearProfileImage ? null : (profileImage ?? this.profileImage),
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
