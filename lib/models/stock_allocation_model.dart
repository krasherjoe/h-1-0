/// 在庫引当モデル
class StockAllocation {
  final String id;
  final String? orderId;
  final String? salesId;
  final String productId;
  final String warehouseId;
  final int allocatedQuantity;
  final String status; // allocated, released, partially_delivered
  final DateTime createdAt;

  const StockAllocation({
    required this.id,
    this.orderId,
    this.salesId,
    required this.productId,
    this.warehouseId = 'default',
    required this.allocatedQuantity,
    this.status = 'allocated',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'order_id': orderId,
    'sales_id': salesId,
    'product_id': productId,
    'warehouse_id': warehouseId,
    'allocated_quantity': allocatedQuantity,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

  factory StockAllocation.fromMap(Map<String, dynamic> map) => StockAllocation(
    id: map['id'] as String,
    orderId: map['order_id'] as String?,
    salesId: map['sales_id'] as String?,
    productId: map['product_id'] as String,
    warehouseId: map['warehouse_id'] as String? ?? 'default',
    allocatedQuantity: map['allocated_quantity'] as int? ?? 0,
    status: map['status'] as String? ?? 'allocated',
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
