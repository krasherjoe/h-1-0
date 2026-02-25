class Product {
  final String id;
  final String name;
  final int defaultUnitPrice;
  final String? barcode;
  final String? category;
  final int stockQuantity; // 追加
  final String? odooId;
  final bool isLocked; // ロック

  Product({
    required this.id,
    required this.name,
    this.defaultUnitPrice = 0,
    this.barcode,
    this.category,
    this.stockQuantity = 0, // 追加
    this.odooId,
    this.isLocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_unit_price': defaultUnitPrice,
      'barcode': barcode,
      'category': category,
      'stock_quantity': stockQuantity, // 追加
      'is_locked': isLocked ? 1 : 0,
      'odoo_id': odooId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      defaultUnitPrice: map['default_unit_price'] ?? 0,
      barcode: map['barcode'],
      category: map['category'],
      stockQuantity: map['stock_quantity'] ?? 0, // 追加
      isLocked: (map['is_locked'] ?? 0) == 1,
      odooId: map['odoo_id'],
    );
  }

  Product copyWith({
    String? id,
    String? name,
    int? defaultUnitPrice,
    String? barcode,
    String? odooId,
    bool? isLocked,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      odooId: odooId ?? this.odooId,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
