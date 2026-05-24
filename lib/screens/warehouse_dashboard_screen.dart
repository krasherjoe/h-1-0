import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'stock_inquiry_screen.dart';
import 'stock_transfer_screen.dart';
import 'stock_outbound_screen.dart';
import 'stock_inbound_screen.dart';

class WarehouseDashboardScreen extends StatefulWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  State<WarehouseDashboardScreen> createState() => _WarehouseDashboardScreenState();
}

class _WarehouseDashboardScreenState extends State<WarehouseDashboardScreen> {
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = true;
  String _selectedWarehouseId = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query('warehouses', orderBy: 'name ASC');
      final loaded = <Map<String, dynamic>>[];
      for (final wh in rows) {
        final id = wh['id'] as String;
        final counts = await db.rawQuery('''
          SELECT COUNT(*) as total,
                 SUM(CASE WHEN CAST(quantity AS INTEGER) < 10 THEN 1 ELSE 0 END) as low,
                 SUM(CASE WHEN CAST(quantity AS INTEGER) = 0 THEN 1 ELSE 0 END) as out
          FROM warehouse_stock WHERE warehouse_id = ?
        ''', [id]);
        loaded.add({
          'id': id,
          'name': wh['name'] as String? ?? '',
          'totalProducts': (counts.first['total'] as num?)?.toInt() ?? 0,
          'lowStockItems': (counts.first['low'] as num?)?.toInt() ?? 0,
          'outOfStockItems': (counts.first['out'] as num?)?.toInt() ?? 0,
        });
      }
      setState(() {
        _warehouses = loaded;
        if (_warehouses.isNotEmpty) {
          _selectedWarehouseId = _warehouses.first['id'];
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
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
        title: const Text('WD:倉庫ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: _warehouses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warehouse, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(height: 16),
                  Text(
                    '倉庫データがありません',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedWarehouseId,
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
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '在庫総額',
                            '¥${_formatNumber(_selectedWarehouse!['totalValue'])}',
                            Icons.attach_money,
                            Theme.of(context).colorScheme.secondary,
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
                            Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '欠品',
                            '${_selectedWarehouse!['outOfStockItems']}',
                            Icons.error,
                            Theme.of(context).colorScheme.error,
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
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInquiryScreen()));
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          '入出庫履歴',
                          Icons.history,
                          () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInboundScreen()));
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          '在庫移動',
                          Icons.swap_horiz,
                          () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen()));
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
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
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
