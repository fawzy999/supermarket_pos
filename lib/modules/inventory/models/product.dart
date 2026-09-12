class Product {
  final int? id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String? unit;
  final String? packagingType;
  final double? unitsPerPackage;
  final double? innerCount;
  final double? innerSize;
  final String? imagePath;
  final double purchasePrice;
  final double salePrice;
  final double quantity;
  final double reorderLevel;
  final String createdAt;

  Product({
    this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.unit,
    this.packagingType,
    this.unitsPerPackage,
    this.innerCount,
    this.innerSize,
    this.imagePath,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    required this.reorderLevel,
    required this.createdAt,
  });

  /// لو الكمية وصلت لحد إعادة الطلب أو أقل
  bool get isLowStock => quantity <= reorderLevel;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'barcode': barcode,
        'category_id': categoryId,
        'unit': unit,
        'packaging_type': packagingType,
        'units_per_package': unitsPerPackage,
        'inner_count': innerCount,
        'inner_size': innerSize,
        'image_path': imagePath,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'quantity': quantity,
        'reorder_level': reorderLevel,
        'created_at': createdAt,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        barcode: map['barcode'] as String?,
        categoryId: map['category_id'] as int?,
        unit: map['unit'] as String?,
        packagingType: map['packaging_type'] as String?,
        unitsPerPackage: (map['units_per_package'] as num?)?.toDouble(),
        innerCount: (map['inner_count'] as num?)?.toDouble(),
        innerSize: (map['inner_size'] as num?)?.toDouble(),
        imagePath: map['image_path'] as String?,
        purchasePrice: (map['purchase_price'] as num).toDouble(),
        salePrice: (map['sale_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        reorderLevel: (map['reorder_level'] as num).toDouble(),
        createdAt: map['created_at'] as String,
      );

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    String? unit,
    String? packagingType,
    double? unitsPerPackage,
    double? innerCount,
    double? innerSize,
    String? imagePath,
    double? purchasePrice,
    double? salePrice,
    double? quantity,
    double? reorderLevel,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      unit: unit ?? this.unit,
      packagingType: packagingType ?? this.packagingType,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      innerCount: innerCount ?? this.innerCount,
      innerSize: innerSize ?? this.innerSize,
      imagePath: imagePath ?? this.imagePath,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      createdAt: createdAt,
    );
  }
}
