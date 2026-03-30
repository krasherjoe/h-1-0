import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/inventory_model.dart';
import 'database_helper.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Inventory>> getAllInventory() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory',
      orderBy: 'product_name ASC',
    );

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }

  Future<Inventory?> getInventory(String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory',
      where: 'product_id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Inventory.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateInventory(String productId, int quantity) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    
    await db.insert(
      'inventory',
      {
        'id': const Uuid().v4(),
        'product_id': productId,
        'product_name': '商品名', // 実際は商品マスターから取得
        'quantity': quantity,
        'reserved_quantity': 0,
        'warehouse_id': 'WH-001',
        'warehouse_name': '主倉庫',
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> adjustInventory(String productId, int adjustment) async {
    final inventory = await getInventory(productId);
    final newQuantity = (inventory?.quantity ?? 0) + adjustment;
    
    if (newQuantity < 0) {
      throw Exception('在庫がマイナスになります');
    }
    
    await updateInventory(productId, newQuantity);
  }

  Future<void> adjustReservation(String productId, int adjustment) async {
    final db = await _dbHelper.database;
    final inventory = await getInventory(productId);
    
    if (inventory == null) {
      throw Exception('在庫が見つかりません');
    }
    
    final newReserved = (inventory.reservedQuantity + adjustment)
        .clamp(0, inventory.quantity);
    
    await db.update(
      'inventory',
      {
        'reserved_quantity': newReserved,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<Inventory>> getLowStockItems() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory',
      where: 'quantity <= reorder_point AND reorder_point IS NOT NULL',
      orderBy: 'product_name ASC',
    );

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }

  Future<List<Inventory>> getOutOfStockItems() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory',
      where: 'quantity <= 0',
      orderBy: 'product_name ASC',
    );

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }

  Future<void> saveInventory(Inventory inventory) async {
    final db = await _dbHelper.database;
    await db.insert(
      'inventory',
      inventory.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteInventory(String id) async {
    final db = await _dbHelper.database;
    await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

}
