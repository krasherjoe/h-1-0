import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 在庫評価額レポート画面（シンプル版）
class InventoryValueReportScreen extends StatefulWidget {
  const InventoryValueReportScreen({super.key});

  @override
  State<InventoryValueReportScreen> createState() =>
      _InventoryValueReportScreenState();
}

class _InventoryValueReportScreenState
    extends State<InventoryValueReportScreen> {
  bool _isLoading = true;
  String _selectedWarehouse = 'all';
  String _selectedPeriod = 'current';

  // サンプルデータ（実際にはデータベースから取得）
  final List<Map<String, dynamic>> _inventories = [
    {
      'productName': '製品A',
      'warehouseName': '主倉庫',
      'currentStock': 120.5,
      'unit': '個',
      'averageCost': 1500,
      'totalValue': 180750,
      'status': 'normal',
    },
    {
      'productName': '製品B',
      'warehouseName': '主倉庫',
      'currentStock': 85.0,
      'unit': '個',
      'averageCost': 2000,
      'totalValue': 170000,
      'status': 'normal',
    },
    {
      'productName': '製品C',
      'warehouseName': '主倉庫',
      'currentStock': 15.0,
      'unit': '個',
      'averageCost': 800,
      'totalValue': 12000,
      'status': 'low_stock',
    },
    {
      'productName': '製品D',
      'warehouseName': '倉庫B',
      'currentStock': 0.0,
      'unit': '個',
      'averageCost': 1200,
      'totalValue': 0,
      'status': 'out_of_stock',
    },
    {
      'productName': '製品E',
      'warehouseName': '倉庫B',
      'currentStock': 250.0,
      'unit': '個',
      'averageCost': 500,
      'totalValue': 125000,
      'status': 'overstock',
    },
  ];

  final Map<String, dynamic> _statistics = {
    'totalValue': 487750,
    'totalProducts': 5,
    'normalStock': 2,
    'lowStock': 1,
    'outOfStock': 1,
    'overstock': 1,
    'warehouseCount': {'主倉庫': 2, '倉庫B': 3},
    'warehouseValue': {'主倉庫': 350750, '倉庫B': 137000},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // 実際のデータ読み込み処理
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('IR:在庫評価額レポート'),
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'データ更新',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'レポート出力',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(),
                  const SizedBox(height: 16),
                  _buildValueSummary(),
                  const SizedBox(height: 16),
                  _buildValueChart(),
                  const SizedBox(height: 16),
                  _buildWarehouseAnalysis(),
                  const SizedBox(height: 16),
                  _buildInventoryStatusAnalysis(),
                  const SizedBox(height: 16),
                  _buildDetailedTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedWarehouse,
                decoration: const InputDecoration(
                  labelText: '倉庫',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('すべて')),
                  ...(_statistics['warehouseCount'] as Map<String, int>).keys
                      .map((key) {
                        return DropdownMenuItem(value: key, child: Text(key));
                      }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedWarehouse = value!;
                  });
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: '表示期間',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'current', child: Text('現在')),
                  DropdownMenuItem(value: 'month', child: Text('月次')),
                  DropdownMenuItem(value: 'quarter', child: Text('四半期')),
                  DropdownMenuItem(value: 'year', child: Text('年次')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    final totalValue = _statistics['totalValue'] as double? ?? 0;
    final totalProducts = _statistics['totalProducts'] as int? ?? 0;
    final avgValuePerProduct = totalProducts > 0
        ? totalValue / totalProducts
        : 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            '総評価額',
            '¥${totalValue.toStringAsFixed(0)}',
            Icons.account_balance,
            colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            '製品数',
            totalProducts.toString(),
            Icons.inventory,
            colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            '平均単価',
            '¥${avgValuePerProduct.toStringAsFixed(0)}',
            Icons.calculate,
            colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            '評価日時',
            DateTime.now().toString().substring(0, 10),
            Icons.calendar_today,
            colorScheme.tertiaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在庫評価額分布',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 300, child: _buildPieChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final colorScheme = Theme.of(context).colorScheme;
    final statusData = [
      {
        'status': '正常',
        'count': _statistics['normalStock'] as int? ?? 0,
        'color': colorScheme.primary,
      },
      {
        'status': '低在庫',
        'count': _statistics['lowStock'] as int? ?? 0,
        'color': colorScheme.secondary,
      },
      {
        'status': '欠品',
        'count': _statistics['outOfStock'] as int? ?? 0,
        'color': colorScheme.error,
      },
      {
        'status': '過剰在庫',
        'count': _statistics['overstock'] as int? ?? 0,
        'color': colorScheme.tertiary,
      },
    ];

    return CustomPaint(
      painter: PieChartPainter(data: statusData, size: const Size(250, 250)),
      child: Container(),
    );
  }

  Widget _buildWarehouseAnalysis() {
    final warehouseData = _statistics['warehouseValue'] as Map<String, double>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '倉庫別評価額',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildWarehouseBarChart(warehouseData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseBarChart(Map<String, double> warehouseData) {
    final colorScheme = Theme.of(context).colorScheme;
    final data = warehouseData.values.map((value) => value / 1000000).toList();
    final labels = warehouseData.keys.toList();

    return CustomPaint(
      painter: BarChartPainter(
        data: data,
        color: colorScheme.primary,
        maxValue: data.isNotEmpty
            ? data.reduce((a, b) => a > b ? a : b) * 1.2
            : 1.0,
        labels: labels,
      ),
      child: Container(),
    );
  }

  Widget _buildInventoryStatusAnalysis() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在庫状態分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    '正常',
                    _statistics['normalStock'] as int? ?? 0,
                    colorScheme.primary,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusCard(
                    '低在庫',
                    _statistics['lowStock'] as int? ?? 0,
                    colorScheme.secondary,
                    Icons.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusCard(
                    '欠品',
                    _statistics['outOfStock'] as int? ?? 0,
                    colorScheme.error,
                    Icons.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusCard(
                    '過剰在庫',
                    _statistics['overstock'] as int? ?? 0,
                    colorScheme.tertiary,
                    Icons.inventory_2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, int count, Color color, IconData icon) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedTable() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在庫評価詳細',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('製品名')),
                  DataColumn(label: Text('倉庫')),
                  DataColumn(label: Text('現在在庫')),
                  DataColumn(label: Text('単価')),
                  DataColumn(label: Text('評価額')),
                  DataColumn(label: Text('状態')),
                ],
                rows: _inventories.map((inventory) {
                  final status = inventory['status'] as String;
                  final statusColor = _getStatusColor(colorScheme, status);
                  final statusDisplayName = _getStatusDisplayName(status);

                  return DataRow(
                    cells: [
                      DataCell(Text(inventory['productName'] as String)),
                      DataCell(Text(inventory['warehouseName'] as String)),
                      DataCell(
                        Text(
                          '${(inventory['currentStock'] as double).toStringAsFixed(2)} ${inventory['unit'] as String}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '¥${(inventory['averageCost'] as double).toStringAsFixed(2)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '¥${(inventory['totalValue'] as double).toStringAsFixed(2)}',
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusDisplayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme, String status) {
    switch (status) {
      case 'normal':
        return colorScheme.primary;
      case 'low_stock':
        return colorScheme.secondary;
      case 'out_of_stock':
        return colorScheme.error;
      case 'overstock':
        return colorScheme.tertiary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'normal':
        return '正常';
      case 'low_stock':
        return '低在庫';
      case 'out_of_stock':
        return '欠品';
      case 'overstock':
        return '過剰在庫';
      default:
        return status;
    }
  }

  void _exportReport() {
    // レポート出力処理
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('レポート出力機能は今後実装予定です')));
  }
}

/// シンプルパイチャートペインター
class PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Size size;

  PieChartPainter({required this.data, required this.size});

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    final total = data.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );
    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (final item in data) {
      final count = item['count'] as int;
      final color = item['color'] as Color;
      final sweepAngle = (count / total) * 2 * math.pi;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }
}

/// シンプルバーチャートペインター
class BarChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;
  final List<String> labels;

  BarChartPainter({
    required this.data,
    required this.color,
    required this.maxValue,
    required this.labels,
  });

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barWidth = size.width / (data.length * 2);
    final spacing = barWidth;

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxValue) * size.height;
      final x = i * (barWidth + spacing) + spacing;
      final y = size.height - barHeight;

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);
    }
  }
}
