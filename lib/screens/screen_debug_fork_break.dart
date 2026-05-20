// 顧客 HASH チェーン修復画面（事故物件検出・自動マージ）
// Screen ID: SD:フォーク修復
// 実行方法：flutter run lib/screens/screen_debug_fork_break.dart

import 'package:flutter/material.dart';
import 'package:h_1/services/database_helper.dart';

class DebugForkBreakScreen extends StatefulWidget {
  const DebugForkBreakScreen({super.key});

  @override
  State<DebugForkBreakScreen> createState() => _DebugForkBreakScreenState();
}

class _DebugForkBreakScreenState extends State<DebugForkBreakScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _duplicateCustomers = [];
  List<Map<String, dynamic>> _brokenChainCustomers = [];
  bool _isScanning = false;
  String _statusMessage = '待機中';

  // スキャン実行
  Future<void> _scanForIssues() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'スキャンを開始しています...';
      _duplicateCustomers.clear();
      _brokenChainCustomers.clear();
    });

    try {
      final db = await _dbHelper.database;

      // 1. 全顧客取得（最新バージョンのみ）
      setState(() => _statusMessage = '顧客データを取得中...');
      final allCustomers = await db.query(
        'customers',
        where: 'is_current = 1 AND is_hidden = 0',
      );

      if (!mounted) return;
      setState(() => _allCustomers = allCustomers);

      // 2. 同一表示名でグループ化
      setState(() => _statusMessage = '重複顧客を検出中...');
      final nameGroups = <String, List<Map<String, dynamic>>>{};
      for (var customer in allCustomers) {
        final name = customer['display_name'] as String? ?? '無名';
        if (!nameGroups.containsKey(name)) {
          nameGroups[name] = [];
        }
        nameGroups[name]!.add(customer);
      }

      // 3. 同一名の事故物件を抽出
      for (var entry in nameGroups.entries) {
        if (entry.value.length > 1) {
          for (var customer in entry.value) {
            _duplicateCustomers.add(customer);
          }
        }
      }

      // ID フィールドを整数に変換（SQLite の型キャスト対策）
      for (var customer in _duplicateCustomers) {
        final idValue = customer['id'];
        if (idValue is String) {
          customer['id'] = int.parse(idValue);
        } else if (idValue is! int) {
          debugPrint('警告：無効な ID 形式 ${idValue.runtimeType}');
        }
      }

      // HASH チェーン断絶レコードも同様に処理
      for (var customer in _brokenChainCustomers) {
        final idValue = customer['id'];
        if (idValue is String) {
          customer['id'] = int.parse(idValue);
        } else if (idValue is! int) {
          debugPrint('警告：無効な ID 形式 ${idValue.runtimeType}');
        }
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'HASH チェーン断絶を検出中...');

      // 4. HASH チェーン断絶を検出
      for (var customer in allCustomers) {
        final prevHash = customer['previous_hash'] as String?;
        if (prevHash != null && prevHash.isNotEmpty) {
          final parent = await db.query(
            'customers',
            where: 'content_hash = ?',
            whereArgs: [prevHash],
          );

          if (parent.isEmpty) {
            _brokenChainCustomers.add(customer);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage =
            'スキャン完了（${_duplicateCustomers.length}件の重複、${_brokenChainCustomers.length}件の断絶を検出）';
      });

      if (_duplicateCustomers.isEmpty && _brokenChainCustomers.isEmpty) {
        _showSuccessDialog();
      } else {
        _showResultsDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showErrorDialog('スキャンエラー：$e');
    }
  }

  // 自動マージ実行
  Future<void> _repairAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 修復を実行しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('検出された問題:\n'),
            Text('・重複顧客：${_duplicateCustomers.length}件\n'),
            Text('・HASH チェーン断絶：${_brokenChainCustomers.length}件\n'),
            const SizedBox(height: 8),
            const Text('以下の処理を実行します:\n'),
            Text('1. 重複顧客を最新バージョンに自動マージ\n'),
            Text('2. 失われる情報は顧客メモに記録\n'),
            Text('3. HASH チェーン断絶レコードを削除\n'),
            const SizedBox(height: 16),
            Text(
              '⚠️ この操作は取り消せません。',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('修復を実行'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isScanning = true;
      _statusMessage = '修復処理を開始します...';
    });

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // 1. 重複顧客のマージ
        for (var customer in _duplicateCustomers) {
          if (!mounted) return;
          setState(
            () => _statusMessage =
                'マージ中：${customer['display_name']}（ID: ${customer['id']}）',
          );

          // String 型 ID を安全に変換
          final customerId = customer['id'] is int
              ? customer['id'] as int
              : (customer['id'] is String ? int.parse(customer['id']) : 0);
          final displayName = customer['display_name'] as String;

          // 他の重複レコードを取得（ID を安全に変換）
          final otherCustomers = _duplicateCustomers.where((c) {
            final otherId = c['id'] is int
                ? c['id'] as int
                : (c['id'] is String ? int.parse(c['id']) : 0);
            return c['display_name'] == displayName && otherId != customerId;
          });

          // 他の重複レコードがある場合、情報をマージ
          for (var other in otherCustomers) {
            // メモを結合（失われる情報を記録）
            final existingMemo = customer['memo'] as String? ?? '';
            final otherMemo = other['memo'] as String? ?? '';
            final otherHistory = other['history_notes'] as String? ?? '';

            String mergedMemo = existingMemo;
            if (otherMemo.isNotEmpty) {
              mergedMemo +=
                  '\n\n--- 自動マージによる追加（ID: ${other['id']}から） ---\n$otherMemo';
            }
            if (otherHistory.isNotEmpty) {
              mergedMemo +=
                  '\n\n--- 履歴ノート（ID: ${other['id']}から） ---\n$otherHistory';
            }

            // メモ更新
            await txn.update(
              'customers',
              {
                'memo': mergedMemo,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [customerId],
            );

            // 重複レコードを非公開・最新でないことにする
            await txn.update(
              'customers',
              {
                'is_current': 0,
                'is_hidden': 1,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [other['id']],
            );

            debugPrint('マージ完了：${other['id']} → ${customerId}');
          }
        }

        // 2. HASH チェーン断絶レコードの削除
        for (var customer in _brokenChainCustomers) {
          if (!mounted) return;
          setState(
            () => _statusMessage =
                '削除中：${customer['display_name']}（ID: ${customer['id']}）',
          );

          // String 型 ID を安全に変換
          final customerId = customer['id'] is int
              ? customer['id'] as int
              : (customer['id'] is String ? int.parse(customer['id']) : 0);

          // メモに記録してから削除
          final displayName = customer['display_name'] as String;
          final existingMemos = await txn.query(
            'customers',
            where: 'display_name = ? AND is_current = 1 AND id != ?',
            whereArgs: [displayName, customerId],
          );

          if (existingMemos.isNotEmpty) {
            // 正規レコードが存在する場合、情報をマージ
            final idValue = existingMemos.first['id'];
            final targetId = idValue is int
                ? idValue
                : (idValue is String ? int.parse(idValue) : 0);
            final otherMemo = customer['memo'] as String? ?? '';
            final otherHistory = customer['history_notes'] as String? ?? '';

            if (otherMemo.isNotEmpty || otherHistory.isNotEmpty) {
              final existingMemo = existingMemos.first['memo'] as String? ?? '';
              String mergedMemo = existingMemo;
              if (otherMemo.isNotEmpty) {
                mergedMemo +=
                    '\n\n--- 断絶レコードからマージ（ID: ${customer['id']}から） ---\n$otherMemo';
              }
              if (otherHistory.isNotEmpty) {
                mergedMemo +=
                    '\n\n--- 履歴ノート（ID: ${customer['id']}から） ---\n$otherHistory';
              }

              await txn.update(
                'customers',
                {
                  'memo': mergedMemo,
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where: 'id = ?',
                whereArgs: [targetId],
              );
            }
          }

          // 断絶レコードを削除
          await txn.delete(
            'customers',
            where: 'id = ?',
            whereArgs: [customer['id']],
          );
          debugPrint('削除完了：${customer['id']}');
        }

        if (!mounted) return;
        setState(() => _statusMessage = '修復処理完了');
      });

      if (!mounted) return;
      _showRepairCompleteDialog();

      // スキャン再実行
      await _scanForIssues();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showErrorDialog('修復エラー：$e');
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 スキャン結果'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('現在有効な顧客数：${_allCustomers.length}件'),
              Text('重複顧客（事故物件）: ${_duplicateCustomers.length}件'),
              Text('HASH チェーン断絶：${_brokenChainCustomers.length}件'),
              const SizedBox(height: 16),
              if (_duplicateCustomers.isNotEmpty) ...[
                const Text(
                  '📋 重複顧客リスト:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._duplicateCustomers.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '- ${c['display_name']} (ID: ${c['id']}, Version: ${c['version']})',
                    ),
                  ),
                ),
              ],
              if (_brokenChainCustomers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '🔗 HASH チェーン断絶リスト:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                ..._brokenChainCustomers.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '- ${c['display_name']} (ID: ${c['id']})',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: _repairAll,
            icon: const Icon(Icons.build),
            label: const Text('自動修復を実行'),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ スキャン完了'),
        content: const Text('問題は見つかりませんでした。\nすべての顧客で HASH チェーンが正常に動作しています。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showRepairCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✨ 修復完了'),
        content: const Text('すべての事故物件を正常に処理しました。\n顧客メモに必要な情報が記録されています。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FK:フォーク修復 - HASH チェーン管理'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '顧客 HASH チェーン修復ツール',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '事故物件（重複・HASH チェーン断絶）を検出・自動修復します',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 概要',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('現在有効な顧客数：${_allCustomers.length}件'),
                  Text('重複顧客（事故物件）: ${_duplicateCustomers.length}件'),
                  Text('HASH チェーン断絶：${_brokenChainCustomers.length}件'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isScanning)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanForIssues,
                      icon: const Icon(Icons.search),
                      label: const Text('スキャン実行'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _duplicateCustomers.isEmpty &&
                              _brokenChainCustomers.isEmpty
                          ? null
                          : _repairAll,
                      icon: const Icon(Icons.build),
                      label: const Text('自動修復'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            _duplicateCustomers.isEmpty &&
                                _brokenChainCustomers.isEmpty
                            ? Theme.of(context).colorScheme.outlineVariant
                            : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('📝 ステータス：$_statusMessage'),
            ),
          ],
        ),
      ),
    );
  }
}

// メイン関数（単独実行用）
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: DebugForkBreakScreen()));
}
