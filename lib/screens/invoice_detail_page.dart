import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'product_picker_modal.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailPage({Key? key, required this.invoice}) : super(key: key);

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late TextEditingController _formalNameController;
  late TextEditingController _notesController;
  late List<InvoiceItem> _items;
  late bool _isEditing;
  late Invoice _currentInvoice;
  String? _currentFilePath;
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
    _currentFilePath = widget.invoice.filePath;
    _formalNameController = TextEditingController(text: _currentInvoice.customer.formalName);
    _notesController = TextEditingController(text: _currentInvoice.notes ?? "");
    _items = List.from(_currentInvoice.items);
    _isEditing = false;
  }

  @override
  void dispose() {
    _formalNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItem(description: "新項目", quantity: 1, unitPrice: 0));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _pickFromMaster() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ProductPickerModal(
          onItemSelected: (item) {
            setState(() {
              _items.add(item);
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final String formalName = _formalNameController.text.trim();
    if (formalName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取引先の正式名称を入力してください')),
      );
      return;
    }

    // 顧客情報を更新
    final updatedCustomer = _currentInvoice.customer.copyWith(
      formalName: formalName,
    );

    final updatedInvoice = _currentInvoice.copyWith(
      customer: updatedCustomer,
      items: _items,
      notes: _notesController.text,
    );

    // データベースに保存
    await _invoiceRepo.saveInvoice(updatedInvoice);
    
    // 顧客の正式名称が変更されている可能性があるため、マスターも更新
    if (updatedCustomer.formalName != widget.invoice.customer.formalName) {
      await _customerRepo.saveCustomer(updatedCustomer);
    }

    setState(() => _isEditing = false);

    final newPath = await generateInvoicePdf(updatedInvoice);
    if (newPath != null) {
      final finalInvoice = updatedInvoice.copyWith(filePath: newPath);
      await _invoiceRepo.saveInvoice(finalInvoice); // パスを更新して再保存
      
      setState(() {
        _currentInvoice = finalInvoice;
        _currentFilePath = newPath;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データベースとPDFを更新しました')),
      );
    }
  }

  void _exportCsv() {
    final csvData = _currentInvoice.toCsv();
    Share.share(csvData, subject: '請求書データ_CSV');
  }

  @override
  Widget build(BuildContext context) {
    final amountFormatter = NumberFormat("#,###");

    return Scaffold(
      appBar: AppBar(
        title: const Text("販売アシスト1号 請求書詳細"),
        backgroundColor: Colors.blueGrey,
        actions: [
          if (!_isEditing) ...[
            IconButton(icon: const Icon(Icons.grid_on), onPressed: _exportCsv, tooltip: "CSV出力"),
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
          ] else ...[
            IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
            IconButton(icon: const Icon(Icons.cancel), onPressed: () => setState(() => _isEditing = false)),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const Divider(height: 32),
            const Text("明細一覧", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildItemTable(amountFormatter),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text("空の行を追加"),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickFromMaster,
                      icon: const Icon(Icons.list_alt),
                      label: const Text("マスターから選択"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildSummarySection(amountFormatter),
            const SizedBox(height: 24),
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final dateFormatter = DateFormat('yyyy年MM月dd日');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isEditing) ...[
          TextField(
            controller: _formalNameController,
            decoration: const InputDecoration(labelText: "取引先 正式名称", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: "備考", border: OutlineInputBorder()),
          ),
        ] else ...[
          Text("${_currentInvoice.customer.formalName} ${_currentInvoice.customer.title}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (_currentInvoice.customer.department != null && _currentInvoice.customer.department!.isNotEmpty)
            Text(_currentInvoice.customer.department!, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text("請求番号: ${_currentInvoice.invoiceNumber}"),
          Text("発行日: ${dateFormatter.format(_currentInvoice.date)}"),
          if (_currentInvoice.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text("備考: ${_currentInvoice.notes}", style: const TextStyle(color: Colors.black87)),
          ]
        ],
      ],
    );
  }

  Widget _buildItemTable(NumberFormat formatter) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FixedColumnWidth(50),
        2: FixedColumnWidth(80),
        3: FlexColumnWidth(2),
        4: FixedColumnWidth(40),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _TableCell("品名"), _TableCell("数量"), _TableCell("単価"), _TableCell("金額"), _TableCell(""),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          int idx = entry.key;
          InvoiceItem item = entry.value;
          if (_isEditing) {
            return TableRow(children: [
              _EditableCell(
                initialValue: item.description,
                onChanged: (val) => item.description = val,
              ),
              _EditableCell(
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                onChanged: (val) => setState(() => item.quantity = int.tryParse(val) ?? 0),
              ),
              _EditableCell(
                initialValue: item.unitPrice.toString(),
                keyboardType: TextInputType.number,
                onChanged: (val) => setState(() => item.unitPrice = int.tryParse(val) ?? 0),
              ),
              _TableCell(formatter.format(item.subtotal)),
              IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _removeItem(idx)),
            ]);
          } else {
            return TableRow(children: [
              _TableCell(item.description),
              _TableCell(item.quantity.toString()),
              _TableCell(formatter.format(item.unitPrice)),
              _TableCell(formatter.format(item.subtotal)),
              const SizedBox(),
            ]);
          }
        }),
      ],
    );
  }

  Widget _buildSummarySection(NumberFormat formatter) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 200,
        child: Column(
          children: [
            _SummaryRow("小計 (税抜)", formatter.format(_isEditing ? _calculateCurrentSubtotal() : _currentInvoice.subtotal)),
            _SummaryRow("消費税 (10%)", formatter.format(_isEditing ? (_calculateCurrentSubtotal() * 0.1).floor() : _currentInvoice.tax)),
            const Divider(),
            _SummaryRow("合計 (税込)", "￥${formatter.format(_isEditing ? (_calculateCurrentSubtotal() * 1.1).floor() : _currentInvoice.totalAmount)}", isBold: true),
          ],
        ),
      ),
    );
  }

  int _calculateCurrentSubtotal() {
    return _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Widget _buildFooterActions() {
    if (_isEditing || _currentFilePath == null) return const SizedBox();
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openPdf,
            icon: const Icon(Icons.launch),
            label: const Text("PDFを開く"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _sharePdf,
            icon: const Icon(Icons.share),
            label: const Text("共有"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _openPdf() async => await OpenFilex.open(_currentFilePath!);
  Future<void> _sharePdf() async {
    if (_currentFilePath != null) {
      await Share.shareXFiles([XFile(_currentFilePath!)], text: '請求書送付');
    }
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
  );
}

class _EditableCell extends StatelessWidget {
  final String initialValue;
  final TextInputType keyboardType;
  final Function(String) onChanged;
  const _EditableCell({required this.initialValue, this.keyboardType = TextInputType.text, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0),
    child: TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
      onChanged: onChanged,
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  const _SummaryRow(this.label, this.value, {this.isBold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : null)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : null)),
      ],
    ),
  );
}
