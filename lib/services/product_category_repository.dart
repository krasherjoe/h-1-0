import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product_category_model.dart';
import 'database_helper.dart';

class ProductCategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<ProductCategory>> getAllCategories({bool includeInactive = false}) async {
    final db = await _dbHelper.database;
    final where = includeInactive ? '' : 'WHERE is_active = 1';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM product_categories
      $where
      ORDER BY name ASC
    ''');

    return List.generate(maps.length, (i) => ProductCategory.fromMap(maps[i]));
  }

  Future<ProductCategory?> getCategoryById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'product_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ProductCategory.fromMap(maps.first);
  }

  Future<ProductCategory?> getCategoryByName(String name) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'product_categories',
      where: 'name = ? AND is_active = 1',
      whereArgs: [name],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ProductCategory.fromMap(maps.first);
  }

  Future<void> saveCategory(ProductCategory category) async {
    final db = await _dbHelper.database;
    await db.insert(
      'product_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    // 論理削除（is_active = 0）
    await db.update(
      'product_categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreCategory(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'product_categories',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// カテゴリー名から ID を取得（なければ作成）
  Future<String> getOrCreateCategoryId(String categoryName) async {
    if (categoryName.isEmpty) {
      return ''; // 空の場合は空文字列を返す
    }

    final existing = await getCategoryByName(categoryName);
    if (existing != null) {
      return existing.id;
    }

    // 新規作成
    final newCategory = ProductCategory(
      id: const Uuid().v4(),
      name: categoryName,
    );
    await saveCategory(newCategory);
    return newCategory.id;
  }
}
