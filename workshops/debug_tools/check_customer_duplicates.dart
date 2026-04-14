// 顧客重複チェックスクリプト（単独実行用）
// 実行方法：cd /home/user/code/h-1.flutter.0 && dart --enable-asserts workshops/debug_tools/check_customer_duplicates.dart

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crypto/crypto.dart';

void main() async {
  print('=== 顧客 HASH チェーン事故物件検出 ===\n');

  // FFI バインディングの初期化
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  try {
    // データベースパスの取得
    final appDir = Directory.current.path;
    final dbPath = path.join(appDir, 'data', '販売アシスト 1 号.db');

    print('📁 データベースパス：$dbPath\n');

    if (!File(dbPath).existsSync()) {
      print('❌ データベースが見つかりません：$dbPath');
      print('\nアプリ内の DB パスを確認してください。\n');
      return;
    }

    // データベースを開く
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 43, onCreate: (db, version) {}),
    );

    print('✅ データベース接続成功\n');

    // 1. is_current=1 の顧客を全て取得
    final allCustomers = await db.query(
      'customers',
      where: 'is_current = 1 AND is_hidden = 0',
    );

    print('📊 現在有効な顧客数：${allCustomers.length}\n');

    // 2. 同一表示名でグループ化
    final nameGroups = <String, List<Map<String, dynamic>>>{};
    for (var customer in allCustomers) {
      final name = customer['display_name'] as String? ?? '無名';
      if (!nameGroups.containsKey(name)) {
        nameGroups[name] = [];
      }
      nameGroups[name]!.add(customer);
    }

    // 3. 同一名の事故物件を抽出
    final suspiciousCustomers = <Map<String, dynamic>>[];
    int duplicateCount = 0;

    for (var entry in nameGroups.entries) {
      if (entry.value.length > 1) {
        print('⚠️ 同名顧客（${entry.value.length}件）: ${entry.key}');
        for (var customer in entry.value) {
          final id = customer['id'];
          final version = customer['version'] ?? 0;
          final hash = customer['content_hash'] ?? '';
          final prevHash = customer['previous_hash'] ?? '';

          print('   - ID: $id, Version: $version');
          if (hash.isNotEmpty) {
            print('     Hash: ${hash.substring(0, 16)}...');
          } else {
            print('     Hash: (未設定)');
          }
          if (prevHash.isNotEmpty) {
            print('     PrevHash: ${prevHash.substring(0, 16)}...');
          } else {
            print('     PrevHash: (未設定)');
          }
          suspiciousCustomers.add(customer);
        }
        duplicateCount += entry.value.length;
        print('');
      }
    }

    // 4. HASH チェーン断絶を検出
    print('🔗 HASH チェーン断絶検出:\n');
    int brokenChainCount = 0;

    for (var customer in suspiciousCustomers) {
      final prevHash = customer['previous_hash'] as String?;
      if (prevHash != null && prevHash.isNotEmpty) {
        // previous_hash が存在するレコードの親を検索
        final parent = await db.query(
          'customers',
          where: 'content_hash = ?',
          whereArgs: [prevHash],
        );

        if (parent.isEmpty) {
          print(
            '❌ 断絶：ID=${customer['id']}, PrevHash=${prevHash.substring(0, 16)}...',
          );
          print('   親レコードが存在しない');
          brokenChainCount++;
        }
      }
    }

    // 5. HASH チェーン整合性チェック
    print('\n🔐 HASH チェーン整合性チェック:\n');
    int hashMismatchCount = 0;

    for (var customer in allCustomers) {
      final expectedHash = await calculateCustomerHash(customer);
      final actualHash = customer['content_hash'] as String? ?? '';

      if (expectedHash != actualHash) {
        print('❌ ハッシュ不一致：ID=${customer['id']}');
        print('   期待値：$expectedHash');
        print('   実際：$actualHash');
        hashMismatchCount++;
      }
    }

    // 結果汇总
    print('\n' + '=' * 50);
    print('=== 検出結果 ===');
    print('=' * 50);
    print('現在有効な顧客数：${allCustomers.length}件');
    print('同名顧客（事故物件）: $duplicateCount 件');
    print('HASH チェーン断絶：$brokenChainCount 件');
    print('ハッシュ不一致：$hashMismatchCount 件');
    print('=' * 50);

    if (duplicateCount > 0 || brokenChainCount > 0 || hashMismatchCount > 0) {
      print('\n⚠️ 問題が検出されました！修復スクリプトを実行してください。\n');
    } else {
      print('\n✅ すべての顧客で HASH チェーンが正常です。\n');
    }

    // データベースをクローズ
    await db.close();
  } catch (e, stackTrace) {
    print('❌ エラー：$e');
    print('\nスタックトレース:');
    print(stackTrace);
  }
}

/// 顧客の HASH を計算
Future<String> calculateCustomerHash(Map<String, dynamic> customer) async {
  final fields = [
    customer['id'] ?? '',
    customer['display_name'] ?? '',
    customer['formal_name'] ?? '',
    customer['title'] ?? '',
    customer['department'] ?? '',
    customer['address'] ?? '',
    customer['tel'] ?? '',
    customer['email'] ?? '',
    customer['contact_version_id'] ?? '',
    customer['odoo_id'] ?? '',
    customer['is_locked'] ?? 0,
    customer['is_hidden'] ?? 0,
    customer['head_char1'] ?? '',
    customer['head_char2'] ?? '',
    customer['valid_from'] ?? '',
    customer['valid_to'] ?? '',
    customer['is_current'] ?? 0,
    customer['version'] ?? 0,
    customer['previous_hash'] ?? '',
  ];

  final data = fields.join('|');
  final bytes = utf8.encode(data);
  final hash = sha256.convert(bytes);
  return hash.toString();
}
