import '../core/utils/date_utils.dart';

class ProductModel {
  final int? id;
  final String productCode;
  final String? barcode;
  final String name;
  final int? categoryId;
  final String unit;
  final double purchasePrice;
  final double salesPrice;
  final double taxRate;
  final double stockQuantity;
  final double minimumStock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient category name
  final String? categoryName;

  ProductModel({
    this.id,
    required this.productCode,
    this.barcode,
    required this.name,
    this.categoryId,
    this.unit = 'Nos',
    this.purchasePrice = 0.0,
    this.salesPrice = 0.0,
    this.taxRate = 0.0,
    this.stockQuantity = 0.0,
    this.minimumStock = 5.0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.categoryName,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stockQuantity <= minimumStock;
  double get inventoryValue => stockQuantity * purchasePrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_code': productCode,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'purchase_price': purchasePrice,
      'sales_price': salesPrice,
      'tax_rate': taxRate,
      'stock_quantity': stockQuantity,
      'minimum_stock': minimumStock,
      'is_active': isActive ? 1 : 0,
      'created_at': AppDateUtils.formatDb(createdAt),
      'updated_at': AppDateUtils.formatDb(updatedAt),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {String? categoryName}) {
    return ProductModel(
      id: map['id'] as int?,
      productCode: map['product_code'] as String,
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      categoryId: map['category_id'] as int?,
      unit: (map['unit'] as String?) ?? 'Nos',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      salesPrice: (map['sales_price'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (map['minimum_stock'] as num?)?.toDouble() ?? 5.0,
      isActive: (map['is_active'] as int?) != 0,
      createdAt: AppDateUtils.parseDb(map['created_at']),
      updatedAt: AppDateUtils.parseDb(map['updated_at']),
      categoryName: categoryName ?? map['category_name'] as String?,
    );
  }

  ProductModel copyWith({
    int? id,
    String? productCode,
    String? barcode,
    String? name,
    int? categoryId,
    String? unit,
    double? purchasePrice,
    double? salesPrice,
    double? taxRate,
    double? stockQuantity,
    double? minimumStock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
  }) {
    return ProductModel(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salesPrice: salesPrice ?? this.salesPrice,
      taxRate: taxRate ?? this.taxRate,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel && runtimeType == other.runtimeType && id != null && id == other.id;

  @override
  int get hashCode => id?.hashCode ?? super.hashCode;
}
