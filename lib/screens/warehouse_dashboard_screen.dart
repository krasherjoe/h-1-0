import 'package:flutter/material.dart';

class WarehouseDashboardScreen extends StatefulWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  State<WarehouseDashboardScreen> createState() => _WarehouseDashboardScreenState();
}

class _WarehouseDashboardScreenState extends State<WarehouseDashboardScreen> {
  final List<Map<String, dynamic>> _warehouses = [];
  String _selectedWarehouseId = '';

  @override
  void initState() {
    super.initState();
    _loadSampleData();
  }

  void _loadSampleData() {
    setState(() {
      _warehouses.addAll([
        {
          'id': 'WH-001',
          'name': 'メイン倉庫',
          'totalProducts': 245,
          'lowStockItems': 12,
          'outOfStockItems': 3,
          'totalValue': 4500000,
        },
        {
          'id': 'WH-002',
          'name': 'サブ倉庫A',
          'totalProducts': 89,
          'lowStockItems': 5,
          'outOfStockItems': 1,
          'totalValue': 890000,
        },
      ]);
      if (_warehouses.isNotEmpty) {
        _selectedWarehouseId = _warehouses.first['id'];
      }
    });
  }

  Map<String, dynamic>? get _selectedWarehouse {
    if (_selectedWarehouseId.isEmpty) return null;
    return _warehouses.firstWhere(
      (w) => w['id'] == _selectedWarehouseId,
      orElse: () => {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('WH:倉庫ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('データ更新（未実装）')),
              );
            },
          ),
        ],
      ),
      body: _warehouses.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warehouse, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '倉庫データがありません',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedWarehouseId,
                    decoration: const InputDecoration(
                      labelText: '倉庫選択',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warehouse),
                    ),
                    items: _warehouses.map((wh) {
                      return DropdownMenuItem<String>(
                        value: wh['id'],
                        child: Text(wh['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedWarehouseId = value;
                        });
                      }
                    },
                  ),
                ),
                if (_selectedWarehouse != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '総商品数',
                            '${_selectedWarehouse!['totalProducts']}',
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '在庫総額',
                            '¥${_formatNumber(_selectedWarehouse!['totalValue'])}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '低在庫',
                            '${_selectedWarehouse!['lowStockItems']}',
                            Icons.warning,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '欠品',
                            '${_selectedWarehouse!['outOfStockItems']}',
                            Icons.error,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'クイックアクション',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          '在庫一覧',
                          Icons.list_alt,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('在庫一覧表示（未実装）')),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          '入出庫履歴',
                          Icons.history,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('入出庫履歴表示（未実装）')),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          '在庫移動',
                          Icons.swap_horiz,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('在庫移動画面へ（未実装）')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
