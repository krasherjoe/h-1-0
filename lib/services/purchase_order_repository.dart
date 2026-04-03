import 'package:sqflite/sqflite.dart';

import '../models/purchase_order_models.dart';
import 'database_helper.dart';

class PurchaseOrderRepository {
  PurchaseOrderRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> upsertOrder(PurchaseOrder order) async {
    final db = await _dbHelper.database;
    final withTotals = order.recalcTotals();
    await db.transaction((txn) async {
      await txn.insert('purchase_orders', withTotals.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('purchase_order_items', where: 'order_id = ?', whereArgs: [withTotals.id]);
      for (final item in withTotals.items) {
        await txn.insert('purchase_order_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<PurchaseOrder?> findById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('purchase_orders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final items = await _fetchItems(db, id);
    return PurchaseOrder.fromMap(rows.first, items: items);
  }

  Future<List<PurchaseOrder>> fetchOrders({PurchaseOrderStatus? status, int? limit}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await db.query(
      'purchase_orders',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'order_date DESC, updated_at DESC',
      limit: limit,
    );
    final result = <PurchaseOrder>[];
    for (final row in rows) {
      final items = await _fetchItems(db, row['id'] as String);
      result.add(PurchaseOrder.fromMap(row, items: items));
    }
    return result;
  }

  Future<void> deleteOrder(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('purchase_order_items', where: 'order_id = ?', whereArgs: [id]);
      await txn.delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<PurchaseOrderItem>> _fetchItems(DatabaseExecutor db, String orderId) async {
    final rows = await db.query('purchase_order_items', where: 'order_id = ?', whereArgs: [orderId]);
    return rows.map(PurchaseOrderItem.fromMap).toList();
  }
}
