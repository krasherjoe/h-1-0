import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_list_style.dart';
import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/app_settings_repository.dart';
import '../services/invoice_repository.dart';
import '../services/pdf_generator.dart';
import '../services/storage_monitor.dart';
import '../utils/theme_utils.dart';
import '../theme/invoice_list_style_theme.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import '../widgets/storage_warning_dialog.dart';
import 'invoice_input_screen.dart';

/// Q1: 見積入力画面（IV画面を流用）
class QuotationInputScreen extends StatefulWidget {
  const QuotationInputScreen({super.key});

  @override
  State<QuotationInputScreen> createState() => _QuotationInputScreenState();
}

enum _QuotationFilter { draft, confirmed }

class _QuotationInputScreenState extends State<QuotationInputScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  final NumberFormat _currencyFormatter = NumberFormat('#,###');
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');
  bool _loading = true;
  _QuotationFilter _filter = _QuotationFilter.draft;
  List<Invoice> _quotations = [];
  final Map<String, bool> _confirming = {};
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  InvoiceListStyle _listStyle = InvoiceListStyle.legacy;

  @override
  void initState() {
    super.initState();
    _load();
    _loadListStyle();
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
      _quotations = invoices.where((inv) => inv.documentType == DocumentType.estimation).toList();
      _loading = false;
    });
    await _loadListStyle();
  }

  Future<void> _loadListStyle() async {
    final style = await _settingsRepo.getInvoiceListStyle();
    if (!mounted) return;
    setState(() => _listStyle = style);
  }

  InvoiceListStyleTheme get _currentListTheme => InvoiceListStyleThemes.resolve(_listStyle, Theme.of(context).colorScheme);

  bool get _isA2Style => _listStyle == InvoiceListStyle.a2;

  Widget? _buildStatusChip(bool isDraft, InvoiceListStyleTheme theme, ColorScheme cs) {
    if (!theme.showStatusChip) return null;
    final bg = isDraft ? cs.secondaryContainer.withValues(alpha: 0.3) : cs.primaryContainer.withValues(alpha: 0.3);
    final color = isDraft ? cs.secondary : cs.primary;
    final label = isDraft ? '下書き' : '確定';
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: color),
    );
  }

  List<Invoice> get _visibleQuotations {
    final query = _searchController.text.trim().toLowerCase();

    bool matchesFilter(Invoice quotation) {
      if (_filter == _QuotationFilter.draft && !quotation.isDraft) return false;
      if (_filter == _QuotationFilter.confirmed && quotation.isDraft) return false;
      if (query.isNotEmpty) {
        final number = quotation.invoiceNumber.toLowerCase();
        final customer = quotation.customerNameForDisplay.toLowerCase();
        if (!number.contains(query) && !customer.contains(query)) {
          return false;
        }
      }
      if (_startDate != null && quotation.date.isBefore(_startDate!)) return false;
      if (_endDate != null && quotation.date.isAfter(_endDate!)) return false;
      return true;
    }

    final filtered = _quotations.where(matchesFilter).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered.take(100).toList();
  }

  Future<void> _pickDate({required bool isStart}) async {
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

  Future<void> _createQuotation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (_, __) {},
          initialDocumentType: DocumentType.estimation,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _editQuotation(Invoice quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (_, __) {},
          existingInvoice: quotation,
          initialDocumentType: DocumentType.estimation,
          startViewMode: false,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<bool> _confirmDialog(Invoice quotation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確定してよろしいですか？'),
        content: Text('${quotation.customerNameForDisplay}\nこの見積を確定すると編集できなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定する')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmQuotation(Invoice quotation) async {
    if (quotation.isLocked || !quotation.isDraft) return;
    setState(() => _confirming[quotation.id] = true);
    try {
      final confirmed = quotation.copyWith(isDraft: false, isLocked: true);
      await _invoiceRepo.saveInvoice(confirmed);
      final pdfPath = await generateInvoicePdf(confirmed);
      if (pdfPath != null) {
        await _invoiceRepo.saveInvoice(confirmed.copyWith(filePath: pdfPath));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('見積を確定しました')));
      await _load();
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('ストレージ容量不足')) {
          final space = await StorageMonitor().getAvailableSpaceFormatted();
          await StorageWarningDialog.showBlocking(context, space);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('確定に失敗しました: $e')));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _confirming.remove(quotation.id));
      }
    }
  }

  Future<void> _handleConfirmLongPress(Invoice quotation) async {
    final ok = await _confirmDialog(quotation);
    if (!ok) return;
    await _confirmQuotation(quotation);
  }

  Future<void> _openPreview(Invoice quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfPreviewPage(
          invoice: quotation,
          isUnlocked: true,
          isLocked: quotation.isLocked,
          allowFormalIssue: quotation.isDraft && !quotation.isLocked,
          onFormalIssue: () async {
            final ok = await _confirmDialog(quotation);
            if (!ok) return false;
            await _confirmQuotation(quotation);
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

  Future<void> _convertToOrder(Invoice quotation) async {
    final newInvoice = quotation.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentType: DocumentType.invoice,
      isDraft: true,
      isLocked: false,
      date: DateTime.now(),
      filePath: null,
      metaJson: null,
      metaHash: null,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (_, __) {},
          existingInvoice: newInvoice,
          startViewMode: false,
          showCopyBadge: true,
        ),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('受注（請求）伝票に変換しました。内容を確認して保存してください')));
    await _load();
  }

  Future<void> _showQuotationActions(Invoice quotation) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDFプレビュー'),
              onTap: () async {
                Navigator.pop(context);
                await _openPreview(quotation);
              },
            ),
            if (quotation.isDraft && !quotation.isLocked)
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('確定'),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleConfirmLongPress(quotation);
                },
              ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('受注変換'),
              onTap: () async {
                Navigator.pop(context);
                await _convertToOrder(quotation);
              },
            ),
            if (!quotation.isLocked)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('編集'),
                onTap: () async {
                  Navigator.pop(context);
                  await _editQuotation(quotation);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quotations = _visibleQuotations;
    final styleTheme = _currentListTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: documentTypeColor(DocumentType.estimation, cs, isDark),
        foregroundColor: appBarForeground(documentTypeColor(DocumentType.estimation, cs, isDark)),
        title: const Text('Q1:見積入力'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createQuotation,
        icon: const Icon(Icons.add),
        label: const Text('新規見積'),
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
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDate(isStart: true),
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(_startDate == null ? '開始日未設定' : '開始: ${DateFormat('yyyy/MM/dd').format(_startDate!)}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDate(isStart: false),
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
                      isSelected: _QuotationFilter.values.map((f) => f == _filter).toList(),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: (index) => setState(() => _filter = _QuotationFilter.values[index]),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('下書き')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('確定済')),
                      ],
                    ),
                  ),
                  if (quotations.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(_filter == _QuotationFilter.draft ? '下書き見積はありません' : '確定済み見積はありません'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: quotations.length,
                        itemBuilder: (context, index) {
                          final quotation = quotations[index];
                          final confirming = _confirming[quotation.id] ?? false;
                          final bool isDraft = quotation.isDraft;
                          final subject = quotation.subject?.trim().isNotEmpty == true
                              ? quotation.subject!
                              : (quotation.items.isNotEmpty ? quotation.items.first.description : '');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: styleTheme.cardColor(isDraft),
                            elevation: styleTheme.cardElevation(isDraft),
                            shape: styleTheme.cardShape,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (isDraft)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, right: 8),
                                          child: Icon(Icons.edit_note, size: 20, color: Theme.of(context).colorScheme.secondary),
                                        ),
                                      Text(_dateFormatter.format(quotation.date), style: const TextStyle(fontSize: 12)),
                                      const Spacer(),
                                      Text(quotation.customerNameForDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('￥${_currencyFormatter.format(quotation.totalAmount)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (isDraft)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('下書き', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                                        ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: () => _openPreview(quotation),
                                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                                        label: const Text('PDFプレビュー', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      ),
                                      const SizedBox(width: 8),
                                      if (quotation.isDraft && !quotation.isLocked)
                                        GestureDetector(
                                          onLongPress: confirming ? null : () => _handleConfirmLongPress(quotation),
                                          behavior: HitTestBehavior.opaque,
                                          child: FilledButton.tonalIcon(
                                            onPressed: confirming ? null : () {
                                              final messenger = ScaffoldMessenger.of(context);
                                              messenger.hideCurrentSnackBar();
                                              messenger.showSnackBar(const SnackBar(content: Text('長押しで確定します')));
                                            },
                                            icon: confirming
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Icon(Icons.check_circle, size: 16),
                                            label: Text(confirming ? '' : '確定', style: const TextStyle(fontSize: 11)),
                                          ),
                                        ),
                                      if (!quotation.isLocked)
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () => _editQuotation(quotation),
                                          tooltip: '編集',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
