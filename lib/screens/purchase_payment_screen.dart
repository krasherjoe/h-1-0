import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase_order_models.dart';
import '../models/supplier_model.dart';
import '../services/purchase_order_service.dart';
import '../services/purchase_payment_service.dart';
import '../services/supplier_repository.dart';
import '../widgets/screen_id_title.dart';
import 'supplier_picker_modal.dart';

class PurchasePaymentListScreen extends StatefulWidget {
  const PurchasePaymentListScreen({super.key});

  @override
  State<PurchasePaymentListScreen> createState() => _PurchasePaymentListScreenState();
}

class _PurchasePaymentListScreenState extends State<PurchasePaymentListScreen> {
  final PurchasePaymentService _service = PurchasePaymentService();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final PurchaseOrderService _orderService = PurchaseOrderService();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  bool _isLoading = true;
  List<PurchasePayment> _payments = const [];
  PurchasePaymentStatus? _filterStatus;
  final Map<String, String> _supplierNames = {};
  final Map<String, String> _orderNumbers = {};
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    final payments = await _service.fetchPayments(status: _filterStatus);
    final supplierIds = payments.map((p) => p.supplierId).whereType<String>().toSet();
    for (final id in supplierIds) {
      if (_supplierNames.containsKey(id)) continue;
      final supplier = await _supplierRepository.findById(id);
      if (supplier != null) {
        _supplierNames[id] = supplier.name;
      }
    }
    final orderIds = payments.map((p) => p.purchaseOrderId).whereType<String>().toSet();
    for (final id in orderIds) {
      if (_orderNumbers.containsKey(id)) continue;
      final order = await _orderService.findById(id);
      if (order != null) {
        _orderNumbers[id] = order.documentNumber;
      }
    }
    if (!mounted) return;
    setState(() {
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _openEditor({PurchasePayment? payment}) async {
    final result = await Navigator.of(context).push<PurchasePayment>(
      MaterialPageRoute(builder: (_) => PurchasePaymentEditorPage(payment: payment)),
    );
    if (result != null) {
      await _loadPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('支払 ${_dateFormat.format(result.paymentDate)} を保存しました')));
    }
  }

  Future<void> _confirmBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('一括削除'),
        content: Text('${_selectedIds.length}件の支払データを削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = _selectedIds.toList();
    for (final id in ids) {
      await _service.deletePayment(id);
    }
    if (!mounted) return;
    setState(() { _selectMode = false; _selectedIds.clear(); });
    await _loadPayments();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length}件削除しました')));
  }

  Future<void> _confirmDelete(PurchasePayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('支払を削除'),
        content: Text('${_dateFormat.format(payment.paymentDate)} の支払を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deletePayment(payment.id);
    if (!mounted) return;
    await _loadPayments();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
  }

  Color _statusColor(ColorScheme cs, PurchasePaymentStatus status) {
    switch (status) {
      case PurchasePaymentStatus.scheduled:
        return cs.secondary;
      case PurchasePaymentStatus.paid:
        return cs.primary;
      case PurchasePaymentStatus.cancelled:
        return cs.error;
    }
  }

  String _supplierLabel(PurchasePayment payment) {
    if (payment.supplierId == null) {
      return '仕入先未設定';
    }
    return _supplierNames[payment.supplierId] ?? '仕入先読込中';
  }

  String _orderLabel(PurchasePayment payment) {
    if (payment.purchaseOrderId == null) {
      return '発注連携なし';
    }
    return _orderNumbers[payment.purchaseOrderId] ?? '発注読込中';
  }

  @override
  Widget build(BuildContext context) {
    final actions = _selectMode
        ? <Widget>[
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: '選択を削除',
                onPressed: _confirmBatchDelete,
              ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '選択解除',
              onPressed: () => setState(() { _selectMode = false; _selectedIds.clear(); }),
            ),
          ]
        : <Widget>[
            PopupMenuButton<PurchasePaymentStatus?>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                setState(() => _filterStatus = value);
                _loadPayments();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: null, child: Text('すべて表示')),
                ...PurchasePaymentStatus.values.map(
                  (status) => PopupMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8), color: _statusColor(Theme.of(context).colorScheme, status)),
                        Text(status.displayName),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ];

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _payments.isEmpty
            ? const Center(child: Text('支払データがありません。右下のボタンから登録してください。'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _payments.length,
                itemBuilder: (context, index) => _buildPaymentCard(_payments[index]),
              );

    return Scaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: Text('$_selectedCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {},
              )
            : const BackButton(),
        title: Text(_selectMode ? '${_selectedIds.length}件選択' : 'PS:支払予定管理'),
        actions: actions,
      ),
      body: RefreshIndicator(onRefresh: _loadPayments, child: body),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('支払を登録'),
            ),
    );
  }

  int get _selectedCount => _selectedIds.length;

  Widget _buildPaymentCard(PurchasePayment payment) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs, payment.status);
    final checked = _selectedIds.contains(payment.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: _selectMode
            ? () => setState(() { if (checked) _selectedIds.remove(payment.id); else _selectedIds.add(payment.id); })
            : () => _openEditor(payment: payment),
        onLongPress: () {
          if (!_selectMode) setState(() { _selectMode = true; _selectedIds.add(payment.id); });
        },
        leading: _selectMode ? Checkbox(value: checked, onChanged: (_) {
          setState(() { if (checked) _selectedIds.remove(payment.id); else _selectedIds.add(payment.id); });
        }) : null,
        title: Text('${_currencyFormat.format(payment.amount)} / ${payment.method ?? '支払方法未設定'}'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('支払日: ${_dateFormat.format(payment.paymentDate)}'),
              const SizedBox(height: 4),
              Text(_supplierLabel(payment)),
              const SizedBox(height: 4),
              Text(_orderLabel(payment)),
            ],
          ),
        ),
        trailing: _selectMode ? null : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(payment.status.displayName, style: TextStyle(color: statusColor)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (v) {
                if (v == 'delete') _confirmDelete(payment);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16), SizedBox(width: 8), Text('削除')])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PurchasePaymentEditorPage extends StatefulWidget {
  const PurchasePaymentEditorPage({super.key, this.payment});

  final PurchasePayment? payment;

  @override
  State<PurchasePaymentEditorPage> createState() => _PurchasePaymentEditorPageState();
}

class _PurchasePaymentEditorPageState extends State<PurchasePaymentEditorPage> {
  final PurchasePaymentService _service = PurchasePaymentService();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final PurchaseOrderService _orderService = PurchaseOrderService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  final Uuid _uuid = const Uuid();

  DateTime _paymentDate = DateTime.now();
  PurchasePaymentStatus _status = PurchasePaymentStatus.scheduled;
  String? _supplierId;
  String? _supplierName;
  String? _purchaseOrderId;
  String? _purchaseOrderNumber;
  String? _method = '銀行振込';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    if (payment != null) {
      _paymentDate = payment.paymentDate;
      _status = payment.status;
      _supplierId = payment.supplierId;
      _purchaseOrderId = payment.purchaseOrderId;
      _method = payment.method ?? _method;
      _amountController.text = payment.amount.toString();
      _notesController.text = payment.notes ?? '';
      _loadSupplierName(payment.supplierId);
      _loadOrderNumber(payment.purchaseOrderId);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplierName(String? supplierId) async {
    if (supplierId == null) return;
    final supplier = await _supplierRepository.findById(supplierId);
    if (!mounted) return;
    setState(() => _supplierName = supplier?.name ?? '仕入先不明');
  }

  Future<void> _loadOrderNumber(String? orderId) async {
    if (orderId == null) return;
    final order = await _orderService.findById(orderId);
    if (!mounted) return;
    setState(() => _purchaseOrderNumber = order?.documentNumber ?? '発注不明');
  }

  Future<void> _pickSupplier() async {
    final selected = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SupplierPickerModal(onSupplierSelected: (value) => Navigator.pop(ctx, value)),
    );
    if (selected == null) return;
    setState(() {
      _supplierId = selected.id;
      _supplierName = selected.name;
    });
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _pickOrder() async {
    final orders = await _orderService.fetchOrders(limit: 100);
    if (!mounted) return;
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('発注データがありません')));
      return;
    }
    final selected = await showModalBottomSheet<PurchaseOrder>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PurchaseOrderPickerSheet(orders: orders, dateFormat: _dateFormat),
    );
    if (selected == null) return;
    setState(() {
      _purchaseOrderId = selected.id;
      _purchaseOrderNumber = selected.documentNumber;
    });
  }

  void _clearOrderLink() {
    setState(() {
      _purchaseOrderId = null;
      _purchaseOrderNumber = null;
    });
  }

  int get _amountValue => int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (_isSaving) return;
    final amount = _amountValue;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支払額を入力してください')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final paymentId = widget.payment?.id ?? _uuid.v4();
      final now = DateTime.now();
      final payment = PurchasePayment(
        id: paymentId,
        purchaseOrderId: _purchaseOrderId,
        supplierId: _supplierId,
        paymentDate: _paymentDate,
        amount: amount,
        method: _method,
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.payment?.createdAt ?? now,
        updatedAt: now,
      );
      final saved = await _service.savePayment(payment);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountFormatted = _amountValue > 0 ? _currencyFormat.format(_amountValue) : '未入力';
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: ScreenAppBarTitle(
          screenId: 'PS',
          title: widget.payment == null ? '支払登録' : '支払編集',
        ),
        actions: [
          IconButton(onPressed: _isSaving ? null : _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(_supplierName ?? '仕入先を選択'),
                subtitle: const Text('タップして仕入先を選択'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickSupplier,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('発注と連携'),
                subtitle: Text(_purchaseOrderNumber ?? '未連携'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (_purchaseOrderId != null)
                      IconButton(onPressed: _clearOrderLink, icon: const Icon(Icons.clear, size: 20)),
                    TextButton(onPressed: _pickOrder, child: const Text('選択')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('支払日'),
                subtitle: Text(_dateFormat.format(_paymentDate)),
                trailing: TextButton(onPressed: _pickPaymentDate, child: const Text('変更')),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '支払額 (円)',
                helperText: '現在値: $amountFormatted',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: '支払方法'),
              items: const [
                DropdownMenuItem(value: '銀行振込', child: Text('銀行振込')),
                DropdownMenuItem(value: '現金', child: Text('現金')),
                DropdownMenuItem(value: '振替', child: Text('口座振替')),
                DropdownMenuItem(value: 'カード', child: Text('カード払い')),
                DropdownMenuItem(value: 'その他', child: Text('その他')),
              ],
              onChanged: (value) => setState(() => _method = value),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('ステータス'),
                trailing: DropdownButton<PurchasePaymentStatus>(
                  value: _status,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                  items: PurchasePaymentStatus.values
                      .map((status) => DropdownMenuItem(value: status, child: Text(status.displayName)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'メモ (任意)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseOrderPickerSheet extends StatelessWidget {
  const _PurchaseOrderPickerSheet({required this.orders, required this.dateFormat});

  final List<PurchaseOrder> orders;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 50, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
          const Text('発注を選択', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  title: Text(order.documentNumber),
                  subtitle: Text(dateFormat.format(order.orderDate)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, order),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
