import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/purchase_entry_models.dart';
import '../models/supplier_model.dart';
import '../services/purchase_entry_service.dart';
import '../services/purchase_receipt_service.dart';
import '../services/supplier_repository.dart';
import '../widgets/screen_id_title.dart';
import 'supplier_picker_modal.dart';

class PurchaseReceiptsScreen extends StatefulWidget {
  const PurchaseReceiptsScreen({super.key});

  @override
  State<PurchaseReceiptsScreen> createState() => _PurchaseReceiptsScreenState();
}

class _PurchaseReceiptsScreenState extends State<PurchaseReceiptsScreen> {
  final PurchaseReceiptService _receiptService = PurchaseReceiptService();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  bool _isLoading = true;
  bool _isRefreshing = false;
  List<PurchaseReceipt> _receipts = const [];
  Map<String, int> _receiptAllocations = const {};
  Map<String, String> _supplierNames = const {};
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }
    try {
      final receipts = await _receiptService.fetchReceipts(startDate: _startDate, endDate: _endDate);
      final allocationMap = <String, int>{};
      for (final receipt in receipts) {
        final links = await _receiptService.fetchLinks(receipt.id);
        allocationMap[receipt.id] = links.fold<int>(0, (sum, link) => sum + link.allocatedAmount);
      }
      final supplierIds = receipts.map((r) => r.supplierId).whereType<String>().toSet();
      final supplierNames = Map<String, String>.from(_supplierNames);
      for (final id in supplierIds) {
        if (supplierNames.containsKey(id)) continue;
        final supplier = await _supplierRepository.fetchSuppliers(includeHidden: true).then(
          (list) => list.firstWhere(
            (s) => s.id == id,
            orElse: () => Supplier(id: id, displayName: '仕入先不明', formalName: '仕入先不明', updatedAt: DateTime.now()),
          ),
        );
        supplierNames[id] = supplier.displayName;
      }
      if (!mounted) return;
      setState(() {
        _receipts = receipts;
        _receiptAllocations = allocationMap;
        _supplierNames = supplierNames;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('支払データの取得に失敗しました: $e')));
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadReceipts();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now().subtract(const Duration(days: 30))) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
    _loadReceipts();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadReceipts();
  }

  Future<void> _openEditor({PurchaseReceipt? receipt}) async {
    final updated = await Navigator.of(context).push<PurchaseReceipt>(
      MaterialPageRoute(builder: (_) => PurchaseReceiptEditorPage(receipt: receipt)),
    );
    if (updated != null) {
      await _loadReceipts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支払データを保存しました')));
    }
  }

  Future<void> _confirmDelete(PurchaseReceipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('支払を削除'),
        content: Text('${_dateFormat.format(receipt.paymentDate)}の${_currencyFormat.format(receipt.amount)}を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _receiptService.deleteReceipt(receipt.id);
      if (!mounted) return;
      await _loadReceipts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支払を削除しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
    }
  }

  String _supplierLabel(PurchaseReceipt receipt) {
    if (receipt.supplierId == null) {
      return '仕入先未設定';
    }
    return _supplierNames[receipt.supplierId] ?? '仕入先読込中';
  }

  @override
  Widget build(BuildContext context) {
    final filterLabel = [
      if (_startDate != null) '開始: ${_dateFormat.format(_startDate!)}',
      if (_endDate != null) '終了: ${_dateFormat.format(_endDate!)}',
    ].join(' / ');

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _receipts.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 140),
                      Icon(Icons.account_balance_wallet_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Center(child: Text('支払データがありません。右下のボタンから登録してください。')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _receipts.length,
                    itemBuilder: (context, index) => _buildReceiptCard(_receipts[index]),
                  ),
          );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const ScreenAppBarTitle(screenId: 'PS', title: '支払予定管理'),
        actions: [
          IconButton(
            tooltip: '開始日を選択',
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDate(isStart: true),
          ),
          IconButton(
            tooltip: '終了日を選択',
            icon: const Icon(Icons.event),
            onPressed: () => _pickDate(isStart: false),
          ),
          IconButton(
            tooltip: 'フィルターをクリア',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: (_startDate == null && _endDate == null) ? null : _clearFilters,
          ),
          const SizedBox(width: 4),
        ],
        bottom: filterLabel.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(filterLabel, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ),
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('支払を登録'),
      ),
    );
  }

  Widget _buildReceiptCard(PurchaseReceipt receipt) {
    final allocated = _receiptAllocations[receipt.id] ?? 0;
    final allocationRatio = receipt.amount == 0 ? 0.0 : allocated / receipt.amount;
    final cs = Theme.of(context).colorScheme;
    final statusColor = allocationRatio >= 0.999
        ? cs.primary
        : allocationRatio <= 0
            ? cs.secondary
            : cs.tertiary;
    final supplier = _supplierLabel(receipt);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _openEditor(receipt: receipt),
        title: Text(
          _currencyFormat.format(receipt.amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(supplier),
              const SizedBox(height: 4),
              Text('割当: ${_currencyFormat.format(allocated)} / ${_currencyFormat.format(receipt.amount)}'),
              if (receipt.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(receipt.notes!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ],
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_dateFormat.format(receipt.paymentDate)),
            const SizedBox(height: 4),
            Text(receipt.method ?? '未設定', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: statusColor.withAlpha(32), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                allocationRatio >= 0.999
                    ? '全額割当済'
                    : allocationRatio <= 0
                        ? '未割当'
                        : '一部割当',
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        contentPadding: const EdgeInsets.all(16),
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onLongPress: () => _confirmDelete(receipt),
      ),
    );
  }
}

class PurchaseReceiptEditorPage extends StatefulWidget {
  const PurchaseReceiptEditorPage({super.key, this.receipt});

  final PurchaseReceipt? receipt;

  @override
  State<PurchaseReceiptEditorPage> createState() => _PurchaseReceiptEditorPageState();
}

class _PurchaseReceiptEditorPageState extends State<PurchaseReceiptEditorPage> {
  final PurchaseReceiptService _receiptService = PurchaseReceiptService();
  final PurchaseEntryService _entryService = PurchaseEntryService();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  DateTime _paymentDate = DateTime.now();
  String? _supplierId;
  String? _supplierName;
  String? _method = '銀行振込';
  bool _isSaving = false;
  bool _isInitializing = true;

  List<_AllocationRow> _allocations = [];
  List<PurchaseEntry> _entries = [];
  Map<String, int> _baseAllocated = {};

  @override
  void initState() {
    super.initState();
    final receipt = widget.receipt;
    if (receipt != null) {
      _paymentDate = receipt.paymentDate;
      _amountController.text = receipt.amount.toString();
      _notesController.text = receipt.notes ?? '';
      _method = receipt.method ?? '銀行振込';
      _supplierId = receipt.supplierId;
      if (_supplierId != null) {
        _loadSupplierName(_supplierId!);
      }
    } else {
      _amountController.text = '';
    }
    _amountController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    for (final row in _allocations) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSupplierName(String supplierId) async {
    final suppliers = await _supplierRepository.fetchSuppliers(includeHidden: true);
    final supplier = suppliers.firstWhere(
      (s) => s.id == supplierId,
      orElse: () => Supplier(id: supplierId, displayName: '仕入先不明', formalName: '仕入先不明', updatedAt: DateTime.now()),
    );
    if (!mounted) return;
    setState(() => _supplierName = supplier.displayName);
  }

  Future<void> _loadData() async {
    try {
      final entries = await _entryService.fetchEntries();
      final totals = await _receiptService.fetchAllocatedTotals(entries.map((e) => e.id));
      final allocationRows = <_AllocationRow>[];
      if (widget.receipt != null) {
        final links = await _receiptService.fetchLinks(widget.receipt!.id);
        for (final link in links) {
          final current = totals[link.purchaseEntryId] ?? 0;
          totals[link.purchaseEntryId] = current - link.allocatedAmount;
          var entry = entries.firstWhere(
            (e) => e.id == link.purchaseEntryId,
            orElse: () => PurchaseEntry(
              id: link.purchaseEntryId,
              issueDate: DateTime.now(),
              status: PurchaseEntryStatus.draft,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          allocationRows.add(_AllocationRow(entry: entry, amount: link.allocatedAmount));
        }
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _baseAllocated = totals;
        _allocations = allocationRows;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInitializing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('支払フォームの読み込みに失敗しました: $e')));
    }
  }

  Future<void> _pickSupplier() async {
    final selected = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SupplierPickerModal(
        onSupplierSelected: (supplier) {
          Navigator.pop(ctx, supplier);
        },
      ),
    );
    if (selected == null) return;
    setState(() {
      _supplierId = selected.id;
      _supplierName = selected.name;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _addAllocation() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('割当対象となる仕入伝票がありません')));
      return;
    }
    final entry = await showModalBottomSheet<PurchaseEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PurchaseEntryPickerSheet(
        entries: _entries,
        dateFormat: _dateFormat,
        currencyFormat: _currencyFormat,
        getOutstanding: _availableForEntry,
      ),
    );
    if (!mounted) return;
    if (entry == null) return;
    final maxForEntry = _availableForEntry(entry);
    if (maxForEntry <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('選択した仕入伝票には割当余力がありません')));
      return;
    }
    final receiptAmount = _receiptAmount;
    final remainingReceipt = receiptAmount > 0 ? receiptAmount - _sumAllocations : maxForEntry;
    final initial = remainingReceipt > 0 ? remainingReceipt.clamp(0, maxForEntry).toInt() : maxForEntry;
    setState(() {
      _allocations.add(_AllocationRow(entry: entry, amount: initial));
    });
  }

  int get _receiptAmount => int.tryParse(_amountController.text) ?? 0;

  int get _sumAllocations => _allocations.fold<int>(0, (sum, row) => sum + row.amount);

  int _availableForEntry(PurchaseEntry entry, [_AllocationRow? excluding]) {
    final base = _baseAllocated[entry.id] ?? 0;
    final others = _allocations.where((row) => row.entry.id == entry.id && row != excluding).fold<int>(0, (sum, row) => sum + row.amount);
    return entry.amountTaxIncl - base - others;
  }

  int _maxForRow(_AllocationRow row) {
    return _availableForEntry(row.entry, row) + row.amount;
  }

  void _handleAllocationChanged(_AllocationRow row) {
    final value = row.amount;
    final max = _maxForRow(row);
    if (value > max) {
      row.setAmount(max);
    } else if (value < 0) {
      row.setAmount(0);
    }
    setState(() {});
  }

  void _removeAllocation(_AllocationRow row) {
    setState(() {
      _allocations.remove(row);
      row.dispose();
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final amount = _receiptAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支払額を入力してください')));
      return;
    }
    final totalAlloc = _sumAllocations;
    if (totalAlloc > amount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('割当総額が支払額を超えています')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      PurchaseReceipt saved;
      final allocations = _allocations
          .where((row) => row.amount > 0)
          .map((row) => PurchaseReceiptAllocationInput(purchaseEntryId: row.entry.id, amount: row.amount))
          .toList();
      if (widget.receipt == null) {
        saved = await _receiptService.createReceipt(
          supplierId: _supplierId,
          paymentDate: _paymentDate,
          amount: amount,
          method: _method,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          allocations: allocations,
        );
      } else {
        final updated = widget.receipt!.copyWith(
          supplierId: _supplierId,
          paymentDate: _paymentDate,
          amount: amount,
          method: _method,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        saved = await _receiptService.updateReceipt(receipt: updated, allocations: allocations);
      }
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
    final title = widget.receipt == null ? '支払を登録' : '支払を編集';
    final receiptAmount = _receiptAmount;
    final allocSum = _sumAllocations;
    final remaining = (receiptAmount - allocSum).clamp(-999999999, 999999999).toInt();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: ScreenAppBarTitle(
          screenId: 'PS',
          title: title == '支払を登録' ? '支払登録' : '支払編集',
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '支払額 (円)'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('支払日'),
                      subtitle: Text(_dateFormat.format(_paymentDate)),
                      trailing: TextButton(onPressed: _pickDate, child: const Text('変更')),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_supplierName ?? '仕入先を選択'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickSupplier,
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
                      onChanged: (val) => setState(() => _method = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'メモ (任意)'),
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Text('割当: ${_currencyFormat.format(allocSum)} / ${_currencyFormat.format(receiptAmount)}'),
                        const Spacer(),
                        Text(
                          remaining >= 0 ? '残り: ${_currencyFormat.format(remaining)}' : '超過: ${_currencyFormat.format(remaining.abs())}',
                          style: TextStyle(color: remaining >= 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final row in _allocations)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row.entry.subject?.isNotEmpty == true ? row.entry.subject! : '仕入伝票',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('${_dateFormat.format(row.entry.issueDate)} / ${_currencyFormat.format(row.entry.amountTaxIncl)}'),
                                      ],
                                    ),
                                  ),
                                  IconButton(onPressed: () => _removeAllocation(row), icon: const Icon(Icons.delete_outline)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: row.controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '割当額',
                                  helperText: '残余 ${_currencyFormat.format((_maxForRow(row) - row.amount).clamp(0, double.infinity))}',
                                ),
                                onChanged: (_) => _handleAllocationChanged(row),
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _addAllocation,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('仕入伝票を割当'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AllocationRow {
  _AllocationRow({required this.entry, required int amount})
      : controller = TextEditingController(text: amount.toString()),
        _amount = amount;

  final PurchaseEntry entry;
  final TextEditingController controller;
  int _amount;

  int get amount => _amount;

  void setAmount(int value) {
    _amount = value;
    controller.text = value.toString();
  }

  void dispose() => controller.dispose();
}

class _PurchaseEntryPickerSheet extends StatelessWidget {
  const _PurchaseEntryPickerSheet({
    required this.entries,
    required this.dateFormat,
    required this.currencyFormat,
    required this.getOutstanding,
  });

  final List<PurchaseEntry> entries;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final int Function(PurchaseEntry entry) getOutstanding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: const [
                  Text('仕入伝票を選択', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final outstanding = getOutstanding(entry);
                  return ListTile(
                    title: Text(entry.subject?.isNotEmpty == true ? entry.subject! : '仕入伝票'),
                    subtitle: Text(
                      '${entry.supplierNameSnapshot ?? '仕入先未設定'}\n${dateFormat.format(entry.issueDate)}  /  ${currencyFormat.format(entry.amountTaxIncl)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('残余', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text(currencyFormat.format(outstanding),
                            style: TextStyle(color: outstanding > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error)),
                      ],
                    ),
                    onTap: () => Navigator.pop(context, entry),
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
