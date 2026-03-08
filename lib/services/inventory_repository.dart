import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/inventory_model.dart';
import 'database_helper.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Inventory>> getAllInventory() async {
    final db = await _dbHelper.database;
    
    // サンプルデータがなければ生成
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM inventory');
    if ((count.first['count'] as int) == 0) {
      await _generateSampleInventory();
    }
    
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

  Future<void> _generateSampleInventory() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    
    final sampleInventory = [
      Inventory(
        id: const Uuid().v4(),
        productId: 'PROD-001',
        productName: 'サンプル商品A',
        quantity: 100,
        reservedQuantity: 20,
        location: 'A-1-01',
        warehouseId: 'WH-001',
        warehouseName: '主倉庫',
        unitCost: 1000.0,
        reorderPoint: 50,
        safetyStock: 20,
        updatedAt: now,
      ),
      Inventory(
        id: const Uuid().v4(),
        productId: 'PROD-002',
        productName: 'サンプル商品B',
        quantity: 25,
        reservedQuantity: 5,
        location: 'A-1-02',
        warehouseId: 'WH-001',
        warehouseName: '主倉庫',
        unitCost: 2000.0,
        reorderPoint: 30,
        safetyStock: 10,
        updatedAt: now,
      ),
      Inventory(
        id: const Uuid().v4(),
        productId: 'PROD-003',
        productName: 'サンプル商品C',
        quantity: 0,
        reservedQuantity: 0,
        location: 'B-2-01',
        warehouseId: 'WH-001',
        warehouseName: '主倉庫',
        unitCost: 500.0,
        reorderPoint: 20,
        safetyStock: 5,
        updatedAt: now,
      ),
    ];

    for (final inventory in sampleInventory) {
      await db.insert('inventory', inventory.toMap());
    }
  }
}
