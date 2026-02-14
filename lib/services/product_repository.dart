import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import 'package:uuid/uuid.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'name ASC');
    
    if (maps.isEmpty) {
      await _generateSampleProducts();
      return getAllProducts();
    }
    
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<void> _generateSampleProducts() async {
    final samples = [
      Product(id: const Uuid().v4(), name: "基本技術料", defaultUnitPrice: 50000),
      Product(id: const Uuid().v4(), name: "出張診断費", defaultUnitPrice: 10000),
      Product(id: const Uuid().v4(), name: "交換用ハードディスク (1TB)", defaultUnitPrice: 8500),
      Product(id: const Uuid().v4(), name: "メモリ増設 (8GB)", defaultUnitPrice: 6000),
      Product(id: const Uuid().v4(), name: "OSインストール作業", defaultUnitPrice: 15000),
      Product(id: const Uuid().v4(), name: "データ復旧作業 (軽度)", defaultUnitPrice: 30000),
      Product(id: const Uuid().v4(), name: "LANケーブル (5m)", defaultUnitPrice: 1200),
      Product(id: const Uuid().v4(), name: "ウイルス除去作業", defaultUnitPrice: 20000),
      Product(id: const Uuid().v4(), name: "液晶ディスプレイ (24インチ)", defaultUnitPrice: 25000),
      Product(id: const Uuid().v4(), name: "定期保守契約料 (月額)", defaultUnitPrice: 5000),
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
  }

  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
