import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'package:uuid/uuid.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Product>> getAllProducts({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final String where = includeHidden ? '' : 'WHERE COALESCE(mh.is_hidden, p.is_hidden, 0) = 0';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
      FROM products p
      LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
      $where
      ORDER BY ${includeHidden ? 'p.id DESC' : 'p.name ASC'}
    ''');

    if (maps.isEmpty) {
      await _generateSampleProducts();
      return getAllProducts(includeHidden: includeHidden);
    }

    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> searchProducts(String query, {bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final args = ['%$query%', '%$query%', '%$query%'];
    final String whereHidden = includeHidden ? '' : 'AND COALESCE(mh.is_hidden, p.is_hidden, 0) = 0';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
      FROM products p
      LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
      WHERE (p.name LIKE ? OR p.barcode LIKE ? OR p.category LIKE ?)
      $whereHidden
      ORDER BY ${includeHidden ? 'p.id DESC' : 'p.name ASC'}
      LIMIT 50
    ''', args);
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<void> _generateSampleProducts() async {
    final samples = [
      Product(id: const Uuid().v4(), name: "基本技術料", defaultUnitPrice: 50000, category: "技術料"),
      Product(id: const Uuid().v4(), name: "出張診断費", defaultUnitPrice: 10000, category: "諸経費"),
      Product(id: const Uuid().v4(), name: "交換用ハードディスク (1TB)", defaultUnitPrice: 8500, category: "パーツ"),
      Product(id: const Uuid().v4(), name: "メモリ増設 (8GB)", defaultUnitPrice: 6000, category: "パーツ"),
      Product(id: const Uuid().v4(), name: "OSインストール作業", defaultUnitPrice: 15000, category: "技術料"),
      Product(id: const Uuid().v4(), name: "データ復旧作業 (軽度)", defaultUnitPrice: 30000, category: "技術料"),
      Product(id: const Uuid().v4(), name: "LANケーブル (5m)", defaultUnitPrice: 1200, category: "サプライ"),
      Product(id: const Uuid().v4(), name: "ウイルス除去作業", defaultUnitPrice: 20000, category: "技術料"),
      Product(id: const Uuid().v4(), name: "液晶ディスプレイ (24インチ)", defaultUnitPrice: 25000, category: "周辺機器"),
      Product(id: const Uuid().v4(), name: "定期保守契約料 (月額)", defaultUnitPrice: 5000, category: "保守"),
    ];
    for (var s in samples) {
      await saveProduct(s);
    }
  }

  Future<void> saveProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _logRepo.logAction(
      action: "SAVE_PRODUCT",
      targetType: "PRODUCT",
      targetId: product.id,
      details: "商品名: ${product.name}, 単価: ${product.defaultUnitPrice}, カテゴリ: ${product.category ?? '未設定'}",
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logRepo.logAction(
      action: "DELETE_PRODUCT",
      targetType: "PRODUCT",
      targetId: id,
      details: "商品を削除しました",
    );
  }

  Future<void> setHidden(String id, bool hidden) async {
    final db = await _dbHelper.database;
    await db.insert(
      'master_hidden',
      {
        'master_type': 'product',
        'master_id': id,
        'is_hidden': hidden ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logRepo.logAction(
      action: hidden ? "HIDE_PRODUCT" : "UNHIDE_PRODUCT",
      targetType: "PRODUCT",
      targetId: id,
      details: hidden ? "商品を非表示にしました" : "商品を再表示しました",
    );
  }

  Future<void> updateStockQuantities(Map<String, int> adjustments) async {
    if (adjustments.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final entry in adjustments.entries) {
        await txn.update(
          'products',
          {'stock_quantity': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });

    for (final entry in adjustments.entries) {
      await _logRepo.logAction(
        action: 'STOCKTAKE_ADJUST',
        targetType: 'PRODUCT',
        targetId: entry.key,
        details: '棚卸で在庫数を${entry.value}に更新',
      );
    }
  }
}
