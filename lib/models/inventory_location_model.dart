/// 在庫ロケーションモデル
class InventoryLocation {
  final String id;
  final String warehouseId;
  final String locationCode;
  final String locationName;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryLocation({
    required this.id,
    required this.warehouseId,
    required this.locationCode,
    required this.locationName,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Mapに変換（DB保存用）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'warehouse_id': warehouseId,
      'location_code': locationCode,
      'location_name': locationName,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Mapから生成（DB読み込み用）
  factory InventoryLocation.fromMap(Map<String, dynamic> map) {
    return InventoryLocation(
      id: map['id'] as String,
      warehouseId: map['warehouse_id'] as String,
      locationCode: map['location_code'] as String,
      locationName: map['location_name'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// コピーを作成
  InventoryLocation copyWith({
    String? id,
    String? warehouseId,
    String? locationCode,
    String? locationName,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryLocation(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      locationCode: locationCode ?? this.locationCode,
      locationName: locationName ?? this.locationName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryLocation &&
        other.id == id &&
        other.warehouseId == warehouseId &&
        other.locationCode == locationCode &&
        other.locationName == locationName &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      warehouseId,
      locationCode,
      locationName,
      description,
      isActive,
    );
  }

  @override
  String toString() {
    return 'InventoryLocation(id: $id, code: $locationCode, name: $locationName, active: $isActive)';
  }
}

/// 在庫移動タイプ
enum InventoryMovementType {
  stockIn,    // 入庫
  stockOut,   // 出庫
  transfer,   // 移動
  adjustment, // 調整
  stocktake,  // 棚卸
}

/// 在庫移動モデル
class InventoryMovement {
  final String id;
  final String productId;
  final String warehouseId;
  final String? locationId;
  final InventoryMovementType movementType;
  final int quantity;
  final String? referenceId;
  final String? referenceType;
  final String? notes;
  final DateTime movementDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.warehouseId,
    this.locationId,
    required this.movementType,
    required this.quantity,
    this.referenceId,
    this.referenceType,
    this.notes,
    required this.movementDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Mapに変換（DB保存用）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'location_id': locationId,
      'movement_type': movementType.name,
      'quantity': quantity,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'notes': notes,
      'movement_date': movementDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Mapから生成（DB読み込み用）
  factory InventoryMovement.fromMap(Map<String, dynamic> map) {
    return InventoryMovement(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      warehouseId: map['warehouse_id'] as String,
      locationId: map['location_id'] as String?,
      movementType: InventoryMovementType.values.firstWhere(
        (e) => e.name == map['movement_type'],
        orElse: () => InventoryMovementType.adjustment,
      ),
      quantity: map['quantity'] as int,
      referenceId: map['reference_id'] as String?,
      referenceType: map['reference_type'] as String?,
      notes: map['notes'] as String?,
      movementDate: DateTime.parse(map['movement_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// 移動タイプ名を取得
  String get movementTypeName {
    switch (movementType) {
      case InventoryMovementType.stockIn:
        return '入庫';
      case InventoryMovementType.stockOut:
        return '出庫';
      case InventoryMovementType.transfer:
        return '移動';
      case InventoryMovementType.adjustment:
        return '調整';
      case InventoryMovementType.stocktake:
        return '棚卸';
    }
  }

  /// コピーを作成
  InventoryMovement copyWith({
    String? id,
    String? productId,
    String? warehouseId,
    String? locationId,
    InventoryMovementType? movementType,
    int? quantity,
    String? referenceId,
    String? referenceType,
    String? notes,
    DateTime? movementDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      warehouseId: warehouseId ?? this.warehouseId,
      locationId: locationId ?? this.locationId,
      movementType: movementType ?? this.movementType,
      quantity: quantity ?? this.quantity,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      notes: notes ?? this.notes,
      movementDate: movementDate ?? this.movementDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryMovement &&
        other.id == id &&
        other.productId == productId &&
        other.warehouseId == warehouseId &&
        other.locationId == locationId &&
        other.movementType == movementType &&
        other.quantity == quantity &&
        other.referenceId == referenceId &&
        other.referenceType == referenceType &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      productId,
      warehouseId,
      locationId,
      movementType,
      quantity,
      referenceId,
      referenceType,
      notes,
    );
  }

  @override
  String toString() {
    return 'InventoryMovement(id: $id, type: $movementType, quantity: $quantity, date: $movementDate)';
  }
}
