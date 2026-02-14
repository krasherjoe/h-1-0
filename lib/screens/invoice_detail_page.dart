import 'package:flutter/material.dart';
import 'invoice_input_screen.dart'; // Add this line
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../services/company_repository.dart';
import 'product_picker_modal.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/print_service.dart';
import '../models/company_model.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;
  final bool isUnlocked;

  const InvoiceDetailPage({Key? key, required this.invoice, this.isUnlocked = false}) : super(key: key);

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late TextEditingController _formalNameController;
  late TextEditingController _notesController;
  late List<InvoiceItem> _items;
  late bool _isEditing;
  late Invoice _currentInvoice;
  late double _taxRate; // 追加
  late bool _includeTax; // 追加
  String? _currentFilePath;
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _companyRepo = CompanyRepository();
  CompanyInfo? _companyInfo;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
    _currentFilePath = widget.invoice.filePath;
    _formalNameController = TextEditingController(text: _currentInvoice.customer.formalName);
    _notesController = TextEditingController(text: _currentInvoice.notes ?? "");
    _items = List.from(_currentInvoice.items);
    _taxRate = _currentInvoice.taxRate; // 初期化
    _includeTax = _currentInvoice.taxRate > 0; // 初期化
    _isEditing = false;
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    final info = await _companyRepo.getCompanyInfo();
    setState(() => _companyInfo = info);
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
      taxRate: _includeTax ? _taxRate : 0.0, // 更新
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

  Future<void> _printReceipt() async {
    final printService = PrintService();
    final isConnected = await printService.isConnected;
    
    if (!isConnected) {
      final devices = await printService.getPairedDevices();
      if (devices.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ペアリング済みのデバイスが見つかりません。OSの設定を確認してください。")));
        return;
      }
      
      final selected = await showDialog<BluetoothInfo>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("プリンターを選択"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, idx) => ListTile(
                leading: const Icon(Icons.print),
                title: Text(devices[idx].name ?? "Unknown Device"),
                subtitle: Text(devices[idx].macAdress ?? ""),
                onTap: () => Navigator.pop(context, devices[idx]),
              ),
            ),
          ),
        ),
      );
      
      if (selected != null) {
        final ok = await printService.connect(selected.macAdress!);
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("接続に失敗しました。")));
          return;
        }
      } else {
        return;
      }
    }
    
    final success = await printService.printReceipt(_currentInvoice);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("レシートを印刷しました。")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("印刷エラーが発生しました。")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");
    final isDraft = _currentInvoice.isDraft;
    final themeColor = isDraft ? Colors.blueGrey.shade800 : Colors.white;
    final textColor = isDraft ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        leading: const BackButton(), // 常に表示
        title: Text(isDraft ? "伝票詳細 (下書き)" : "販売アシスト1号 伝票詳細"),
        backgroundColor: isDraft ? Colors.black87 : Colors.blueGrey,
        actions: [
          if (isDraft && !_isEditing)
            TextButton.icon(
              icon: const Icon(Icons.check_circle_outline, color: Colors.orangeAccent),
              label: const Text("正式発行", style: TextStyle(color: Colors.orangeAccent)),
              onPressed: _showPromoteDialog,
            ),
          if (!_isEditing) ...[
            IconButton(icon: const Icon(Icons.grid_on), onPressed: _exportCsv, tooltip: "CSV出力"),
            if (widget.isUnlocked)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: "コピーして新規作成",
                onPressed: () async {
                  // 新しいIDを生成して複製
                  final newId = DateTime.now().millisecondsSinceEpoch.toString();
                  final duplicateInvoice = _currentInvoice.copyWith(
                    id: newId,
                    date: DateTime.now(),
                    isDraft: true, // 下書きとして開始
                  );
                  
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceInputForm(
                        onInvoiceGenerated: (inv, path) {
                           // ここでは特に何もしない（詳細画面は元の伝票を表示し続けるため）
                           // ただし、履歴画面に戻った時にリロードされる必要がある（HistoryScreen側で対応済み）
                        },
                        existingInvoice: duplicateInvoice,
                      ),
                    ),
                  );
                },
              ),
            if (widget.isUnlocked)
              IconButton(
                icon: const Icon(Icons.edit_note), // アイコン変更
                tooltip: "詳細編集",
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceInputForm(
                        onInvoiceGenerated: (inv, path) {
                          // 保存完了時のコールバック（必要なら）
                        },
                        existingInvoice: _currentInvoice,
                      ),
                    ),
                  );
                  // 戻ってきたらデータを再読み込み（リポジトリから取得）
                  final repo = InvoiceRepository();
                  final customerRepo = CustomerRepository();
                  final customers = await customerRepo.getAllCustomers();
                  final updated = (await repo.getAllInvoices(customers)).firstWhere((i) => i.id == _currentInvoice.id, orElse: () => _currentInvoice);
                  setState(() => _currentInvoice = updated);
                },
              ),
          ] else ...[
            if (isDraft)
              TextButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.orangeAccent),
                label: const Text("正式発行", style: TextStyle(color: Colors.orangeAccent)),
                onPressed: _showPromoteDialog,
              ),
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
            _buildHeaderSection(textColor),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              _buildDraftToggleEdit(), // 編集用トグル
              const SizedBox(height: 16),
              _buildExperimentalSection(isDraft),
            ],
            Divider(height: 32, color: isDraft ? Colors.white70 : Colors.grey),
            Text("明細一覧", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            _buildItemTable(fmt, textColor, isDraft),
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
            _buildSummarySection(fmt, textColor, isDraft),
            const SizedBox(height: 24),
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Color textColor) {
    final dateFormatter = DateFormat('yyyy年MM月dd日');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isEditing) ...[
          TextField(
            controller: _formalNameController,
            decoration: const InputDecoration(labelText: "取引先 正式名称", border: OutlineInputBorder()),
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: "備考", border: OutlineInputBorder()),
            style: TextStyle(color: textColor),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "伝票番号: ${_currentInvoice.invoiceNumber}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentInvoice.isDraft ? Colors.orange : Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentInvoice.isDraft ? "下書き" : "確定済",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("日付: ${DateFormat('yyyy/MM/dd').format(_currentInvoice.date)}", style: TextStyle(color: textColor.withOpacity(0.8))),
          const SizedBox(height: 8),
          Text("取引先:", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Text("${_currentInvoice.customerNameForDisplay} ${_currentInvoice.customer.title}",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          if (_currentInvoice.subject?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text("件名: ${_currentInvoice.subject}", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
          ],
          if (_currentInvoice.customer.department != null && _currentInvoice.customer.department!.isNotEmpty)
            Text(_currentInvoice.customer.department!, style: TextStyle(fontSize: 16, color: textColor)),
          if (_currentInvoice.latitude != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text(
                    "座標: ${_currentInvoice.latitude!.toStringAsFixed(4)}, ${_currentInvoice.longitude!.toStringAsFixed(4)}",
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ],
          if (_currentInvoice.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text("備考: ${_currentInvoice.notes}", style: TextStyle(color: textColor.withOpacity(0.9))),
          ],
        ],
      ],
    );
  }

  Widget _buildItemTable(NumberFormat formatter, Color textColor, bool isDraft) {
    return Table(
      border: TableBorder.all(color: isDraft ? Colors.white24 : Colors.grey.shade300),
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
          decoration: BoxDecoration(color: isDraft ? Colors.black26 : Colors.grey.shade100),
          children: [
            _TableCell("品名", textColor: textColor),
            _TableCell("数量", textColor: textColor),
            _TableCell("単価", textColor: textColor),
            _TableCell("金額", textColor: textColor),
            const _TableCell(""),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          int idx = entry.key;
          InvoiceItem item = entry.value;
          if (_isEditing) {
            return TableRow(children: [
              _EditableCell(
                initialValue: item.description,
                textColor: textColor,
                onChanged: (val) => item.description = val,
              ),
              _EditableCell(
                initialValue: item.quantity.toString(),
                textColor: textColor,
                keyboardType: TextInputType.number,
                onChanged: (val) => setState(() => item.quantity = int.tryParse(val) ?? 0),
              ),
              _EditableCell(
                initialValue: item.unitPrice.toString(),
                textColor: textColor,
                keyboardType: TextInputType.number,
                onChanged: (val) => setState(() => item.unitPrice = int.tryParse(val) ?? 0),
              ),
              _TableCell(formatter.format(item.subtotal), textColor: textColor),
              IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _removeItem(idx)),
            ]);
          } else {
            return TableRow(children: [
              _TableCell(item.description, textColor: textColor),
              _TableCell(item.quantity.toString(), textColor: textColor),
              _TableCell(formatter.format(item.unitPrice), textColor: textColor),
              _TableCell(formatter.format(item.subtotal), textColor: textColor),
              const SizedBox(),
            ]);
          }
        }),
      ],
    );
  }

  Widget _buildSummarySection(NumberFormat formatter, Color textColor, bool isDraft) {
    final double currentTaxRate = _isEditing ? (_includeTax ? _taxRate : 0.0) : _currentInvoice.taxRate;
    final int subtotal = _isEditing ? _calculateCurrentSubtotal() : _currentInvoice.subtotal;
    final int tax = (subtotal * currentTaxRate).floor();
    final int total = subtotal + tax;

    return Column(
      children: [
        _buildSummaryRow("小計", formatter.format(subtotal), textColor),
        if (currentTaxRate > 0) ...[
          if (_companyInfo?.taxDisplayMode == 'normal')
            _buildSummaryRow("消費税 (${(currentTaxRate * 100).toInt()}%)", formatter.format(tax), textColor),
          if (_companyInfo?.taxDisplayMode == 'text_only')
            _buildSummaryRow("消費税", "（税別）", textColor),
        ],
        const Divider(color: Colors.grey),
        _buildSummaryRow(currentTaxRate > 0 ? "合計金額 (税込)" : "合計金額", "￥${formatter.format(total)}", textColor, isTotal: true),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color textColor, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: textColor)),
          Text(value, style: TextStyle(fontSize: isTotal ? 20 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Colors.orangeAccent : textColor)),
        ],
      ),
    );
  }

  int _calculateCurrentSubtotal() {
    return _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Widget _buildExperimentalSection(bool isDraft) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDraft ? Colors.black45 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("税率設定 (編集用)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("消費税: ", style: TextStyle(color: isDraft ? Colors.white70 : Colors.black87)),
              ChoiceChip(
                label: const Text("10%"),
                selected: _taxRate == 0.10,
                onSelected: (val) => setState(() => _taxRate = 0.10),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("8%"),
                selected: _taxRate == 0.08,
                onSelected: (val) => setState(() => _taxRate = 0.08),
              ),
              const Spacer(),
              Switch(
                value: _includeTax,
                onChanged: (val) => setState(() => _includeTax = val),
              ),
              Text(_includeTax ? "税込表示" : "非課税"),
            ],
          ),
        ],
      ),
    );
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
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _printReceipt,
            icon: const Icon(Icons.print),
            label: const Text("レシート"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _showPromoteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("正式発行"),
        content: const Text("この下書き伝票を「確定」として正式に発行しますか？\n(下書きモードが解除され、通常の背景に戻ります)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("正式発行する"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final promoted = _currentInvoice.copyWith(isDraft: false);
      await _invoiceRepo.updateInvoice(promoted);
      setState(() {
        _currentInvoice = promoted;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を正式発行しました")));
      }
    }
  }

  Widget _buildDraftToggleEdit() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _currentInvoice.isDraft ? Colors.black26 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.drafts, color: Colors.orange),
          const SizedBox(width: 12),
          const Expanded(child: Text("下書き状態として保持", style: TextStyle(fontWeight: FontWeight.bold))),
          Switch(
            value: _currentInvoice.isDraft,
            onChanged: (val) {
              setState(() {
                _currentInvoice = _currentInvoice.copyWith(isDraft: val);
              });
            },
          ),
        ],
      ),
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
  final Color? textColor;
  const _TableCell(this.text, {this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: textColor)),
    );
  }
}

class _EditableCell extends StatelessWidget {
  final String initialValue;
  final TextInputType keyboardType;
  final Function(String) onChanged;
  final Color? textColor;

  const _EditableCell({
    required this.initialValue,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextField(
        controller: TextEditingController(text: initialValue),
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: textColor),
        onChanged: onChanged,
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
      ),
    );
  }
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
