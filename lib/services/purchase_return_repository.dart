import 'package:sqflite/sqflite.dart';

import '../models/purchase_order_models.dart';
import 'database_helper.dart';

class PurchaseReturnRepository {
  PurchaseReturnRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> upsertReturn(PurchaseReturn purchaseReturn) async {
    final db = await _dbHelper.database;
    final withTotals = purchaseReturn.recalcTotals();
    await db.transaction((txn) async {
      await txn.insert('purchase_returns', withTotals.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('purchase_return_items', where: 'return_id = ?', whereArgs: [withTotals.id]);
      for (final item in withTotals.items) {
        await txn.insert('purchase_return_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<PurchaseReturn?> findById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('purchase_returns', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final items = await _fetchItems(db, id);
    return PurchaseReturn.fromMap(rows.first, items: items);
  }

  Future<List<PurchaseReturn>> fetchReturns({PurchaseReturnStatus? status, int? limit}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await db.query(
      'purchase_returns',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'return_date DESC, updated_at DESC',
      limit: limit,
    );
    final result = <PurchaseReturn>[];
    for (final row in rows) {
      final items = await _fetchItems(db, row['id'] as String);
      result.add(PurchaseReturn.fromMap(row, items: items));
    }
    return result;
  }

  Future<void> deleteReturn(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('purchase_return_items', where: 'return_id = ?', whereArgs: [id]);
      await txn.delete('purchase_returns', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<PurchaseReturnItem>> _fetchItems(DatabaseExecutor db, String returnId) async {
    final rows = await db.query('purchase_return_items', where: 'return_id = ?', whereArgs: [returnId]);
    return rows.map(PurchaseReturnItem.fromMap).toList();
  }
}
