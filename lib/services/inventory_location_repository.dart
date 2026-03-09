import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory_location_model.dart';
import 'database_helper.dart';

/// 在庫ロケーションリポジトリ
class InventoryLocationRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// すべてのロケーションを取得
  Future<List<InventoryLocation>> getAllLocations() async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_locations',
      orderBy: 'warehouse_id, location_code',
    );

    return maps.map((map) => InventoryLocation.fromMap(map)).toList();
  }

  /// ウェアハウス別のロケーションを取得
  Future<List<InventoryLocation>> getLocationsByWarehouse(String warehouseId) async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_locations',
      where: 'warehouse_id = ?',
      whereArgs: [warehouseId],
      orderBy: 'location_code',
    );

    return maps.map((map) => InventoryLocation.fromMap(map)).toList();
  }

  /// アクティブなロケーションのみを取得
  Future<List<InventoryLocation>> getActiveLocations() async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_locations',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'warehouse_id, location_code',
    );

    return maps.map((map) => InventoryLocation.fromMap(map)).toList();
  }

  /// IDでロケーションを取得
  Future<InventoryLocation?> getLocation(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_locations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return InventoryLocation.fromMap(maps.first);
  }

  /// ロケーションを保存
  Future<void> saveLocation(InventoryLocation location) async {
    final database = await _db.database;
    final now = DateTime.now();
    final updatedLocation = location.copyWith(updatedAt: now);

    await database.insert(
      'inventory_locations',
      updatedLocation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ロケーションを削除
  Future<void> deleteLocation(String id) async {
    final database = await _db.database;
    await database.delete(
      'inventory_locations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ロケーションを非アクティブ化
  Future<void> deactivateLocation(String id) async {
    final database = await _db.database;
    await database.update(
      'inventory_locations',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ロケーションコードが存在するか確認
  Future<bool> locationCodeExists(String warehouseId, String locationCode, {String? excludeId}) async {
    final database = await _db.database;
    String where = 'warehouse_id = ? AND location_code = ?';
    List<dynamic> whereArgs = [warehouseId, locationCode];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final result = await database.query(
      'inventory_locations',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// デフォルトロケーションを作成
  Future<InventoryLocation> createDefaultLocation(String warehouseId) async {
    final existing = await getLocationsByWarehouse(warehouseId);
    if (existing.isNotEmpty) {
      return existing.firstWhere((loc) => loc.isActive, orElse: () => existing.first);
    }

    final defaultLocation = InventoryLocation(
      id: const Uuid().v4(),
      warehouseId: warehouseId,
      locationCode: 'DEFAULT',
      locationName: 'デフォルト',
      description: '自動作成されたデフォルトロケーション',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveLocation(defaultLocation);
    return defaultLocation;
  }
}

/// 在庫移動リポジトリ
class InventoryMovementRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// すべての移動履歴を取得
  Future<List<InventoryMovement>> getAllMovements() async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_movements',
      orderBy: 'movement_date DESC, created_at DESC',
    );

    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// 商品別の移動履歴を取得
  Future<List<InventoryMovement>> getMovementsByProduct(String productId) async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'movement_date DESC, created_at DESC',
    );

    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// ウェアハウス別の移動履歴を取得
  Future<List<InventoryMovement>> getMovementsByWarehouse(String warehouseId) async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_movements',
      where: 'warehouse_id = ?',
      whereArgs: [warehouseId],
      orderBy: 'movement_date DESC, created_at DESC',
    );

    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// ロケーション別の移動履歴を取得
  Future<List<InventoryMovement>> getMovementsByLocation(String locationId) async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_movements',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'movement_date DESC, created_at DESC',
    );

    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// 日付範囲の移動履歴を取得
  Future<List<InventoryMovement>> getMovementsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final database = await _db.database;
    final maps = await database.query(
      'inventory_movements',
      where: 'movement_date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'movement_date DESC, created_at DESC',
    );

    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// 移動を記録
  Future<void> recordMovement(InventoryMovement movement) async {
    final database = await _db.database;
    final now = DateTime.now();
    final updatedMovement = movement.copyWith(
      createdAt: now,
      updatedAt: now,
    );

    await database.insert(
      'inventory_movements',
      updatedMovement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 入庫を記録
  Future<void> recordStockIn({
    required String productId,
    required String warehouseId,
    String? locationId,
    required int quantity,
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    final movement = InventoryMovement(
      id: const Uuid().v4(),
      productId: productId,
      warehouseId: warehouseId,
      locationId: locationId,
      movementType: InventoryMovementType.stockIn,
      quantity: quantity,
      referenceId: referenceId,
      referenceType: referenceType,
      notes: notes,
      movementDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await recordMovement(movement);
  }

  /// 出庫を記録
  Future<void> recordStockOut({
    required String productId,
    required String warehouseId,
    String? locationId,
    required int quantity,
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    final movement = InventoryMovement(
      id: const Uuid().v4(),
      productId: productId,
      warehouseId: warehouseId,
      locationId: locationId,
      movementType: InventoryMovementType.stockOut,
      quantity: quantity,
      referenceId: referenceId,
      referenceType: referenceType,
      notes: notes,
      movementDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await recordMovement(movement);
  }

  /// 棚卸を記録
  Future<void> recordStocktake({
    required String productId,
    required String warehouseId,
    String? locationId,
    required int countedQuantity,
    String? notes,
  }) async {
    // 現在の在庫数を取得（実装は別途）
    // ここでは棚卸差分を記録
    final movement = InventoryMovement(
      id: const Uuid().v4(),
      productId: productId,
      warehouseId: warehouseId,
      locationId: locationId,
      movementType: InventoryMovementType.stocktake,
      quantity: countedQuantity,
      notes: notes,
      movementDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await recordMovement(movement);
  }

  /// 移動を削除
  Future<void> deleteMovement(String id) async {
    final database = await _db.database;
    await database.delete(
      'inventory_movements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 商品の現在の在庫数を計算
  Future<int> getCurrentStock(String productId, {String? warehouseId, String? locationId}) async {
    final database = await _db.database;
    
    String where = 'product_id = ?';
    List<dynamic> whereArgs = [productId];
    
    if (warehouseId != null) {
      where += ' AND warehouse_id = ?';
      whereArgs.add(warehouseId);
    }
    
    if (locationId != null) {
      where += ' AND location_id = ?';
      whereArgs.add(locationId);
    }

    final result = await database.rawQuery('''
      SELECT 
        SUM(CASE 
          WHEN movement_type = 'stockIn' THEN quantity
          WHEN movement_type = 'stockOut' THEN -quantity
          WHEN movement_type = 'stocktake' THEN quantity - (
            SELECT COALESCE(SUM(
              CASE 
                WHEN movement_type = 'stockIn' THEN quantity
                WHEN movement_type = 'stockOut' THEN -quantity
                ELSE 0
              END
            ), 0)
            FROM inventory_movements 
            WHERE product_id = ? AND movement_date < (
              SELECT MIN(movement_date) 
              FROM inventory_movements 
              WHERE product_id = ? AND movement_type = 'stocktake'
            )
          )
          ELSE 0
        END) as current_stock
      FROM inventory_movements
      WHERE $where
    ''', whereArgs + [productId, productId]);

    final stock = Sqflite.firstIntValue(result) ?? 0;
    return stock < 0 ? 0 : stock;
  }

  /// 移動統計を取得
  Future<Map<String, dynamic>> getMovementStats({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final database = await _db.database;
    
    String where = '1=1';
    List<dynamic> whereArgs = [];
    
    if (warehouseId != null) {
      where += ' AND warehouse_id = ?';
      whereArgs.add(warehouseId);
    }
    
    if (startDate != null) {
      where += ' AND movement_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      where += ' AND movement_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await database.rawQuery('''
      SELECT 
        movement_type,
        COUNT(*) as count,
        SUM(quantity) as total_quantity
      FROM inventory_movements
      WHERE $where
      GROUP BY movement_type
    ''', whereArgs);

    final stats = <String, Map<String, dynamic>>{};
    for (final row in result) {
      final type = row['movement_type'] as String;
      stats[type] = {
        'count': row['count'] as int,
        'total_quantity': row['total_quantity'] as int,
      };
    }

    return stats;
  }
}
