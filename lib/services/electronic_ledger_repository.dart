import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'hash_utils.dart';

/// 電子帳簿保存法対応リポジトリ（追記-only: UPDATE禁止）
class ElectronicLedgerRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final Random _random = Random.secure();

  static const String _lastLedgerTimestampKey = 'last_ledger_timestamp';

  /// バージョン管理用の一意な行IDを生成
  String _generateRowId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(999999).toString().padLeft(6, '0');
    return 'EL-$now-$rand';
  }

  /// 次のグローバルシーケンス番号を取得（連続性確保）
  Future<int> _getNextSequenceNumber() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT MAX(sequence_number) as max_seq FROM electronic_ledgers',
    );
    final maxSeq = result.first['max_seq'] as int?;
    return (maxSeq ?? 0) + 1;
  }

  /// タイムスタンプ逆行を検出（端末時計改ざんの疑い）
  Future<bool> _detectTimestampTampering(DateTime currentTime) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTimestamp = prefs.getInt(_lastLedgerTimestampKey);
    if (lastTimestamp != null) {
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      if (currentTime.isBefore(lastTime)) {
        return true;
      }
    }
    await prefs.setInt(
      _lastLedgerTimestampKey,
      currentTime.millisecondsSinceEpoch,
    );
    return false;
  }

  /// 電子帳簿データを保存（新規: 追記INSERTのみ）
  Future<void> saveElectronicLedger({
    required String documentId,
    required String documentType,
    required Map<String, dynamic> documentData,
    required DateTime createdAt,
    String? businessProfileId,
  }) async {
    final db = await _db.database;
    final rowId = _generateRowId();
    final now = DateTime.now();

    // タイムスタンプ逆行検出
    if (await _detectTimestampTampering(now)) {
      throw Exception(
        'タイムスタンプ逆行が検出されました。端末の時計設定を確認してください。',
      );
    }

    final sequenceNumber = await _getNextSequenceNumber();

    final documentJson = jsonEncode(documentData);
    final documentHash = _generateDocumentHash(documentJson, null);

    final metadata = {
      'documentType': documentType,
      'businessProfileId': businessProfileId,
      'createdAt': createdAt.toIso8601String(),
      'documentHash': documentHash,
      'dataSize': documentJson.length,
      'version': 1,
      'previousHash': null,
      'sequenceNumber': sequenceNumber,
    };

    await db.insert('electronic_ledgers', {
      'id': rowId,
      'document_id': documentId,
      'document_type': documentType,
      'document_data': documentJson,
      'document_hash': documentHash,
      'previous_hash': null,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'business_profile_id': businessProfileId,
      'is_active': 1,
      'is_current': 1,
      'version': 1,
      'valid_from': createdAt.toIso8601String(),
      'valid_to': null,
      'sequence_number': sequenceNumber,
    });
  }

  /// 電子帳簿データを更新（追記INSERTのみ: document_dataはUPDATE禁止）
  Future<void> updateElectronicLedger({
    required String documentId,
    required Map<String, dynamic> documentData,
    required DateTime updatedAt,
  }) async {
    final db = await _db.database;

    // 現在のカレントレコードを取得
    final current = await db.query(
      'electronic_ledgers',
      where: 'document_id = ? AND is_current = 1 AND is_active = 1',
      whereArgs: [documentId],
    );

    if (current.isEmpty) {
      throw Exception('ドキュメントが見つかりません: $documentId');
    }

    final currentRecord = current.first;
    final currentRowId = currentRecord['id'] as String;
    final currentHash = currentRecord['document_hash'] as String;
    final currentVersion = (currentRecord['version'] as int?) ?? 1;
    final currentMetadata =
        jsonDecode(currentRecord['metadata'] as String) as Map<String, dynamic>;

    final documentJson = jsonEncode(documentData);
    final documentHash = _generateDocumentHash(documentJson, currentHash);

    // 履歴テーブルに旧データを退避（冗長バックアップ）
    await db.insert('electronic_ledger_history', {
      'id': _generateRowId(),
      'ledger_id': currentRowId,
      'document_data': currentRecord['document_data'],
      'document_hash': currentHash,
      'metadata': currentRecord['metadata'],
      'created_at': currentRecord['created_at'],
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 旧レコードを非カレント化（メタデータのみUPDATE: document_dataは不変）
    final now = DateTime.now().toIso8601String();
    await db.update(
      'electronic_ledgers',
      {
        'is_current': 0,
        'valid_to': now,
      },
      where: 'id = ?',
      whereArgs: [currentRowId],
    );

    // 新バージョンをINSERT（電帳法: 追記のみ）
    final newVersion = currentVersion + 1;
    final newSequenceNumber = await _getNextSequenceNumber();
    final newMetadata = {
      'documentType': currentMetadata['documentType'],
      'businessProfileId': currentMetadata['businessProfileId'],
      'createdAt': currentMetadata['createdAt'],
      'updatedAt': updatedAt.toIso8601String(),
      'documentHash': documentHash,
      'dataSize': documentJson.length,
      'version': newVersion,
      'previousHash': currentHash,
      'sequenceNumber': newSequenceNumber,
    };

    await db.insert('electronic_ledgers', {
      'id': _generateRowId(),
      'document_id': documentId,
      'document_type': currentRecord['document_type'],
      'document_data': documentJson,
      'document_hash': documentHash,
      'previous_hash': currentHash,
      'metadata': jsonEncode(newMetadata),
      'created_at': currentRecord['created_at'],
      'updated_at': now,
      'business_profile_id': currentRecord['business_profile_id'],
      'is_active': 1,
      'is_current': 1,
      'version': newVersion,
      'valid_from': now,
      'valid_to': null,
      'sequence_number': newSequenceNumber,
    });
  }

  /// 電子帳簿データを取得（最新カレントバージョン）
  Future<Map<String, dynamic>?> getElectronicLedger(String documentId) async {
    final db = await _db.database;

    final result = await db.query(
      'electronic_ledgers',
      where: 'document_id = ? AND is_active = 1 AND is_current = 1',
      whereArgs: [documentId],
    );

    if (result.isEmpty) return null;

    final record = result.first;

    // データ整合性チェック（ハッシュ + previous_hash チェーン）
    final storedHash = record['document_hash'] as String;
    final documentData = record['document_data'] as String;
    final previousHash = record['previous_hash'] as String?;
    final calculatedHash = _generateDocumentHash(documentData, previousHash);

    if (storedHash != calculatedHash) {
      throw Exception('データ改ざんが検出されました: $documentId');
    }

    return {
      'id': record['id'],
      'documentId': record['document_id'],
      'documentType': record['document_type'],
      'documentData': jsonDecode(documentData),
      'metadata': jsonDecode(record['metadata'] as String),
      'createdAt': DateTime.parse(record['created_at'] as String),
      'updatedAt': DateTime.parse(record['updated_at'] as String),
      'version': record['version'],
      'previousHash': previousHash,
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
      // データ整合性チェック（previous_hash含め）
      final storedHash = record['document_hash'] as String;
      final documentData = record['document_data'] as String;
      final previousHash = record['previous_hash'] as String?;
      final calculatedHash = _generateDocumentHash(documentData, previousHash);

      if (storedHash != calculatedHash) {
        throw Exception('データ改ざんが検出されました: ${record['id']}');
      }

      return {
        'id': record['id'],
        'documentId': record['document_id'],
        'documentType': record['document_type'],
        'documentData': jsonDecode(documentData),
        'metadata': jsonDecode(record['metadata'] as String),
        'createdAt': DateTime.parse(record['created_at'] as String),
        'updatedAt': DateTime.parse(record['updated_at'] as String),
        'version': record['version'],
        'isCurrent': record['is_current'] == 1,
      };
    }).toList();
  }

  /// 電子帳簿データの履歴を取得（メインテーブルの過去バージョン）
  Future<List<Map<String, dynamic>>> getLedgerHistory(String documentId) async {
    final db = await _db.database;

    // メインテーブルから document_id に紐づく全バージョンを取得（カレントを除く）
    final mainResult = await db.query(
      'electronic_ledgers',
      where: 'document_id = ? AND is_current = 0',
      whereArgs: [documentId],
      orderBy: 'version DESC',
    );

    // 冗長履歴テーブルからも取得
    final historyResult = await db.query(
      'electronic_ledger_history',
      where: 'ledger_id IN (SELECT id FROM electronic_ledgers WHERE document_id = ?)',
      whereArgs: [documentId],
      orderBy: 'created_at DESC',
    );

    final mainHistory = mainResult.map((record) {
      return {
        'id': record['id'],
        'documentId': record['document_id'],
        'documentData': jsonDecode(record['document_data'] as String),
        'documentHash': record['document_hash'],
        'previousHash': record['previous_hash'],
        'metadata': jsonDecode(record['metadata'] as String),
        'version': record['version'],
        'createdAt': DateTime.parse(record['created_at'] as String),
        'updatedAt': DateTime.parse(record['updated_at'] as String),
        'source': 'main_table',
      };
    }).toList();

    final backupHistory = historyResult.map((record) {
      return {
        'id': record['id'],
        'ledgerId': record['ledger_id'],
        'documentData': jsonDecode(record['document_data'] as String),
        'documentHash': record['document_hash'],
        'metadata': jsonDecode(record['metadata'] as String),
        'createdAt': DateTime.parse(record['created_at'] as String),
        'updatedAt': DateTime.parse(record['updated_at'] as String),
        'source': 'history_backup',
      };
    }).toList();

    return [...mainHistory, ...backupHistory];
  }

  /// 電子帳簿データを削除（論理削除: 全バージョン対象）
  Future<void> deleteElectronicLedger(String documentId) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'electronic_ledgers',
      {
        'is_active': 0,
        'is_current': 0,
        'updated_at': now,
      },
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  /// データ整合性チェック（全データ: ハッシュ + チェーン検証）
  Future<List<Map<String, dynamic>>> verifyDataIntegrity() async {
    final db = await _db.database;

    final result = await db.query(
      'electronic_ledgers',
      where: 'is_active = 1',
      orderBy: 'document_id, version ASC',
    );

    final issues = <Map<String, dynamic>>[];
    final Map<String, Map<String, dynamic>> previousVersions = {};

    for (final record in result) {
      final rowId = record['id'] as String;
      final documentId = record['document_id'] as String? ?? rowId;
      final storedHash = record['document_hash'] as String;
      final documentData = record['document_data'] as String;
      final previousHash = record['previous_hash'] as String?;
      final version = (record['version'] as int?) ?? 1;

      // 1. 単体ハッシュ整合性
      final calculatedHash = _generateDocumentHash(documentData, previousHash);
      if (storedHash != calculatedHash) {
        issues.add({
          'rowId': rowId,
          'documentId': documentId,
          'documentType': record['document_type'],
          'issue': 'ハッシュ値不一致',
          'storedHash': storedHash,
          'calculatedHash': calculatedHash,
          'version': version,
          'createdAt': record['created_at'],
        });
        continue;
      }

      // 2. チェーン連結整合性
      if (previousHash != null && previousHash.isNotEmpty) {
        final prevRecord = previousVersions[documentId];
        if (prevRecord != null) {
          final prevHash = prevRecord['document_hash'] as String?;
          final chainValid = HashUtils.verifyPreviousHashLinkage(
            currentHash: storedHash,
            previousHash: previousHash,
            previousContentHash: prevHash,
          );
          if (!chainValid) {
            issues.add({
              'rowId': rowId,
              'documentId': documentId,
              'documentType': record['document_type'],
              'issue': 'ハッシュチェーン不整合',
              'previousHash': previousHash,
              'expectedPreviousHash': prevHash,
              'version': version,
              'createdAt': record['created_at'],
            });
          }
        }
      }

      // 3. シーケンス番号連続性チェック
      final sequenceNumber = record['sequence_number'] as int?;
      if (sequenceNumber != null && previousVersions.containsKey(documentId)) {
        final prevRecord = previousVersions[documentId];
        final prevSeq = prevRecord?['sequence_number'] as int?;
        if (prevSeq != null && sequenceNumber <= prevSeq) {
          issues.add({
            'rowId': rowId,
            'documentId': documentId,
            'documentType': record['document_type'],
            'issue': 'シーケンス番号逆行',
            'sequenceNumber': sequenceNumber,
            'expectedMinSequence': prevSeq + 1,
            'version': version,
            'createdAt': record['created_at'],
          });
        }
      }

      previousVersions[documentId] = record;
    }

    // 4. グローバルシーケンス番号ギャップ検出
    final globalSequences = result
        .where((r) => r['sequence_number'] != null)
        .map((r) => r['sequence_number'] as int)
        .toList();
    if (globalSequences.isNotEmpty) {
      globalSequences.sort();
      for (int i = 1; i < globalSequences.length; i++) {
        if (globalSequences[i] - globalSequences[i - 1] > 1) {
          issues.add({
            'rowId': 'GLOBAL',
            'documentId': 'GLOBAL',
            'documentType': 'ALL',
            'issue': 'シーケンス番号ギャップ',
            'missingSequences':
                List.generate(globalSequences[i] - globalSequences[i - 1] - 1,
                    (idx) => globalSequences[i - 1] + 1 + idx),
            'version': 0,
            'createdAt': null,
          });
        }
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

  /// ドキュメントハッシュ値を生成（previous_hashを含めてチェーン化）
  String _generateDocumentHash(String documentData, String? previousHash) {
    final input = [
      documentData,
      previousHash ?? '',
    ].join('|');
    return sha256.convert(utf8.encode(input)).toString();
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
      
      // 電帳法対応: DELETEは禁止（7年間保存義務）
      // 元テーブルからは削除せず、is_current=0にしてアーカイブ済みフラグを立てる
      await db.update(
        'electronic_ledgers',
        {
          'is_current': 0,
          'valid_to': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [record['id']],
      );
    }
  }
}
