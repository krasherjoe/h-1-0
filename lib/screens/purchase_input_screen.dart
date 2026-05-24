import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase_model.dart';
import '../models/purchase_order_models.dart';
import '../models/supplier_model.dart';
import '../models/product_model.dart';
import '../widgets/document_card.dart';
import '../services/purchase_repository.dart';
import '../services/purchase_order_service.dart';
import '../services/product_repository.dart';
import '../services/database_helper.dart';
import '../models/base_document.dart';
import 'supplier_picker_modal.dart';
import 'product_picker_modal.dart';

/// PE: 仕入入力フォーム（ラインアイテム付き）
class PurchaseInputScreen extends StatefulWidget {
  final String? existingPurchaseId;
  const PurchaseInputScreen({super.key, this.existingPurchaseId});

  @override
  State<PurchaseInputScreen> createState() => _PurchaseInputScreenState();
}

class _PurchaseInputScreenState extends State<PurchaseInputScreen> {
  final _repo = PurchaseRepository();
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _deliveryLocationController = TextEditingController();

  Supplier? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  bool _includeTax = true;
  double _taxRate = 0.10;
  bool _isDraft = true;
  bool _saving = false;
  bool _isLoading = true;

  List<_LineItem> _items = [];
  String? _linkedOrderId;
  String? _linkedOrderNumber;
  final PurchaseOrderService _orderService = PurchaseOrderService();

  @override
  void initState() {
    super.initState();
    if (widget.existingPurchaseId != null) {
      _loadExisting(widget.existingPurchaseId!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExisting(String id) async {
    final purchase = await _repo.getPurchase(id);
    if (purchase == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仕入データが見つかりません')),
      );
      Navigator.pop(context);
      return;
    }
    _selectedSupplier = purchase.supplier;
    _subjectController.text = purchase.subject ?? '';
    _notesController.text = purchase.notes ?? '';
    _invoiceNumberController.text = purchase.invoiceNumber ?? '';
    _deliveryLocationController.text = purchase.deliveryLocation ?? '';
    _selectedDate = purchase.date;
    _dueDate = purchase.dueDate;
    _taxRate = purchase.taxRate;
    _isDraft = purchase.status == DocumentStatus.draft;
    _linkedOrderId = purchase.purchaseOrderId;
    _linkedOrderNumber = purchase.purchaseOrderNumber;

    final productRepo = ProductRepository();
    final loadedItems = <_LineItem>[];
    for (var i = 0; i < purchase.items.length; i++) {
      final item = purchase.items[i];
      final product = await productRepo.getProduct(item.productId);
      loadedItems.add(_LineItem(
        id: item.id,
        product: product,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        taxRate: item.taxRate,
      ));
    }

    if (!mounted) return;
    setState(() {
      _items = loadedItems;
      _isLoading = false;
    });
  }

  Future<void> _pickSupplier() async {
    final result = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SupplierPickerModal(
        onSupplierSelected: (s) => Navigator.pop(context, s),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedSupplier = result);
    }
  }

  Future<void> _pickPurchaseOrder() async {
    final orders = await _orderService.fetchOrders(status: PurchaseOrderStatus.approved);
    if (!mounted) return;
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('承認済みの発注がありません')),
      );
      return;
    }
    final selected = await showModalBottomSheet<PurchaseOrder>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PurchaseOrderPickerSheet(orders: orders),
    );
    if (selected != null && mounted) {
      setState(() {
        _linkedOrderId = selected.id;
        _linkedOrderNumber = selected.documentNumber;
        if (_selectedSupplier == null) {
          _selectedSupplier = Supplier(
            id: selected.supplierId ?? '',
            displayName: selected.supplierSnapshot ?? '不明',
            formalName: selected.supplierSnapshot ?? '不明',
            updatedAt: DateTime.now(),
          );
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _addItem(Product product) async {
    if (!mounted) return;
    final controller = TextEditingController(text: '1');
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u{00a5}${product.defaultUnitPrice} x 数量'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text) ?? 1),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (qty != null && qty > 0 && mounted) {
      setState(() {
        _items.add(_LineItem(
          id: const Uuid().v4(),
          product: product,
          productName: product.name,
          quantity: qty,
          unitPrice: product.defaultUnitPrice,
          taxRate: _taxRate,
        ));
      });
    }
  }

  void _removeItem(String itemId) {
    setState(() => _items.removeWhere((i) => i.id == itemId));
  }

  void _updateItem(String itemId, {int? quantity, int? unitPrice}) {
    setState(() {
      for (final item in _items) {
        if (item.id == itemId) {
          if (quantity != null) item.quantity = quantity;
          if (unitPrice != null) item.unitPrice = unitPrice;
        }
      }
    });
  }

  (int subtotal, int tax, int total) _calculate() {
    int subTotal = 0;
    for (final item in _items) {
      final lineSubtotal = item.quantity * item.unitPrice;
      subTotal += lineSubtotal;
    }
    final tax = _includeTax
        ? (subTotal / (1 + _taxRate) * _taxRate).round()
        : (subTotal * _taxRate).round();
    return (subTotal, tax, subTotal + tax);
  }

  Future<void> _save() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仕入先を選択してください')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品を選択してください')),
      );
      return;
    }

    setState(() => _saving = true);

    final (subtotal, tax, total) = _calculate();
    final now = DateTime.now();
    final documentId = widget.existingPurchaseId ?? const Uuid().v4();

    final purchase = Purchase(
      id: documentId,
      documentNumber: widget.existingPurchaseId != null
          ? (await _repo.getPurchase(widget.existingPurchaseId!))?.documentNumber ?? await _generateDocumentNumber()
          : await _generateDocumentNumber(),
      date: _selectedDate,
      supplier: _selectedSupplier,
      items: _items.map((i) => DocumentItem(
        id: i.id,
        productId: i.product?.id ?? '',
        productName: i.productName,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        subtotal: i.quantity * i.unitPrice,
        taxRate: i.taxRate,
      )).toList(),
      subtotal: subtotal,
      taxAmount: tax,
      total: total,
      taxRate: _taxRate,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      subject: _subjectController.text.isNotEmpty ? _subjectController.text : null,
      status: _isDraft ? DocumentStatus.draft : DocumentStatus.confirmed,
      createdAt: widget.existingPurchaseId != null
          ? (await _repo.getPurchase(widget.existingPurchaseId!))?.createdAt ?? now
          : now,
      updatedAt: now,
      dueDate: _dueDate,
      purchaseStatus: _isDraft ? PurchaseStatus.draft : PurchaseStatus.confirmed,
      paymentStatus: PaymentStatus.unpaid,
      invoiceNumber: _invoiceNumberController.text.isNotEmpty ? _invoiceNumberController.text : null,
      deliveryLocation: _deliveryLocationController.text.isNotEmpty ? _deliveryLocationController.text : null,
      purchaseOrderId: _linkedOrderId,
      purchaseOrderNumber: _linkedOrderNumber,
    );

    try {
      await _repo.savePurchase(purchase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仕入を保存しました')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _generateDocumentNumber() async {
    final now = DateTime.now();
    final prefix = 'P${now.year}${now.month.toString().padLeft(2, '0')}';
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM purchases WHERE document_number LIKE ?',
      ['$prefix%'],
    );
    final count = result.first['count'] as int;
    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('PE:仕入読込中')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isEdit = widget.existingPurchaseId != null;
    final (subtotal, tax, total) = _calculate();

    return Scaffold(
      appBar: AppBar(
        title: Text('PE:${isEdit ? '仕入編集' : '仕入入力'}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('保存', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 仕入先選択
          Card(
            child: ListTile(
              leading: const Icon(Icons.business),
              title: Text(_selectedSupplier?.name ?? '仕入先を選択'),
              subtitle: _selectedSupplier?.contactPerson != null ? Text('担当者: ${_selectedSupplier!.contactPerson}') : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickSupplier,
            ),
          ),
          const SizedBox(height: 12),

          // 発注連携
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt),
              title: Text(_linkedOrderNumber ?? '発注と連携'),
              subtitle: Text(_linkedOrderId != null ? '発注番号: $_linkedOrderNumber' : 'タップして発注を選択'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_linkedOrderId != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() { _linkedOrderId = null; _linkedOrderNumber = null; }),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: _pickPurchaseOrder,
            ),
          ),
          const SizedBox(height: 12),

          // 伝票日付
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy年MM月dd日').format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 12),

          // 支払期日
          Card(
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(_dueDate != null ? DateFormat('yyyy年MM月dd日').format(_dueDate!) : '支払期日を設定'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDueDate,
            ),
          ),
          const SizedBox(height: 12),

          // 件名
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: '件名',
              prefixIcon: Icon(Icons.subject),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 請求書番号
          TextField(
            controller: _invoiceNumberController,
            decoration: const InputDecoration(
              labelText: '請求書番号',
              prefixIcon: Icon(Icons.receipt_long),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 入庫場所
          TextField(
            controller: _deliveryLocationController,
            decoration: const InputDecoration(
              labelText: '入庫場所',
              prefixIcon: Icon(Icons.warehouse),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ラインアイテムヘッダー
          Row(
            children: [
              const Text('商品明細', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showProductPicker,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('追加'),
                style: FilledButton.styleFrom(minimumSize: const Size(60, 36)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ラインアイテム一覧
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    SizedBox(height: 8),
                    Text('商品を追加してください'),
                  ],
                ),
              ),
            )
          else
            ..._items.map((item) => _buildItemCard(item, theme)),

          const SizedBox(height: 16),

          // 税設定
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('税込')),
                    ButtonSegment(value: false, label: Text('税別')),
                  ],
                  selected: {_includeTax},
                  onSelectionChanged: (v) {
                    if (v.isNotEmpty) setState(() => _includeTax = v.first);
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<double>(
                value: _taxRate,
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('非課税')),
                  DropdownMenuItem(value: 0.08, child: Text('8%')),
                  DropdownMenuItem(value: 0.10, child: Text('10%')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _taxRate = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 金額内訳
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPriceRow('小計', subtotal),
                _buildPriceRow('消費税', tax),
                const Divider(),
                _buildPriceRow('合計', total, isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 備考
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: '備考',
              prefixIcon: Icon(Icons.note),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // ステータス
          SwitchListTile.adaptive(
            title: const Text('下書きとして保存'),
            subtitle: const Text('OFFにすると確定状態で保存されます'),
            value: _isDraft,
            onChanged: (v) => setState(() => _isDraft = v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showProductPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ProductPickerModal(
        onProductSelected: (product) async {
          Navigator.pop(ctx);
          await _addItem(product);
        },
      ),
    );
  }

  Widget _buildItemCard(_LineItem item, ThemeData theme) {
    final lineTotal = item.quantity * item.unitPrice;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(item.productName),
            subtitle: Text('\u{00a5}${item.unitPrice.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            )} x ${item.quantity}'),
            trailing: Text(
              '\u{00a5}${lineTotal.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              )}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: item.quantity.toString()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '数量',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final qty = int.tryParse(v) ?? 0;
                      _updateItem(item.id, quantity: qty);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: item.unitPrice.toString()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '単価',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final price = int.tryParse(v) ?? 0;
                      _updateItem(item.id, unitPrice: price);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: () => _removeItem(item.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount, {bool isTotal = false}) {
    final formatted = '\u{00a5}${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(formatted, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    _invoiceNumberController.dispose();
    _deliveryLocationController.dispose();
    super.dispose();
  }
}

class _LineItem {
  String id;
  Product? product;
  final String productName;
  int quantity;
  int unitPrice;
  double taxRate;

  _LineItem({
    required this.id,
    required this.product,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
  });
}

// Quantity field state accessor for dialog

class _PurchaseOrderPickerSheet extends StatelessWidget {
  const _PurchaseOrderPickerSheet({required this.orders});

  final List<PurchaseOrder> orders;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('発注を選択', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text(order.documentNumber),
                  subtitle: Text('${order.supplierSnapshot ?? "不明"} / ${dateFormat.format(order.orderDate)}'),
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

