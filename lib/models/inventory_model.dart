class Inventory {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final String warehouseId;
  final String warehouseName;
  final DateTime updatedAt;

  Inventory({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.warehouseId,
    required this.warehouseName,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      warehouseId: map['warehouse_id'] as String,
      warehouseName: map['warehouse_name'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
