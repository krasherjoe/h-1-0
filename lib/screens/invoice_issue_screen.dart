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
import '../theme/invoice_list_style_theme.dart';
import '../widgets/invoice_list_a2_card.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import '../widgets/storage_warning_dialog.dart';
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
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  final NumberFormat _currencyFormatter = NumberFormat('#,###');
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');
  bool _loading = true;
  _InvoiceIssueFilter _filter = _InvoiceIssueFilter.pending;
  List<Invoice> _invoices = [];
  final Map<String, bool> _issuing = {};
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  InvoiceListStyle _listStyle = InvoiceListStyle.legacy;
  Set<String> _redInvoiceSourceIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadListStyle();
  }

  Future<void> _editInvoice(Invoice invoice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: invoice,
          onInvoiceGenerated: (updated, path) {},
          initialDocumentType: DocumentType.invoice,
          startViewMode: false,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<bool> _confirmFormalIssue(Invoice invoice) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('正式発行の確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${invoice.customerNameForDisplay}'),
            const SizedBox(height: 8),
            const Text('この請求書を正式発行すると、\n電子帳簿保存法により二度と編集できなくなります。\n\n確定してよろしいですか？'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定する')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleFormalIssueLongPress(Invoice invoice) async {
    final confirmed = await _confirmFormalIssue(invoice);
    if (!confirmed) return;
    await _formalIssue(invoice);
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
      _redInvoiceSourceIds = _invoices
          .where((i) => i.isRedInvoice && i.sourceDocumentId != null)
          .map((i) => i.sourceDocumentId!)
          .toSet();
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

  Future<void> _showInvoiceActions(Invoice invoice) async {
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
                await _openPreview(invoice);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('PDF再送'),
              onTap: () async {
                Navigator.pop(context);
                await _openPreview(invoice);
              },
            ),
            if (invoice.isDraft && !invoice.isLocked)
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('正式発行'),
                subtitle: const Text('長押しで正式発行（電子帳簿保存法対応）'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正式発行するには長押ししてください')),
                  );
                },
                onLongPress: () async {
                  Navigator.pop(context);
                  await _handleFormalIssueLongPress(invoice);
                },
              ),
            if (!invoice.isLocked)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('編集'),
                onTap: () async {
                  Navigator.pop(context);
                  await _editInvoice(invoice);
                },
              ),
            const Divider(),
            FutureBuilder<bool>(
              future: _invoiceRepo.hasSales(invoice.id),
              builder: (context, snapshot) {
                final hasSales = snapshot.data ?? false;
                return ListTile(
                  leading: Icon(Icons.receipt_long, color: hasSales ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                  title: const Text('売上伝票'),
                  subtitle: Text(hasSales ? '作成済み' : '未作成'),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.payments, color: invoice.getPaymentStatusColor(Theme.of(context).colorScheme)),
              title: const Text('入金状況'),
              subtitle: Text(invoice.paymentStatusDisplay),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildStatusChip(bool isDraft, InvoiceListStyleTheme theme, ColorScheme cs) {
    if (!theme.showStatusChip) return null;
    final bg = isDraft ? cs.primary.withValues(alpha: 0.12) : cs.primaryContainer.withValues(alpha: 0.3);
    final color = isDraft ? cs.onSurfaceVariant : cs.primary;
    final label = isDraft ? '未発行' : '発行済';
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: color),
    );
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
          onInvoiceGenerated: (invoice, path) {},
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
        if (e.toString().contains('ストレージ容量不足')) {
          final space = await StorageMonitor().getAvailableSpaceFormatted();
          await StorageWarningDialog.showBlocking(context, space);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正式発行に失敗しました: $e')));
        }
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
    final styleTheme = _currentListTheme;
    final isA2Style = _isA2Style;
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
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          if (isA2Style) {
                            return InvoiceListA2Card(
                              invoice: invoice,
                              amountFormatter: _currencyFormatter,
                              dateFormatter: _dateFormatter,
                              draftLabel: '未発行',
                              onTap: () => _openPreview(invoice),
                              onLongPress: () => _showInvoiceActions(invoice),
                              hasRedInvoice: _redInvoiceSourceIds.contains(invoice.id),
                            );
                          }

                          final issuing = _issuing[invoice.id] ?? false;
                          final bool isDraft = invoice.isDraft;
                          final bool isRed = invoice.isRedInvoice;
                           final bool isCancelled = _redInvoiceSourceIds.contains(invoice.id);
                           final cs = Theme.of(context).colorScheme;
                           final statusChip = _buildStatusChip(isDraft, styleTheme, cs);
                           return Card(
                             margin: const EdgeInsets.only(bottom: 12),
                             color: isRed
                                 ? cs.error.withValues(alpha: 0.08)
                                 : (isCancelled ? cs.error.withValues(alpha: 0.04) : styleTheme.cardColor(isDraft)),
                             elevation: styleTheme.cardElevation(isDraft),
                             shape: (isRed || isCancelled)
                                 ? RoundedRectangleBorder(
                                     borderRadius: BorderRadius.circular(12),
                                     side: BorderSide(color: cs.error.withValues(alpha: 0.3), width: 1.5),
                                   )
                                 : styleTheme.cardShape,
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
if (isRed)
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                           margin: const EdgeInsets.only(right: 6),
                                           decoration: BoxDecoration(
                                             color: cs.error.withValues(alpha: 0.12),
                                             borderRadius: BorderRadius.circular(10),
                                           ),
                                           child: Text(
                                             '赤伝',
                                             style: TextStyle(
                                               fontSize: 11,
                                               fontWeight: FontWeight.w700,
                                               color: cs.error,
                                             ),
                                           ),
                                         )
                                       else if (isCancelled)
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                           margin: const EdgeInsets.only(right: 6),
                                           decoration: BoxDecoration(
                                             color: cs.error.withValues(alpha: 0.12),
                                             borderRadius: BorderRadius.circular(10),
                                           ),
                                           child: Text(
                                             '赤伝済',
                                             style: TextStyle(
                                               fontSize: 11,
                                               fontWeight: FontWeight.w700,
                                               color: cs.error,
                                             ),
                                           ),
                                         )
                                      else if (statusChip != null) ...[
                                        const SizedBox(width: 8),
                                        statusChip,
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('請求日: ${_dateFormatter.format(invoice.date)}'),
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
                                          onPressed: issuing
                                              ? null
                                              : () {
                                                  final messenger = ScaffoldMessenger.of(context);
                                                  messenger.hideCurrentSnackBar();
                                                  messenger.showSnackBar(
                                                    const SnackBar(content: Text('長押しで正式発行を確定します')),
                                                  );
                                                },
                                          onLongPress: issuing ? null : () => _handleFormalIssueLongPress(invoice),
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
                                      const Spacer(),
                                      if (!invoice.isLocked)
                                        TextButton.icon(
                                          onPressed: () => _editInvoice(invoice),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('編集'),
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
