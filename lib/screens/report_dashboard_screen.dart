import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';

/// RP:売上レポートダッシュボード
class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});
  @override
  State<ReportDashboardScreen> createState() => _ReportDashboardScreenState();
}

class _ReportDashboardScreenState extends State<ReportDashboardScreen> {
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _nf = NumberFormat('#,###');
  final _df = DateFormat('yyyy/MM/dd');

  bool _loading = true;
  int _year = DateTime.now().year;
  Map<String, int> _monthly = {};
  int _yearTotal = 0;
  int _unpaidTotal = 0;
  int _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final monthly = await _invoiceRepo.getMonthlySales(_year);
      final yearly = await _invoiceRepo.getYearlyTotal(_year);
      final customers = await _customerRepo.getAllCustomers();
      final all = await _invoiceRepo.getAllInvoices(customers);
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      int unpaid = 0, todayAmt = 0;
      for (final inv in all) {
        if (inv.documentType == DocumentType.invoice && !inv.isDraft) {
          if (inv.paymentStatus != PaymentStatus.paid) {
            unpaid += inv.totalAmount - inv.receivedAmount;
          }
          final d = '${inv.date.year}-${inv.date.month.toString().padLeft(2, '0')}-${inv.date.day.toString().padLeft(2, '0')}';
          if (d == todayStr) todayAmt += inv.totalAmount;
        }
      }
      if (!mounted) return;
      setState(() { _monthly = monthly; _yearTotal = yearly; _unpaidTotal = unpaid; _todayTotal = todayAmt; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('RP:売上レポート')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 年間サマリーカード
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => setState(() { _year--; _load(); }),
                            ),
                            Text('$_year年', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => setState(() { _year++; _load(); }),
                            ),
                            const Spacer(),
                            Text('年間: ¥${_nf.format(_yearTotal)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._buildMonthlyBars(cs),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // サマリー行
                Row(
                  children: [
                    Expanded(child: _summaryCard('本日', '¥${_nf.format(_todayTotal)}', Colors.blue, cs)),
                    const SizedBox(width: 8),
                    Expanded(child: _summaryCard('年累計', '¥${_nf.format(_yearTotal)}', cs.primary, cs)),
                    const SizedBox(width: 8),
                    Expanded(child: _summaryCard('未回収', '¥${_nf.format(_unpaidTotal)}', cs.error, cs)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMonthlyBars(ColorScheme cs) {
    final months = List.generate(12, (i) => '${(i + 1).toString().padLeft(2, '0')}');
    final maxVal = _monthly.values.fold<int>(0, (a, b) => a > b ? a : b);
    return months.map((m) {
      final val = _monthly[m] ?? 0;
      final ratio = maxVal > 0 ? val / maxVal : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 30, child: Text('${int.parse(m)}月', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 16,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(val > 0 ? cs.primary : Colors.transparent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: Text('¥${_nf.format(val)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
          ],
        ),
      );
    }).toList();
  }
}
