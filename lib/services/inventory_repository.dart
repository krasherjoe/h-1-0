import '../models/inventory_model.dart';
import 'database_helper.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Inventory>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        i.id,
        i.product_id,
        p.name as product_name,
        i.quantity,
        i.warehouse_id,
        w.name as warehouse_name,
        i.updated_at
      FROM inventory i
      LEFT JOIN products p ON i.product_id = p.id
      LEFT JOIN warehouses w ON i.warehouse_id = w.id
      ORDER BY p.name
    ''');

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }

  Future<List<Inventory>> getByWarehouse(String warehouseId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        i.id,
        i.product_id,
        p.name as product_name,
        i.quantity,
        i.warehouse_id,
        w.name as warehouse_name,
        i.updated_at
      FROM inventory i
      LEFT JOIN products p ON i.product_id = p.id
      LEFT JOIN warehouses w ON i.warehouse_id = w.id
      WHERE i.warehouse_id = ?
      ORDER BY p.name
    ''', [warehouseId]);

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }
}
