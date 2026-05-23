/// 在庫入出庫トランザクション
class StockTransaction {
  final String id;
  final String productId;
  final String productName;
  final String? warehouseId;
  final String? warehouseName;
  final int quantity; // 正=入庫, 負=出庫
  final String type; // inbound, outbound, transfer_in, transfer_out, adjustment, purchase_receipt, sales_delivery
  final String? referenceId; // 関連伝票ID（PO, sales等）
  final String? referenceNumber; // 関連伝票番号
  final String? notes;
  final DateTime createdAt;

  const StockTransaction({
    required this.id,
    required this.productId,
    required this.productName,
    this.warehouseId,
    this.warehouseName,
    required this.quantity,
    required this.type,
    this.referenceId,
    this.referenceNumber,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'warehouse_id': warehouseId,
    'warehouse_name': warehouseName,
    'quantity': quantity,
    'type': type,
    'reference_id': referenceId,
    'reference_number': referenceNumber,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  factory StockTransaction.fromMap(Map<String, dynamic> map) => StockTransaction(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    productName: map['product_name'] as String? ?? '',
    warehouseId: map['warehouse_id'] as String?,
    warehouseName: map['warehouse_name'] as String?,
    quantity: map['quantity'] as int? ?? 0,
    type: map['type'] as String? ?? '',
    referenceId: map['reference_id'] as String?,
    referenceNumber: map['reference_number'] as String?,
    notes: map['notes'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
