import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';

/// 請求書選択モーダル（売上伝票への紐付け用）
class InvoicePickerModal extends StatefulWidget {
  final List<String>? selectedInvoiceIds;
  final Function(List<Invoice>) onInvoicesSelected;

  const InvoicePickerModal({
    super.key,
    this.selectedInvoiceIds,
    required this.onInvoicesSelected,
  });

  @override
  State<InvoicePickerModal> createState() => _InvoicePickerModalState();
}

class _InvoicePickerModalState extends State<InvoicePickerModal> {
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _searchCtrl = TextEditingController();

  List<Invoice> _allInvoices = [];
  List<Invoice> _filteredInvoices = [];
  Set<String> _selectedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.selectedInvoiceIds?.toSet() ?? {};
    _searchCtrl.addListener(() => setState(() {}));
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final customers = await _customerRepo.getAllCustomers();
    final invoices = await _invoiceRepo.getAllInvoices(customers);
    final invoiceOnly = invoices.where((i) => i.documentType == DocumentType.invoice).toList();
    if (!mounted) return;
    setState(() {
      _allInvoices = invoiceOnly;
      _filteredInvoices = invoiceOnly;
      _loading = false;
    });
  }

  void _onToggle(Invoice invoice) {
    setState(() {
      if (_selectedIds.contains(invoice.id)) {
        _selectedIds.remove(invoice.id);
      } else {
        _selectedIds.add(invoice.id);
      }
    });
  }

  void _onConfirm() {
    final selected = _allInvoices.where((i) => _selectedIds.contains(i.id)).toList();
    widget.onInvoicesSelected(selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    _filteredInvoices = _allInvoices.where((i) {
      if (query.isEmpty) return true;
      final subject = (i.subject ?? '').toLowerCase();
      final customer = (i.customerNameForDisplay).toLowerCase();
      return subject.contains(query) || customer.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('請求書を選択', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_selectedIds.length}件選択', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '件名・得意先で検索',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? const Center(child: Text('請求書がありません'))
                    : ListView.builder(
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          final isSelected = _selectedIds.contains(invoice.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _onToggle(invoice),
                            title: Text(
                              invoice.subject ?? '（件名なし）',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invoice.customerNameForDisplay),
                                Text(
                                  '￥${NumberFormat('#,###').format(invoice.totalAmount)}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            secondary: const Icon(Icons.receipt_long),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedIds.isEmpty ? null : _onConfirm,
                    child: const Text('選択'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
