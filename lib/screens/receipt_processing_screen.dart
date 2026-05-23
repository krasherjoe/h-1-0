import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../services/database_helper.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../utils/theme_utils.dart';

class ReceiptProcessingScreen extends StatefulWidget {
  const ReceiptProcessingScreen({super.key, this.initialInvoice});
  final Invoice? initialInvoice;
  @override
  State<ReceiptProcessingScreen> createState() => _ReceiptProcessingScreenState();
}

class _ReceiptProcessingScreenState extends State<ReceiptProcessingScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final NumberFormat _nf = NumberFormat('#,###');
  final DateFormat _df = DateFormat('yyyy/MM/dd');

  List<Invoice> _invoices = [];
  bool _loading = true;

  // 入金登録フォーム
  Invoice? _selected;
  final _amountCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = '振込';
  bool _saving = false;

  static const _methods = ['現金', '振込', 'クレジットカード', '手形', 'その他'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final customers = await _customerRepo.getAllCustomers();
      final all = await _invoiceRepo.getAllInvoices(customers);
      if (!mounted) return;
      final unpaid = all.where((inv) =>
        inv.documentType == DocumentType.invoice &&
        !inv.isDraft &&
        inv.paymentStatus != PaymentStatus.paid
      ).toList()..sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _invoices = unpaid;
        _loading = false;
      });
      if (widget.initialInvoice != null && unpaid.any((i) => i.id == widget.initialInvoice!.id)) {
        _select(unpaid.firstWhere((i) => i.id == widget.initialInvoice!.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('読込失敗: $e')));
    }
  }

  void _select(Invoice inv) {
    setState(() {
      _selected = inv;
      _amountCtrl.text = inv.remainingAmount.toString();
    });
  }

  Future<void> _register() async {
    if (_selected == null) return;
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[,\s]'), ''));
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      final inv = _selected!;
      final newReceived = inv.receivedAmount + amount;
      final newStatus = newReceived >= inv.totalAmount ? PaymentStatus.paid : PaymentStatus.partial;

      // receiptsテーブルに入金レコードを追加 → updatePaymentStatusで再計算
      final db = await DatabaseHelper().database;
      await db.insert('receipts', {
        'id': const Uuid().v4(),
        'invoice_id': inv.id,
        'amount': amount,
        'receipt_date': _paymentDate.toIso8601String(),
        'payment_method': _paymentMethod,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _invoiceRepo.updatePaymentStatus(inv.id);

      // 領収証（receipt）を元の請求書と同一内容で生成
      final slip = Invoice(
        id: const Uuid().v4(),
        customer: inv.customer,
        date: _paymentDate,
        items: inv.items.map((i) => i.copyWith()).toList(),
        taxRate: inv.taxRate,
        documentType: DocumentType.receipt,
        isDraft: false, isLocked: true,
        subject: '領収: ${inv.invoiceNumber} (${_paymentMethod})',
        paymentStatus: PaymentStatus.paid,
        receivedAmount: amount,
      );
      await _invoiceRepo.saveInvoice(slip);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inv.customerNameForDisplay} から ${_nf.format(amount)} の入金を登録しました')),
      );
      setState(() { _selected = null; _amountCtrl.clear(); });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登録失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('RP:入金処理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('未入金の請求書はありません'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _invoices.length,
                        itemBuilder: (_, i) {
                          final inv = _invoices[i];
                          final selected = _selected?.id == inv.id;
                          final statusColor = inv.paymentStatus == PaymentStatus.partial
                              ? Colors.orange
                              : cs.error;
                          return Card(
                            color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
                            child: InkWell(
                              onTap: () => _select(inv),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(inv.customerNameForDisplay,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text('${_df.format(inv.date)} ${inv.invoiceNumber}',
                                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                          Text('残高: ${_nf.format(inv.remainingAmount)} / ${_nf.format(inv.totalAmount)}',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                        ],
                                      ),
                                    ),
                                    Text(inv.paymentStatusDisplay, style: TextStyle(fontSize: 11, color: statusColor)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_selected != null) _buildPaymentForm(cs),
                  ],
                ),
    );
  }

  Widget _buildPaymentForm(ColorScheme cs) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('入金登録: ${_selected!.customerNameForDisplay}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '入金額', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context,
                      initialDate: _paymentDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _paymentDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_df.format(_paymentDate), style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _paymentMethod, underline: const SizedBox(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
                items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _register,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(_saving ? '登録中...' : '入金登録する'),
            ),
          ),
        ],
      ),
    );
  }
}
