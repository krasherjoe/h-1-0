import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'receipt_processing_screen.dart';

/// 売掛金管理（AR）: 顧客別未回収額・消し込み確認
class AccountsReceivableScreen extends StatefulWidget {
  const AccountsReceivableScreen({super.key});
  @override
  State<AccountsReceivableScreen> createState() => _AccountsReceivableScreenState();
}

class _AccountsReceivableScreenState extends State<AccountsReceivableScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final NumberFormat _nf = NumberFormat('#,###');
  final DateFormat _df = DateFormat('yyyy/MM/dd');

  bool _loading = true;
  List<Invoice> _unpaid = [];
  Map<String, int> _customerTotals = {};

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
      final unpaid = all.where((inv) =>
        inv.documentType == DocumentType.invoice &&
        inv.paymentStatus != PaymentStatus.paid
      ).toList()..sort((a, b) => a.date.compareTo(b.date));
      final totals = <String, int>{};
      for (final inv in unpaid) {
        final name = inv.customerNameForDisplay;
        totals[name] = (totals[name] ?? 0) + inv.remainingAmount;
      }
      setState(() {
        _unpaid = unpaid;
        _customerTotals = totals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showBadDebtAction(Invoice inv) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('貸倒処理'),
        content: Text('${inv.customerNameForDisplay}\n未回収額: ￥${_nf.format(inv.remainingAmount)}\n\nこの請求を貸倒処理（赤伝発行）しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'write_off'),
            child: Text('貸倒処理する', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (result != 'write_off') return;
    await _issueRedInvoice(inv);
  }

  Future<void> _issueRedInvoice(Invoice inv) async {
    try {
      // 赤伝を作成（数量を反転、合計をマイナスに）
      final redItems = inv.items.map((i) => i.negate()).toList();
      final red = Invoice(
        id: const Uuid().v4(),
        customer: inv.customer,
        date: DateTime.now(),
        items: redItems,
        taxRate: inv.taxRate,
        documentType: DocumentType.invoice,
        isDraft: false, isLocked: true,
        subject: '貸倒: ${inv.invoiceNumber}',
        sourceDocumentId: inv.id,
        paymentStatus: PaymentStatus.paid,
        receivedAmount: 0,
      );
      await _invoiceRepo.saveInvoice(red);

      // 元の請求書を貸倒済みに更新
      await _invoiceRepo.updatePaymentStatus(inv.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inv.customerNameForDisplay} を貸倒処理しました（赤伝発行済）')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('貸倒処理に失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR:売掛金管理'),
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
          : _unpaid.isEmpty
              ? const Center(child: Text('未回収の売掛金はありません'))
              : Column(
                  children: [
                    // 顧客別サマリー
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('未回収サマリー（${_customerTotals.length}社）',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
                          const SizedBox(height: 8),
                          ..._customerTotals.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                                Text('￥${_nf.format(e.value)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.error)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _unpaid.length,
                        itemBuilder: (_, i) {
                          final inv = _unpaid[i];
                          final days = DateTime.now().difference(inv.date).inDays;
                          final aging = days <= 30 ? '30日以内' : days <= 60 ? '60日以内' : '60日超';
                          final agingColor = days <= 30 ? Colors.orange : days <= 60 ? Colors.deepOrange : cs.error;
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onLongPress: () => _showBadDebtAction(inv),
                              child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(inv.customerNameForDisplay,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: agingColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                        child: Text(aging, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: agingColor)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(_df.format(inv.date), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                      const SizedBox(width: 8),
                                      Text(inv.invoiceNumber, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('未回収: ￥${_nf.format(inv.remainingAmount)}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.error)),
                                      const Spacer(),
                                      Text('請求: ￥${_nf.format(inv.totalAmount)}',
                                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
