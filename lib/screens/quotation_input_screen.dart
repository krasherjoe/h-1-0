import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'invoice_input_screen.dart';
import 'customer_master_screen.dart';

class QuotationInputScreen extends StatefulWidget {
  const QuotationInputScreen({super.key});

  @override
  State<QuotationInputScreen> createState() => _QuotationInputScreenState();
}

class _QuotationInputScreenState extends State<QuotationInputScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  List<Invoice> _quotations = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, draft, locked

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepo.getAllCustomers();
    final allInvoices = await _repo.getAllInvoices(customers);
    
    if (!mounted) return;
    
    setState(() {
      // DocumentType.estimation のみフィルタ
      _quotations = allInvoices
          .where((inv) => inv.documentType == DocumentType.estimation)
          .toList();
      
      // 日付降順でソート
      _quotations.sort((a, b) => b.date.compareTo(a.date));
      
      _isLoading = false;
    });
  }

  List<Invoice> get _filteredQuotations {
    switch (_filterStatus) {
      case 'draft':
        return _quotations.where((q) => q.isDraft).toList();
      case 'locked':
        return _quotations.where((q) => q.isLocked).toList();
      default:
        return _quotations;
    }
  }

  Future<void> _createNewQuotation() async {
    // 顧客選択
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );

    if (customer == null || !mounted) return;

    // InvoiceInputForm を見積モードで起動
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (invoice, path) async {
            // 保存後の処理
            await _loadQuotations();
            if (!mounted) return;
            Navigator.pop(context);
          },
          initialDocumentType: DocumentType.estimation,
          startViewMode: false, // 編集モードで開始
          showNewBadge: true,
        ),
      ),
    );

    await _loadQuotations();
  }

  Future<void> _editQuotation(Invoice quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: quotation,
          onInvoiceGenerated: (invoice, path) async {
            await _loadQuotations();
            if (!mounted) return;
            Navigator.pop(context);
          },
          initialDocumentType: DocumentType.estimation,
          startViewMode: true,
        ),
      ),
    );

    await _loadQuotations();
  }

  Future<void> _copyQuotation(Invoice quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: quotation,
          onInvoiceGenerated: (invoice, path) async {
            await _loadQuotations();
            if (!mounted) return;
            Navigator.pop(context);
          },
          initialDocumentType: DocumentType.estimation,
          startViewMode: false,
          showCopyBadge: true,
        ),
      ),
    );

    await _loadQuotations();
  }

  Future<void> _deleteQuotation(Invoice quotation) async {
    if (quotation.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ロック済み見積は削除できません')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('見積削除'),
        content: Text('見積「${quotation.subject ?? '無題'}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.deleteInvoice(quotation.id);
    await _loadQuotations();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('見積を削除しました')),
    );
  }

  Future<void> _convertToOrder(Invoice quotation) async {
    // 見積を受注（納品書）に変換
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('受注変換'),
        content: const Text('この見積を受注（納品書）に変換しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('変換'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 新しい納品書として作成（IDは新規生成される）
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: quotation,
          onInvoiceGenerated: (invoice, path) async {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('受注（納品書）を作成しました')),
            );
          },
          initialDocumentType: DocumentType.delivery,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Q1:見積入力'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewQuotation,
            tooltip: '新規見積作成',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('全て')),
              const PopupMenuItem(value: 'draft', child: Text('下書きのみ')),
              const PopupMenuItem(value: 'locked', child: Text('正式発行のみ')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredQuotations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.request_quote, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _filterStatus == 'all'
                            ? '見積がありません'
                            : 'フィルタ条件に一致する見積がありません',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadQuotations,
                  child: ListView.builder(
                    itemCount: _filteredQuotations.length,
                    itemBuilder: (context, index) {
                      final quotation = _filteredQuotations[index];
                      return _buildQuotationCard(quotation);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewQuotation,
        icon: const Icon(Icons.add),
        label: const Text('新規見積'),
      ),
    );
  }

  Widget _buildQuotationCard(Invoice quotation) {
    final total = quotation.items.fold<int>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final taxAmount = (total * quotation.taxRate).round();
    final grandTotal = total + taxAmount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _editQuotation(quotation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quotation.customer.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (quotation.subject != null && quotation.subject!.isNotEmpty)
                          Text(
                            quotation.subject!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${NumberFormat('#,###').format(grandTotal)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd').format(quotation.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(quotation.isDraft ? '下書き' : '正式発行'),
                    backgroundColor: quotation.isDraft
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    labelStyle: TextStyle(
                      color: quotation.isDraft ? Colors.orange : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                  if (quotation.isLocked) ...[
                    const SizedBox(width: 8),
                    const Chip(
                      label: Text('ロック'),
                      backgroundColor: Colors.grey,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 20),
                    onPressed: () => _copyQuotation(quotation),
                    tooltip: 'コピー',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: () => _convertToOrder(quotation),
                    tooltip: '受注変換',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _deleteQuotation(quotation),
                    tooltip: '削除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
