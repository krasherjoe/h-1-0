import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/sales_model.dart';
import '../models/customer_model.dart';
import '../services/sales_repository.dart';
import '../services/database_helper.dart';
import '../widgets/document_card.dart';
import 'customer_picker_modal.dart';

/// SE1: 売上入力フォーム
class SalesInputScreen extends StatefulWidget {
  final Sales? existingSales;
  const SalesInputScreen({super.key, this.existingSales});

  @override
  State<SalesInputScreen> createState() => _SalesInputScreenState();
}

class _SalesInputScreenState extends State<SalesInputScreen> {
  final _repo = SalesRepository();

  final _subjectController = TextEditingController();
  final _amountController = TextEditingController();

  Customer? _selectedCustomer;
  DateTime _selectedDate = DateTime.now();
  bool _includeTax = true;
  double _taxRate = 0.10;
  bool _isDraft = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSales != null) {
      _loadExisting(widget.existingSales!);
    }
  }

  void _loadExisting(Sales s) {
    _selectedCustomer = s.customer;
    _subjectController.text = s.subject ?? '';
    _amountController.text = s.total.toString();
    _selectedDate = s.date;
    _taxRate = s.taxRate;
    _isDraft = s.status == DocumentStatus.draft;
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

  int _parseAmount() {
    final text = _amountController.text.replaceAll(',', '');
    return int.tryParse(text) ?? 0;
  }

  (int subtotal, int tax, int total) _calculate() {
    final amount = _parseAmount();
    if (!_includeTax) {
      final tax = (amount * _taxRate).round();
      return (amount, tax, amount + tax);
    }
    // 税込金額から逆算
    final subtotal = (amount / (1 + _taxRate)).round();
    final tax = amount - subtotal;
    return (subtotal, tax, amount);
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('顧客を選択してください')),
      );
      return;
    }

    final amount = _parseAmount();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額を入力してください')),
      );
      return;
    }

    setState(() => _saving = true);

    final (subtotal, tax, total) = _calculate();
    final now = DateTime.now();
    final sales = Sales(
      id: widget.existingSales?.id ?? Uuid().v4(),
      documentNumber: widget.existingSales?.documentNumber ?? await _generateDocumentNumber(),
      date: _selectedDate,
      customer: _selectedCustomer,
      items: [],
      subtotal: subtotal,
      taxAmount: tax,
      total: total,
      taxRate: _taxRate,
      notes: null,
      subject: _subjectController.text.isNotEmpty ? _subjectController.text : null,
      status: _isDraft ? DocumentStatus.draft : DocumentStatus.confirmed,
      invoiceId: widget.existingSales?.invoiceId,
      createdAt: widget.existingSales?.createdAt ?? now,
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
    final theme = Theme.of(context);
    final isEdit = widget.existingSales != null;
    final (subtotal, tax, total) = _calculate();

    return Scaffold(
      appBar: AppBar(
        title: Text('SE1:${isEdit ? '売上編集' : '売上入力'}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(color: Colors.white)),
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

          // 金額
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '金額',
              prefixIcon: Icon(Icons.currency_yen),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

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

          // ステータス
          SwitchListTile.adaptive(
            title: const Text('下書きとして保存'),
            subtitle: const Text('OFFにすると確定状態で保存されます'),
            value: _isDraft,
            onChanged: (v) => setState(() => _isDraft = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount, {bool isTotal = false}) {
    final formatted = '¥${amount.toString().replaceAllMapped(
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
}
