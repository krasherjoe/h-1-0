import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../services/google_calendar_service.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'receipt_processing_screen.dart';

/// 入金伝票一覧（販売管理用）
class PaymentSlipListScreen extends StatefulWidget {
  const PaymentSlipListScreen({super.key});
  @override
  State<PaymentSlipListScreen> createState() => _PaymentSlipListScreenState();
}

class _PaymentSlipListScreenState extends State<PaymentSlipListScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final NumberFormat _nf = NumberFormat('#,###');
  final DateFormat _df = DateFormat('yyyy/MM/dd');

  List<Invoice> _paid = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final customers = await _customerRepo.getAllCustomers();
      final all = await _invoiceRepo.getAllInvoices(customers);
      if (!mounted) return;
      setState(() {
        _paid = all.where((inv) =>
          inv.documentType == DocumentType.invoice &&
          inv.paymentStatus != PaymentStatus.unpaid
        ).toList()..sort((a, b) => b.date.compareTo(a.date));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showCalendarAction(Invoice inv) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.event_busy),
            title: const Text('カレンダーイベント削除'),
            subtitle: Text('${inv.customerNameForDisplay} の入金カレンダーイベントを削除'),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await GoogleCalendarService().deletePaymentEvent(inv.invoiceNumber);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'カレンダーイベントを削除しました' : 'イベントが見つかりませんでした')),
              );
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RP:入金伝票一覧'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptProcessingScreen()));
              if (!mounted) return;
              await _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('入金登録'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _paid.isEmpty
              ? const Center(child: Text('入金データがありません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _paid.length,
                  itemBuilder: (_, i) {
                    final inv = _paid[i];
                    final isPartial = inv.paymentStatus == PaymentStatus.partial;
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onLongPress: () => _showCalendarAction(inv),
                        child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(inv.customerNameForDisplay,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
                                const Spacer(),
                                Text(_df.format(inv.date), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('￥${_nf.format(inv.receivedAmount)} 入金済',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.primary)),
                                const Spacer(),
                                if (isPartial)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                    child: Text('一部入金', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                    child: Text('完了', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${inv.invoiceNumber}  残高: ￥${_nf.format(inv.remainingAmount)}',
                                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    );
                  },
                ),
    );
  }
}
