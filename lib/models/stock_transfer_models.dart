import 'package:flutter/foundation.dart';

@immutable
class WarehouseStock {
  const WarehouseStock({
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    required this.updatedAt,
  });

  final String productId;
  final String warehouseId;
  final int quantity;
  final DateTime updatedAt;

  factory WarehouseStock.fromMap(Map<String, Object?> map) {
    return WarehouseStock(
      productId: map['product_id'] as String,
      warehouseId: map['warehouse_id'] as String,
      quantity: map['quantity'] as int? ?? 0,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

@immutable
class StockTransferItem {
  const StockTransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.quantity,
    this.notes,
  });

  final String id;
  final String transferId;
  final String productId;
  final int quantity;
  final String? notes;

  StockTransferItem copyWith({
    String? id,
    String? transferId,
    String? productId,
    int? quantity,
    String? notes,
  }) {
    return StockTransferItem(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  factory StockTransferItem.fromMap(Map<String, Object?> map) {
    return StockTransferItem(
      id: map['id'] as String,
      transferId: map['transfer_id'] as String,
      productId: map['product_id'] as String,
      quantity: map['quantity'] as int? ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transfer_id': transferId,
      'product_id': productId,
      'quantity': quantity,
      'notes': notes,
    };
  }
}

@immutable
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.documentNo,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.transferDate,
    required this.createdAt,
    required this.updatedAt,
    this.memo,
    this.createdByDevice,
    this.items = const [],
  });

  final String id;
  final String documentNo;
  final String fromWarehouseId;
  final String toWarehouseId;
  final DateTime transferDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? memo;
  final String? createdByDevice;
  final List<StockTransferItem> items;

  StockTransfer copyWith({
    String? id,
    String? documentNo,
    String? fromWarehouseId,
    String? toWarehouseId,
    DateTime? transferDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? memo,
    String? createdByDevice,
    List<StockTransferItem>? items,
  }) {
    return StockTransfer(
      id: id ?? this.id,
      documentNo: documentNo ?? this.documentNo,
      fromWarehouseId: fromWarehouseId ?? this.fromWarehouseId,
      toWarehouseId: toWarehouseId ?? this.toWarehouseId,
      transferDate: transferDate ?? this.transferDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memo: memo ?? this.memo,
      createdByDevice: createdByDevice ?? this.createdByDevice,
      items: items ?? this.items,
    );
  }

  factory StockTransfer.fromMap(Map<String, Object?> map, {List<StockTransferItem> items = const []}) {
    return StockTransfer(
      id: map['id'] as String,
      documentNo: map['document_no'] as String,
      fromWarehouseId: map['from_warehouse_id'] as String,
      toWarehouseId: map['to_warehouse_id'] as String,
      memo: map['memo'] as String?,
      transferDate: DateTime.parse(map['transfer_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      createdByDevice: map['created_by_device'] as String?,
      items: items,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_no': documentNo,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'memo': memo,
      'transfer_date': transferDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by_device': createdByDevice,
    };
  }
}

class StockTransferLineInput {
  const StockTransferLineInput({
    required this.productId,
    required this.quantity,
    this.notes,
  });

  final String productId;
  final int quantity;
  final String? notes;
}
