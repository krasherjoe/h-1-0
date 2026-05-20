import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/invoice_repository.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _invoiceRepo = InvoiceRepository();
  int _targetYear = DateTime.now().year;
  Map<String, int> _monthlySales = {};
  int _yearlyTotal = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final monthly = await _invoiceRepo.getMonthlySales(_targetYear);
    final yearly = await _invoiceRepo.getYearlyTotal(_targetYear);
    setState(() {
      _monthlySales = monthly;
      _yearlyTotal = yearly;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");

    return Scaffold(
      appBar: AppBar(
        title: Text("売上・資金管理レポート"),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildYearSelector(),
                _buildYearlySummary(fmt),
                const Divider(height: 1),
                Expanded(child: _buildMonthlyList(fmt)),
              ],
            ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _targetYear--);
              _loadData();
            },
          ),
          Text(
            "$_targetYear年度",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _targetYear++);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYearlySummary(NumberFormat fmt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        children: [
          Text("年間売上合計 (請求確定分)", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text(
            "￥${fmt.format(_yearlyTotal)}",
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyList(NumberFormat fmt) {
    return ListView.builder(
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = (index + 1).toString().padLeft(2, '0');
        final amount = _monthlySales[month] ?? 0;
        final percentage = _yearlyTotal > 0 ? (amount / _yearlyTotal * 100).toStringAsFixed(1) : "0.0";

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text("${index + 1}", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          title: Text("${index + 1}月の売上"),
          subtitle: amount > 0 ? Text("シェア: $percentage%") : null,
          trailing: Text(
            "￥${fmt.format(amount)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amount > 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
// FontWeight.bold in Text widget is TextStyle.fontWeight not pw.FontWeight
// Corrected to FontWeight.bold below in replace or write.
