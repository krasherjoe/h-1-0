import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'database_helper.dart';

/// 電子帳簿保存法対応リポジトリ
class ElectronicLedgerRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// 電子帳簿データを保存
  Future<void> saveElectronicLedger({
    required String documentId,
    required String documentType,
    required Map<String, dynamic> documentData,
    required DateTime createdAt,
    String? businessProfileId,
  }) async {
    final db = await _db.database;
    
    // ドキュメントデータをJSONシリアライズ
    final documentJson = jsonEncode(documentData);
    
    // ハッシュ値を生成（改ざん検出用）
    final documentHash = _generateDocumentHash(documentJson);
    
    // メタデータを生成
    final metadata = {
      'documentId': documentId,
      'documentType': documentType,
      'businessProfileId': businessProfileId,
      'createdAt': createdAt.toIso8601String(),
      'documentHash': documentHash,
      'dataSize': documentJson.length,
      'version': '1.0',
    };

    await db.insert('electronic_ledgers', {
      'id': documentId,
      'document_type': documentType,
      'document_data': documentJson,
      'document_hash': documentHash,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'business_profile_id': businessProfileId,
      'is_active': 1,
    });
  }

  /// 電子帳簿データを更新
  Future<void> updateElectronicLedger({
    required String documentId,
    required Map<String, dynamic> documentData,
    required DateTime updatedAt,
  }) async {
    final db = await _db.database;
    
    // ドキュメントデータをJSONシリアライズ
    final documentJson = jsonEncode(documentData);
    
    // 新しいハッシュ値を生成
    final documentHash = _generateDocumentHash(documentJson);
    
    // 既存レコードを取得
    final existing = await db.query(
      'electronic_ledgers',
      where: 'id = ?',
      whereArgs: [documentId],
    );
    
    if (existing.isEmpty) {
      throw Exception('ドキュメントが見つかりません: $documentId');
    }
    
    final existingRecord = existing.first;
    final metadata = jsonDecode(existingRecord['metadata'] as String);
    
    // メタデータを更新
    metadata['updatedAt'] = updatedAt.toIso8601String();
    metadata['documentHash'] = documentHash;
    metadata['dataSize'] = documentJson.length;
    metadata['version'] = (double.tryParse(metadata['version'].toString()) ?? 1.0) + 0.1;
    
    // 履歴レコードを作成
    await db.insert('electronic_ledger_history', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'ledger_id': documentId,
      'document_data': existingRecord['document_data'],
      'document_hash': existingRecord['document_hash'],
      'metadata': existingRecord['metadata'],
      'created_at': existingRecord['created_at'],
      'updated_at': DateTime.now().toIso8601String(),
    });
    
    // メインレコードを更新
    await db.update(
      'electronic_ledgers',
      {
        'document_data': documentJson,
        'document_hash': documentHash,
        'metadata': jsonEncode(metadata),
        'updated_at': updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// 電子帳簿データを取得
  Future<Map<String, dynamic>?> getElectronicLedger(String documentId) async {
    final db = await _db.database;
    
    final result = await db.query(
      'electronic_ledgers',
      where: 'id = ? AND is_active = 1',
      whereArgs: [documentId],
    );
    
    if (result.isEmpty) return null;
    
    final record = result.first;
    
    // データ整合性チェック（ハッシュ検証）
    final storedHash = record['document_hash'] as String;
    final documentData = record['document_data'] as String;
    final calculatedHash = _generateDocumentHash(documentData);
    
    if (storedHash != calculatedHash) {
      throw Exception('データ改ざんが検出されました: $documentId');
    }
    
    return {
      'id': record['id'],
      'documentType': record['document_type'],
      'documentData': jsonDecode(documentData),
      'metadata': jsonDecode(record['metadata'] as String),
      'createdAt': DateTime.parse(record['created_at'] as String),
      'updatedAt': DateTime.parse(record['updated_at'] as String),
    };
  }

  /// 期間指定で電子帳簿データを検索
  Future<List<Map<String, dynamic>>> searchElectronicLedgers({
    required DateTime startDate,
    required DateTime endDate,
    String? documentType,
    String? businessProfileId,
    int? limit,
    int? offset,
  }) async {
    final db = await _db.database;
    
    final whereConditions = <String>['is_active = 1'];
    final whereArgs = <dynamic>[];
    
    // 期間条件
    whereConditions.add('created_at >= ? AND created_at <= ?');
    whereArgs.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    
    // ドキュメントタイプ条件
    if (documentType != null) {
      whereConditions.add('document_type = ?');
      whereArgs.add(documentType);
    }
    
    // ビジネスプロファイル条件
    if (businessProfileId != null) {
      whereConditions.add('business_profile_id = ?');
      whereArgs.add(businessProfileId);
    }
    
    final orderBy = 'created_at DESC';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';
    
    final result = await db.rawQuery('''
      SELECT * FROM electronic_ledgers 
      WHERE ${whereConditions.join(' AND ')}
      ORDER BY $orderBy
      $limitClause $offsetClause
    ''', whereArgs);
    
    return result.map((record) {
      // データ整合性チェック
      final storedHash = record['document_hash'] as String;
      final documentData = record['document_data'] as String;
      final calculatedHash = _generateDocumentHash(documentData);
      
      if (storedHash != calculatedHash) {
        throw Exception('データ改ざんが検出されました: ${record['id']}');
      }
      
      return {
        'id': record['id'],
        'documentType': record['document_type'],
        'documentData': jsonDecode(documentData),
        'metadata': jsonDecode(record['metadata'] as String),
        'createdAt': DateTime.parse(record['created_at'] as String),
        'updatedAt': DateTime.parse(record['updated_at'] as String),
      };
    }).toList();
  }

  /// 電子帳簿データの履歴を取得
  Future<List<Map<String, dynamic>>> getLedgerHistory(String documentId) async {
    final db = await _db.database;
    
    final result = await db.query(
      'electronic_ledger_history',
      where: 'ledger_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_at DESC',
    );
    
    return result.map((record) {
      return {
        'id': record['id'],
        'ledgerId': record['ledger_id'],
        'documentData': jsonDecode(record['document_data'] as String),
        'metadata': jsonDecode(record['metadata'] as String),
        'createdAt': DateTime.parse(record['created_at'] as String),
        'updatedAt': DateTime.parse(record['updated_at'] as String),
      };
    }).toList();
  }

  /// 電子帳簿データを削除（論理削除）
  Future<void> deleteElectronicLedger(String documentId) async {
    final db = await _db.database;
    
    await db.update(
      'electronic_ledgers',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// データ整合性チェック（全データ）
  Future<List<Map<String, dynamic>>> verifyDataIntegrity() async {
    final db = await _db.database;
    
    final result = await db.query(
      'electronic_ledgers',
      where: 'is_active = 1',
    );
    
    final issues = <Map<String, dynamic>>[];
    
    for (final record in result) {
      final storedHash = record['document_hash'] as String;
      final documentData = record['document_data'] as String;
      final calculatedHash = _generateDocumentHash(documentData);
      
      if (storedHash != calculatedHash) {
        issues.add({
          'documentId': record['id'],
          'documentType': record['document_type'],
          'issue': 'ハッシュ値不一致',
          'storedHash': storedHash,
          'calculatedHash': calculatedHash,
          'createdAt': record['created_at'],
        });
      }
    }
    
    return issues;
  }

  /// データベース統計情報を取得
  Future<Map<String, dynamic>> getDatabaseStatistics() async {
    final db = await _db.database;
    
    // 総ドキュメント数
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM electronic_ledgers WHERE is_active = 1',
    );
    final totalCount = totalResult.first['count'] as int;
    
    // ドキュメントタイプ別統計
    final typeResult = await db.rawQuery('''
      SELECT document_type, COUNT(*) as count 
      FROM electronic_ledgers 
      WHERE is_active = 1 
      GROUP BY document_type
    ''');
    
    // データサイズ統計
    final sizeResult = await db.rawQuery('''
      SELECT SUM(LENGTH(document_data)) as total_size,
             AVG(LENGTH(document_data)) as avg_size
      FROM electronic_ledgers 
      WHERE is_active = 1
    ''');
    
    return {
      'totalDocuments': totalCount,
      'documentsByType': typeResult.map((r) => {
        'type': r['document_type'],
        'count': r['count'],
      }).toList(),
      'totalDataSize': sizeResult.first['total_size'] ?? 0,
      'averageDataSize': sizeResult.first['avg_size'] ?? 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// ドキュメントハッシュ値を生成
  String _generateDocumentHash(String documentData) {
    return sha256.convert(utf8.encode(documentData)).toString();
  }

  /// 古いデータをアーカイブ
  Future<void> archiveOldData({DateTime? beforeDate}) async {
    final db = await _db.database;
    final archiveDate = beforeDate ?? DateTime.now().subtract(const Duration(days: 365 * 7)); // 7年前
    
    // アーカイブ対象データを検索
    final toArchive = await db.query(
      'electronic_ledgers',
      where: 'created_at < ? AND is_active = 1',
      whereArgs: [archiveDate.toIso8601String()],
    );
    
    // アーカイブテーブルに移動
    for (final record in toArchive) {
      await db.insert('electronic_ledger_archive', {
        'id': record['id'],
        'document_type': record['document_type'],
        'document_data': record['document_data'],
        'document_hash': record['document_hash'],
        'metadata': record['metadata'],
        'created_at': record['created_at'],
        'updated_at': record['updated_at'],
        'business_profile_id': record['business_profile_id'],
        'archived_at': DateTime.now().toIso8601String(),
      });
      
      // 元テーブルから削除
      await db.delete(
        'electronic_ledgers',
        where: 'id = ?',
        whereArgs: [record['id']],
      );
    }
  }
}
