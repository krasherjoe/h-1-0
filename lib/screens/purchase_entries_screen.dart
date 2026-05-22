import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase_entry_models.dart';
import '../models/supplier_model.dart';
import '../services/purchase_entry_service.dart';
import '../widgets/line_item_editor.dart';
import '../widgets/paste_buffer_dialog.dart';
import '../widgets/screen_id_title.dart';
import 'product_picker_modal.dart';
import 'supplier_picker_modal.dart';

class PurchaseEntriesScreen extends StatefulWidget {
  const PurchaseEntriesScreen({super.key});

  @override
  State<PurchaseEntriesScreen> createState() => _PurchaseEntriesScreenState();
}

class _PurchaseEntriesScreenState extends State<PurchaseEntriesScreen> {
  final PurchaseEntryService _service = PurchaseEntryService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  bool _isLoading = true;
  bool _isRefreshing = false;
  PurchaseEntryStatus? _filterStatus;
  List<PurchaseEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }
    try {
      final entries = await _service.fetchEntries(status: _filterStatus);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('仕入伝票の取得に失敗しました: $e')));
    }
  }

  void _setFilter(PurchaseEntryStatus? status) {
    setState(() => _filterStatus = status);
    _loadEntries();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadEntries();
  }

  Future<void> _openEditor({PurchaseEntry? entry}) async {
    final saved = await Navigator.push<PurchaseEntry>(
      context,
      MaterialPageRoute(builder: (_) => PurchaseEntryEditorPage(entry: entry)),
    );
    if (saved != null) {
      await _loadEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仕入伝票を保存しました')));
    }
  }

  Future<void> _deleteEntry(PurchaseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('仕入伝票を削除'),
        content: Text('${entry.subject ?? '無題'} を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteEntry(entry.id);
    if (!mounted) return;
    await _loadEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仕入伝票を削除しました')));
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _entries.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 140),
                      Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(height: 12),
                      Center(child: Text('仕入伝票がありません。右下のボタンから登録してください。')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
                  ),
          );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        leading: const BackButton(),
        title: const ScreenAppBarTitle(screenId: 'PE', title: '仕入入力'),
        actions: [
          PopupMenuButton<PurchaseEntryStatus?>(
            icon: const Icon(Icons.filter_alt),
            onSelected: _setFilter,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...PurchaseEntryStatus.values.map((status) => PopupMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  )),
            ],
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('仕入伝票を登録'),
      ),
    );
  }

  Widget _buildEntryCard(PurchaseEntry entry) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _openEditor(entry: entry),
        onLongPress: () => _deleteEntry(entry),
        title: Text(entry.subject?.isNotEmpty == true ? entry.subject! : '無題の仕入伝票',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.supplierNameSnapshot ?? '仕入先未設定'),
              const SizedBox(height: 4),
              Text('計上日: ${DateFormat('yyyy/MM/dd').format(entry.issueDate)}'),
            ],
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(entry.status.displayName, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(entry.amountTaxIncl),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchaseEntryEditorPage extends StatefulWidget {
  const PurchaseEntryEditorPage({super.key, this.entry});

  final PurchaseEntry? entry;

  @override
  State<PurchaseEntryEditorPage> createState() => _PurchaseEntryEditorPageState();
}

class _PurchaseEntryEditorPageState extends State<PurchaseEntryEditorPage> {
  final PurchaseEntryService _service = PurchaseEntryService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final uuid = const Uuid();

  Supplier? _supplier;
  String? _supplierSnapshot;
  DateTime _issueDate = DateTime.now();
  bool _isSaving = false;
  final List<LineItemFormData> _lines = [];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _subjectController.text = entry.subject ?? '';
      _notesController.text = entry.notes ?? '';
      _issueDate = entry.issueDate;
      _supplierSnapshot = entry.supplierNameSnapshot;
      _lines.addAll(entry.items
          .map((item) => LineItemFormData(
                id: item.id,
                productId: item.productId,
                productName: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                taxRate: item.taxRate,
              ))
          .toList());
    }
    if (_lines.isEmpty) {
      _lines.add(LineItemFormData(quantity: 1, unitPrice: 0));
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SupplierPickerModal(
        onSupplierSelected: (supplier) {
          Navigator.pop(ctx, supplier);
        },
      ),
    ).then((selected) {
      if (selected == null) return;
      setState(() {
        _supplier = selected;
        _supplierSnapshot = selected.name;
      });
    });
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _issueDate = picked);
  }

  Future<void> _pasteItemsFromBuffer() async {
    final parsed = await showPasteBufferScreen(context);
    if (parsed.isEmpty) return;
    setState(() {
      for (final item in parsed) {
        _lines.add(LineItemFormData(productName: item.name, quantity: 1, unitPrice: item.price, taxRate: 0.1));
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${parsed.length}件の明細を追加しました')),
    );
  }

  void _addLine() {
    setState(() => _lines.add(LineItemFormData(quantity: 1, unitPrice: 0)));
  }

  void _removeLine(int index) {
    setState(() {
      final removed = _lines.removeAt(index);
      removed.dispose();
      if (_lines.isEmpty) {
        _lines.add(LineItemFormData(quantity: 1, unitPrice: 0));
      }
    });
  }

  Future<void> _pickProduct(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductPickerModal(
        onProductSelected: (product) {
          setState(() => _lines[index].applyProduct(product));
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_lines.every((line) => line.descriptionController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('少なくとも1件の明細を入力してください')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final entryId = widget.entry?.id ?? uuid.v4();
      final items = _lines.map((line) {
        final quantity = line.quantityValue;
        final unitPrice = line.unitPriceValue;
        return PurchaseLineItem(
          id: line.id ?? uuid.v4(),
          purchaseEntryId: entryId,
          description: line.description.isEmpty ? '商品' : line.description,
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: quantity * unitPrice,
          productId: line.productId,
          taxRate: line.taxRate ?? 0,
        );
      }).toList();

      final entry = PurchaseEntry(
        id: entryId,
        supplierId: _supplier?.id ?? widget.entry?.supplierId,
        supplierNameSnapshot: _supplierSnapshot,
        subject: _subjectController.text.trim().isEmpty ? '仕入伝票' : _subjectController.text.trim(),
        issueDate: _issueDate,
        status: widget.entry?.status ?? PurchaseEntryStatus.draft,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.entry?.createdAt ?? now,
        updatedAt: now,
        items: items,
      );

      final saved = await _service.saveEntry(entry);
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        leading: const BackButton(),
        title: ScreenAppBarTitle(
          screenId: 'PE',
          title: widget.entry == null ? '仕入伝票作成' : '仕入伝票編集',
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                title: Text(_supplierSnapshot ?? '仕入先を選択'),
                subtitle: const Text('タップして仕入先を選択'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickSupplier,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                title: const Text('計上日'),
                subtitle: Text(DateFormat('yyyy/MM/dd').format(_issueDate)),
                trailing: TextButton(onPressed: _pickIssueDate, child: const Text('変更')),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: '件名'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('明細', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._lines.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LineItemCard(
                  data: entry.value,
                  onPickProduct: () => _pickProduct(entry.key),
                  onRemove: () => _removeLine(entry.key),
                ),
              ),
            ),
            Row(
              children: [
                TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: const Text('明細を追加')),
                const Spacer(),
                TextButton.icon(onPressed: _pasteItemsFromBuffer, icon: const Icon(Icons.content_paste), label: const Text('貼付')),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'メモ'),
                  minLines: 2,
                  maxLines: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
