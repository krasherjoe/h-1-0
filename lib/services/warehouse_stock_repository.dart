import 'package:sqflite/sqflite.dart';

import '../models/stock_transfer_models.dart';
import 'database_helper.dart';

class WarehouseStockRepository {
  WarehouseStockRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<WarehouseStock?> fetchStock(String productId, String warehouseId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final rows = await db.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WarehouseStock.fromMap(rows.first);
  }

  Future<int> getQuantity(String productId, String warehouseId, {DatabaseExecutor? executor}) async {
    final stock = await fetchStock(productId, warehouseId, executor: executor);
    return stock?.quantity ?? 0;
  }

  Future<List<WarehouseStock>> fetchByProduct(String productId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final rows = await db.query(
      'warehouse_stock',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return rows.map(WarehouseStock.fromMap).toList();
  }

  Future<void> setQuantity(String productId, String warehouseId, int quantity, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.insert(
      'warehouse_stock',
      {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> adjustQuantity(String productId, String warehouseId, int delta, {DatabaseExecutor? executor}) async {
    final current = await getQuantity(productId, warehouseId, executor: executor);
    final next = current + delta;
    if (next < 0) {
      throw StateError('倉庫[$warehouseId]の商品[$productId]の在庫が不足しています (残量: $current, 変動: $delta)');
    }
    await setQuantity(productId, warehouseId, next, executor: executor);
  }

  Future<int> getTotalQuantity(String productId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final result = await db.rawQuery(
      'SELECT SUM(quantity) AS total FROM warehouse_stock WHERE product_id = ?',
      [productId],
    );
    final total = result.first['total'];
    return (total as int?) ?? 0;
  }

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _dbHelper.database;
  }
}
