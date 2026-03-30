import 'package:sqflite/sqflite.dart';
import '../models/supplier_model.dart';
import 'database_helper.dart';

class SupplierRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Supplier>> getAllSuppliers({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final filter = includeHidden ? '' : 'WHERE COALESCE(mh.is_hidden, s.is_hidden, 0) = 0';
    
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*, COALESCE(mh.is_hidden, s.is_hidden, 0) AS is_hidden
      FROM suppliers s
      LEFT JOIN master_hidden mh ON mh.master_type = 'supplier' AND mh.master_id = s.id
      $filter
      ORDER BY ${includeHidden ? 's.id DESC' : 's.display_name ASC'}
    ''');
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  Future<void> ensureSupplierColumns() async {
    final db = await _dbHelper.database;
    // best-effort, ignore errors if columns already exist
    try {
      await db.execute('ALTER TABLE suppliers ADD COLUMN head_char1 TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE suppliers ADD COLUMN head_char2 TEXT');
    } catch (_) {}
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSupplier(String id) async {
    final db = await _dbHelper.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<Supplier?> getSupplier(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Supplier.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Supplier>> fetchSuppliers({bool includeHidden = false}) async {
    return getAllSuppliers(includeHidden: includeHidden);
  }

  Future<Supplier?> findById(String id) async {
    return getSupplier(id);
  }

}
