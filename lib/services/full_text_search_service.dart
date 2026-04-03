import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// 全文検索サービス
class FullTextSearchService {
  static FullTextSearchService? _instance;
  static FullTextSearchService get instance => _instance ??= FullTextSearchService._();
  
  FullTextSearchService._();
  
  final DatabaseHelper _db = DatabaseHelper();
  
  /// FTSテーブルを作成
  Future<void> createFtsTables() async {
    final db = await _db.database;
    
    // 顧客FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS customers_fts USING fts5(
        display_name,
        formal_name,
        address,
        tel,
        email,
        department,
        content='customers',
        content_rowid='id'
      )
    ''');
    
    // 製品FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(
        name,
        description,
        barcode,
        category,
        content='products',
        content_rowid='id'
      )
    ''');
    
    // 請求書FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS invoices_fts USING fts5(
        document_number,
        subject,
        notes,
        content='invoices',
        content_rowid='id'
      )
    ''');
    
    // 取引先FTSテーブル（仕入先）
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS suppliers_fts USING fts5(
        name,
        contact_person,
        email,
        tel,
        address,
        notes,
        content='suppliers',
        content_rowid='id'
      )
    ''');
    
    debugPrint('FTS tables created successfully');
  }
  
  /// FTSインデックスを更新
  Future<void> updateFtsIndex() async {
    final db = await _db.database;
    
    try {
      // 顧客データをFTSにインデックス
      await db.execute('''
        INSERT INTO customers_fts(customers_fts)
        SELECT display_name, formal_name, address, tel, email, department
        FROM customers
        WHERE display_name IS NOT NULL OR formal_name IS NOT NULL
      ''');
      
      // 製品データをFTSにインデックス
      await db.execute('''
        INSERT INTO products_fts(products_fts)
        SELECT name, description, barcode, category
        FROM products
        WHERE name IS NOT NULL
      ''');
      
      // 請求書データをFTSにインデックス
      await db.execute('''
        INSERT INTO invoices_fts(invoices_fts)
        SELECT document_number, subject, notes
        FROM invoices
        WHERE document_number IS NOT NULL
      ''');
      
      // 仕入先データをFTSにインデックス
      await db.execute('''
        INSERT INTO suppliers_fts(suppliers_fts)
        SELECT name, contact_person, email, tel, address, notes
        FROM suppliers
        WHERE name IS NOT NULL
      ''');
      
      debugPrint('FTS index updated successfully');
    } catch (e) {
      debugPrint('Error updating FTS index: $e');
      rethrow;
    }
  }
  
  /// 顧客を全文検索
  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final db = await _db.database;
    
    final results = await db.rawQuery('''
      SELECT c.*, customers_fts.rank
      FROM customers c
      JOIN customers_fts ON c.id = customers_fts.rowid
      WHERE customers_fts MATCH ?
      ORDER BY customers_fts.rank DESC
      LIMIT 50
    ''', [query]);
    
    return results;
  }
  
  /// 製品を全文検索
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await _db.database;
    
    final results = await db.rawQuery('''
      SELECT p.*, products_fts.rank
      FROM products p
      JOIN products_fts ON p.id = products_fts.rowid
      WHERE products_fts MATCH ?
      ORDER BY products_fts.rank DESC
      LIMIT 50
    ''', [query]);
    
    return results;
  }
  
  /// 請求書を全文検索
  Future<List<Map<String, dynamic>>> searchInvoices(String query) async {
    final db = await _db.database;
    
    final results = await db.rawQuery('''
      SELECT i.*, invoices_fts.rank
      FROM invoices i
      JOIN invoices_fts ON i.id = invoices_fts.rowid
      WHERE invoices_fts MATCH ?
      ORDER BY invoices_fts.rank DESC
      LIMIT 50
    ''', [query]);
    
    return results;
  }
  
  /// 仕入先を全文検索
  Future<List<Map<String, dynamic>>> searchSuppliers(String query) async {
    final db = await _db.database;
    
    final results = await db.rawQuery('''
      SELECT s.*, suppliers_fts.rank
      FROM suppliers s
      JOIN suppliers_fts ON s.id = suppliers_fts.rowid
      WHERE suppliers_fts MATCH ?
      ORDER BY suppliers_fts.rank DESC
      LIMIT 50
    ''', [query]);
    
    return results;
  }
  
  /// 全データを横断検索
  Future<Map<String, List<Map<String, dynamic>>>> searchAll(String query) async {
    final results = <String, List<Map<String, dynamic>>>{};
    
    try {
      // 並列で各テーブルを検索
      final futures = <Future<List<Map<String, dynamic>>>>[
        searchCustomers(query),
        searchProducts(query),
        searchInvoices(query),
        searchSuppliers(query),
      ];
      
      final searchResults = await Future.wait(futures);
      
      results['customers'] = searchResults[0];
      results['products'] = searchResults[1];
      results['invoices'] = searchResults[2];
      results['suppliers'] = searchResults[3];
      
    } catch (e) {
      debugPrint('Error in searchAll: $e');
    }
    
    return results;
  }
  
  /// 高度な検索（フィルター付き）
  Future<Map<String, List<Map<String, dynamic>>>> advancedSearch({
    required String query,
    List<String>? targetTypes,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    final results = <String, List<Map<String, dynamic>>>{};
    final searchLimit = limit ?? 50;
    
    if (targetTypes == null || targetTypes.contains('customers')) {
      final customers = await _searchCustomersWithFilters(query, filters);
      results['customers'] = customers.take(searchLimit).toList();
    }
    
    if (targetTypes == null || targetTypes.contains('products')) {
      final products = await _searchProductsWithFilters(query, filters);
      results['products'] = products.take(searchLimit).toList();
    }
    
    if (targetTypes == null || targetTypes.contains('invoices')) {
      final invoices = await _searchInvoicesWithFilters(query, filters);
      results['invoices'] = invoices.take(searchLimit).toList();
    }
    
    if (targetTypes == null || targetTypes.contains('suppliers')) {
      final suppliers = await _searchSuppliersWithFilters(query, filters);
      results['suppliers'] = suppliers.take(searchLimit).toList();
    }
    
    return results;
  }
  
  /// 顧客をフィルター付きで検索
  Future<List<Map<String, dynamic>>> _searchCustomersWithFilters(
    String query,
    Map<String, dynamic>? filters,
  ) async {
    final db = await _db.database;
    
    String whereClause = 'customers_fts MATCH ?';
    List<dynamic> whereArgs = [query];
    
    if (filters != null) {
      if (filters['is_locked'] != null) {
        whereClause += ' AND c.is_locked = ?';
        whereArgs.add(filters['is_locked'] ? 1 : 0);
      }
      
      if (filters['is_hidden'] != null) {
        whereClause += ' AND c.is_hidden = ?';
        whereArgs.add(filters['is_hidden'] ? 1 : 0);
      }
    }
    
    final results = await db.rawQuery('''
      SELECT c.*, customers_fts.rank
      FROM customers c
      JOIN customers_fts ON c.id = customers_fts.rowid
      WHERE $whereClause
      ORDER BY customers_fts.rank DESC
      LIMIT 50
    ''', whereArgs);
    
    return results;
  }
  
  /// 製品をフィルター付きで検索
  Future<List<Map<String, dynamic>>> _searchProductsWithFilters(
    String query,
    Map<String, dynamic>? filters,
  ) async {
    final db = await _db.database;
    
    String whereClause = 'products_fts MATCH ?';
    List<dynamic> whereArgs = [query];
    
    if (filters != null) {
      if (filters['category'] != null) {
        whereClause += ' AND p.category = ?';
        whereArgs.add(filters['category']);
      }
      
      if (filters['is_hidden'] != null) {
        whereClause += ' AND p.is_hidden = ?';
        whereArgs.add(filters['is_hidden'] ? 1 : 0);
      }
    }
    
    final results = await db.rawQuery('''
      SELECT p.*, products_fts.rank
      FROM products p
      JOIN products_fts ON p.id = products_fts.rowid
      WHERE $whereClause
      ORDER BY products_fts.rank DESC
      LIMIT 50
    ''', whereArgs);
    
    return results;
  }
  
  /// 請求書をフィルター付きで検索
  Future<List<Map<String, dynamic>>> _searchInvoicesWithFilters(
    String query,
    Map<String, dynamic>? filters,
  ) async {
    final db = await _db.database;
    
    String whereClause = 'invoices_fts MATCH ?';
    List<dynamic> whereArgs = [query];
    
    if (filters != null) {
      if (filters['document_type'] != null) {
        whereClause += ' AND i.document_type = ?';
        whereArgs.add(filters['document_type']);
      }
      
      if (filters['is_draft'] != null) {
        whereClause += ' AND i.is_draft = ?';
        whereArgs.add(filters['is_draft'] ? 1 : 0);
      }
    }
    
    final results = await db.rawQuery('''
      SELECT i.*, invoices_fts.rank
      FROM invoices i
      JOIN invoices_fts ON i.id = invoices_fts.rowid
      WHERE $whereClause
      ORDER BY invoices_fts.rank DESC
      LIMIT 50
    ''', whereArgs);
    
    return results;
  }
  
  /// 仕入先をフィルター付きで検索
  Future<List<Map<String, dynamic>>> _searchSuppliersWithFilters(
    String query,
    Map<String, dynamic>? filters,
  ) async {
    final db = await _db.database;
    
    String whereClause = 'suppliers_fts MATCH ?';
    List<dynamic> whereArgs = [query];
    
    if (filters != null) {
      if (filters['is_hidden'] != null) {
        whereClause += ' AND s.is_hidden = ?';
        whereArgs.add(filters['is_hidden'] ? 1 : 0);
      }
    }
    
    final results = await db.rawQuery('''
      SELECT s.*, suppliers_fts.rank
      FROM suppliers s
      JOIN suppliers_fts ON s.id = suppliers_fts.rowid
      WHERE $whereClause
      ORDER BY suppliers_fts.rank DESC
      LIMIT 50
    ''', whereArgs);
    
    return results;
  }
  
  /// 検索サジェストを取得
  Future<List<String>> getSuggestions(String query) async {
    final db = await _db.database;
    
    if (query.length < 2) return [];
    
    final suggestions = <String>[];
    
    // 顧客名のサジェスト
    final customerResults = await db.query(
      'customers_fts',
      columns: ['display_name'],
      where: 'display_name MATCH ?',
      whereArgs: ['$query*'],
      limit: 5,
    );
    
    for (final result in customerResults) {
      final name = result['display_name'] as String?;
      if (name != null && !suggestions.contains(name)) {
        suggestions.add(name);
      }
    }
    
    // 製品名のサジェスト
    final productResults = await db.query(
      'products_fts',
      columns: ['name'],
      where: 'name MATCH ?',
      whereArgs: ['$query*'],
      limit: 5,
    );
    
    for (final result in productResults) {
      final name = result['name'] as String?;
      if (name != null && !suggestions.contains(name)) {
        suggestions.add(name);
      }
    }
    
    return suggestions.take(10).toList();
  }
  
  /// FTS統計情報を取得
  Future<Map<String, dynamic>> getFtsStatistics() async {
    final db = await _db.database;
    
    final stats = <String, dynamic>{};
    
    // 各FTSテーブルのレコード数
    final tables = ['customers_fts', 'products_fts', 'invoices_fts', 'suppliers_fts'];
    
    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        stats[table] = result.first['count'];
      } catch (e) {
        debugPrint('Error getting stats for $table: $e');
        stats[table] = 0;
      }
    }
    
    return stats;
  }
  
  /// FTSインデックスを再構築
  Future<void> rebuildFtsIndex() async {
    final db = await _db.database;
    
    try {
      // 既存のインデックスを削除
      await db.execute('DELETE FROM customers_fts');
      await db.execute('DELETE FROM products_fts');
      await db.execute('DELETE FROM invoices_fts');
      await db.execute('DELETE FROM suppliers_fts');
      
      // インデックスを再構築
      await updateFtsIndex();
      
      debugPrint('FTS index rebuilt successfully');
    } catch (e) {
      debugPrint('Error rebuilding FTS index: $e');
      rethrow;
    }
  }
  
  /// 日本語検索のための正規化
  String normalizeForJapaneseSearch(String query) {
    // カタカナをひらがなに変換（簡易版）
    String normalized = query;
    
    // カタカナをひらがなに変換
    const katakanaToHiragana = {
      'ア': 'あ', 'イ': 'い', 'ウ': 'う', 'エ': 'え', 'オ': 'お',
      'カ': 'か', 'キ': 'き', 'ク': 'く', 'ケ': 'け', 'コ': 'こ',
      'ガ': 'が', 'ギ': 'ぎ', 'グ': 'ぐ', 'ゲ': 'げ', 'ゴ': 'ご',
      'サ': 'さ', 'シ': 'し', 'ス': 'す', 'セ': 'せ', 'ソ': 'そ',
      'ザ': 'ざ', 'ジ': 'じ', 'ズ': 'ず', 'ゼ': 'ぜ', 'ゾ': 'ぞ',
      'タ': 'た', 'チ': 'ち', 'ツ': 'つ', 'テ': 'て', 'ト': 'と',
      'ダ': 'だ', 'ヂ': 'ぢ', 'ヅ': 'づ', 'デ': 'で', 'ド': 'ど',
      'ナ': 'な', 'ニ': 'に', 'ヌ': 'ぬ', 'ネ': 'ね', 'ノ': 'の',
      'ハ': 'は', 'ヒ': 'ひ', 'フ': 'ふ', 'ヘ': 'へ', 'ホ': 'ほ',
      'バ': 'ば', 'ビ': 'び', 'ブ': 'ぶ', 'ベ': 'べ', 'ボ': 'ぼ',
      'パ': 'ぱ', 'ピ': 'ぴ', 'プ': 'ぷ', 'ペ': 'ぺ', 'ポ': 'ぽ',
      'マ': 'ま', 'ミ': 'み', 'ム': 'む', 'メ': 'め', 'モ': 'も',
      'ヤ': 'や', 'ユ': 'ゆ', 'ヨ': 'よ',
      'ラ': 'ら', 'リ': 'り', 'ル': 'る', 'レ': 'れ', 'ロ': 'ろ',
      'ワ': 'わ', 'ヲ': 'を', 'ン': 'ん',
      'ー': '-',
    };
    
    for (final entry in katakanaToHiragana.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    
    // 全角文字を半角に変換
    normalized = normalized
        .replaceAll('０', '0').replaceAll('１', '1').replaceAll('２', '2')
        .replaceAll('３', '3').replaceAll('４', '4').replaceAll('５', '5')
        .replaceAll('６', '6').replaceAll('７', '7').replaceAll('８', '8')
        .replaceAll('９', '9')
        .replaceAll('（', '(').replaceAll('）', ')')
        .replaceAll('［', '[').replaceAll('］', ']')
        .replaceAll('｛', '{').replaceAll('｝', '}')
        .replaceAll('　', ' ');
    
    return normalized.toLowerCase().trim();
  }
  
  /// 検索クエリを最適化
  String optimizeSearchQuery(String query) {
    String optimized = query.trim();
    
    // 空白で分割してOR検索に変換
    final words = optimized.split(RegExp(r'\s+'));
    if (words.length > 1) {
      optimized = words.map((word) => '"$word"').join(' OR ');
    }
    
    // ワイルドカードを追加
    if (!optimized.contains('*')) {
      optimized = '$optimized*';
    }
    
    return optimized;
  }
}
