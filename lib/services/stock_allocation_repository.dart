import 'package:uuid/uuid.dart';
import '../models/stock_allocation_model.dart';
import 'database_helper.dart';

/// 在庫引当リポジトリ
class StockAllocationRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<StockAllocation>> getByProduct(String productId) async {
    final db = await _db.database;
    final rows = await db.query('stock_allocations',
      where: 'product_id = ? AND status = ?',
      whereArgs: [productId, 'allocated'],
    );
    return rows.map(StockAllocation.fromMap).toList();
  }

  Future<int> getAllocatedQuantity(String productId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(allocated_quantity), 0) as qty
      FROM stock_allocations
      WHERE product_id = ? AND status = ?
    ''', [productId, 'allocated']);
    return (rows.first['qty'] as num?)?.toInt() ?? 0;
  }

  /// 受注から引当を作成
  Future<void> allocateForOrder(String orderId, String productId, int quantity) async {
    final db = await _db.database;
    await db.insert('stock_allocations', StockAllocation(
      id: const Uuid().v4(),
      orderId: orderId,
      productId: productId,
      allocatedQuantity: quantity,
      createdAt: DateTime.now(),
    ).toMap());
  }

  /// 出庫後に引当を解除
  Future<void> releaseByOrder(String orderId) async {
    final db = await _db.database;
    await db.update('stock_allocations',
      {'status': 'released', 'released_at': DateTime.now().toIso8601String()},
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }
}
