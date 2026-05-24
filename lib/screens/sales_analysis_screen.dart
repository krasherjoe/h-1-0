import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../services/customer_repository.dart';
import '../services/database_helper.dart';
import '../services/invoice_repository.dart';

/// SA:売上分析（実DB連携）
class SalesAnalysisScreen extends StatefulWidget {
  const SalesAnalysisScreen({super.key});
  @override
  State<SalesAnalysisScreen> createState() => _SalesAnalysisScreenState();
}

class _SalesAnalysisScreenState extends State<SalesAnalysisScreen> {
  final _nf = NumberFormat('#,###');
  final _df = DateFormat('yyyy/MM/dd');

  bool _isLoading = true;
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _categoryData = [];
  int _year = DateTime.now().year;
  int _totalRevenue = 0, _totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await CustomerRepository().getAllCustomers();
      final all = await InvoiceRepository().getAllInvoices(customers);
      final invoices = all.where((inv) =>
        inv.date.year == _year && !inv.isDraft &&
        (inv.documentType == DocumentType.invoice || inv.documentType == DocumentType.estimation)
      ).toList();

      _totalRevenue = invoices.fold(0, (s, i) => s + i.totalAmount);
      _totalOrders = invoices.length;

      // 月次データ
      final monthly = List.generate(12, (i) => {
        'month': '${i + 1}月',
        'revenue': 0.0,
        'orders': 0,
        'paid': 0,
      });
      for (final inv in invoices) {
        final m = inv.date.month - 1;
        monthly[m]['revenue'] = (monthly[m]['revenue'] as double) + inv.totalAmount.toDouble();
        monthly[m]['orders'] = (monthly[m]['orders'] as int) + 1;
        if (inv.paymentStatus == PaymentStatus.paid) monthly[m]['paid'] = (monthly[m]['paid'] as int) + inv.totalAmount;
      }
      _monthlyData = monthly;

      // カテゴリ別（商品名の先頭から分類）
      final catMap = <String, double>{};
      for (final inv in invoices) {
        for (final item in inv.items) {
          final cat = item.description.length > 4 ? item.description.substring(0, 2) : item.description;
          catMap[cat] = (catMap[cat] ?? 0) + item.subtotal.toDouble();
        }
      }
      final sorted = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _categoryData = sorted.take(5).map((e) => {
        'category': e.key,
        'revenue': e.value,
      }).toList();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _maxMonthly => _monthlyData.map((m) => (m['revenue'] as double)).reduce((a, b) => a > b ? a : b);
  double get _maxCategory => _categoryData.map((c) => (c['revenue'] as double)).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('SA:売上分析'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () { setState(() { _year--; _loadData(); }); }),
          Text('$_year', style: const TextStyle(fontSize: 16)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { setState(() { _year++; _loadData(); }); }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monthlyData.isEmpty
              ? const Center(child: Text('データがありません'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryCards(cs),
                      const SizedBox(height: 16),
                      _buildChart(cs),
                      const SizedBox(height: 16),
                      if (_categoryData.isNotEmpty) _buildCategoryChart(cs),
                      const SizedBox(height: 16),
                      _buildTable(cs),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards(ColorScheme cs) {
    final avgOrder = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _card('総売上', '¥${_nf.format(_totalRevenue)}', Icons.trending_up, cs.primary),
          const SizedBox(width: 8),
          _card('請求件数', '${_nf.format(_totalOrders)}件', Icons.receipt, cs.tertiary),
          const SizedBox(width: 8),
          _card('平均単価', '¥${_nf.format(avgOrder.toInt())}', Icons.calculate, cs.secondary),
        ],
      ),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: SizedBox(
        width: 180,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  Text(title, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月次売上推移', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: (_monthlyData.length * 60.0).clamp(300, 800),
                  child: CustomPaint(
                    painter: BarChartPainter(
                      data: _monthlyData.map((m) => (m['revenue'] as double) / 10000).toList(),
                      maxValue: (_maxMonthly / 10000).ceilToDouble(),
                      labels: _monthlyData.map((m) => m['month'] as String).toList(),
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('商品別売上', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: CustomPaint(
              painter: BarChartPainter(
                data: _categoryData.map((c) => (c['revenue'] as double) / 10000).toList(),
                maxValue: (_maxCategory / 10000).ceilToDouble(),
                labels: _categoryData.map((c) => c['category'] as String).toList(),
                color: cs.tertiary,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月別詳細', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [DataColumn(label: Text('月')), DataColumn(label: Text('売上')), DataColumn(label: Text('件数'))],
                rows: _monthlyData.map((m) => DataRow(cells: [
                  DataCell(Text(m['month'] as String)),
                  DataCell(Text('¥${_nf.format((m['revenue'] as double).toInt())}')),
                  DataCell(Text('${(m['orders'] as int)}件')),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エクスポート機能は準備中です')));
  }
}

class BarChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final List<String> labels;
  final Color color;

  BarChartPainter({required this.data, required this.maxValue, required this.labels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue <= 0) return;
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final barW = (size.width - 40) / data.length;
    for (var i = 0; i < data.length; i++) {
      final h = (data[i] / maxValue) * (size.height - 20);
      final x = 10.0 + i * barW;
      final y = size.height - 20 - h;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y, barW - 4, h), const Radius.circular(3)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
