import 'package:sqflite/sqflite.dart';

import '../models/purchase_entry_models.dart';
import 'database_helper.dart';

class PurchaseEntryRepository {
  PurchaseEntryRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> upsertEntry(PurchaseEntry entry) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('purchase_entries', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('purchase_line_items', where: 'purchase_entry_id = ?', whereArgs: [entry.id]);
      for (final item in entry.items) {
        await txn.insert('purchase_line_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<PurchaseEntry?> findById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('purchase_entries', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final items = await _fetchItems(db, id);
    return PurchaseEntry.fromMap(rows.first, items: items);
  }

  Future<List<PurchaseEntry>> fetchEntries({PurchaseEntryStatus? status, int? limit}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await db.query(
      'purchase_entries',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'issue_date DESC, updated_at DESC',
      limit: limit,
    );
    final result = <PurchaseEntry>[];
    for (final row in rows) {
      final items = await _fetchItems(db, row['id'] as String);
      result.add(PurchaseEntry.fromMap(row, items: items));
    }
    return result;
  }

  Future<void> deleteEntry(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('purchase_line_items', where: 'purchase_entry_id = ?', whereArgs: [id]);
      await txn.delete('purchase_receipt_links', where: 'purchase_entry_id = ?', whereArgs: [id]);
      await txn.delete('purchase_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<PurchaseLineItem>> _fetchItems(DatabaseExecutor db, String entryId) async {
    final rows = await db.query('purchase_line_items', where: 'purchase_entry_id = ?', whereArgs: [entryId]);
    return rows.map(PurchaseLineItem.fromMap).toList();
  }
}
