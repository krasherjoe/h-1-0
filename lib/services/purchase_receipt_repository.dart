import 'package:sqflite/sqflite.dart';

import '../models/purchase_entry_models.dart';
import 'database_helper.dart';

class PurchaseReceiptRepository {
  PurchaseReceiptRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> upsertReceipt(PurchaseReceipt receipt, List<PurchaseReceiptLink> links) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('purchase_receipts', receipt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('purchase_receipt_links', where: 'receipt_id = ?', whereArgs: [receipt.id]);
      for (final link in links) {
        await txn.insert('purchase_receipt_links', link.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<PurchaseReceipt>> fetchReceipts({DateTime? startDate, DateTime? endDate}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (startDate != null) {
      where.add('payment_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.add('payment_date <= ?');
      args.add(endDate.toIso8601String());
    }
    final rows = await db.query(
      'purchase_receipts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'payment_date DESC, updated_at DESC',
    );
    return rows.map(PurchaseReceipt.fromMap).toList();
  }

  Future<PurchaseReceipt?> findById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('purchase_receipts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return PurchaseReceipt.fromMap(rows.first);
  }

  Future<List<PurchaseReceiptLink>> fetchLinks(String receiptId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('purchase_receipt_links', where: 'receipt_id = ?', whereArgs: [receiptId]);
    return rows.map(PurchaseReceiptLink.fromMap).toList();
  }

  Future<Map<String, int>> fetchAllocatedTotals(Iterable<String> purchaseEntryIds) async {
    final ids = purchaseEntryIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    final db = await _dbHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT purchase_entry_id, SUM(allocated_amount) AS total FROM purchase_receipt_links WHERE purchase_entry_id IN ($placeholders) GROUP BY purchase_entry_id',
      ids,
    );
    final result = <String, int>{};
    for (final row in rows) {
      final entryId = row['purchase_entry_id'] as String?;
      if (entryId == null) continue;
      result[entryId] = (row['total'] as num?)?.toInt() ?? 0;
    }
    return result;
  }

  Future<void> deleteReceipt(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('purchase_receipt_links', where: 'receipt_id = ?', whereArgs: [id]);
      await txn.delete('purchase_receipts', where: 'id = ?', whereArgs: [id]);
    });
  }
}
