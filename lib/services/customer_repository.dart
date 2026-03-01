import 'package:sqflite/sqflite.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';
import 'package:uuid/uuid.dart';
import 'activity_log_repository.dart';
import '../models/customer_contact.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Customer>> getAllCustomers({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final filter = includeHidden ? '' : 'WHERE COALESCE(mh.is_hidden, c.is_hidden, 0) = 0';
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
             COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
      FROM customers c
      LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
      LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
      $filter
      ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
    ''');
    if (maps.isEmpty) {
      await _generateSampleCustomers(limit: 3);
      maps = await db.rawQuery('''
        SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
               COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
        FROM customers c
        LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
        LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
        $filter
        ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
      ''');
    }
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<void> ensureCustomerColumns() async {
    final db = await _dbHelper.database;
    // best-effort, ignore errors if columns already exist
    try {
      await db.execute('ALTER TABLE customers ADD COLUMN contact_version_id INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE customers ADD COLUMN head_char1 TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE customers ADD COLUMN head_char2 TEXT');
    } catch (_) {}
  }

  Future<void> _generateSampleCustomers({int limit = 3}) async {
    final samples = [
      Customer(id: const Uuid().v4(), displayName: "佐々木製作所", formalName: "株式会社 佐々木製作所", title: "御中", tel: "03-1111-2222", address: "東京都港区1-1-1"),
      Customer(id: const Uuid().v4(), displayName: "田中商事", formalName: "田中商事 株式会社", title: "様", tel: "03-3333-4444", address: "東京都中央区2-2-2"),
      Customer(id: const Uuid().v4(), displayName: "山田建材", formalName: "有限会社 山田建材", title: "御中", tel: "045-555-6666", address: "神奈川県横浜市3-3-3"),
      Customer(id: const Uuid().v4(), displayName: "鈴木運送", formalName: "鈴木運送 合同会社", title: "様", tel: "052-777-8888", address: "愛知県名古屋市4-4-4"),
      Customer(id: const Uuid().v4(), displayName: "伊藤工務店", formalName: "伊藤工務店", title: "様", tel: "06-9999-0000", address: "大阪府大阪市5-5-5"),
    ];
    for (var s in samples.take(limit)) {
      await saveCustomer(s);
    }
  }

  Future<void> saveCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'customers',
        customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _upsertActiveContact(txn, customer);
    });

    await _logRepo.logAction(
      action: "SAVE_CUSTOMER",
      targetType: "CUSTOMER",
      targetId: customer.id,
      details: "名称: ${customer.formalName}, 敬称: ${customer.title}",
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logRepo.logAction(
      action: "DELETE_CUSTOMER",
      targetType: "CUSTOMER",
      targetId: id,
      details: "顧客を削除しました",
    );
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

  Future<List<Customer>> searchCustomers(String query, {bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final where = includeHidden ? '' : 'AND COALESCE(mh.is_hidden, c.is_hidden, 0) = 0';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
             COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
      FROM customers c
      LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
      LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
      WHERE (c.display_name LIKE ? OR c.formal_name LIKE ?) $where
      ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
      LIMIT 50
    ''', ['%$query%', '%$query%']);
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<void> updateContact({required String customerId, String? email, String? tel, String? address}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final nextVersion = await _nextContactVersion(txn, customerId);
      await txn.update('customer_contacts', {'is_active': 0}, where: 'customer_id = ?', whereArgs: [customerId]);
      await txn.insert('customer_contacts', {
        'id': const Uuid().v4(),
        'customer_id': customerId,
        'email': email,
        'tel': tel,
        'address': address,
        'version': nextVersion,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await _logRepo.logAction(
      action: "UPDATE_CUSTOMER_CONTACT",
      targetType: "CUSTOMER",
      targetId: customerId,
      details: "連絡先を更新 (version up)",
    );
  }

  Future<CustomerContact?> getActiveContact(String customerId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('customer_contacts', where: 'customer_id = ? AND is_active = 1', whereArgs: [customerId], limit: 1);
    if (rows.isEmpty) return null;
    return CustomerContact.fromMap(rows.first);
  }

  Future<void> setHidden(String id, bool hidden) async {
    final db = await _dbHelper.database;
    await db.insert(
      'master_hidden',
      {
        'master_type': 'customer',
        'master_id': id,
        'is_hidden': hidden ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logRepo.logAction(
      action: hidden ? "HIDE_CUSTOMER" : "UNHIDE_CUSTOMER",
      targetType: "CUSTOMER",
      targetId: id,
      details: hidden ? "顧客を非表示にしました" : "顧客を再表示しました",
    );
  }

  Future<int> _nextContactVersion(DatabaseExecutor txn, String customerId) async {
    final res = await txn.rawQuery('SELECT MAX(version) as v FROM customer_contacts WHERE customer_id = ?', [customerId]);
    final current = res.first['v'] as int?;
    return (current ?? 0) + 1;
  }

  Future<void> _upsertActiveContact(DatabaseExecutor txn, Customer customer) async {
    final nextVersion = await _nextContactVersion(txn, customer.id);
    await txn.update('customer_contacts', {'is_active': 0}, where: 'customer_id = ?', whereArgs: [customer.id]);
    await txn.insert('customer_contacts', {
      'id': const Uuid().v4(),
      'customer_id': customer.id,
      'email': customer.email,
      'tel': customer.tel,
      'address': customer.address,
      'version': nextVersion,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
