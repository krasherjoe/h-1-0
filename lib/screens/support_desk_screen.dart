import 'package:flutter/material.dart';
import '../services/database_helper.dart';

/// SD:サポートデスク（簡易問い合わせ管理）
class SupportDeskScreen extends StatefulWidget {
  const SupportDeskScreen({super.key});
  @override
  State<SupportDeskScreen> createState() => _SupportDeskScreenState();
}

class _SupportDeskScreenState extends State<SupportDeskScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 現状は問い合わせ用のテーブルがないので、空表示
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('SD:サポートデスク')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(),
        icon: const Icon(Icons.add),
        label: const Text('新規問い合わせ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.support_agent, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('問い合わせ記録がありません', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('問い合わせ機能は準備中です', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _tickets.length,
                  itemBuilder: (_, i) => Card(child: ListTile(title: Text(_tickets[i]['subject'] ?? ''))),
                ),
    );
  }

  void _create() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('問い合わせ登録機能は準備中です')),
    );
  }
}
