// 顧客 HASH チェーン修復スクリプト - 事故物件検出用
// 実行方法：flutter run lib/workshops/repair_customer_hash_chain/debug_fork_break.dart

import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../models/customer_model.dart';

Future<void> main() async {
  print('=== 顧客 HASH チェーン事故物件検出 ===\n');

  final db = await DatabaseHelper().database;

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
        print('     Hash: ${hash.substring(0, 16)}...');
        print('     PrevHash: ${prevHash.substring(0, 16)}...');
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

  print('\n=== 検出結果 ===');
  print('同名顧客（事故物件）: $duplicateCount 件');
  print('HASH チェーン断絶：$brokenChainCount 件');
  print('\n📝 修復スクリプトを実行してマージ・削除してください');
}
