import 'package:flutter/material.dart';
import '../services/database_helper.dart';

/// データベース情報確認用デバッグ画面
class DatabaseDebugScreen extends StatefulWidget {
  const DatabaseDebugScreen({super.key});

  @override
  State<DatabaseDebugScreen> createState() => _DatabaseDebugScreenState();
}

class _DatabaseDebugScreenState extends State<DatabaseDebugScreen> {
  String _dbInfo = '読み込み中...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDbInfo();
  }

  Future<void> _loadDbInfo() async {
    try {
      final db = await DatabaseHelper().database;

      // バージョン取得
      final versionResult = await db.rawQuery('PRAGMA user_version');
      final version = versionResult.first['user_version'] as int? ?? 0;

      // customers テーブルカラム一覧
      final columnsResult = await db.rawQuery('PRAGMA table_info(customers)');
      final columns = columnsResult.map((c) => c['name'] as String).toList();

      // is_current カラムがあるか確認
      final hasIsCurrent = columns.contains('is_current');

      // products テーブルカラム一覧
      final productColumnsResult = await db.rawQuery(
        'PRAGMA table_info(products)',
      );
      final productColumns = productColumnsResult
          .map((c) => c['name'] as String)
          .toList();
      final hasProductIsCurrent = productColumns.contains('is_current');

      setState(() {
        _dbInfo =
            '''
データベース情報
━━━━━━━━━━━━━━━━━━━━━━━
バージョン：v$version

customers テーブルカラム（${columns.length}個）:
${columns.join('\n')}

is_current カラム存在：$hasIsCurrent

products テーブルカラム（${productColumns.length}個）:
${productColumns.join('\n')}

products.is_current カラム存在：$hasProductIsCurrent
━━━━━━━━━━━━━━━━━━━━━━━
''';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _dbInfo = 'エラーが発生しました:\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DB デバッグ情報'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _dbInfo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadDbInfo,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再読み込み'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
