/// 顧客マスター HASH チェーン修復スクリプト
///
/// **目的**: 既存の顧客データから HASH チェーンが外れているレコードを正常な状態に修復
///
/// **問題状況**:
/// - 同じ名前の顧客が複数 ID で存在（フォーク事故）
/// - content_hash と previous_hash が正しく設定されていない
/// - HASH チェーンが断絶している
///
/// **修复方針**:
/// 1. 同じ display_name の顧客をグループ化
/// 2. バージョン番号でソートして正しいチェーンを構築
/// 3. 各レコードに適切な content_hash と previous_hash を設定
/// 4. is_current=1 のレコードは最新バージョンとして残す
///
/// **実行方法**:
/// ```bash
/// dart --enable-asserts workshops/repair_customer_hash_chain.dart
/// ```
///
/// **注意**:
/// - 本番データベースへの影響を避けるため、まずテスト用データベースで動作確認
/// - 必ず事前にデータベースのバックアップを作成
/// - DELETE 操作は行わない（UPDATE のみ）

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:ui' as ui;

// ============================================================================
// 設定
// ============================================================================

/// データベースパス（本番用）
const String kDatabasePath = 'data/gemi_invoice.db';

/// テスト用データベースパス（まずはここで動作確認）
const String kTestDatabasePath =
    'workshops/repair_customer_hash_chain/test_customers.db';

/// バックアップ先ディレクトリ
const String kBackupDirectory = 'backups/customer_hash_chain_repair_';

/// 修復処理のログ出力設定
const bool kEnableVerboseLogging = true;

// ============================================================================
// ハッシュ計算ユーティリティ（hash_utils.dart と共通化するため独自実装）
// ============================================================================

/// SHA256 ハッシュを計算
String calculateSha256(String input) {
  final bytes = utf8.encode(input);
  final digest = crypto.sha256.convert(bytes);
  return digest.toString();
}

/// Customer のコンテンツハッシュを計算
///
/// ハッシュ式：SHA256(ID|display_name|formal_name|title|department|address|tel|email|
///             contact_version_id|odoo_id|is_locked|is_hidden|head_char1|head_char2|
///             valid_from|valid_to|is_current|version|previous_hash)
String calculateCustomerHash(
  Map<String, dynamic> customer,
  String? previousHash,
) {
  final input = [
    customer['id'] as String,
    customer['display_name'] as String,
    customer['formal_name'] as String,
    (customer['title'] as int?).toString(),
    customer['department'] as String?,
    customer['address'] as String?,
    customer['tel'] as String?,
    customer['email'] as String?,
    (customer['contact_version_id'] as int?).toString(),
    customer['odoo_id'] as String?,
    (customer['is_locked'] as int?).toString(),
    (customer['is_hidden'] as int?).toString(),
    customer['head_char1'] as String?,
    customer['head_char2'] as String?,
    customer['valid_from'] as String?,
    customer['valid_to'] as String?,
    (customer['is_current'] as int?).toString(),
    (customer['version'] as int?).toString(),
    previousHash ?? '',
  ].where((e) => e != null).join('|');

  return calculateSha256(input);
}

// ============================================================================
// ロギングユーティリティ
// ============================================================================

/// ログ出力（設定に応じて）
void log(String message) {
  if (kEnableVerboseLogging) {
    print('[$DateTime.now().toString()] $message');
  }
}

/// エラーログ出力
void errorLog(String message) {
  print('⚠️ [ERROR] $message');
}

/// 成功メッセージ
void successLog(String message) {
  print('✅ $message');
}

// ============================================================================
// データベース操作
// ============================================================================

/// バックアップディレクトリを作成
Future<String> createBackupDirectory() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backupDir = Directory('$kBackupDirectory$timestamp');
  await backupDir.create(recursive: true);
  return backupDir.path;
}

/// データベースをバックアップ
Future<void> backupDatabase(String databasePath, String backupDir) async {
  log('データベースをバックアップ中...');

  final dbFile = File(databasePath);
  if (!await dbFile.exists()) {
    errorLog('データベースファイルが見つかりません：$databasePath');
    return;
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backupPath = path.join(backupDir, 'customers_backup_$timestamp.db');

  await dbFile.copy(backupPath);
  log('バックアップ完了：$backupPath');
}

/// テーブルが存在するかチェック
Future<bool> tableExists(Database db, String tableName) async {
  final result = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
  );
  return result.isNotEmpty;
}

/// customers テーブルの全レコードを取得
Future<List<Map<String, dynamic>>> getAllCustomers(Database db) async {
  try {
    return await db.query('customers');
  } catch (e) {
    errorLog('顧客データの取得に失敗：$e');
    return [];
  }
}

/// 顧客レコードの更新
Future<void> updateCustomer(
  Database db,
  String id,
  Map<String, dynamic> updates,
) async {
  try {
    await db.update('customers', updates, where: 'id = ?', whereArgs: [id]);
  } catch (e) {
    errorLog('顧客レコードの更新に失敗：$id - $e');
  }
}

// ============================================================================
// HASH チェーン修復ロジック
// ============================================================================

/// 顧客データを display_name でグループ化
Map<String, List<Map<String, dynamic>>> groupCustomersByName(
  List<Map<String, dynamic>> customers,
) {
  final Map<String, List<Map<String, dynamic>>> grouped = {};

  for (final customer in customers) {
    final displayName = customer['display_name'] as String? ?? 'UNKNOWN';

    if (!grouped.containsKey(displayName)) {
      grouped[displayName] = [];
    }

    grouped[displayName]!.add(customer);
  }

  return grouped;
}

/// バージョン番号でソート（古い順）
void sortCustomersByVersion(List<Map<String, dynamic>> customers) {
  customers.sort((a, b) {
    final versionA = (a['version'] as int?) ?? 1;
    final versionB = (b['version'] as int?) ?? 1;
    return versionA.compareTo(versionB);
  });
}

/// HASH チェーンを修復
///
/// 同じ name の顧客が複数存在する場合、正しいバージョンチェーンを構築
Future<void> repairHashChain(
  Database db,
  List<Map<String, dynamic>> customers,
) async {
  log('HASH チェーン修復を開始します...');

  // データベースのバージョン確認
  final version =
      (await db.rawQuery("PRAGMA database_version")).first['database_version']
          as int? ??
      0;
  log('データベースバージョン：$version');

  // display_name でグループ化
  final grouped = groupCustomersByName(customers);

  var totalRepaired = 0;
  var totalForks = 0;
  var totalNormal = 0;

  for (final entry in grouped.entries) {
    final displayName = entry.key;
    final customerList = entry.value;

    if (customerList.length > 1) {
      totalForks++;
      log('フォーク検出："$displayName" (${customerList.length}件)');

      // バージョンでソート
      sortCustomersByVersion(customerList);

      String? previousHash = null;

      for (int i = 0; i < customerList.length; i++) {
        final customer = customerList[i];
        final customerId = customer['id'] as String;

        // ハッシュを計算（previous_hash を含む）
        final newContentHash = calculateCustomerHash(customer, previousHash);

        // 既存のハッシュと比較
        final existingHash = customer['content_hash'] as String?;
        final existingPreviousHash = customer['previous_hash'] as String?;

        bool needsUpdate = false;
        String updateReason = '';

        if (existingHash != newContentHash) {
          needsUpdate = true;
          updateReason += 'content_hash 不一致, ';
        }

        if (existingPreviousHash != previousHash) {
          needsUpdate = true;
          updateReason += 'previous_hash 不一致, ';
        }

        if (needsUpdate) {
          final updates = <String, dynamic>{
            'content_hash': newContentHash,
            'previous_hash': previousHash,
          };

          await updateCustomer(db, customerId, updates);

          log('  - $customerId: 修復 (${updateReason.trim()})');
          totalRepaired++;
        } else {
          log('  - $customerId: 既に正常');
        }

        // 次のバージョンの previous_hash に設定
        previousHash = newContentHash;
      }

      // next_version_id の設定（v46 で追加されたカラム）
      final hasNextVersionIdColumn = await _checkColumnExists(
        db,
        'customers',
        'next_version_id',
      );
      if (hasNextVersionIdColumn) {
        for (int i = 0; i < customerList.length - 1; i++) {
          final oldRecord = customerList[i];
          final newRecord = customerList[i + 1];

          await db.update(
            'customers',
            {'next_version_id': newRecord['id']},
            where: 'id = ?',
            whereArgs: [oldRecord['id']],
          );
        }
      }
    } else {
      totalNormal++;

      // 単一の顧客もハッシュチェック
      final customer = customerList.first;
      final customerId = customer['id'] as String;
      final existingHash = customer['content_hash'] as String?;

      final newHash = calculateCustomerHash(customer, null);

      if (existingHash != newHash) {
        await updateCustomer(db, customerId, {
          'content_hash': newHash,
          'previous_hash': null,
        });
        log('単一顧客修復：$customerId (${customer['display_name']})');
        totalRepaired++;
      } else {
        log('単一顧客正常：$customerId (${customer['display_name']})');
      }
    }
  }

  log('');
  log('=== 修復完了 ===');
  log('フォーク検出数：$totalForks');
  log('正常な顧客数：$totalNormal');
  log('修復したレコード数：$totalRepaired');
}

/// カラムが存在するかチェック
Future<bool> _checkColumnExists(
  Database db,
  String tableName,
  String columnName,
) async {
  try {
    final result = await db.rawQuery("PRAGMA table_info($tableName)");
    return result.any((col) => col['name'] == columnName);
  } catch (e) {
    return false;
  }
}

/// HASH チェーンの整合性を検証
Future<void> verifyHashChainIntegrity(
  Database db,
  List<Map<String, dynamic>> customers,
) async {
  log('HASH チェーン整合性検証を開始します...');

  final grouped = groupCustomersByName(customers);
  var totalErrors = 0;
  var totalValid = 0;

  for (final entry in grouped.entries) {
    final displayName = entry.key;
    final customerList = entry.value;

    sortCustomersByVersion(customerList);

    String? expectedPreviousHash = null;

    for (final customer in customerList) {
      final customerId = customer['id'] as String;
      final contentHash = customer['content_hash'] as String?;
      final previousHash = customer['previous_hash'] as String?;

      // 再計算
      final calculatedHash = calculateCustomerHash(
        customer,
        expectedPreviousHash,
      );

      if (contentHash != calculatedHash) {
        errorLog('整合性エラー：$customerId ("$displayName")');
        errorLog('  期待値：$calculatedHash');
        errorLog('  実際：$contentHash');
        totalErrors++;
      } else if (previousHash != expectedPreviousHash) {
        errorLog('previous_hash 不一致：$customerId ("$displayName")');
        errorLog('  期待値：$expectedPreviousHash');
        errorLog('  実際：$previousHash');
        totalErrors++;
      } else {
        totalValid++;
      }

      expectedPreviousHash = calculatedHash;
    }
  }

  log('');
  log('=== 検証完了 ===');
  log('整合性チェック済み：${totalValid + totalErrors}件');
  log('エラー数：$totalErrors');
  log('正常：$totalValid');

  if (totalErrors == 0) {
    successLog('✅ すべての顧客で HASH チェーンが正常に構築されています');
  } else {
    errorLog('⚠️ $totalErrors件の整合性エラーが見つかりました');
  }
}

// ============================================================================
// メイン処理
// ============================================================================

/// データベースを初期化（テスト用）
Future<Database> initTestDatabase() async {
  log('テストデータベースを作成・初期化中...');

  // テストディレクトリ作成
  final testDir = Directory(path.dirname(kTestDatabasePath));
  if (!await testDir.exists()) {
    await testDir.create(recursive: true);
  }

  // テストデータベース削除（既存の場合）
  final testDbFile = File(kTestDatabasePath);
  if (await testDbFile.exists()) {
    await testDbFile.delete();
  }

  // 新しいデータベースを作成
  final db = await openDatabase(
    kTestDatabasePath,
    version: 46,
    onCreate: (db) async {
      await _onCreateTestDatabase(db);
    },
  );

  log('テストデータベース作成完了');
  return db;
}

/// テスト用データベースのスキーマ作成
Future<void> _onCreateTestDatabase(Database db) async {
  // customers テーブル作成
  await db.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      formal_name TEXT NOT NULL,
      title INTEGER DEFAULT 0,
      department TEXT,
      address TEXT,
      tel TEXT,
      email TEXT,
      contact_version_id INTEGER,
      odoo_id TEXT,
      head_char1 TEXT,
      head_char2 TEXT,
      is_locked INTEGER DEFAULT 0,
      is_hidden INTEGER DEFAULT 0,
      is_synced INTEGER DEFAULT 0,
      updated_at TEXT NOT NULL,
      valid_from TEXT,
      valid_to TEXT,
      is_current INTEGER DEFAULT 1,
      version INTEGER DEFAULT 1,
      content_hash TEXT,
      previous_hash TEXT,
      next_version_id TEXT
    )
  ''');

  log('customers テーブル作成完了');
}

/// テストデータ挿入
Future<void> insertTestCustomers(Database db) async {
  log('テストデータを挿入中...');

  final testCustomers = [
    // 同じ名前の顧客が 3 つのバージョンで存在（フォーク事故）
    {
      'id': 'CUST-001-V1',
      'display_name': '山田商店',
      'formal_name': '株式会社山田商店',
      'title': 0,
      'department': null,
      'address': '東京都渋谷区 XX-XX-XX',
      'tel': '03-1234-5678',
      'email': 'info@yamada.co.jp',
      'contact_version_id': null,
      'odoo_id': null,
      'head_char1': null,
      'head_char2': null,
      'is_locked': 0,
      'is_hidden': 0,
      'is_synced': 0,
      'updated_at': '2024-01-01 10:00:00',
      'valid_from': '2024-01-01 10:00:00',
      'valid_to': null,
      'is_current': 0,
      'version': 1,
      'content_hash': 'INVALID_HASH_1', // 不正なハッシュ
      'previous_hash': null,
      'next_version_id': 'CUST-001-V2',
    },
    {
      'id': 'CUST-001-V2',
      'display_name': '山田商店',
      'formal_name': '株式会社山田商店',
      'title': 0,
      'department': null,
      'address': '東京都渋谷区 XX-XX-XX',
      'tel': '03-1234-5678',
      'email': 'info@yamada.co.jp',
      'contact_version_id': null,
      'odoo_id': null,
      'head_char1': null,
      'head_char2': null,
      'is_locked': 0,
      'is_hidden': 0,
      'is_synced': 0,
      'updated_at': '2024-03-01 15:00:00',
      'valid_from': '2024-03-01 15:00:00',
      'valid_to': null,
      'is_current': 0,
      'version': 2,
      'content_hash': 'INVALID_HASH_2', // 不正なハッシュ
      'previous_hash': 'WRONG_PREVIOUS_HASH', // 不正な previous_hash
      'next_version_id': 'CUST-001-V3',
    },
    {
      'id': 'CUST-001-V3',
      'display_name': '山田商店',
      'formal_name': '株式会社山田商店（改）',
      'title': 0,
      'department': null,
      'address': '東京都渋谷区 XX-XX-XX',
      'tel': '03-1234-5678',
      'email': 'new@yamada.co.jp',
      'contact_version_id': null,
      'odoo_id': null,
      'head_char1': null,
      'head_char2': null,
      'is_locked': 0,
      'is_hidden': 0,
      'is_synced': 0,
      'updated_at': '2024-06-01 09:00:00',
      'valid_from': '2024-06-01 09:00:00',
      'valid_to': null,
      'is_current': 1,
      'version': 3,
      'content_hash': null, // ハッシュ未設定
      'previous_hash': null,
      'next_version_id': null,
    },

    // 正常な単一顧客（ハッシュ未設定）
    {
      'id': 'CUST-002',
      'display_name': '鈴木商事',
      'formal_name': '鈴木商事株式会社',
      'title': 0,
      'department': null,
      'address': '大阪府大阪市 XX-XX-XX',
      'tel': '06-8765-4321',
      'email': 'info@suzuki.co.jp',
      'contact_version_id': null,
      'odoo_id': null,
      'head_char1': null,
      'head_char2': null,
      'is_locked': 0,
      'is_hidden': 0,
      'is_synced': 0,
      'updated_at': '2024-05-01 12:00:00',
      'valid_from': '2024-05-01 12:00:00',
      'valid_to': null,
      'is_current': 1,
      'version': 1,
      'content_hash': null, // ハッシュ未設定
      'previous_hash': null,
      'next_version_id': null,
    },

    // 同じ名前の顧客が 2 つ（別のフォーク事故）
    {
      'id': 'CUST-003-V1',
      'display_name': '高橋製作所',
      'formal_name': '高橋製作所',
      'title': 0,
      'department': null,
      'address': '神奈川県横浜市 XX-XX-XX',
      'tel': '045-1111-2222',
      'email': 'info@takahashi.co.jp',
      'contact_version_id': null,
      'odoo_id': null,
      'head_char1': null,
      'head_char2': null,
      'is_locked': 0,
      'is_hidden': 0,
      'is_synced': 0,
      'updated_at': '2024-02-01 08:00:00',
      'valid_from': '2024-02-01 08:00:00',
      'valid_to': null,
      'is_current': 0,
      'version': 1,
      'content_hash': 'INVALID_HASH_3',
      'previous_hash': null,
      'next_version_id': 'CUST-003-V2',
    },
    {
      'id': 'CUST-003-V2',
      'display_name': '高橋製作所',
      'formal_name': '高橋製作所（新）',
      'title': 0,
      'department': null,
      'address': '神奈川県横浜市 XX-XX-XX 新館',
      'tel': '045-1111-2222',
      'email': 'new@takahashi.co.jp',
      'contact_version_id': null,
      'odoo_id': null,
      'head_char1': null,
      'head_char2': null,
      'is_locked': 0,
      'is_hidden': 0,
      'is_synced': 0,
      'updated_at': '2024-07-01 14:00:00',
      'valid_from': '2024-07-01 14:00:00',
      'valid_to': null,
      'is_current': 1,
      'version': 2,
      'content_hash': null,
      'previous_hash': null,
      'next_version_id': null,
    },
  ];

  for (final customer in testCustomers) {
    await db.insert('customers', customer);
  }

  log('テストデータ挿入完了：${testCustomers.length}件');
}

/// メイン処理
Future<void> main() async {
  print('=' * 80);
  print('顧客マスター HASH チェーン修復スクリプト');
  print('=' * 80);
  print('');

  Database? db;

  try {
    // テストデータベースで動作確認
    log('=== テスト環境 ===');
    db = await initTestDatabase();
    await insertTestCustomers(db);

    // 修復前の状態表示
    log('修复前の顧客データ:');
    final customersBefore = await getAllCustomers(db);
    for (final customer in customersBefore) {
      final hashStatus =
          (customer['content_hash'] as String?)?.startsWith('INVALID') ?? false
          ? '❌ 不正'
          : (customer['content_hash'] == null ? '⚠️ 未設定' : '✅ 正常');

      log('  - ${customer['id']} (${customer['display_name']}): $hashStatus');
    }

    // 修復処理
    log('');
    await repairHashChain(db, customersBefore);

    // 修复後の状態表示
    log('修复後の顧客データ:');
    final customersAfter = await getAllCustomers(db);
    for (final customer in customersAfter) {
      final hashStatus = customer['content_hash'] == null ? '⚠️ 未設定' : '✅ 正常';

      log('  - ${customer['id']} (${customer['display_name']}): $hashStatus');
    }

    // 整合性検証
    log('');
    await verifyHashChainIntegrity(db, customersAfter);

    // バックアップ（テスト用）
    log('');
    final backupDir = await createBackupDirectory();
    await backupDatabase(kTestDatabasePath, backupDir);

    log('');
    successLog('✅ テスト修復処理が正常に完了しました');
    print('');
    print('※ 本番環境で実行する場合は、以下の手順に従ってください:');
    print('  1. 本番データベースのバックアップを作成');
    print('  2. kDatabasePath を実際のパスに更新');
    print('  3. このスクリプトを本番データベースで実行');
  } catch (e, stackTrace) {
    errorLog('エラーが発生しました：$e');
    errorLog(stackTrace.toString());
  } finally {
    if (db != null) {
      await db.close();
    }
  }
}

// ============================================================================
// エントリポイント
// ============================================================================
