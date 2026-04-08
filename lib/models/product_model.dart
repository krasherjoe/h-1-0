class Product {
  final String id;
  final String name;
  final int defaultUnitPrice;
  final int wholesalePrice;
  final String? barcode;
  final String? category;
  final String? categoryId; // カテゴリー ID
  final int? stockQuantity; // null = 在庫管理なし、0以上 = 在庫数
  final String? odooId;
  final bool isLocked; // ロック
  final bool isHidden; // 非表示

  Product({
    required this.id,
    required this.name,
    this.defaultUnitPrice = 0,
    this.wholesalePrice = 0,
    this.barcode,
    this.category,
    this.categoryId,
    this.stockQuantity,
    this.odooId,
    this.isLocked = false,
    this.isHidden = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_unit_price': defaultUnitPrice,
      'wholesale_price': wholesalePrice,
      'barcode': barcode,
      'category': category,
      'category_id': categoryId,
      'stock_quantity': stockQuantity,
      'is_locked': isLocked ? 1 : 0,
      'odoo_id': odooId,
      'is_hidden': isHidden ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      defaultUnitPrice: map['default_unit_price'] ?? 0,
      wholesalePrice: map['wholesale_price'] ?? 0,
      barcode: map['barcode'],
      category: map['category'],
      categoryId: map['category_id'],
      stockQuantity: map['stock_quantity'],
      isLocked: (map['is_locked'] ?? 0) == 1,
      odooId: map['odoo_id'],
      isHidden: (map['is_hidden'] ?? 0) == 1,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    int? defaultUnitPrice,
    int? wholesalePrice,
    String? barcode,
    String? category,
    String? categoryId,
    int? stockQuantity,
    String? odooId,
    bool? isLocked,
    bool? isHidden,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      odooId: odooId ?? this.odooId,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}
