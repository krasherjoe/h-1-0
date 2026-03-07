import 'package:sqflite/sqflite.dart';

import '../models/warehouse_model.dart';
import 'activity_log_repository.dart';
import 'database_helper.dart';

class WarehouseRepository {
  WarehouseRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Warehouse>> fetchWarehouses({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'warehouses',
      where: includeHidden ? null : 'is_hidden = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => Warehouse.fromMap(row)).toList();
  }

  Future<void> saveWarehouse(Warehouse warehouse) async {
    final db = await _dbHelper.database;
    await db.insert(
      'warehouses',
      warehouse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _logRepo.logAction(
      action: 'SAVE_WAREHOUSE',
      targetType: 'WAREHOUSE',
      targetId: warehouse.id,
      details: '倉庫名: ${warehouse.name}',
    );
  }

  Future<void> deleteWarehouse(String warehouseId) async {
    final db = await _dbHelper.database;
    await db.delete('warehouses', where: 'id = ?', whereArgs: [warehouseId]);

    await _logRepo.logAction(
      action: 'DELETE_WAREHOUSE',
      targetType: 'WAREHOUSE',
      targetId: warehouseId,
      details: '倉庫を削除しました',
    );
  }

  Future<void> setHidden(String id, bool hidden) async {
    final db = await _dbHelper.database;
    await db.update(
      'warehouses',
      {'is_hidden': hidden ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logRepo.logAction(
      action: hidden ? 'HIDE_WAREHOUSE' : 'UNHIDE_WAREHOUSE',
      targetType: 'WAREHOUSE',
      targetId: id,
      details: hidden ? '倉庫を非表示にしました' : '倉庫を再表示しました',
    );
  }
}
