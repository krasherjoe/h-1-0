import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../models/subscription_model.dart';
import '../services/subscription_repository.dart';
import 'customer_master_screen.dart';

class SubscriptionListScreen extends StatefulWidget {
  const SubscriptionListScreen({super.key});
  @override
  State<SubscriptionListScreen> createState() => _SubscriptionListScreenState();
}

class _SubscriptionListScreenState extends State<SubscriptionListScreen> {
  final _repo = SubscriptionRepository();
  final _nf = NumberFormat('#,###');
  final _df = DateFormat('yyyy/MM/dd');

  String _cycleLabel(String c) {
    switch (c) {
      case 'monthly': return '月';
      case 'quarterly': return '3ヶ月';
      case 'half_yearly': return '6ヶ月';
      case 'yearly': return '年';
      default: return '${c}日';
    }
  }

  List<Subscription> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAll();
    if (!mounted) return;
    setState(() { _list = list; _loading = false; });
  }

  Future<void> _create() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerMasterScreen(selectionMode: true)),
    );
    if (customer == null) return;

    final amountCtrl = TextEditingController();
  int totalCycles = 12;
  int customDays = 45;
  String cycle = 'monthly';
  DateTime startDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          title: const Text('定期請求設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('顧客: ${customer.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '1回あたり金額', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: cycle, decoration: const InputDecoration(labelText: 'サイクル', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('毎月')),
                    DropdownMenuItem(value: 'quarterly', child: Text('3ヶ月')),
                    DropdownMenuItem(value: 'half_yearly', child: Text('6ヶ月')),
                    DropdownMenuItem(value: 'yearly', child: Text('毎年')),
                    DropdownMenuItem(value: 'custom', child: Text('カスタム')),
                  ],
                  onChanged: (v) => setSheet(() => cycle = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: '総回数（0=無制限）', isDense: true, border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => totalCycles = int.tryParse(v) ?? 0,
                  controller: TextEditingController(text: totalCycles.toString()),
                ),
                if (cycle == 'custom') ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'サイクル日数', isDense: true, border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => customDays = int.tryParse(v) ?? 45,
                    controller: TextEditingController(text: customDays.toString()),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => startDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('開始日: ${_df.format(startDate)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (result != true) return;

    final amount = int.tryParse(amountCtrl.text);
    if (amount == null || amount <= 0) return;

    final cycleDays = switch (cycle) {
      'monthly' => 30,
      'quarterly' => 90,
      'half_yearly' => 180,
      'yearly' => 365,
      _ => customDays,
    };

    final now = DateTime.now();
    await _repo.save(Subscription(
      id: const Uuid().v4(),
      customerId: customer.id,
      customerName: customer.displayName,
      amount: amount,
      cycle: cycle,
      cycleDays: cycleDays,
      totalCycles: totalCycles,
      startDate: startDate,
      nextBillingDate: startDate,
      createdAt: now, updatedAt: now,
    ));
    await _load();
  }

  Future<void> _batchGenerate() async {
    final now = DateTime.now();
    final due = _list.where((s) =>
      s.isActive &&
      s.nextBillingDate != null &&
      !s.nextBillingDate!.isAfter(now) &&
      (s.totalCycles == 0 || s.completedCycles < s.totalCycles)
    ).toList();

    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成期限の定期請求はありません')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('一括生成'),
        content: Text('${due.length}件の定期請求の請求書を生成しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成')),
        ],
      ),
    );
    if (confirmed != true) return;

    var ok = 0, ng = 0;
    for (final s in due) {
      try {
        await _repo.generateInvoice(s);
        ok++;
      } catch (_) { ng++; }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ok}件生成${ng > 0 ? "（${ng}件失敗）" : ""}')),
    );
    await _load();
  }

  Future<void> _generateInvoice(Subscription sub) async {
    try {
      final invoice = await _repo.generateInvoice(sub);
      if (invoice != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('請求書を生成しました: ${invoice.invoiceNumber}')),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('請求書生成失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('定期請求管理')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'batch_gen',
            onPressed: _batchGenerate,
            icon: const Icon(Icons.receipt_long, size: 20),
            label: const Text('一括生成', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new_sub',
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('新規定期'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('定期請求がありません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final s = _list[i];
                    final remaining = s.totalCycles > 0 ? s.totalCycles - s.completedCycles : -1;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(s.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: s.isActive ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(s.isActive ? '有効' : '停止', style: TextStyle(fontSize: 10, color: s.isActive ? Colors.green.shade700 : Colors.grey)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('¥${_nf.format(s.amount)} / ${_cycleLabel(s.cycle)}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
                                const Spacer(),
                                Text('${s.completedCycles}回完了${remaining >= 0 ? " / 残$remaining回" : ""}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              ],
                            ),
                            if (s.nextBillingDate != null) ...[
                              const SizedBox(height: 4),
                              Text('次回請求: ${_df.format(s.nextBillingDate!)}',
                                  style: TextStyle(fontSize: 11, color: cs.primary)),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.receipt, size: 16),
                                  label: const Text('請求書生成', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _generateInvoice(s),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
