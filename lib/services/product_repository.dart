import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'hash_utils.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Product>> getAllProducts({bool includeHidden = false}) async {
    if (kIsWeb) {
      // Webプラットフォームではダミーデータを返す
      return [];
    }
    final db = await _dbHelper.database;
    final String where = includeHidden
        ? ''
        : 'WHERE COALESCE(mh.is_hidden, p.is_hidden, 0) = 0';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
      FROM products p
      LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
      $where
      ORDER BY ${includeHidden ? 'p.id DESC' : 'p.name ASC'}
    ''');

    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> searchProducts(
    String query, {
    bool includeHidden = false,
  }) async {
    if (kIsWeb) {
      return [];
    }
    final db = await _dbHelper.database;
    final args = ['%$query%', '%$query%', '%$query%'];
    final String whereHidden = includeHidden
        ? ''
        : 'AND COALESCE(mh.is_hidden, p.is_hidden, 0) = 0';
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

  Future<void> saveProduct(Product product) async {
    if (kIsWeb) {
      throw UnsupportedError('Web プラットフォームでは商品保存は使用できません');
    }
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 既存の現行レコードを非現行化（履歴化）
      final existing = await txn.query(
        'products',
        where: 'id = ? AND is_current = 1',
        whereArgs: [product.id],
      );

      if (existing.isNotEmpty) {
        // 既存レコードを非現行化
        await txn.update(
          'products',
          {'is_current': 0, 'valid_to': DateTime.now().toIso8601String()},
          where: 'id = ? AND is_current = 1',
          whereArgs: [product.id],
        );
      }

      // 新しいバージョンとして INSERT（HASH チェーン計算）
      final productMap = product.toMap();
      final previousHash = existing.isNotEmpty
          ? existing.first['content_hash']
          : null;

      // HASH 計算
      final contentHash = HashUtils.calculateProductHash(
        id: product.id!,
        name: product.name,
        defaultUnitPrice: product.defaultUnitPrice,
        wholesalePrice: product.wholesalePrice,
        barcode: product.barcode,
        category: product.category,
        categoryId: product.categoryId,
        stockQuantity: product.stockQuantity,
        odooId: product.odooId,
        isLocked: product.isLocked,
        isHidden: product.isHidden,
        validFrom: product.validFrom,
        previousHash: product.previousHash,
      );

      productMap['content_hash'] = contentHash;
      productMap['previous_hash'] = previousHash ?? '';
      productMap['is_current'] = 1;
      final currentVersion =
          (existing.isNotEmpty ? existing.first['version'] : 0) as int? ?? 0;
      productMap['version'] = currentVersion + 1;
      productMap['valid_from'] = DateTime.now().toIso8601String();
      productMap['valid_to'] = null;

      await txn.insert(
        'products',
        productMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    await _logRepo.logAction(
      action: "SAVE_PRODUCT",
      targetType: "PRODUCT",
      targetId: product.id,
      details:
          "商品名：${product.name}, 単価：${product.defaultUnitPrice}, カテゴリ：${product.category ?? '未設定'} (version up)",
    );
  }

  Future<void> deleteProduct(String id) async {
    if (kIsWeb) {
      throw UnsupportedError('Web プラットフォームでは商品削除は使用できません');
    }
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);

    await _logRepo.logAction(
      action: "DELETE_PRODUCT",
      targetType: "PRODUCT",
      targetId: id,
      details: "商品を削除しました",
    );
  }

  /// 電子帳簿保存法対応：非表示フラグのみ設定（実際の削除は行わない）
  Future<void> setHiddenProduct(String id, bool hidden) async {
    if (kIsWeb) {
      throw UnsupportedError('Web プラットフォームでは商品非表示は使用できません');
    }
    final db = await _dbHelper.database;
    // products テーブルの is_hidden フィールドを更新
    await db.update(
      'products',
      {'isHidden': hidden ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _logRepo.logAction(
      action: hidden ? "HIDE_PRODUCT" : "UNHIDE_PRODUCT",
      targetType: "PRODUCT",
      targetId: id,
      details: hidden ? "商品を非表示にしました（電子帳簿保存法対応）" : "商品を再表示しました（電子帳簿保存法対応）",
    );
  }

  Future<void> setHidden(String id, bool hidden) async {
    if (kIsWeb) {
      throw UnsupportedError('Webプラットフォームでは非表示設定は使用できません');
    }
    final db = await _dbHelper.database;
    await db.insert('master_hidden', {
      'master_type': 'product',
      'master_id': id,
      'is_hidden': hidden ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _logRepo.logAction(
      action: hidden ? "HIDE_PRODUCT" : "UNHIDE_PRODUCT",
      targetType: "PRODUCT",
      targetId: id,
      details: hidden ? "商品を非表示にしました" : "商品を再表示しました",
    );
  }

  Future<void> updateStockQuantities(Map<String, int> adjustments) async {
    if (kIsWeb) {
      throw UnsupportedError('Webプラットフォームでは在庫更新は使用できません');
    }
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
