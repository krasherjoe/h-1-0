import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';

/// 高速検索サービス（FTS対応）
class FastSearchService {
  static final FastSearchService _instance = FastSearchService._internal();
  factory FastSearchService() => _instance;
  FastSearchService._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // FTSテーブルの初期化
  Future<void> initializeFtsTables() async {
    final db = await _dbHelper.database;
    
    // 商品FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(
        id UNINDEXED,
        name,
        description,
        barcode,
        category,
        tags,
        content='products',
        content_rowid='rowid'
      )
    ''');
    
    // 顧客FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS clients_fts USING fts5(
        id UNINDEXED,
        name,
        kana,
        address,
        phone,
        email,
        notes,
        content='clients',
        content_rowid='rowid'
      )
    ''');
    
    // 仕入先FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS suppliers_fts USING fts5(
        id UNINDEXED,
        name,
        kana,
        address,
        phone,
        email,
        notes,
        content='suppliers',
        content_rowid='rowid'
      )
    ''');
    
    // 見積FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS quotes_fts USING fts5(
        id UNINDEXED,
        quote_no,
        title,
        notes,
        client_name,
        content='quotes',
        content_rowid='rowid'
      )
    ''');
    
    // 受注FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS orders_fts USING fts5(
        id UNINDEXED,
        order_no,
        title,
        notes,
        client_name,
        content='orders',
        content_rowid='rowid'
      )
    ''');
    
    // 売上FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS sales_fts USING fts5(
        id UNINDEXED,
        sales_no,
        title,
        notes,
        client_name,
        content='sales',
        content_rowid='rowid'
      )
    ''');
    
    // 在庫FTSテーブル
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS inventory_fts USING fts5(
        id UNINDEXED,
        product_name,
        warehouse_name,
        notes,
        content='warehouse_stock',
        content_rowid='rowid'
      )
    ''');
  }
  
  // FTSインデックスの再構築
  Future<void> rebuildFtsIndex() async {
    final db = await _dbHelper.database;
    
    try {
      await db.execute('INSERT INTO products_fts(products_fts) VALUES(\'rebuild\')');
      await db.execute('INSERT INTO clients_fts(clients_fts) VALUES(\'rebuild\')');
      await db.execute('INSERT INTO suppliers_fts(suppliers_fts) VALUES(\'rebuild\')');
      await db.execute('INSERT INTO quotes_fts(quotes_fts) VALUES(\'rebuild\')');
      await db.execute('INSERT INTO orders_fts(orders_fts) VALUES(\'rebuild\')');
      await db.execute('INSERT INTO sales_fts(sales_fts) VALUES(\'rebuild\')');
      await db.execute('INSERT INTO inventory_fts(inventory_fts) VALUES(\'rebuild\')');
    } catch (e) {
      print('FTSインデックス再構築エラー: $e');
    }
  }
  
  // 商品高速検索
  Future<List<Map<String, dynamic>>> searchProducts({
    required String query,
    int limit = 50,
    String? category,
    bool onlyActive = true,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT p.*, 
             products_fts.rank,
             snippet(products_fts, 1, '[', ']', '...', 32) as name_snippet,
             snippet(products_fts, 2, '[', ']', '...', 64) as description_snippet
      FROM products_fts
      JOIN products p ON p.id = products_fts.id
      WHERE products_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (category != null) {
      sql += ' AND p.category = ?';
      args.add(category);
    }
    
    if (onlyActive) {
      sql += ' AND p.is_active = 1';
    }
    
    sql += ' ORDER BY products_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 顧客高速検索
  Future<List<Map<String, dynamic>>> searchClients({
    required String query,
    int limit = 50,
    bool onlyActive = true,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT c.*, 
             clients_fts.rank,
             snippet(clients_fts, 1, '[', ']', '...', 32) as name_snippet,
             snippet(clients_fts, 2, '[', ']', '...', 32) as kana_snippet,
             snippet(clients_fts, 3, '[', ']', '...', 64) as address_snippet
      FROM clients_fts
      JOIN clients c ON c.id = clients_fts.id
      WHERE clients_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (onlyActive) {
      sql += ' AND c.is_active = 1';
    }
    
    sql += ' ORDER BY clients_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 仕入先高速検索
  Future<List<Map<String, dynamic>>> searchSuppliers({
    required String query,
    int limit = 50,
    bool onlyActive = true,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT s.*, 
             suppliers_fts.rank,
             snippet(suppliers_fts, 1, '[', ']', '...', 32) as name_snippet,
             snippet(suppliers_fts, 2, '[', ']', '...', 32) as kana_snippet,
             snippet(suppliers_fts, 3, '[', ']', '...', 64) as address_snippet
      FROM suppliers_fts
      JOIN suppliers s ON s.id = suppliers_fts.id
      WHERE suppliers_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (onlyActive) {
      sql += ' AND s.is_active = 1';
    }
    
    sql += ' ORDER BY suppliers_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 見積高速検索
  Future<List<Map<String, dynamic>>> searchQuotes({
    required String query,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? clientId,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT q.*, 
             quotes_fts.rank,
             snippet(quotes_fts, 1, '[', ']', '...', 32) as quote_no_snippet,
             snippet(quotes_fts, 2, '[', ']', '...', 64) as title_snippet,
             snippet(quotes_fts, 3, '[', ']', '...', 128) as notes_snippet
      FROM quotes_fts
      JOIN quotes q ON q.id = quotes_fts.id
      WHERE quotes_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (startDate != null) {
      sql += ' AND q.created_at >= ?';
      args.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      sql += ' AND q.created_at <= ?';
      args.add(endDate.toIso8601String());
    }
    
    if (clientId != null) {
      sql += ' AND q.client_id = ?';
      args.add(clientId);
    }
    
    sql += ' ORDER BY quotes_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 受注高速検索
  Future<List<Map<String, dynamic>>> searchOrders({
    required String query,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? clientId,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT o.*, 
             orders_fts.rank,
             snippet(orders_fts, 1, '[', ']', '...', 32) as order_no_snippet,
             snippet(orders_fts, 2, '[', ']', '...', 64) as title_snippet,
             snippet(orders_fts, 3, '[', ']', '...', 128) as notes_snippet
      FROM orders_fts
      JOIN orders o ON o.id = orders_fts.id
      WHERE orders_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (startDate != null) {
      sql += ' AND o.created_at >= ?';
      args.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      sql += ' AND o.created_at <= ?';
      args.add(endDate.toIso8601String());
    }
    
    if (clientId != null) {
      sql += ' AND o.client_id = ?';
      args.add(clientId);
    }
    
    sql += ' ORDER BY orders_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 売上高速検索
  Future<List<Map<String, dynamic>>> searchSales({
    required String query,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? clientId,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT s.*, 
             sales_fts.rank,
             snippet(sales_fts, 1, '[', ']', '...', 32) as sales_no_snippet,
             snippet(sales_fts, 2, '[', ']', '...', 64) as title_snippet,
             snippet(sales_fts, 3, '[', ']', '...', 128) as notes_snippet
      FROM sales_fts
      JOIN sales s ON s.id = sales_fts.id
      WHERE sales_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (startDate != null) {
      sql += ' AND s.created_at >= ?';
      args.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      sql += ' AND s.created_at <= ?';
      args.add(endDate.toIso8601String());
    }
    
    if (clientId != null) {
      sql += ' AND s.client_id = ?';
      args.add(clientId);
    }
    
    sql += ' ORDER BY sales_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 在庫高速検索
  Future<List<Map<String, dynamic>>> searchInventory({
    required String query,
    int limit = 50,
    String? warehouseId,
    bool onlyPositiveStock = true,
  }) async {
    final db = await _dbHelper.database;
    
    String sql = '''
      SELECT ws.*, p.name as product_name, p.category, w.name as warehouse_name,
             inventory_fts.rank,
             snippet(inventory_fts, 1, '[', ']', '...', 32) as product_name_snippet,
             snippet(inventory_fts, 2, '[', ']', '...', 32) as warehouse_name_snippet
      FROM inventory_fts
      JOIN warehouse_stock ws ON ws.rowid = inventory_fts.rowid
      JOIN products p ON p.id = ws.product_id
      JOIN warehouses w ON w.id = ws.warehouse_id
      WHERE inventory_fts MATCH ?
    ''';
    
    List<dynamic> args = [query];
    
    if (warehouseId != null) {
      sql += ' AND ws.warehouse_id = ?';
      args.add(warehouseId);
    }
    
    if (onlyPositiveStock) {
      sql += ' AND ws.quantity > 0';
    }
    
    sql += ' ORDER BY inventory_fts.rank LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(sql, args);
  }
  
  // 全文検索（複数テーブル横断）
  Future<Map<String, List<Map<String, dynamic>>>> globalSearch({
    required String query,
    int limitPerType = 20,
  }) async {
    final results = <String, List<Map<String, dynamic>>>{};
    
    // 並列検索
    final futures = <Future<List<Map<String, dynamic>>>>[];
    
    futures.add(searchProducts(query: query, limit: limitPerType));
    futures.add(searchClients(query: query, limit: limitPerType));
    futures.add(searchSuppliers(query: query, limit: limitPerType));
    futures.add(searchQuotes(query: query, limit: limitPerType));
    futures.add(searchOrders(query: query, limit: limitPerType));
    futures.add(searchSales(query: query, limit: limitPerType));
    futures.add(searchInventory(query: query, limit: limitPerType));
    
    final searchResults = await Future.wait(futures);
    
    results['products'] = searchResults[0];
    results['clients'] = searchResults[1];
    results['suppliers'] = searchResults[2];
    results['quotes'] = searchResults[3];
    results['orders'] = searchResults[4];
    results['sales'] = searchResults[5];
    results['inventory'] = searchResults[6];
    
    return results;
  }
  
  // オートコンプリート検索
  Future<List<Map<String, dynamic>>> autoComplete({
    required String query,
    required String type, // 'product', 'client', 'supplier'
    int limit = 10,
  }) async {
    final db = await _dbHelper.database;
    
    switch (type.toLowerCase()) {
      case 'product':
        return await db.rawQuery('''
          SELECT p.id, p.name, p.barcode, p.category,
                 products_fts.rank,
                 snippet(products_fts, 1, '[', ']', '...', 32) as name_snippet
          FROM products_fts
          JOIN products p ON p.id = products_fts.id
          WHERE products_fts MATCH ?
          AND p.is_active = 1
          ORDER BY products_fts.rank
          LIMIT ?
        ''', [query, limit]);
        
      case 'client':
        return await db.rawQuery('''
          SELECT c.id, c.name, c.kana, c.phone,
                 clients_fts.rank,
                 snippet(clients_fts, 1, '[', ']', '...', 32) as name_snippet,
                 snippet(clients_fts, 2, '[', ']', '...', 32) as kana_snippet
          FROM clients_fts
          JOIN clients c ON c.id = clients_fts.id
          WHERE clients_fts MATCH ?
          AND c.is_active = 1
          ORDER BY clients_fts.rank
          LIMIT ?
        ''', [query, limit]);
        
      case 'supplier':
        return await db.rawQuery('''
          SELECT s.id, s.name, s.kana, s.phone,
                 suppliers_fts.rank,
                 snippet(suppliers_fts, 1, '[', ']', '...', 32) as name_snippet,
                 snippet(suppliers_fts, 2, '[', ']', '...', 32) as kana_snippet
          FROM suppliers_fts
          JOIN suppliers s ON s.id = suppliers_fts.id
          WHERE suppliers_fts MATCH ?
          AND s.is_active = 1
          ORDER BY suppliers_fts.rank
          LIMIT ?
        ''', [query, limit]);
        
      default:
        return [];
    }
  }
  
  // バーコード検索
  Future<Map<String, dynamic>?> searchByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    
    final results = await db.query(
      'products',
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [barcode],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }
  
  // 類似商品検索
  Future<List<Map<String, dynamic>>> findSimilarProducts({
    required String productId,
    int limit = 10,
  }) async {
    final db = await _dbHelper.database;
    
    // まず商品情報を取得
    final product = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    
    if (product.isEmpty) return [];
    
    final productData = product.first;
    final name = productData['name'] as String;
    final category = productData['category'] as String;
    
    // 名前の一部とカテゴリで類似商品を検索
    final nameParts = name.split(' ').where((part) => part.length > 1).toList();
    
    if (nameParts.isEmpty) return [];
    
    final searchQuery = nameParts.map((part) => '$part*').join(' OR ');
    
    return await db.rawQuery('''
      SELECT p.*, 
             products_fts.rank
      FROM products_fts
      JOIN products p ON p.id = products_fts.id
      WHERE products_fts MATCH ?
      AND p.id != ?
      AND p.is_active = 1
      AND (p.category = ? OR p.category LIKE ?)
      ORDER BY products_fts.rank
      LIMIT ?
    ''', [searchQuery, productId, category, '%$category%', limit]);
  }
  
  // FTS統計情報
  Future<Map<String, dynamic>> getFtsStatistics() async {
    final db = await _dbHelper.database;
    
    final stats = <String, dynamic>{};
    
    // 各テーブルのレコード数
    final tables = ['products', 'clients', 'suppliers', 'quotes', 'orders', 'sales'];
    
    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      stats['${table}_count'] = result.first['count'];
    }
    
    // FTSテーブルのサイズ情報
    final ftsTables = ['products_fts', 'clients_fts', 'suppliers_fts', 'quotes_fts', 'orders_fts', 'sales_fts'];
    
    for (final ftsTable in ftsTables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $ftsTable');
        stats['${ftsTable}_count'] = result.first['count'];
      } catch (e) {
        stats['${ftsTable}_count'] = 0;
      }
    }
    
    return stats;
  }
  
  // FTSテーブルの最適化
  Future<void> optimizeFtsTables() async {
    final db = await _dbHelper.database;
    
    try {
      await db.execute('VACUUM');
      await db.execute('ANALYZE');
      
      // 各FTSテーブルの最適化
      await db.execute('INSERT INTO products_fts(products_fts) VALUES(\'optimize\')');
      await db.execute('INSERT INTO clients_fts(clients_fts) VALUES(\'optimize\')');
      await db.execute('INSERT INTO suppliers_fts(suppliers_fts) VALUES(\'optimize\')');
      await db.execute('INSERT INTO quotes_fts(quotes_fts) VALUES(\'optimize\')');
      await db.execute('INSERT INTO orders_fts(orders_fts) VALUES(\'optimize\')');
      await db.execute('INSERT INTO sales_fts(sales_fts) VALUES(\'optimize\')');
      await db.execute('INSERT INTO inventory_fts(inventory_fts) VALUES(\'optimize\')');
    } catch (e) {
      print('FTSテーブル最適化エラー: $e');
    }
  }
  
  // 検索クエリのサジェスト
  Future<List<String>> suggestQueries({
    required String partialQuery,
    required String type,
    int limit = 10,
  }) async {
    final db = await _dbHelper.database;
    
    switch (type.toLowerCase()) {
      case 'product':
        final results = await db.rawQuery('''
          SELECT DISTINCT name
          FROM products_fts
          WHERE name MATCH ?
          ORDER BY rank
          LIMIT ?
        ''', ['$partialQuery*', limit]);
        
        return results.map((r) => r['name'] as String).toList();
        
      case 'client':
        final results = await db.rawQuery('''
          SELECT DISTINCT name, kana
          FROM clients_fts
          WHERE name MATCH ? OR kana MATCH ?
          ORDER BY rank
          LIMIT ?
        ''', ['$partialQuery*', '$partialQuery*', limit]);
        
        final suggestions = <String>[];
        for (final r in results) {
          suggestions.add(r['name'] as String);
          if (r['kana'] != null && (r['kana'] as String).isNotEmpty) {
            suggestions.add(r['kana'] as String);
          }
        }
        return suggestions;
        
      default:
        return [];
    }
  }
}
