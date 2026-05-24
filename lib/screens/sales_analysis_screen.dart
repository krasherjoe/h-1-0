import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 売上分析画面（シンプル版）
class SalesAnalysisScreen extends StatefulWidget {
  const SalesAnalysisScreen({super.key});

  @override
  State<SalesAnalysisScreen> createState() => _SalesAnalysisScreenState();
}

class _SalesAnalysisScreenState extends State<SalesAnalysisScreen> {
  String _selectedPeriod = 'month';
  String _selectedChartType = 'revenue';
  bool _isLoading = false;

  // サンプルデータ（実際にはデータベースから取得）
  final List<Map<String, dynamic>> _monthlyData = [
    {'month': '1月', 'revenue': 1200000.0, 'profit': 240000.0, 'orders': 45},
    {'month': '2月', 'revenue': 1500000.0, 'profit': 320000.0, 'orders': 52},
    {'month': '3月', 'revenue': 1800000.0, 'profit': 410000.0, 'orders': 61},
    {'month': '4月', 'revenue': 1600000.0, 'profit': 350000.0, 'orders': 58},
    {'month': '5月', 'revenue': 2100000.0, 'profit': 520000.0, 'orders': 73},
    {'month': '6月', 'revenue': 2300000.0, 'profit': 580000.0, 'orders': 81},
  ];

  final List<Map<String, dynamic>> _categoryData = [
    {'category': '製品A', 'revenue': 3500000.0, 'profit': 890000.0, 'quantity': 120},
    {'category': '製品B', 'revenue': 2800000.0, 'profit': 620000.0, 'quantity': 95},
    {'category': '製品C', 'revenue': 1900000.0, 'profit': 380000.0, 'quantity': 67},
    {'category': '製品D', 'revenue': 1200000.0, 'profit': 180000.0, 'quantity': 43},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SA:売上分析'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'データ更新',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'データエクスポート',
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
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildSimpleChartSection(),
                  const SizedBox(height: 16),
                  _buildCategoryAnalysis(),
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
                value: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: '集計期間',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('日次')),
                  DropdownMenuItem(value: 'week', child: Text('週次')),
                  DropdownMenuItem(value: 'month', child: Text('月次')),
                  DropdownMenuItem(value: 'quarter', child: Text('四半期')),
                  DropdownMenuItem(value: 'year', child: Text('年次')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                  });
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedChartType,
                decoration: const InputDecoration(
                  labelText: 'チャートタイプ',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'revenue', child: Text('売上')),
                  DropdownMenuItem(value: 'profit', child: Text('利益')),
                  DropdownMenuItem(value: 'orders', child: Text('注文数')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedChartType = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final nf = NumberFormat('#,###');
    final totalRevenue = _monthlyData.fold<double>(0, (s, i) => s + (i['revenue'] as double));
    final totalProfit = _monthlyData.fold<double>(0, (s, i) => s + (i['profit'] as double));
    final totalOrders = _monthlyData.fold<int>(0, (s, i) => s + (i['orders'] as int));
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _summaryCard('総売上', '¥${nf.format(totalRevenue.toInt())}', Icons.trending_up, cs.primary),
          const SizedBox(width: 8),
          _summaryCard('総利益', '¥${nf.format(totalProfit.toInt())}', Icons.show_chart, cs.primary),
          const SizedBox(width: 8),
          _summaryCard('総注文数', nf.format(totalOrders), Icons.shopping_cart, cs.tertiary),
          const SizedBox(width: 8),
          _summaryCard('平均単価', '¥${nf.format(avgOrderValue.toInt())}', Icons.calculate, cs.secondary),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleChartSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getChartTitle()}推移',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _buildSimpleLineChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLineChart() {
    final data = _monthlyData.map((item) {
      switch (_selectedChartType) {
        case 'revenue':
          return (item['revenue'] as double) / 1000000;
        case 'profit':
          return (item['profit'] as double) / 1000000;
        case 'orders':
          return (item['orders'] as int).toDouble();
        default:
          return 0.0;
      }
    }).toList();

    return CustomPaint(
      painter: LineChartPainter(data: data, color: Theme.of(context).colorScheme.primary, maxValue: 3.0),
      child: Container(),
    );
  }

  Widget _buildCategoryAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'カテゴリー別分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _buildSimpleBarChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleBarChart() {
    final data = _categoryData.map((item) {
      return (item['revenue'] as double) / 1000000;
    }).toList();

    return CustomPaint(
      painter: BarChartPainter(
        data: data,
        color: Theme.of(context).colorScheme.primary,
        maxValue: 4.0,
        labels: _categoryData
            .map((item) => item['category'] as String)
            .toList(),
      ),
      child: Container(),
    );
  }

  Widget _buildDetailedTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '詳細データ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('月')),
                  DataColumn(label: Text('売上')),
                  DataColumn(label: Text('利益')),
                  DataColumn(label: Text('利益率')),
                  DataColumn(label: Text('注文数')),
                  DataColumn(label: Text('平均単価')),
                ],
                rows: _monthlyData.map((data) {
                  final revenue = data['revenue'] as double;
                  final profit = data['profit'] as double;
                  final orders = data['orders'] as int;
                  final profitRate = revenue > 0 ? (profit / revenue * 100) : 0;
                  final avgOrderValue = orders > 0 ? revenue / orders : 0;

                  return DataRow(
                    cells: [
                      DataCell(Text(data['month'] as String)),
                      DataCell(Text('¥${revenue.toStringAsFixed(0)}')),
                      DataCell(Text('¥${profit.toStringAsFixed(0)}')),
                      DataCell(Text('${profitRate.toStringAsFixed(1)}%')),
                      DataCell(Text(orders.toString())),
                      DataCell(Text('¥${avgOrderValue.toStringAsFixed(0)}')),
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

  String _getChartTitle() {
    switch (_selectedChartType) {
      case 'revenue':
        return '売上';
      case 'profit':
        return '利益';
      case 'orders':
        return '注文数';
      default:
        return 'データ';
    }
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

  void _exportData() {
    // データエクスポート処理
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('データエクスポート機能は今後実装予定です')));
  }
}

/// シンプルラインチャートペインター
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;

  LineChartPainter({
    required this.data,
    required this.color,
    required this.maxValue,
  });

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointWidth = size.width / (data.length - 1);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * pointWidth;
      final y = size.height - (data[i] / maxValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // データポイント
    for (int i = 0; i < data.length; i++) {
      final x = i * pointWidth;
      final y = size.height - (data[i] / maxValue * size.height);

      canvas.drawCircle(Offset(x, y), 4, paint);
    }

    canvas.drawPath(path, paint);
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
