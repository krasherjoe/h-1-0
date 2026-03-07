import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({super.key});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final List<Map<String, dynamic>> _entries = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadEntries();
  }
  
  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    // TODO: 実際のデータ読み込み処理
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _entries.clear();
      _isLoading = false;
    });
  }
  
  Future<void> _createNewEntry() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('売上伝票入力画面は今後実装予定です')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('A1:売上入力'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('売上履歴機能は今後実装予定です')),
              );
            },
            tooltip: '売上履歴',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.point_of_sale, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'レジモード売上入力',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'バーコードスキャンで商品を追加',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _createNewEntry,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('新規売上入力'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  '主な機能',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem('バーコードスキャンで即時商品追加'),
                            _buildFeatureItem('在庫リアルタイム確認'),
                            _buildFeatureItem('複数決済方法対応（現金・カード・電子マネー）'),
                            _buildFeatureItem('レシート印刷'),
                            _buildFeatureItem('一時保留・再開機能'),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text(
                          entry['customer'] ?? '一般客',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${DateFormat('yyyy/MM/dd HH:mm').format(entry['date'] ?? DateTime.now())}\n'
                          '合計: ¥${NumberFormat('#,###').format(entry['total'] ?? 0)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('売上詳細画面は今後実装予定です')),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewEntry,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('新規売上'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
  
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
