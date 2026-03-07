import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/invoice_repository.dart';
import '../services/pdf_generator.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import 'invoice_input_screen.dart';

class InvoiceIssueScreen extends StatefulWidget {
  const InvoiceIssueScreen({super.key});

  @override
  State<InvoiceIssueScreen> createState() => _InvoiceIssueScreenState();
}

enum _InvoiceIssueFilter { pending, issued }

class _InvoiceIssueScreenState extends State<InvoiceIssueScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final NumberFormat _currencyFormatter = NumberFormat('#,###');
  bool _loading = true;
  _InvoiceIssueFilter _filter = _InvoiceIssueFilter.pending;
  List<Invoice> _invoices = [];
  final Map<String, bool> _issuing = {};
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customers = await _customerRepo.getAllCustomers();
    final invoices = await _invoiceRepo.getAllInvoices(customers);
    if (!mounted) return;
    setState(() {
      _invoices = invoices.where((inv) => inv.documentType == DocumentType.invoice).toList();
      _loading = false;
    });
  }

  List<Invoice> get _visibleInvoices {
    final query = _searchController.text.trim().toLowerCase();
    bool matchesFilter(Invoice inv) {
      if (_filter == _InvoiceIssueFilter.pending && !inv.isDraft) return false;
      if (_filter == _InvoiceIssueFilter.issued && inv.isDraft) return false;
      if (query.isNotEmpty) {
        final number = inv.invoiceNumber.toLowerCase();
        final customer = inv.customerNameForDisplay.toLowerCase();
        if (!customer.contains(query) && !number.contains(query)) {
          return false;
        }
      }
      if (_startDate != null && inv.date.isBefore(_startDate!)) return false;
      if (_endDate != null && inv.date.isAfter(_endDate!)) return false;
      return true;
    }

    final filtered = _invoices.where(matchesFilter).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered.take(100).toList();
  }

  Future<void> _pickDateRange({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(_endDate!)) {
          _startDate = _endDate;
        }
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _createInvoice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (_, __) {},
          initialDocumentType: DocumentType.invoice,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _formalIssue(Invoice invoice) async {
    if (invoice.isLocked || !invoice.isDraft) return;
    setState(() => _issuing[invoice.id] = true);
    try {
      final promoted = invoice.copyWith(isDraft: false, isLocked: true);
      await _invoiceRepo.saveInvoice(promoted);
      final pdfPath = await generateInvoicePdf(promoted);
      if (pdfPath != null) {
        await _invoiceRepo.saveInvoice(promoted.copyWith(filePath: pdfPath));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請求書を正式発行しました')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正式発行に失敗しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _issuing.remove(invoice.id));
      }
    }
  }

  Future<void> _openPreview(Invoice invoice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfPreviewPage(
          invoice: invoice,
          isUnlocked: true,
          isLocked: invoice.isLocked,
          allowFormalIssue: invoice.isDraft && !invoice.isLocked,
          onFormalIssue: () async {
            await _formalIssue(invoice);
            return true;
          },
          showShare: true,
          showEmail: true,
          showPrint: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _visibleInvoices;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('IV:請求書発行'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInvoice,
        icon: const Icon(Icons.add),
        label: const Text('新規請求書'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '顧客名・伝票番号で検索',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDateRange(isStart: true),
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(_startDate == null ? '開始日未設定' : '開始: ${DateFormat('yyyy/MM/dd').format(_startDate!)}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDateRange(isStart: false),
                                icon: const Icon(Icons.event, size: 18),
                                label: Text(_endDate == null ? '終了日未設定' : '終了: ${DateFormat('yyyy/MM/dd').format(_endDate!)}'),
                              ),
                            ),
                            IconButton(
                              tooltip: '検索条件リセット',
                              onPressed: _searchController.text.isEmpty && _startDate == null && _endDate == null ? null : _clearFilters,
                              icon: const Icon(Icons.clear_all),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ToggleButtons(
                      isSelected: _InvoiceIssueFilter.values.map((f) => f == _filter).toList(),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: (index) => setState(() => _filter = _InvoiceIssueFilter.values[index]),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('未発行')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('発行済')),
                      ],
                    ),
                  ),
                  if (invoices.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(_filter == _InvoiceIssueFilter.pending ? '未発行の請求書はありません' : '発行済みの請求書はありません'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          final issuing = _issuing[invoice.id] ?? false;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          invoice.customerNameForDisplay,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(invoice.isDraft ? '未発行' : '発行済'),
                                        backgroundColor: invoice.isDraft ? Colors.orange.shade50 : Colors.green.shade50,
                                        labelStyle: TextStyle(color: invoice.isDraft ? Colors.orange.shade800 : Colors.green.shade800),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('請求日: ${DateFormat('yyyy/MM/dd').format(invoice.date)}'),
                                  Text('金額: ￥${_currencyFormatter.format(invoice.totalAmount)}'),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _openPreview(invoice),
                                        icon: const Icon(Icons.picture_as_pdf),
                                        label: const Text('プレビュー'),
                                      ),
                                      const SizedBox(width: 12),
                                      if (invoice.isDraft && !invoice.isLocked)
                                        FilledButton.icon(
                                          onPressed: issuing ? null : () => _formalIssue(invoice),
                                          icon: issuing
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Icon(Icons.check_circle),
                                          label: Text(issuing ? '発行中...' : '正式発行'),
                                        )
                                      else
                                        TextButton.icon(
                                          onPressed: () => _openPreview(invoice),
                                          icon: const Icon(Icons.share),
                                          label: const Text('再送'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
