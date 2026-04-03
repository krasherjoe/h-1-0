import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'full_text_search_service.dart';

/// 高速検索サービス拡張
class AdvancedSearchService {
  static AdvancedSearchService? _instance;
  static AdvancedSearchService get instance => _instance ??= AdvancedSearchService._();
  
  AdvancedSearchService._();
  
  final DatabaseHelper _db = DatabaseHelper();
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  /// インデックス最適化
  Future<void> optimizeIndexes() async {
    final db = await _db.database;
    
    try {
      // 顧客テーブルのインデックス最適化
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_display_name ON customers(display_name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_formal_name ON customers(formal_name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_tel ON customers(tel)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email)');
      
      // 製品テーブルのインデックス最適化
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
      
      // 請求書テーブルのインデックス最適化
      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_document_number ON invoices(document_number)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_subject ON invoices(subject)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_document_type ON invoices(document_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices(created_at)');
      
      // 仕入先テーブルのインデックス最適化
      await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_contact_person ON suppliers(contact_person)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_email ON suppliers(email)');
      
      // 複合インデックス作成
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name_tel ON customers(display_name, tel)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name_category ON products(name, category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_type_date ON invoices(document_type, created_at)');
      
      debugPrint('インデックス最適化完了');
    } catch (e) {
      debugPrint('インデックス最適化エラー: $e');
      rethrow;
    }
  }
  
  /// キャッシュ戦略実装
  Future<List<Map<String, dynamic>>> searchWithCache(
    String query, {
    String? table,
    int? limit,
    int? offset,
  }) async {
    final cacheKey = '${table ?? "all"}_${query}_${limit ?? 50}_${offset ?? 0}';
    
    // キャッシュチェック
    if (_searchCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && 
          DateTime.now().difference(timestamp).inMinutes < 5) {
        debugPrint('キャッシュヒット: $cacheKey');
        return _searchCache[cacheKey]!;
      }
    }
    
    // 検索実行
    List<Map<String, dynamic>> results;
    if (table != null) {
      results = await _searchTable(table, query, limit: limit, offset: offset);
    } else {
      results = await _searchAllTables(query, limit: limit, offset: offset);
    }
    
    // キャッシュ保存
    _searchCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    // キャッシュサイズ制限
    _limitCacheSize();
    
    return results;
  }
  
  /// テーブル単位検索
  Future<List<Map<String, dynamic>>> _searchTable(
    String table,
    String query, {
    int? limit,
    int? offset,
  }) async {
    final db = await _db.database;
    
    String whereClause;
    List<dynamic> whereArgs;
    
    if (table == 'customers') {
      whereClause = '(display_name LIKE ? OR formal_name LIKE ? OR tel LIKE ? OR email LIKE ?)';
      whereArgs = ['%$query%', '%$query%', '%$query%', '%$query%'];
    } else if (table == 'products') {
      whereClause = '(name LIKE ? OR description LIKE ? OR barcode LIKE ? OR category LIKE ?)';
      whereArgs = ['%$query%', '%$query%', '%$query%', '%$query%'];
    } else if (table == 'invoices') {
      whereClause = '(document_number LIKE ? OR subject LIKE ? OR notes LIKE ?)';
      whereArgs = ['%$query%', '%$query%', '%$query%'];
    } else if (table == 'suppliers') {
      whereClause = '(name LIKE ? OR contact_person LIKE ? OR email LIKE ? OR tel LIKE ?)';
      whereArgs = ['%$query%', '%$query%', '%$query%', '%$query%'];
    } else {
      return [];
    }
    
    return await db.query(
      table,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'created_at DESC',
    );
  }
  
  /// 全テーブル検索
  Future<List<Map<String, dynamic>>> _searchAllTables(
    String query, {
    int? limit,
    int? offset,
  }) async {
    final futures = <Future<List<Map<String, dynamic>>>>[
      _searchTable('customers', query, limit: limit != null ? limit ~/ 4 : null, offset: offset),
      _searchTable('products', query, limit: limit != null ? limit ~/ 4 : null, offset: offset),
      _searchTable('invoices', query, limit: limit != null ? limit ~/ 4 : null, offset: offset),
      _searchTable('suppliers', query, limit: limit != null ? limit ~/ 4 : null, offset: offset),
    ];
    
    final results = await Future.wait(futures);
    return results.expand((result) => result).toList();
  }
  
  /// キャッシュサイズ制限
  void _limitCacheSize() {
    if (_searchCache.length > 100) {
      final sortedKeys = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // 古いキャッシュを削除
      for (int i = 0; i < 20; i++) {
        final key = sortedKeys[i].key;
        _searchCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
  }
  
  /// キャッシュをクリア
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
    debugPrint('検索キャッシュをクリアしました');
  }
  
  /// 検索アルゴリズム改善
  Future<List<Map<String, dynamic>>> fuzzySearch(
    String query, {
    String? table,
    double threshold = 0.6,
    int? limit,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    // 基本検索で候補を取得
    final candidates = await searchWithCache(
      query,
      table: table,
      limit: limit != null ? limit * 2 : 100,
    );
    
    // あいまい検索でスコアリング
    for (final candidate in candidates) {
      final score = _calculateFuzzyScore(query, candidate);
      if (score >= threshold) {
        candidate['_fuzzy_score'] = score;
        results.add(candidate);
      }
    }
    
    // スコアでソート
    results.sort((a, b) => (b['_fuzzy_score'] as double).compareTo(a['_fuzzy_score'] as double));
    
    return results.take(limit ?? 50).toList();
  }
  
  /// あいまい検索スコア計算
  double _calculateFuzzyScore(String query, Map<String, dynamic> candidate) {
    double maxScore = 0.0;
    
    // 検索対象フィールド
    final fields = _getSearchableFields(candidate);
    
    for (final field in fields) {
      if (field != null && field.isNotEmpty) {
        final score = _levenshteinDistance(query.toLowerCase(), field.toLowerCase());
        final normalizedScore = 1.0 - (score / field.length);
        maxScore = normalizedScore > maxScore ? normalizedScore : maxScore;
      }
    }
    
    return maxScore;
  }
  
  /// 検索可能なフィールドを取得
  List<String?> _getSearchableFields(Map<String, dynamic> candidate) {
    final fields = <String?>[];
    
    if (candidate.containsKey('display_name')) fields.add(candidate['display_name'] as String?);
    if (candidate.containsKey('formal_name')) fields.add(candidate['formal_name'] as String?);
    if (candidate.containsKey('name')) fields.add(candidate['name'] as String?);
    if (candidate.containsKey('subject')) fields.add(candidate['subject'] as String?);
    if (candidate.containsKey('document_number')) fields.add(candidate['document_number'] as String?);
    if (candidate.containsKey('tel')) fields.add(candidate['tel'] as String?);
    if (candidate.containsKey('email')) fields.add(candidate['email'] as String?);
    if (candidate.containsKey('description')) fields.add(candidate['description'] as String?);
    
    return fields;
  }
  
  /// レーベンシュタイン距離計算
  int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );
    
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,     // 削除
          matrix[i][j - 1] + 1,     // 挿入
          matrix[i - 1][j - 1] + cost, // 置換
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[s1.length][s2.length];
  }
  
  /// 検索統計情報を取得
  Future<Map<String, dynamic>> getSearchStatistics() async {
    final db = await _db.database;
    final stats = <String, dynamic>{};
    
    // 各テーブルのレコード数
    final tables = ['customers', 'products', 'invoices', 'suppliers'];
    
    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        stats['${table}_count'] = result.first['count'];
      } catch (e) {
        stats['${table}_count'] = 0;
      }
    }
    
    // キャッシュ統計
    stats['cache_size'] = _searchCache.length;
    stats['cache_hit_rate'] = _calculateCacheHitRate();
    
    return stats;
  }
  
  /// キャッシュヒット率計算
  double _calculateCacheHitRate() {
    // 実際の実装ではヒット率を追跡する必要がある
    return 0.0; // プレースホルダー
  }
  
  /// 検索パフォーマンス測定
  Future<Map<String, dynamic>> measureSearchPerformance(String query) async {
    final stopwatch = Stopwatch()..start();
    
    // 通常検索
    final normalResults = await searchWithCache(query);
    final normalTime = stopwatch.elapsedMilliseconds;
    
    stopwatch.reset();
    
    // あいまい検索
    final fuzzyResults = await fuzzySearch(query);
    final fuzzyTime = stopwatch.elapsedMilliseconds;
    
    stopwatch.reset();
    
    // FTS検索（利用可能な場合）
    List<Map<String, dynamic>> ftsResults = [];
    int ftsTime = 0;
    try {
      final ftsService = FullTextSearchService.instance;
      final allResults = await ftsService.searchAll(query);
      ftsResults = allResults.values.expand((e) => e).toList();
      ftsTime = stopwatch.elapsedMilliseconds;
    } catch (e) {
      debugPrint('FTS検索エラー: $e');
    }
    
    return {
      'query': query,
      'normal_search': {
        'results_count': normalResults.length,
        'time_ms': normalTime,
      },
      'fuzzy_search': {
        'results_count': fuzzyResults.length,
        'time_ms': fuzzyTime,
      },
      'fts_search': {
        'results_count': ftsResults.length,
        'time_ms': ftsTime,
      },
    };
  }
}

/// 検索結果キャッシュサービス
class SearchCacheService {
  static SearchCacheService? _instance;
  static SearchCacheService get instance => _instance ??= SearchCacheService._();
  
  SearchCacheService._();
  
  final Map<String, Uint8List> _compressedCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final int _maxCacheSize = 50 * 1024 * 1024; // 50MB
  int _currentCacheSize = 0;
  
  /// 圧縮キャッシュに保存
  Future<void> saveToCompressedCache(String key, dynamic data) async {
    try {
      // データをシリアライズ
      final jsonString = _serializeData(data);
      final bytes = Uint8List.fromList(jsonString.codeUnits);
      
      // サイズチェック
      if (_currentCacheSize + bytes.length > _maxCacheSize) {
        await _evictOldCache();
      }
      
      _compressedCache[key] = bytes;
      _cacheTimestamps[key] = DateTime.now();
      _currentCacheSize += bytes.length;
      
      debugPrint('圧縮キャッシュ保存: $key (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('圧縮キャッシュ保存エラー: $e');
    }
  }
  
  /// 圧縮キャッシュから読み込み
  Future<dynamic> loadFromCompressedCache(String key) async {
    try {
      final bytes = _compressedCache[key];
      if (bytes == null) return null;
      
      final jsonString = String.fromCharCodes(bytes);
      return _deserializeData(jsonString);
    } catch (e) {
      debugPrint('圧縮キャッシュ読み込みエラー: $e');
      return null;
    }
  }
  
  /// 古いキャッシュを削除
  Future<void> _evictOldCache() async {
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    int evictedSize = 0;
    for (final entry in sortedEntries) {
      final key = entry.key;
      final bytes = _compressedCache[key];
      
      if (bytes != null) {
        evictedSize += bytes.length;
        _compressedCache.remove(key);
        _cacheTimestamps.remove(key);
      }
      
      if (_currentCacheSize - evictedSize < _maxCacheSize * 0.8) {
        break;
      }
    }
    
    _currentCacheSize -= evictedSize;
    debugPrint('キャッシュ削除: ${evictedSize} bytes');
  }
  
  /// データシリアライズ
  String _serializeData(dynamic data) {
    // 実際の実装ではJSONシリアライズを使用
    return data.toString();
  }
  
  /// データデシリアライズ
  dynamic _deserializeData(String jsonString) {
    // 実際の実装ではJSONデシリアライズを使用
    return jsonString;
  }
  
  /// キャッシュ統計
  Map<String, dynamic> getCacheStatistics() {
    return {
      'cache_size_bytes': _currentCacheSize,
      'cache_count': _compressedCache.length,
      'max_cache_size_bytes': _maxCacheSize,
      'utilization_rate': _currentCacheSize / _maxCacheSize,
    };
  }
  
  /// キャッシュをクリア
  void clearCache() {
    _compressedCache.clear();
    _cacheTimestamps.clear();
    _currentCacheSize = 0;
    debugPrint('圧縮キャッシュをクリアしました');
  }
}
