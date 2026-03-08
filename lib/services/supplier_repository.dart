import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
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
    
    if (maps.isEmpty) {
      await _generateSampleSuppliers(limit: 3);
      maps = await db.rawQuery('''
        SELECT s.*, COALESCE(mh.is_hidden, s.is_hidden, 0) AS is_hidden
        FROM suppliers s
        LEFT JOIN master_hidden mh ON mh.master_type = 'supplier' AND mh.master_id = s.id
        $filter
        ORDER BY ${includeHidden ? 's.id DESC' : 's.display_name ASC'}
      ''');
    }
    
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

  Future<void> _generateSampleSuppliers({int limit = 5}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    
    final sampleSuppliers = [
      Supplier(
        id: const Uuid().v4(),
        displayName: 'サプライヤーA',
        formalName: '株式会社サプライヤーA',
        department: '営業部',
        tel: '03-1234-5678',
        email: 'info@supplier-a.com',
        contactPerson: '田中 太郎',
        paymentTerms: '月末締め・翌月末払い',
        closingDay: 31,
        paymentSiteDays: 30,
        updatedAt: now,
      ),
      Supplier(
        id: const Uuid().v4(),
        displayName: 'サプライヤーB',
        formalName: 'サプライヤーB商事',
        department: '仕入部',
        tel: '03-9876-5432',
        email: 'order@supplier-b.com',
        contactPerson: '鈴木 花子',
        paymentTerms: '15日締め・翌15日払い',
        closingDay: 15,
        paymentSiteDays: 30,
        updatedAt: now,
      ),
      Supplier(
        id: const Uuid().v4(),
        displayName: 'サプライヤーC',
        formalName: '有限会社サプライヤーC',
        tel: '06-1111-2222',
        email: 'sales@supplier-c.com',
        contactPerson: '佐藤 次郎',
        paymentTerms: '都度払い',
        paymentSiteDays: 0,
        updatedAt: now,
      ),
    ];

    for (final supplier in sampleSuppliers.take(limit)) {
      await db.insert('suppliers', supplier.toMap());
    }
  }
}
