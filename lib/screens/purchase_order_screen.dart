import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase_order_models.dart';
import '../models/supplier_model.dart';
import '../services/purchase_order_service.dart';
import '../services/supplier_repository.dart';
import '../widgets/line_item_editor.dart';
import '../widgets/paste_buffer_dialog.dart';
import '../widgets/screen_id_title.dart';
import '../models/product_model.dart';
import 'product_master_screen.dart';
import 'supplier_picker_modal.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final PurchaseOrderService _service = PurchaseOrderService();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  bool _isLoading = true;
  List<PurchaseOrder> _orders = const [];
  PurchaseOrderStatus? _filterStatus;
  final Map<String, String> _supplierNames = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _service.fetchOrders(status: _filterStatus);
      final supplierIds = orders.map((o) => o.supplierId).whereType<String>().toSet();
      for (final id in supplierIds) {
        if (_supplierNames.containsKey(id)) continue;
        final supplier = await _supplierRepository.findById(id);
        if (supplier != null) {
          _supplierNames[id] = supplier.name;
        }
      }
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データ取得に失敗: $e'), duration: const Duration(seconds: 5)),
      );
    }
  }

  Future<void> _openEditor({PurchaseOrder? order}) async {
    final result = await Navigator.of(context).push<PurchaseOrder>(
      MaterialPageRoute(builder: (_) => PurchaseOrderEditorPage(order: order)),
    );
    if (result != null) {
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('発注 ${result.documentNumber} を保存しました')),
      );
    }
  }

  Future<void> _confirmDelete(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('発注を削除'),
        content: Text('${order.documentNumber} を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteOrder(order.id);
    if (!mounted) return;
    await _loadOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
  }

  Color _statusColor(ColorScheme cs, PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return cs.secondary;
      case PurchaseOrderStatus.approved:
        return cs.onSurfaceVariant;
      case PurchaseOrderStatus.partiallyReceived:
        return cs.primary;
      case PurchaseOrderStatus.received:
        return cs.primaryContainer;
      case PurchaseOrderStatus.cancelled:
        return cs.error;
    }
  }

  String _supplierLabel(PurchaseOrder order) {
    if (order.supplierSnapshot?.isNotEmpty == true) {
      return order.supplierSnapshot!;
    }
    if (order.supplierId == null) {
      return '仕入先未設定';
    }
    return _supplierNames[order.supplierId] ?? '仕入先読込中';
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      PopupMenuButton<PurchaseOrderStatus?>(
        icon: const Icon(Icons.filter_list),
        onSelected: (value) {
          setState(() => _filterStatus = value);
          _loadOrders();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text('すべて表示')),
          ...PurchaseOrderStatus.values.map(
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
        : _orders.isEmpty
            ? const Center(child: Text('発注データがありません。右下のボタンから登録してください。'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _orders.length,
                itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
              );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const ScreenAppBarTitle(screenId: 'PO', title: '発注管理'),
        actions: actions,
      ),
      body: RefreshIndicator(onRefresh: _loadOrders, child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('発注を作成'),
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs, order.status);
    final supplier = _supplierLabel(order);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _openEditor(order: order),
        onLongPress: () => _confirmDelete(order),
        title: Text(order.documentNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('発注日: ${_dateFormat.format(order.orderDate)}'),
              if (order.expectedDate != null) Text('入荷予定: ${_dateFormat.format(order.expectedDate!)}'),
              const SizedBox(height: 4),
              Text(supplier),
              const SizedBox(height: 4),
              Text('金額: ${_currencyFormat.format(order.total)}'),
            ],
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(order.status.displayName, style: TextStyle(color: statusColor)),
            ),
            const SizedBox(height: 8),
            Text(_supplierNames[order.supplierId ?? ''] ?? ''),
          ],
        ),
      ),
    );
  }
}
class PurchaseOrderEditorPage extends StatefulWidget {
  const PurchaseOrderEditorPage({super.key, this.order});

  final PurchaseOrder? order;

  @override
  State<PurchaseOrderEditorPage> createState() => _PurchaseOrderEditorPageState();
}

class _PurchaseOrderEditorPageState extends State<PurchaseOrderEditorPage> {
  final PurchaseOrderService _service = PurchaseOrderService();
  final TextEditingController _notesController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  final Uuid _uuid = const Uuid();

  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDate;
  PurchaseOrderStatus _status = PurchaseOrderStatus.draft;
  String? _supplierId;
  String? _supplierName;
  bool _isSaving = false;

  final List<LineItemFormData> _lines = [];

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    if (order != null) {
      _orderDate = order.orderDate;
      _expectedDate = order.expectedDate;
      _status = order.status;
      _supplierId = order.supplierId;
      _supplierName = order.supplierSnapshot;
      _notesController.text = order.notes ?? '';
      for (final item in order.items) {
        final data = LineItemFormData(
          id: item.id,
          productId: item.productId,
          productName: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          taxRate: item.taxRate,
          isTaxInclusive: item.isTaxInclusive,
        );
        _registerLine(data);
      }
    }
    if (_lines.isEmpty) {
      _registerLine(LineItemFormData(quantity: 1, unitPrice: 0, taxRate: 0.1));
    }
  }

  void _registerLine(LineItemFormData data) {
    data.taxRate ??= 0.1;
    data.registerChangeListener(_handleLineChanged);
    _lines.add(data);
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.removeChangeListener(_handleLineChanged);
      line.dispose();
    }
    super.dispose();
  }

  void _handleLineChanged() {
    setState(() {});
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

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _orderDate = picked);
    }
  }

  Future<void> _pickExpectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? _orderDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  void _addLine() {
    setState(() {
      _registerLine(LineItemFormData(quantity: 1, unitPrice: 0, taxRate: 0.1));
    });
  }

  void _removeLine(int index) {
    setState(() {
      final removed = _lines.removeAt(index);
      removed.removeChangeListener(_handleLineChanged);
      removed.dispose();
      if (_lines.isEmpty) {
        _registerLine(LineItemFormData(quantity: 1, unitPrice: 0, taxRate: 0.1));
      }
    });
  }

  Future<void> _showPasteBuffer() async {
    final parsed = await showPasteBufferScreen(context);
    if (parsed.isEmpty) return;
    setState(() {
      for (final item in parsed) {
        final data = LineItemFormData(productName: item.name, quantity: 1, unitPrice: item.price, taxRate: 0.1);
        _registerLine(data);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${parsed.length}件の明細を追加しました')),
    );
  }

  Future<void> _pickProduct(int index) async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductMasterScreen(selectionMode: true)),
    );
    if (product == null) return;
    setState(() {
      _lines[index].applyProduct(product);
      _lines[index].unitPriceController.text = product.wholesalePrice.toString();
      _lines[index].isTaxInclusive = product.wholesalePriceIsTaxInclusive;
    });
  }

  Map<String, int> _calculateTotals() {
    int subtotal = 0;
    int tax = 0;
    for (final line in _lines) {
      final lineTotal = line.quantityValue * line.unitPriceValue;
      final rate = line.taxRate ?? 0.1;
      if (line.isTaxInclusive) {
        final taxExcluded = (lineTotal / (1 + rate)).round();
        subtotal += taxExcluded;
        tax += lineTotal - taxExcluded;
      } else {
        subtotal += lineTotal;
        tax += (lineTotal * rate).round();
      }
    }
    return {'subtotal': subtotal, 'tax': tax, 'total': subtotal + tax};
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final validLines = _lines.where((line) => line.description.trim().isNotEmpty && line.quantityValue > 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('明細を1件以上入力してください')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final orderId = widget.order?.id ?? _uuid.v4();
      final documentNumber = widget.order?.documentNumber ?? _service.generateDocumentNumber(date: _orderDate);
      final items = validLines
          .map(
            (line) => PurchaseOrderItem(
              id: line.id ?? _uuid.v4(),
              orderId: orderId,
              productId: line.productId,
              description: line.description.isEmpty ? '商品' : line.description,
              quantity: line.quantityValue,
              unitPrice: line.unitPriceValue,
              taxRate: line.taxRate ?? 0.1,
              lineTotal: line.quantityValue * line.unitPriceValue,
              isTaxInclusive: line.isTaxInclusive,
            ),
          )
          .toList();
      final now = DateTime.now();
      final order = PurchaseOrder(
        id: orderId,
        documentNumber: documentNumber,
        supplierId: _supplierId,
        supplierSnapshot: _supplierName,
        orderDate: _orderDate,
        expectedDate: _expectedDate,
        status: _status,
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.order?.createdAt ?? now,
        updatedAt: now,
        items: items,
      );
      final saved = await _service.saveOrder(order);
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
    final totals = _calculateTotals();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: ScreenAppBarTitle(
          screenId: 'PO',
          title: widget.order == null ? '発注作成' : '発注編集',
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save),
          )
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
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text('発注日'),
                      subtitle: Text(_dateFormat.format(_orderDate)),
                      trailing: TextButton(onPressed: _pickOrderDate, child: const Text('変更')),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text('入荷予定日'),
                      subtitle: Text(_expectedDate == null ? '未設定' : _dateFormat.format(_expectedDate!)),
                      trailing: TextButton(onPressed: _pickExpectedDate, child: const Text('設定')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('ステータス'),
                trailing: DropdownButton<PurchaseOrderStatus>(
                  value: _status,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                  items: PurchaseOrderStatus.values
                      .map((status) => DropdownMenuItem(value: status, child: Text(status.displayName)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('明細', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._lines.asMap().entries.map(
                  (entry) => LineItemCard(
                    data: entry.value,
                    onPickProduct: () => _pickProduct(entry.key),
                    onRemove: () => _removeLine(entry.key),
                    onToggleTaxInclusive: () => setState(() => entry.value.isTaxInclusive = !entry.value.isTaxInclusive),
                  ),
                ),
            Row(
              children: [
                TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: const Text('明細を追加')),
                const Spacer(),
                TextButton.icon(onPressed: _showPasteBuffer, icon: const Icon(Icons.content_paste), label: const Text('貼付')),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('小計(税抜): ${_currencyFormat.format(totals['subtotal'] ?? 0)}'),
                    Text('消費税: ${_currencyFormat.format(totals['tax'] ?? 0)}'),
                    const Divider(),
                    Text('合計: ${_currencyFormat.format(totals['total'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
