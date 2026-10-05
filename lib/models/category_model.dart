import '../core/utils/date_utils.dart';

class CategoryModel {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  CategoryModel({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': AppDateUtils.formatDb(createdAt),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int?) != 0,
      createdAt: AppDateUtils.parseDb(map['created_at']),
    );
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
