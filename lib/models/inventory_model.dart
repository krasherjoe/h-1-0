import 'package:flutter/material.dart';

class Inventory {
  final String id;
  final String productId;      // 商品ID
  final String productName;    // 商品名
  final int quantity;         // 現在在庫数
  final int reservedQuantity; // 引当数
  final String? location;     // 保管場所
  final String warehouseId;   // 倉庫ID
  final String warehouseName; // 倉庫名
  final double? unitCost;     // 単価
  final int? reorderPoint;    // 発注点
  final int? safetyStock;     // 安全在庫
  final DateTime updatedAt;

  Inventory({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.reservedQuantity = 0,
    this.location,
    required this.warehouseId,
    required this.warehouseName,
    this.unitCost,
    this.reorderPoint,
    this.safetyStock,
    required this.updatedAt,
  });

  int get availableQuantity => quantity - reservedQuantity;
  int get totalQuantity => quantity + reservedQuantity;

  bool get isLowStock => reorderPoint != null && quantity <= reorderPoint!;
  bool get isOutOfStock => quantity <= 0;
  bool get isOverReserved => reservedQuantity > quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'reserved_quantity': reservedQuantity,
      'location': location,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'unit_cost': unitCost,
      'reorder_point': reorderPoint,
      'safety_stock': safetyStock,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      reservedQuantity: map['reserved_quantity'] as int? ?? 0,
      location: map['location'],
      warehouseId: map['warehouse_id'] as String,
      warehouseName: map['warehouse_name'] as String,
      unitCost: map['unit_cost'] as double?,
      reorderPoint: map['reorder_point'] as int?,
      safetyStock: map['safety_stock'] as int?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Inventory copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    int? reservedQuantity,
    String? location,
    String? warehouseId,
    String? warehouseName,
    double? unitCost,
    int? reorderPoint,
    int? safetyStock,
    DateTime? updatedAt,
  }) {
    return Inventory(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      location: location ?? this.location,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      unitCost: unitCost ?? this.unitCost,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      safetyStock: safetyStock ?? this.safetyStock,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 在庫を調整
  Inventory adjustInventory(int adjustment) {
    return copyWith(
      quantity: quantity + adjustment,
      updatedAt: DateTime.now(),
    );
  }

  /// 引当を調整
  Inventory adjustReservation(int adjustment) {
    return copyWith(
      reservedQuantity: (reservedQuantity + adjustment).clamp(0, quantity),
      updatedAt: DateTime.now(),
    );
  }

  /// 在庫状態を取得
  String getStockStatus() {
    if (isOutOfStock) return '欠品';
    if (isLowStock) return '要発注';
    if (isOverReserved) return '引当超過';
    return '適正在庫';
  }

  /// 在庫状態の色を取得
  Color getStockStatusColor(ColorScheme cs) {
    if (isOutOfStock) return cs.error;
    if (isLowStock) return cs.secondary;
    if (isOverReserved) return cs.secondary;
    return cs.tertiary;
  }
}
