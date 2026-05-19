import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/sales_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/base_document.dart';
import '../services/sales_repository.dart';
import '../services/product_repository.dart';
import '../services/database_helper.dart';
import '../widgets/document_card.dart';
import 'customer_picker_modal.dart';
import 'product_picker_modal.dart';

/// SE1: 売上入力フォーム（ラインアイテム付き）
class SalesInputScreen extends StatefulWidget {
  final String? existingSalesId;
  const SalesInputScreen({super.key, this.existingSalesId});

  @override
  State<SalesInputScreen> createState() => _SalesInputScreenState();
}

class _SalesInputScreenState extends State<SalesInputScreen> {
  final _repo = SalesRepository();
  final _productRepo = ProductRepository();

  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();

  Customer? _selectedCustomer;
  DateTime _selectedDate = DateTime.now();
  bool _includeTax = true;
  double _taxRate = 0.10;
  bool _isDraft = true;
  bool _saving = false;
  bool _isLoading = true;

  List<_LineItem> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingSalesId != null) {
      _loadExisting(widget.existingSalesId!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExisting(String id) async {
    final sales = await _repo.getSales(id);
    if (sales == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('売上データが見つかりません')),
      );
      Navigator.pop(context);
      return;
    }
    _selectedCustomer = sales.customer;
    _subjectController.text = sales.subject ?? '';
    _notesController.text = sales.notes ?? '';
    _selectedDate = sales.date;
    _taxRate = sales.taxRate;
    _isDraft = sales.status == DocumentStatus.draft;

    final loadedItems = <_LineItem>[];
    for (var i = 0; i < sales.items.length; i++) {
      final item = sales.items[i];
      final product = await _productRepo.getProduct(item.productId);
      loadedItems.add(_LineItem(
        id: item.id,
        product: product,
        productName: item.productName,
        quantity: 1,
        unitPrice: item.subtotal,
        taxRate: item.taxRate,
      ));
    }

    if (!mounted) return;
    setState(() {
      _items = loadedItems;
      _isLoading = false;
    });
  }

  Future<void> _pickCustomer() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CustomerPickerModal(
        onCustomerSelected: (c) => Navigator.pop(context, c),
      ),
    );
    if (customer != null && mounted) {
      setState(() => _selectedCustomer = customer);
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
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('顧客を選択してください')),
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
    final documentId = widget.existingSalesId ?? const Uuid().v4();

    final sales = Sales(
      id: documentId,
      documentNumber: widget.existingSalesId != null
          ? (await _repo.getSales(widget.existingSalesId!))?.documentNumber ?? await _generateDocumentNumber()
          : await _generateDocumentNumber(),
      date: _selectedDate,
      customer: _selectedCustomer,
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
      createdAt: widget.existingSalesId != null
          ? (await _repo.getSales(widget.existingSalesId!))?.createdAt ?? now
          : now,
      updatedAt: now,
    );

    try {
      await _repo.saveSales(sales);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('売上を保存しました')),
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
    final prefix = 'S${now.year}${now.month.toString().padLeft(2, '0')}';
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sales WHERE document_number LIKE ?',
      ['$prefix%'],
    );
    final count = result.first['count'] as int;
    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('SE1:売上読込中')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isEdit = widget.existingSalesId != null;
    final (subtotal, tax, total) = _calculate();

    return Scaffold(
      appBar: AppBar(
        title: Text('SE1:${isEdit ? '売上編集' : '売上入力'}'),
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
          // 顧客選択
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(_selectedCustomer?.displayName ?? '顧客を選択'),
              subtitle: _selectedCustomer?.formalName != null ? Text(_selectedCustomer!.formalName) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCustomer,
            ),
          ),
          const SizedBox(height: 12),

          // 日付
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy年MM月dd日').format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
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
          const SizedBox(height: 16),

          // ラインアイテムヘッダー
          Row(
            children: [
              const Text('明細', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
