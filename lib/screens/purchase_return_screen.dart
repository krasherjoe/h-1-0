import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase_order_models.dart';
import '../models/supplier_model.dart';
import '../services/purchase_return_service.dart';
import '../services/supplier_repository.dart';
import '../widgets/line_item_editor.dart';
import '../widgets/paste_buffer_dialog.dart';
import '../widgets/screen_id_title.dart';
import 'product_picker_modal.dart';
import 'supplier_picker_modal.dart';

class PurchaseReturnListScreen extends StatefulWidget {
  const PurchaseReturnListScreen({super.key});

  @override
  State<PurchaseReturnListScreen> createState() => _PurchaseReturnListScreenState();
}

class _PurchaseReturnListScreenState extends State<PurchaseReturnListScreen> {
  final PurchaseReturnService _service = PurchaseReturnService();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  bool _isLoading = true;
  List<PurchaseReturn> _returns = const [];
  PurchaseReturnStatus? _filterStatus;
  final Map<String, String> _supplierNames = {};

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    setState(() => _isLoading = true);
    final returns = await _service.fetchReturns(status: _filterStatus);
    final supplierIds = returns.map((r) => r.supplierId).whereType<String>().toSet();
    for (final id in supplierIds) {
      if (_supplierNames.containsKey(id)) continue;
      final supplier = await _supplierRepository.findById(id);
      if (supplier != null) {
        _supplierNames[id] = supplier.name;
      }
    }
    if (!mounted) return;
    setState(() {
      _returns = returns;
      _isLoading = false;
    });
  }

  Future<void> _openEditor({PurchaseReturn? purchaseReturn}) async {
    final result = await Navigator.of(context).push<PurchaseReturn>(
      MaterialPageRoute(builder: (_) => PurchaseReturnEditorPage(purchaseReturn: purchaseReturn)),
    );
    if (result != null) {
      await _loadReturns();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('返品 ${result.documentNumber} を保存しました')),
      );
    }
  }

  Future<void> _confirmDelete(PurchaseReturn purchaseReturn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('返品を削除'),
        content: Text('${purchaseReturn.documentNumber} を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteReturn(purchaseReturn.id);
    if (!mounted) return;
    await _loadReturns();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
  }

  Color _statusColor(ColorScheme cs, PurchaseReturnStatus status) {
    switch (status) {
      case PurchaseReturnStatus.draft:
        return cs.secondary;
      case PurchaseReturnStatus.pendingApproval:
        return cs.onSurfaceVariant;
      case PurchaseReturnStatus.processed:
        return cs.primary;
      case PurchaseReturnStatus.cancelled:
        return cs.error;
    }
  }

  String _supplierLabel(PurchaseReturn purchaseReturn) {
    if (purchaseReturn.supplierSnapshot?.isNotEmpty == true) {
      return purchaseReturn.supplierSnapshot!;
    }
    if (purchaseReturn.supplierId == null) {
      return '仕入先未設定';
    }
    return _supplierNames[purchaseReturn.supplierId] ?? '仕入先読込中';
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      PopupMenuButton<PurchaseReturnStatus?>(
        icon: const Icon(Icons.filter_list),
        onSelected: (value) {
          setState(() => _filterStatus = value);
          _loadReturns();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text('すべて表示')),
          ...PurchaseReturnStatus.values.map(
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
        : _returns.isEmpty
            ? const Center(child: Text('返品データがありません。右下のボタンから登録してください。'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _returns.length,
                itemBuilder: (context, index) => _buildReturnCard(_returns[index]),
              );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const ScreenAppBarTitle(screenId: 'PR1', title: '仕入返品入力'),
        actions: actions,
      ),
      body: RefreshIndicator(onRefresh: _loadReturns, child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('返品を作成'),
      ),
    );
  }

  Widget _buildReturnCard(PurchaseReturn purchaseReturn) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs, purchaseReturn.status);
    final supplier = _supplierLabel(purchaseReturn);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _openEditor(purchaseReturn: purchaseReturn),
        onLongPress: () => _confirmDelete(purchaseReturn),
        title: Text(purchaseReturn.documentNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('返品日: ${_dateFormat.format(purchaseReturn.returnDate)}'),
              const SizedBox(height: 4),
              Text(supplier),
              const SizedBox(height: 4),
              Text('金額: ${_currencyFormat.format(purchaseReturn.total)}'),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(purchaseReturn.status.displayName, style: TextStyle(color: statusColor)),
        ),
      ),
    );
  }
}

class PurchaseReturnEditorPage extends StatefulWidget {
  const PurchaseReturnEditorPage({super.key, this.purchaseReturn});

  final PurchaseReturn? purchaseReturn;

  @override
  State<PurchaseReturnEditorPage> createState() => _PurchaseReturnEditorPageState();
}

class _PurchaseReturnEditorPageState extends State<PurchaseReturnEditorPage> {
  final PurchaseReturnService _service = PurchaseReturnService();
  final TextEditingController _notesController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  final Uuid _uuid = const Uuid();

  DateTime _returnDate = DateTime.now();
  PurchaseReturnStatus _status = PurchaseReturnStatus.draft;
  String? _supplierId;
  String? _supplierName;
  bool _isSaving = false;

  final List<LineItemFormData> _lines = [];

  @override
  void initState() {
    super.initState();
    final purchaseReturn = widget.purchaseReturn;
    if (purchaseReturn != null) {
      _returnDate = purchaseReturn.returnDate;
      _status = purchaseReturn.status;
      _supplierId = purchaseReturn.supplierId;
      _supplierName = purchaseReturn.supplierSnapshot;
      _notesController.text = purchaseReturn.notes ?? '';
      for (final item in purchaseReturn.items) {
        final data = LineItemFormData(
          id: item.id,
          productId: item.productId,
          productName: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          taxRate: item.taxRate,
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

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _returnDate = picked);
    }
  }

  Future<void> _pasteItemsFromBuffer() async {
    final parsed = await showPasteBufferDialog(context);
    if (parsed.isEmpty) return;
    setState(() {
      for (final item in parsed) {
        _registerLine(LineItemFormData(productName: item.name, quantity: 1, unitPrice: item.price, taxRate: 0.1));
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${parsed.length}件の明細を追加しました')),
    );
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

  Future<void> _pickProduct(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductPickerModal(onProductSelected: (product) {
        setState(() => _lines[index].applyProduct(product));
      }),
    );
  }

  Map<String, int> _calculateTotals() {
    final subtotal = _lines.fold<int>(0, (sum, line) => sum + (line.quantityValue * line.unitPriceValue));
    final tax = _lines.fold<double>(0, (sum, line) => sum + (line.quantityValue * line.unitPriceValue) * (line.taxRate ?? 0.1)).round();
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
      final returnId = widget.purchaseReturn?.id ?? _uuid.v4();
      final documentNumber = widget.purchaseReturn?.documentNumber ?? _service.generateDocumentNumber(date: _returnDate);
      final items = validLines
          .map(
            (line) => PurchaseReturnItem(
              id: line.id ?? _uuid.v4(),
              returnId: returnId,
              productId: line.productId,
              description: line.description.isEmpty ? '商品' : line.description,
              quantity: line.quantityValue,
              unitPrice: line.unitPriceValue,
              taxRate: line.taxRate ?? 0.1,
              lineTotal: line.quantityValue * line.unitPriceValue,
            ),
          )
          .toList();
      final now = DateTime.now();
      final purchaseReturn = PurchaseReturn(
        id: returnId,
        documentNumber: documentNumber,
        supplierId: _supplierId,
        supplierSnapshot: _supplierName,
        returnDate: _returnDate,
        status: _status,
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.purchaseReturn?.createdAt ?? now,
        updatedAt: now,
        items: items,
      );
      final saved = await _service.saveReturn(purchaseReturn);
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
          screenId: 'PR1',
          title: widget.purchaseReturn == null ? '返品作成' : '返品編集',
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
            Card(
              child: ListTile(
                title: const Text('返品日'),
                subtitle: Text(_dateFormat.format(_returnDate)),
                trailing: TextButton(onPressed: _pickReturnDate, child: const Text('変更')),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('ステータス'),
                trailing: DropdownButton<PurchaseReturnStatus>(
                  value: _status,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                  items: PurchaseReturnStatus.values
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
                  ),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: const Text('明細を追加')),
                  const SizedBox(width: 8),
                  TextButton.icon(onPressed: _pasteItemsFromBuffer, icon: const Icon(Icons.content_paste), label: const Text('貼付')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('小計: ${_currencyFormat.format(totals['subtotal'] ?? 0)}'),
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
