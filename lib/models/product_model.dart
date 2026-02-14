class Product {
  final String id;
  final String name;
  final int defaultUnitPrice;
  final String? odooId;

  Product({
    required this.id,
    required this.name,
    this.defaultUnitPrice = 0,
    this.odooId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_unit_price': defaultUnitPrice,
      'odoo_id': odooId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      defaultUnitPrice: map['default_unit_price'] ?? 0,
      odooId: map['odoo_id'],
    );
  }

  Product copyWith({
    String? id,
    String? name,
    int? defaultUnitPrice,
    String? odooId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      odooId: odooId ?? this.odooId,
    );
  }
}
