import 'package:sqflite/sqflite.dart';

import '../models/supplier_model.dart';
import 'database_helper.dart';

class SupplierRepository {
  SupplierRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Supplier>> fetchSuppliers({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'suppliers',
      where: includeHidden ? null : 'is_hidden = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => Supplier.fromMap(row)).toList();
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSupplier(String supplierId) async {
    final db = await _dbHelper.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [supplierId]);
  }
}
