import 'package:sqflite/sqflite.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';
import 'package:uuid/uuid.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'display_name ASC');
    
    if (maps.isEmpty) {
      await _generateSampleCustomers();
      return getAllCustomers(); // 再帰的に読み込み
    }
    
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<void> _generateSampleCustomers() async {
    final samples = [
      Customer(id: const Uuid().v4(), displayName: "佐々木製作所", formalName: "株式会社 佐々木製作所", title: "御中"),
      Customer(id: const Uuid().v4(), displayName: "田中商事", formalName: "田中商事 株式会社", title: "様"),
      Customer(id: const Uuid().v4(), displayName: "山田建材", formalName: "有限会社 山田建材", title: "御中"),
      Customer(id: const Uuid().v4(), displayName: "鈴木運送", formalName: "鈴木運送 合同会社", title: "様"),
      Customer(id: const Uuid().v4(), displayName: "伊藤工務店", formalName: "伊藤工務店", title: "様"),
      Customer(id: const Uuid().v4(), displayName: "渡辺興業", formalName: "株式会社 渡辺興業", title: "御中"),
      Customer(id: const Uuid().v4(), displayName: "高橋電気", formalName: "高橋電気工業所", title: "様"),
      Customer(id: const Uuid().v4(), displayName: "佐藤商店", formalName: "佐藤商店", title: "様"),
      Customer(id: const Uuid().v4(), displayName: "中村機械", formalName: "中村機械製作所", title: "殿"),
      Customer(id: const Uuid().v4(), displayName: "小林産業", formalName: "小林産業 株式会社", title: "御中"),
    ];
    for (var s in samples) {
      await saveCustomer(s);
    }
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
