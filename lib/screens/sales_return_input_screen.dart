import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'customer_master_screen.dart';

class SalesReturnInputScreen extends StatefulWidget {
  const SalesReturnInputScreen({super.key});

  @override
  State<SalesReturnInputScreen> createState() => _SalesReturnInputScreenState();
}

class _SalesReturnInputScreenState extends State<SalesReturnInputScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  
  Customer? _selectedCustomer;
  List<Invoice> _customerInvoices = [];
  Invoice? _selectedInvoice;
  final Map<String, int> _returnQuantities = {}; // itemId -> 返品数量
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );

    if (customer == null) return;

    setState(() {
      _selectedCustomer = customer;
      _selectedInvoice = null;
      _returnQuantities.clear();
    });

    await _loadCustomerInvoices();
  }

  Future<void> _loadCustomerInvoices() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);

    final customers = await _customerRepo.getAllCustomers();
    final allInvoices = await _repo.getAllInvoices(customers);

    if (!mounted) return;

    setState(() {
      // 選択した顧客の売上伝票のみ（請求書・領収書）
      _customerInvoices = allInvoices
          .where((inv) =>
              inv.customer.id == _selectedCustomer!.id &&
              (inv.documentType == DocumentType.invoice ||
               inv.documentType == DocumentType.receipt) &&
              !inv.isDraft) // 正式発行済みのみ
          .toList();
      
      _customerInvoices.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
    });
  }

  void _selectInvoice(Invoice invoice) {
    setState(() {
      _selectedInvoice = invoice;
      _returnQuantities.clear();
      // 初期値として全商品の返品数量を0に設定
      for (final item in invoice.items) {
        _returnQuantities[item.id!] = 0;
      }
    });
  }

  void _updateReturnQuantity(String itemId, int quantity) {
    setState(() {
      _returnQuantities[itemId] = quantity;
    });
  }

  bool get _canSave {
    if (_selectedInvoice == null) return false;
    final totalReturnQty = _returnQuantities.values.fold<int>(0, (sum, qty) => sum + qty);
    return totalReturnQty > 0;
  }

  Future<void> _saveReturn() async {
    if (!_canSave) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('返品伝票作成'),
        content: const Text('返品伝票を作成しますか？\n在庫が戻され、マイナス伝票が記録されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 返品明細を作成（数量をマイナスにする）
    final returnItems = <InvoiceItem>[];
    for (final item in _selectedInvoice!.items) {
      final returnQty = _returnQuantities[item.id] ?? 0;
      if (returnQty > 0) {
        returnItems.add(InvoiceItem(
          id: const Uuid().v4(),
          productId: item.productId,
          description: item.description,
          quantity: -returnQty, // マイナス数量
          unitPrice: item.unitPrice,
        ));
      }
    }

    // 返品伝票を作成
    final returnInvoice = Invoice(
      id: const Uuid().v4(),
      customer: _selectedInvoice!.customer,
      date: DateTime.now(),
      items: returnItems,
      notes: '返品理由: ${_reasonController.text}\n元伝票ID: ${_selectedInvoice!.id}',
      taxRate: _selectedInvoice!.taxRate,
      documentType: DocumentType.invoice, // 請求書タイプで記録
      isDraft: false, // 正式発行
      subject: '返品: ${_selectedInvoice!.subject ?? ''}',
      isLocked: false,
      terminalId: 'T1',
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await _repo.saveInvoice(returnInvoice);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('返品伝票を作成しました')),
    );

    // 画面をリセット
    setState(() {
      _selectedInvoice = null;
      _returnQuantities.clear();
      _reasonController.clear();
    });

    await _loadCustomerInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('SR1:売上返品入力'),
      ),
      body: Column(
        children: [
          // 顧客選択セクション
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedCustomer == null
                        ? '顧客を選択してください'
                        : _selectedCustomer!.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectCustomer,
                  icon: const Icon(Icons.person),
                  label: const Text('顧客選択'),
                ),
              ],
            ),
          ),

          // 売上伝票一覧
          if (_selectedCustomer != null && _selectedInvoice == null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '返品元の売上伝票を選択',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _customerInvoices.isEmpty
                      ? const Center(
                          child: Text('正式発行済みの売上伝票がありません'),
                        )
                      : ListView.builder(
                          itemCount: _customerInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _customerInvoices[index];
                            return _buildInvoiceCard(invoice);
                          },
                        ),
            ),
          ],

          // 返品明細入力
          if (_selectedInvoice != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '元伝票: ${_selectedInvoice!.subject ?? "無題"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedInvoice = null;
                            _returnQuantities.clear();
                          });
                        },
                        child: const Text('変更'),
                      ),
                    ],
                  ),
                  Text(
                    '日付: ${DateFormat('yyyy/MM/dd').format(_selectedInvoice!.date)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedInvoice!.items.length,
                itemBuilder: (context, index) {
                  final item = _selectedInvoice!.items[index];
                  return _buildReturnItemCard(item);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('返品理由', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '返品理由を入力してください',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSave ? _saveReturn : null,
                      child: const Text('返品伝票を作成'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final total = invoice.items.fold<int>(0, (sum, item) => sum + item.subtotal);
    final taxAmount = (total * invoice.taxRate).round();
    final grandTotal = total + taxAmount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(invoice.subject ?? '無題'),
        subtitle: Text(DateFormat('yyyy/MM/dd').format(invoice.date)),
        trailing: Text(
          '¥${NumberFormat('#,###').format(grandTotal)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () => _selectInvoice(invoice),
      ),
    );
  }

  Widget _buildReturnItemCard(InvoiceItem item) {
    final returnQty = _returnQuantities[item.id] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('元数量: ${item.quantity}'),
                const Spacer(),
                Text('単価: ¥${NumberFormat('#,###').format(item.unitPrice)}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('返品数量:'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: returnQty > 0
                      ? () => _updateReturnQuantity(item.id!, returnQty - 1)
                      : null,
                ),
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  child: Text(
                    returnQty.toString(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: returnQty < item.quantity
                      ? () => _updateReturnQuantity(item.id!, returnQty + 1)
                      : null,
                ),
                const Spacer(),
                Text(
                  '返品額: ¥${NumberFormat('#,###').format(returnQty * item.unitPrice)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
