import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/invoice_repository.dart';
import '../services/pdf_generator.dart';
import '../services/stock_allocation_repository.dart';
import '../services/storage_monitor.dart';
import '../utils/theme_utils.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import '../widgets/storage_warning_dialog.dart';
import 'invoice_detail_page.dart';
import 'invoice_input_screen.dart';

enum _OrderFilter { draft, confirmed }

class OrderInputScreen extends StatefulWidget {
  const OrderInputScreen({super.key});
  @override
  State<OrderInputScreen> createState() => _OrderInputScreenState();
}

class _OrderInputScreenState extends State<OrderInputScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final NumberFormat _currencyFormatter = NumberFormat('#,###');
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');
  final Map<String, bool> _confirming = {};
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  _OrderFilter _filter = _OrderFilter.draft;
  List<Invoice> _orders = [];
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
      final customers = await _customerRepo.getAllCustomers();
      final invoices = await _invoiceRepo.getAllInvoices(customers);
      if (!mounted) return;
      setState(() {
        _orders = invoices.where((inv) => inv.documentType == DocumentType.order).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('受注データの読込に失敗: $e')));
    }
  }

  List<Invoice> get _visibleOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders.where((o) {
      if (_filter == _OrderFilter.draft && !o.isDraft) return false;
      if (_filter == _OrderFilter.confirmed && o.isDraft) return false;
      if (query.isNotEmpty) {
        if (!o.invoiceNumber.toLowerCase().contains(query) &&
            !o.customerNameForDisplay.toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_startDate != null && o.date.isBefore(_startDate!)) return false;
      if (_endDate != null && o.date.isAfter(_endDate!)) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) { _startDate = picked; if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = _startDate; }
      else { _endDate = picked; if (_startDate != null && _startDate!.isAfter(_endDate!)) _startDate = _endDate; }
    });
  }

  void _clearFilters() {
    setState(() { _searchController.clear(); _startDate = null; _endDate = null; });
  }

  Future<void> _createOrder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (inv, _) {
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: inv)));
          },
          initialDocumentType: DocumentType.order,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _createFromEstimate() async {
    final customers = await _customerRepo.getAllCustomers();
    final invoices = await _invoiceRepo.getAllInvoices(customers);
    if (!mounted) return;
    final estimates = invoices.where((inv) => inv.documentType == DocumentType.estimation && inv.isDraft).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (estimates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下書き見積がありません')));
      return;
    }
    final selected = await showDialog<Invoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('見積を選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: estimates.length,
            itemBuilder: (_, i) {
              final e = estimates[i];
              return ListTile(
                title: Text(e.customerNameForDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${_dateFormatter.format(e.date)} ￥${_currencyFormatter.format(e.totalAmount)}'),
                dense: true,
                onTap: () => Navigator.pop(ctx, e),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル'))],
      ),
    );
    if (selected == null) return;
    final newOrder = selected.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentType: DocumentType.order,
      isDraft: true, isLocked: false, date: DateTime.now(),
      filePath: null, metaJson: null, metaHash: null,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (_, __) {},
          existingInvoice: newOrder, startViewMode: false, showCopyBadge: true,
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('見積から受注を作成しました。内容を確認して保存してください')));
    await _load();
  }

  Future<void> _editOrder(Invoice order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (inv, _) {
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: inv)));
          },
          existingInvoice: order,
          initialDocumentType: DocumentType.order,
          startViewMode: false,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _deleteOrder(Invoice order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('${order.customerNameForDisplay} の受注を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _invoiceRepo.deleteInvoice(order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
    await _load();
  }

  Future<void> _openPreview(Invoice order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfPreviewPage(
          invoice: order, isUnlocked: true, isLocked: order.isLocked,
          allowFormalIssue: order.isDraft && !order.isLocked,
          onFormalIssue: () async {
            final ok = await _confirmDialog(order);
            if (!ok) return false;
            await _confirmOrder(order);
            return true;
          },
          showShare: true, showEmail: true, showPrint: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<bool> _confirmDialog(Invoice order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確定しますか？'),
        content: Text('${order.customerNameForDisplay}\nこの受注を確定すると編集できなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定する')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmOrder(Invoice order) async {
    if (order.isLocked || !order.isDraft) return;
    setState(() => _confirming[order.id] = true);
    try {
      final confirmed = order.copyWith(isDraft: false, isLocked: true);
      await _invoiceRepo.saveInvoice(confirmed);
      // 確定時に在庫引当を作成
      final allocRepo = StockAllocationRepository();
      for (final item in confirmed.items) {
        if (item.productId != null && item.quantity > 0) {
          await allocRepo.allocateForOrder(confirmed.id, item.productId!, item.quantity);
        }
      }
      final pdfPath = await generateInvoicePdf(confirmed);
      if (pdfPath != null) await _invoiceRepo.saveInvoice(confirmed.copyWith(filePath: pdfPath));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('受注を確定しました')));
      await _load();
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('ストレージ容量不足')) {
          final space = await StorageMonitor().getAvailableSpaceFormatted();
          await StorageWarningDialog.showBlocking(context, space);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('確定に失敗: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _confirming.remove(order.id));
    }
  }

  Future<void> _handleConfirm(Invoice order) async {
    final ok = await _confirmDialog(order);
    if (!ok) return;
    await _confirmOrder(order);
  }

  Future<void> _showOrderActions(Invoice order) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDFプレビュー'), onTap: () { Navigator.pop(context); _openPreview(order); }),
            if (order.isDraft && !order.isLocked)
              ListTile(leading: const Icon(Icons.check_circle), title: const Text('確定'), onTap: () { Navigator.pop(context); _handleConfirm(order); }),
            if (!order.isLocked)
              ListTile(leading: const Icon(Icons.edit), title: const Text('編集'), onTap: () { Navigator.pop(context); _editOrder(order); }),
            if (!order.isLocked)
              ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () { Navigator.pop(context); _deleteOrder(order); }),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('請求書に変換'),
              onTap: () { Navigator.pop(context); _convertToInvoice(order); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertToInvoice(Invoice order) async {
    final newInv = order.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentType: DocumentType.invoice,
      isDraft: true, isLocked: false, date: DateTime.now(),
      filePath: null, metaJson: null, metaHash: null,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (_, __) {},
          existingInvoice: newInv, startViewMode: false, showCopyBadge: true,
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請求書に変換しました。内容を確認して保存してください')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _visibleOrders;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docColor = documentTypeColor(DocumentType.order, cs, isDark);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: docColor,
        foregroundColor: appBarForeground(docColor),
        title: const Text('OR:受注入力'),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create_from_estimate',
            onPressed: _createFromEstimate,
            icon: const Icon(Icons.copy, size: 20),
            label: const Text('見積から', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_order',
            onPressed: _createOrder,
            icon: const Icon(Icons.add),
            label: const Text('新規受注'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '顧客名・伝票番号で検索',
                        prefixIcon: const Icon(Icons.search),
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
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(_startDate == null ? '開始日' : DateFormat('yyyy/MM/dd').format(_startDate!), style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(_endDate == null ? '終了日' : DateFormat('yyyy/MM/dd').format(_endDate!), style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        IconButton(
                          tooltip: 'フィルタ解除',
                          onPressed: _searchController.text.isEmpty && _startDate == null && _endDate == null ? null : _clearFilters,
                          icon: const Icon(Icons.clear_all),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ToggleButtons(
                      isSelected: _OrderFilter.values.map((f) => f == _filter).toList(),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: (i) => setState(() => _filter = _OrderFilter.values[i]),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('下書き')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('確定済')),
                      ],
                    ),
                  ),
                  if (orders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(_filter == _OrderFilter.draft ? '下書き受注はありません' : '確定済み受注はありません'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final confirming = _confirming[order.id] ?? false;
                          final subject = order.subject?.trim().isNotEmpty == true
                              ? order.subject!
                              : (order.items.isNotEmpty ? order.items.first.description : '');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => _openPreview(order),
                              onLongPress: () => _showOrderActions(order),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(order.customerNameForDisplay,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
                                        const Spacer(),
                                        Text(_dateFormatter.format(order.date),
                                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
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
                                        Text('￥${_currencyFormatter.format(order.totalAmount)}',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _openPreview(order),
                                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                                          label: const Text('PDF', style: TextStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                        ),
                                        if (order.isDraft && !order.isLocked) ...[
                                          const SizedBox(width: 8),
                                          FilledButton.tonalIcon(
                                            onPressed: confirming ? null : () => _handleConfirm(order),
                                            icon: confirming
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Icon(Icons.check_circle, size: 16),
                                            label: Text(confirming ? '確定中...' : '確定', style: const TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                        const Spacer(),
                                        if (!order.isLocked)
                                          TextButton.icon(
                                            onPressed: () => _editOrder(order),
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
