import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/sales_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/base_document.dart';
import '../models/invoice_models.dart';
import '../services/sales_repository.dart';
import '../services/product_repository.dart';
import '../services/database_helper.dart';
import '../widgets/document_card.dart';
import 'customer_picker_modal.dart';
import 'product_picker_modal.dart';
import 'invoice_picker_modal.dart';

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
  List<String> _invoiceIds = [];
  List<Invoice> _linkedInvoices = [];

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
    _invoiceIds = sales.invoiceIds ?? [];

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

  Future<void> _addItem(Product product, BuildContext? dialogContext) async {
    if (!mounted) return;
    if (dialogContext != null) {
      Navigator.pop(dialogContext);
    }
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

  Future<void> _pickInvoices() async {
    final selected = await showModalBottomSheet<List<Invoice>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InvoicePickerModal(
        selectedInvoiceIds: _invoiceIds,
        customerId: _selectedCustomer?.id,
        onInvoicesSelected: (_) {},
      ),
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      setState(() {
        _invoiceIds = selected.map((i) => i.id).toList();
        _linkedInvoices = selected;
      });

      // 請求書内容をインポート
      _importFromInvoices(selected);
    }
  }

  void _importFromInvoices(List<Invoice> invoices) {
    if (invoices.isEmpty) return;
    _performImport(invoices);
  }

  void _performImport(List<Invoice> invoices) {
    final newItems = <_LineItem>[];
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        // 値引き後の小計を数量で割って、値引き後の単価を計算
        final discountedUnitPrice = item.quantity > 0
            ? (item.subtotal / item.quantity).round()
            : item.unitPrice;

        newItems.add(_LineItem(
          id: const Uuid().v4(),
          product: null,
          productName: item.description,
          quantity: item.quantity,
          unitPrice: discountedUnitPrice,
          taxRate: 0.0, // 請求書からインポートした明細は税計算をスキップ
        ));
      }

      // 顧客が未設定なら請求書の顧客を設定
      if (_selectedCustomer == null) {
        _selectedCustomer = invoice.customer;
      }
      // 件名が未設定なら請求書の件名を設定
      if (_subjectController.text.isEmpty && invoice.subject != null) {
        _subjectController.text = invoice.subject!;
      }
    }

    if (!mounted) return;
    setState(() => _items = newItems);
  }

  (int subtotal, int tax, int total) _calculate() {
    int subTotal = 0;
    int taxAmount = 0;
    for (final item in _items) {
      final lineSubtotal = item.quantity * item.unitPrice;
      subTotal += lineSubtotal;
      // taxRateが0.0の明細（請求書からインポート）は税計算をスキップ
      if (item.taxRate > 0) {
        final lineTax = _includeTax
            ? (lineSubtotal / (1 + item.taxRate) * item.taxRate).round()
            : (lineSubtotal * item.taxRate).round();
        taxAmount += lineTax;
      }
    }
    return (subTotal, taxAmount, subTotal + taxAmount);
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
        productId: i.product?.id ?? 'unknown',
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
      invoiceIds: _invoiceIds.isNotEmpty ? _invoiceIds : null,
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
      print('SE1保存エラー: $e');
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
                : const Text('保存'),
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
          const SizedBox(height: 12),

          // 商品追加ボタン
          ElevatedButton.icon(
            onPressed: _showProductPicker,
            icon: const Icon(Icons.add),
            label: const Text('商品を追加'),
          ),
          const SizedBox(height: 12),

          // 請求書紐付けボタン
          ElevatedButton.icon(
            onPressed: _pickInvoices,
            icon: const Icon(Icons.receipt_long),
            label: const Text('請求書を紐付け'),
          ),
          const SizedBox(height: 12),

          // 明細リスト
          ..._items.map((item) => Card(
            child: ListTile(
              title: Text(item.productName),
              subtitle: Text('数量: ${item.quantity} 単価: ¥${item.unitPrice}'),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                onPressed: () => _removeItem(item.id),
              ),
            ),
          )),

          // 合計表示
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceRow('小計', subtotal),
                  if (tax > 0) _buildPriceRow('消費税', tax),
                  const Divider(),
                  _buildPriceRow('合計', total, isTotal: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.save),
      ),
    );
  }

  void _showProductPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ProductPickerModal(
        onProductSelected: (product) async {
          await _addItem(product, ctx);
        },
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
