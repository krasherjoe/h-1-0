import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/delivery_model.dart';
import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/delivery_repository.dart';
import '../services/pdf_generator.dart';
import '../services/stock_transaction_repository.dart';
import '../services/storage_monitor.dart';
import '../utils/theme_utils.dart';
import '../widgets/document_card.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import '../widgets/storage_warning_dialog.dart';
import '../models/customer_model.dart';
import 'invoice_detail_page.dart';
import 'invoice_input_screen.dart';

enum _DeliveryFilter { draft, confirmed }

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});
  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  final DeliveryRepository _deliveryRepo = DeliveryRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final NumberFormat _currencyFormatter = NumberFormat('#,###');
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  _DeliveryFilter _filter = _DeliveryFilter.draft;
  List<Delivery> _deliveries = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _deliveryRepo.getAll();
      if (!mounted) return;
      setState(() {
        _deliveries = list..sort((a, b) => b.date.compareTo(a.date));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データ読込失敗: $e')));
    }
  }

  List<Delivery> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    return _deliveries.where((d) {
      if (_filter == _DeliveryFilter.draft && d.status != DocumentStatus.draft) return false;
      if (_filter == _DeliveryFilter.confirmed && d.status == DocumentStatus.draft) return false;
      if (query.isNotEmpty) {
        final c = d.customer?.displayName.toLowerCase() ?? '';
        if (!c.contains(query) && !d.documentNumber.toLowerCase().contains(query)) return false;
      }
      if (_startDate != null && d.date.isBefore(_startDate!)) return false;
      if (_endDate != null && d.date.isAfter(_endDate!)) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() {
      if (isStart) { _startDate = picked; if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = _startDate; }
      else { _endDate = picked; if (_startDate != null && _startDate!.isAfter(_endDate!)) _startDate = _endDate; }
    });
  }

  void _clearFilters() {
    setState(() { _searchController.clear(); _startDate = null; _endDate = null; });
  }

  Future<void> _create() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoiceInputForm(
        onInvoiceGenerated: (inv, _) {
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: inv)));
        },
        initialDocumentType: DocumentType.delivery, startViewMode: false, showNewBadge: true,
      ),
    ));
    if (!mounted) return;
    await _load();
  }

  Future<void> _edit(Delivery delivery) async {
    final inv = Invoice(
      id: delivery.id, customer: delivery.customer ?? Customer(id: '_', displayName: '(不明)', formalName: '(不明)'), date: delivery.date,
      items: delivery.items.map((i) => InvoiceItem(description: i.productName, quantity: i.quantity, unitPrice: i.unitPrice)).toList(),
      documentType: DocumentType.delivery, isDraft: delivery.status == DocumentStatus.draft,
    );
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoiceInputForm(
        onInvoiceGenerated: (_, __) {},
        existingInvoice: inv, initialDocumentType: DocumentType.delivery, startViewMode: false,
      ),
    ));
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(Delivery delivery) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('削除確認'), content: Text('${delivery.customer?.displayName ?? ''} の配送記録を削除しますか？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ],
    ));
    if (confirmed != true) return;
    await _deliveryRepo.delete(delivery.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
    await _load();
  }

  Future<void> _confirm(Delivery delivery) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('確定しますか？'),
      content: Text('${delivery.customer?.displayName ?? ''}\nこの配送記録を確定すると編集できなくなります。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定する')),
      ],
    ));
    if (ok != true) return;
    // 配送はDeliveryRepository経由で確定
    final updated = Delivery(
      id: delivery.id, documentNumber: delivery.documentNumber, date: delivery.date,
      customer: delivery.customer, items: delivery.items,
      subtotal: delivery.subtotal, taxAmount: delivery.taxAmount, total: delivery.total,
      taxRate: delivery.taxRate, notes: delivery.notes, subject: delivery.subject,
      status: DocumentStatus.confirmed, createdAt: delivery.createdAt, updatedAt: DateTime.now(),
      deliveryAddress: delivery.deliveryAddress, deliveryNote: delivery.deliveryNote,
    );
    await _deliveryRepo.update(updated);
    // 配送確定時に在庫を自動出庫
    final stockRepo = StockTransactionRepository();
    for (final item in delivery.items) {
      if (item.productId.isNotEmpty && item.quantity > 0) {
        await stockRepo.outbound(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          type: 'delivery',
          referenceId: delivery.id,
          referenceNumber: delivery.documentNumber,
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('確定しました')));
    await _load();
  }

  Future<void> _openPreview(Delivery delivery) async {
    // PDFプレビューはInvoice経由で表示（DeliveryからInvoiceに変換）
    final inv = Invoice(
      id: delivery.id, customer: delivery.customer ?? Customer(id: '_', displayName: '(不明)', formalName: '(不明)'), date: delivery.date,
      items: delivery.items.map((i) => InvoiceItem(description: i.productName, quantity: i.quantity, unitPrice: i.unitPrice)).toList(),
      documentType: DocumentType.delivery, isDraft: delivery.status == DocumentStatus.draft,
    );
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoicePdfPreviewPage(invoice: inv, isUnlocked: true, isLocked: delivery.status != DocumentStatus.draft),
    ));
    if (!mounted) return;
    await _load();
  }

  Future<void> _showActions(Delivery delivery) async {
    await showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF'), onTap: () { Navigator.pop(context); _openPreview(delivery); }),
        if (delivery.status == DocumentStatus.draft) ...[
          ListTile(leading: const Icon(Icons.check_circle), title: const Text('確定'), onTap: () { Navigator.pop(context); _confirm(delivery); }),
          ListTile(leading: const Icon(Icons.edit), title: const Text('編集'), onTap: () { Navigator.pop(context); _edit(delivery); }),
        ],
        ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          title: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () { Navigator.pop(context); _delete(delivery); }),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = _visible;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('DL1:配送記録一覧'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create, icon: const Icon(Icons.add), label: const Text('新規配送'),
      ),
      body: SafeArea(
        child: _loading ? const Center(child: CircularProgressIndicator()) : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _searchController, onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '顧客名・伝票番号で検索', prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: cs.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_startDate == null ? '開始日' : DateFormat('yyyy/MM/dd').format(_startDate!), style: const TextStyle(fontSize: 11)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(_endDate == null ? '終了日' : DateFormat('yyyy/MM/dd').format(_endDate!), style: const TextStyle(fontSize: 11)))),
                  IconButton(tooltip: 'フィルタ解除',
                    onPressed: _searchController.text.isEmpty && _startDate == null && _endDate == null ? null : _clearFilters,
                    icon: const Icon(Icons.clear_all)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ToggleButtons(
                isSelected: _DeliveryFilter.values.map((f) => f == _filter).toList(),
                borderRadius: BorderRadius.circular(12),
                onPressed: (i) => setState(() => _filter = _DeliveryFilter.values[i]),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('下書き')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('確定済')),
                ],
              ),
            ),
            if (deliveries.isEmpty)
              Expanded(child: Center(child: Text(_filter == _DeliveryFilter.draft ? '下書き配送はありません' : '確定済み配送はありません')))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final d = deliveries[index];
                    final subject = d.subject?.trim().isNotEmpty == true
                        ? d.subject!
                        : (d.items.isNotEmpty ? d.items.first.productName : '');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _openPreview(d),
                        onLongPress: () => _showActions(d),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(d.customer?.displayName ?? '一般客',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
                                  const Spacer(),
                                  Text(_dateFormatter.format(d.date), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: cs.onSurface)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('￥${_currencyFormatter.format(d.total)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openPreview(d),
                                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                                    label: const Text('PDF', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  ),
                                  if (d.status == DocumentStatus.draft) ...[
                                    const SizedBox(width: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _confirm(d),
                                      icon: const Icon(Icons.check_circle, size: 16),
                                      label: const Text('確定', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (d.status == DocumentStatus.draft)
                                    TextButton.icon(
                                      onPressed: () => _edit(d),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('編集', style: TextStyle(fontSize: 11)),
                                    ),
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
      ),
    );
  }
}
