import 'package:sqflite/sqflite.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'display_name ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<void> saveCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _dbHelper.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // GPS履歴の保存 (直近10件を自動管理)
  Future<void> addGpsHistory(String customerId, double latitude, double longitude) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 履歴を追加
      await txn.insert('customer_gps_history', {
        'customer_id': customerId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': now,
      });

      // 10件を超えた古い履歴を削除
      await txn.execute('''
        DELETE FROM customer_gps_history 
        WHERE id IN (
          SELECT id FROM customer_gps_history 
          WHERE customer_id = ? 
          ORDER BY timestamp DESC 
          LIMIT -1 OFFSET 10
        )
      ''', [customerId]);
    });
  }

  Future<List<Map<String, dynamic>>> getGpsHistory(String customerId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'customer_gps_history',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'timestamp DESC',
    );
  }
}
