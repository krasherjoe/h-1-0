import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 粗利分析画面（シンプル版）
class ProfitAnalysisScreen extends StatefulWidget {
  const ProfitAnalysisScreen({super.key});

  @override
  State<ProfitAnalysisScreen> createState() => _ProfitAnalysisScreenState();
}

class _ProfitAnalysisScreenState extends State<ProfitAnalysisScreen> {
  String _selectedPeriod = 'month';
  String _selectedView = 'gross';
  bool _isLoading = false;
  
  // サンプルデータ（実際にはデータベースから取得）
  final List<Map<String, dynamic>> _profitData = [
    {'month': '1月', 'revenue': 1200000, 'cost': 960000, 'grossProfit': 240000, 'operatingCost': 180000, 'netProfit': 60000},
    {'month': '2月', 'revenue': 1500000, 'cost': 1180000, 'grossProfit': 320000, 'operatingCost': 220000, 'netProfit': 100000},
    {'month': '3月', 'revenue': 1800000, 'cost': 1390000, 'grossProfit': 410000, 'operatingCost': 280000, 'netProfit': 130000},
    {'month': '4月', 'revenue': 1600000, 'cost': 1250000, 'grossProfit': 350000, 'operatingCost': 250000, 'netProfit': 100000},
    {'month': '5月', 'revenue': 2100000, 'cost': 1580000, 'grossProfit': 520000, 'operatingCost': 320000, 'netProfit': 200000},
    {'month': '6月', 'revenue': 2300000, 'cost': 1720000, 'grossProfit': 580000, 'operatingCost': 350000, 'netProfit': 230000},
  ];
  
  final List<Map<String, dynamic>> _productProfitData = [
    {'product': '製品A', 'revenue': 3500000, 'cost': 2610000, 'profit': 890000, 'margin': 25.4},
    {'product': '製品B', 'revenue': 2800000, 'cost': 2180000, 'profit': 620000, 'margin': 22.1},
    {'product': '製品C', 'revenue': 1900000, 'cost': 1520000, 'profit': 380000, 'margin': 20.0},
    {'product': '製品D', 'revenue': 1200000, 'cost': 1020000, 'profit': 180000, 'margin': 15.0},
    {'product': '製品E', 'revenue': 800000, 'cost': 720000, 'profit': 80000, 'margin': 10.0},
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P1:粗利分析'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
                  _buildProfitSummary(),
                  const SizedBox(height: 16),
                  _buildProfitChart(),
                  const SizedBox(height: 16),
                  _buildProductAnalysis(),
                  const SizedBox(height: 16),
                  _buildProfitTable(),
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
                value: _selectedView,
                decoration: const InputDecoration(
                  labelText: '表示タイプ',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'gross', child: Text('粗利益')),
                  DropdownMenuItem(value: 'operating', child: Text('営業利益')),
                  DropdownMenuItem(value: 'net', child: Text('純利益')),
                  DropdownMenuItem(value: 'margin', child: Text('利益率')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedView = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfitSummary() {
    final totalRevenue = _profitData.fold<double>(0, (sum, item) => sum + (item['revenue'] as double));
    final totalCost = _profitData.fold<double>(0, (sum, item) => sum + (item['cost'] as double));
    final totalGrossProfit = _profitData.fold<double>(0, (sum, item) => sum + (item['grossProfit'] as double));
    final totalOperatingCost = _profitData.fold<double>(0, (sum, item) => sum + (item['operatingCost'] as double));
    final totalNetProfit = _profitData.fold<double>(0, (sum, item) => sum + (item['netProfit'] as double));
    
    final grossMargin = totalRevenue > 0 ? (totalGrossProfit / totalRevenue * 100) : 0;
    final operatingMargin = totalRevenue > 0 ? (totalNetProfit / totalRevenue * 100) : 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '総売上',
                '¥${totalRevenue.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                '総売上原価',
                '¥${totalCost.toStringAsFixed(0)}',
                Icons.inventory,
                Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                '粗利益',
                '¥${totalGrossProfit.toStringAsFixed(0)}',
                Icons.show_chart,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                '純利益',
                '¥${totalNetProfit.toStringAsFixed(0)}',
                Icons.account_balance,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '粗利率',
                '${grossMargin.toStringAsFixed(1)}%',
                Icons.percent,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                '営業利益率',
                '${operatingMargin.toStringAsFixed(1)}%',
                Icons.percent,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                '営業費用',
                '¥${totalOperatingCost.toStringAsFixed(0)}',
                Icons.business,
                Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfitChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getViewTitle()}推移',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _buildSimpleLineChart(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSimpleLineChart() {
    final data = _profitData.map((item) {
      switch (_selectedView) {
        case 'gross':
          return (item['grossProfit'] as double) / 1000000;
        case 'operating':
          return (item['netProfit'] as double) / 1000000;
        case 'net':
          return (item['netProfit'] as double) / 1000000;
        case 'margin':
          final revenue = item['revenue'] as double;
          final profit = item['grossProfit'] as double;
          return revenue > 0 ? (profit / revenue * 100) : 0;
        default:
          return 0.0;
      }
    }).cast<double>().toList();
    
    return CustomPaint(
      painter: LineChartPainter(
        data: data,
        color: Colors.green,
        maxValue: 0.6,
      ),
      child: Container(),
    );
  }
  
  String _getViewTitle() {
    switch (_selectedView) {
      case 'gross':
        return '粗利益';
      case 'operating':
        return '営業利益';
      case 'net':
        return '純利益';
      case 'margin':
        return '粗利率';
      default:
        return '利益';
    }
  }
  
  Widget _buildProductAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '製品別粗利分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildProductChart(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProductChart() {
    final data = _productProfitData.map((item) {
      return (item['profit'] as double) / 1000000;
    }).toList();
    
    return CustomPaint(
      painter: BarChartPainter(
        data: data,
        color: Colors.green,
        maxValue: 1.0,
        labels: _productProfitData.map((item) => item['product'] as String).toList(),
      ),
      child: Container(),
    );
  }
  
  Widget _buildProfitTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '粗利詳細データ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('月')),
                  DataColumn(label: Text('売上')),
                  DataColumn(label: Text('売上原価')),
                  DataColumn(label: Text('粗利益')),
                  DataColumn(label: Text('粗利率')),
                  DataColumn(label: Text('営業利益')),
                  DataColumn(label: Text('純利益')),
                ],
                rows: _profitData.map((data) {
                  final revenue = data['revenue'] as double;
                  final cost = data['cost'] as double;
                  final grossProfit = data['grossProfit'] as double;
                  final netProfit = data['netProfit'] as double;
                  final grossMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0;
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(data['month'] as String)),
                      DataCell(Text('¥${revenue.toStringAsFixed(0)}')),
                      DataCell(Text('¥${cost.toStringAsFixed(0)}')),
                      DataCell(Text('¥${grossProfit.toStringAsFixed(0)}')),
                      DataCell(Text('${grossMargin.toStringAsFixed(1)}%')),
                      DataCell(Text('¥${(grossProfit - (data['operatingCost'] as double)).toStringAsFixed(0)}')),
                      DataCell(Text('¥${netProfit.toStringAsFixed(0)}')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('データエクスポート機能は今後実装予定です')),
    );
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
    
    final path = ui.Path();
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
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        paint,
      );
    }
  }
}
