import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'package:printing/printing.dart';
import '../services/gps_service.dart';
import 'customer_picker_modal.dart';
import 'product_picker_modal.dart';
import '../models/company_model.dart';
import '../services/company_repository.dart';

class InvoiceInputForm extends StatefulWidget {
  final Function(Invoice invoice, String filePath) onInvoiceGenerated;
  final Invoice? existingInvoice; // 追加: 編集時の既存伝票

  const InvoiceInputForm({
    Key? key,
    required this.onInvoiceGenerated,
    this.existingInvoice, // 追加
  }) : super(key: key);

  @override
  State<InvoiceInputForm> createState() => _InvoiceInputFormState();
}

class _InvoiceInputFormState extends State<InvoiceInputForm> {
  final _repository = InvoiceRepository();
  Customer? _selectedCustomer;
  final List<InvoiceItem> _items = [];
  double _taxRate = 0.10;
  bool _includeTax = true;
  CompanyInfo? _companyInfo;
  DocumentType _documentType = DocumentType.invoice; // 追加
  DateTime _selectedDate = DateTime.now(); // 追加: 伝票日付
  bool _isDraft = false; // 追加: 下書きモード
  final TextEditingController _subjectController = TextEditingController(); // 追加
  bool _isSaving = false; // 保存中フラグ
  String _status = "取引先と商品を入力してください";
  
  // 署名用の実験的パス
  List<Offset?> _signaturePath = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _repository.cleanupOrphanedPdfs();
    final customerRepo = CustomerRepository();
    final customers = await customerRepo.getAllCustomers();
    if (customers.isNotEmpty) {
      setState(() => _selectedCustomer = customers.first);
    }
    
    final companyRepo = CompanyRepository();
    final companyInfo = await companyRepo.getCompanyInfo();
    setState(() {
      _companyInfo = companyInfo;
      // 既存伝票がある場合は初期値を上書き
      if (widget.existingInvoice != null) {
        final inv = widget.existingInvoice!;
        _selectedCustomer = inv.customer;
        _items.addAll(inv.items);
        _taxRate = inv.taxRate;
        _includeTax = inv.taxRate > 0;
        _documentType = inv.documentType;
        _selectedDate = inv.date;
        _isDraft = inv.isDraft;
        if (inv.subject != null) _subjectController.text = inv.subject!;
      } else {
        _taxRate = companyInfo.defaultTaxRate;
      }
    });
  }

  void _addItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductPickerModal(
        onItemSelected: (item) {
          setState(() => _items.add(item));
          Navigator.pop(context);
        },
      ),
    );
  }

  int get _subTotal => _items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  int get _tax => _includeTax ? (_subTotal * _taxRate).floor() : 0;
  int get _total => _subTotal + _tax;

  Future<void> _saveInvoice({bool generatePdf = true}) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("取引先を選択してください")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("明細を1件以上入力してください")));
      return;
    }

    // GPS情報の取得
    final gpsService = GpsService();
    final pos = await gpsService.getCurrentLocation();
    if (pos != null) {
      await gpsService.logLocation(); // 履歴テーブルにも保存
    }

    final invoice = Invoice(
      id: widget.existingInvoice?.id, // 既存IDがあれば引き継ぐ
      customer: _selectedCustomer!,
      date: _selectedDate,
      items: _items,
      taxRate: _includeTax ? _taxRate : 0.0,
      documentType: _documentType,
      customerFormalNameSnapshot: _selectedCustomer!.formalName,
      subject: _subjectController.text.isNotEmpty ? _subjectController.text : null, // 追加
      notes: _includeTax ? "（消費税 ${(_taxRate * 100).toInt()}% 込み）" : null,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      isDraft: _isDraft, // 追加
    );

    setState(() => _isSaving = true);
    
    // PDF生成有無に関わらず、まずは保存
    if (generatePdf) {
      setState(() => _status = "PDFを生成中...");
      final path = await generateInvoicePdf(invoice);
      if (path != null) {
        final updatedInvoice = invoice.copyWith(filePath: path);
        await _repository.saveInvoice(updatedInvoice);
        if (mounted) widget.onInvoiceGenerated(updatedInvoice, path);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を保存し、PDFを生成しました")));
      }
    } else {
      await _repository.saveInvoice(invoice);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を保存しました（PDF未生成）")));
      if (mounted) Navigator.pop(context);
    }
    
    if (mounted) setState(() => _isSaving = false);
  }

  void _showPreview() {
    if (_selectedCustomer == null) return;
    final invoice = Invoice(
      customer: _selectedCustomer!,
      date: _selectedDate, // 修正
      items: _items,
      taxRate: _includeTax ? _taxRate : 0.0,
      documentType: _documentType,
      customerFormalNameSnapshot: _selectedCustomer!.formalName,
      notes: _includeTax ? "（消費税 ${(_taxRate * 100).toInt()}% 込み）" : "（非課税）",
    );

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Text("${invoice.documentTypeName}プレビュー"),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) async {
                  // PdfGeneratorを少しリファクタして pw.Document を返す関数に分離することも可能だが
                  // ここでは generateInvoicePdf の中身を模したバイト生成を行う
                  // (もしくは generateInvoicePdf のシグネチャを変えてバイトを返すようにする)
                  // 簡易化のため、一時ファイルを作ってそれを読み込むか、Generatorを修正する
                  // 今回は Generator に pw.Document を生成する内部関数を作る
                  final pdfDoc = await buildInvoiceDocument(invoice);
                  return pdfDoc.save();
                },
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");
    final themeColor = _isDraft ? Colors.blueGrey.shade800 : Colors.white;
    final textColor = _isDraft ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isDraft ? "伝票作成 (下書き)" : "販売アシスト1号 V1.5.05"),
        backgroundColor: _isDraft ? Colors.black87 : Colors.blueGrey,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDraftToggle(),
                      const SizedBox(height: 16),
                      _buildDocumentTypeSection(),
                      const SizedBox(height: 16),
                      _buildDateSection(),
                      const SizedBox(height: 16),
                      _buildCustomerSection(),
                      const SizedBox(height: 16),
                      _buildSubjectSection(textColor),
                      const SizedBox(height: 20),
                      _buildItemsSection(fmt),
                      const SizedBox(height: 20),
                      _buildTaxSettings(),
                      const SizedBox(height: 20),
                      _buildSummarySection(fmt),
                      const SizedBox(height: 20),
                      _buildSignatureSection(),
                    ],
                  ),
                ),
              ),
              _buildBottomActionBar(),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("保存中...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeSection() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: DocumentType.values.map((type) {
          final isSelected = _documentType == type;
          String label = "";
          IconData icon = Icons.description;
          switch (type) {
            case DocumentType.estimation: label = "見積"; icon = Icons.article_outlined; break;
            case DocumentType.delivery: label = "納品"; icon = Icons.local_shipping_outlined; break;
            case DocumentType.invoice: label = "請求"; icon = Icons.receipt_long_outlined; break;
            case DocumentType.receipt: label = "領収"; icon = Icons.payments_outlined; break;
          }
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _documentType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigo : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 20),
                    Text(label, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSection() {
    final fmt = DateFormat('yyyy年MM月dd日');
    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.blueGrey),
        title: Text("伝票日付: ${fmt.format(_selectedDate)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("タップして日付を変更"),
        trailing: const Icon(Icons.edit, size: 20),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) {
            setState(() => _selectedDate = picked);
          }
        },
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.business, color: Colors.blueGrey),
        title: Text(_selectedCustomer?.formalName ?? "取引先を選択してください",
            style: TextStyle(color: _selectedCustomer == null ? Colors.grey : Colors.black87, fontWeight: FontWeight.bold)),
        subtitle: const Text("顧客マスターから選択"), // 修正
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => FractionallySizedBox(
              heightFactor: 0.9,
              child: CustomerPickerModal(onCustomerSelected: (c) {
                setState(() => _selectedCustomer = c);
                Navigator.pop(context);
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsSection(NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("明細項目", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text("追加")),
          ],
        ),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text("商品が追加されていません", style: TextStyle(color: Colors.grey))),
          )
        else
          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.description),
                subtitle: Text("￥${fmt.format(item.unitPrice)} x ${item.quantity}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("￥${fmt.format(item.unitPrice * item.quantity)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (idx > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        onPressed: () => setState(() {
                          final temp = _items[idx];
                          _items[idx] = _items[idx - 1];
                          _items[idx - 1] = temp;
                        }),
                        tooltip: "上へ",
                      ),
                    if (idx < _items.length - 1)
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        onPressed: () => setState(() {
                          final temp = _items[idx];
                          _items[idx] = _items[idx + 1];
                          _items[idx + 1] = temp;
                        }),
                        tooltip: "下へ",
                      ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => setState(() => _items.removeAt(idx)),
                      tooltip: "削除",
                    ),
                  ],
                ),
                onTap: () {
                  // 簡易編集ダイアログ
                  final descCtrl = TextEditingController(text: item.description);
                  final qtyCtrl = TextEditingController(text: item.quantity.toString());
                  final priceCtrl = TextEditingController(text: item.unitPrice.toString());
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("明細の編集"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "品名 / 項目")),
                          TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "数量"), keyboardType: TextInputType.number),
                          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "単価"), keyboardType: TextInputType.number),
                        ],
                      ),
                      actions: [
                        TextButton.icon(
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text("マスター参照"),
                          onPressed: () {
                             showModalBottomSheet(
                               context: context,
                               isScrollControlled: true,
                               builder: (context) => ProductPickerModal(
                                 onItemSelected: (selected) {
                                   descCtrl.text = selected.description;
                                   priceCtrl.text = selected.unitPrice.toString();
                                   Navigator.pop(context); // close picker
                                 },
                               ),
                             );
                          },
                        ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _items[idx] = item.copyWith(
                                description: descCtrl.text,
                                quantity: int.tryParse(qtyCtrl.text) ?? item.quantity,
                                unitPrice: int.tryParse(priceCtrl.text) ?? item.unitPrice,
                              );
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("更新"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTaxSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_includeTax) ...[
              const Text("消費税率: ", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
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
            ] else
              const Text("消費税設定: 非課税", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const Spacer(),
            Switch(
              value: _includeTax,
              onChanged: (val) => setState(() => _includeTax = val),
            ),
            Text(_includeTax ? "税込計算" : "非課税"),
          ],
        ),
      ],
    );
  }

  Widget _buildSummarySection(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.indigo.shade900, borderRadius: BorderRadius.circular(12)),
      child: Column(
          children: [
            _buildSummaryRow(_includeTax ? "小計 (税抜)" : "小計", "￥${fmt.format(_subTotal)}", Colors.white70),
            if (_includeTax) ...[
              if (_companyInfo?.taxDisplayMode == 'normal')
                _buildSummaryRow("消費税 (${(_taxRate * 100).toInt()}%)", "￥${fmt.format(_tax)}", Colors.white70),
              if (_companyInfo?.taxDisplayMode == 'text_only')
                _buildSummaryRow("消費税", "(税別)", Colors.white70),
            ],
            const Divider(color: Colors.white24),
            _buildSummaryRow(_includeTax ? "合計金額 (税込)" : "合計金額", "￥${fmt.format(_total)}", Colors.white, fontSize: 24),
          ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {double fontSize = 16}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: fontSize)),
          Text(value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("手書き署名 (実験的)", style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(onPressed: () => setState(() => _signaturePath.clear()), child: const Text("クリア")),
          ],
        ),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                RenderBox renderBox = context.findRenderObject() as RenderBox;
                _signaturePath.add(renderBox.globalToLocal(details.globalPosition));
              });
            },
            onPanEnd: (details) => _signaturePath.add(null),
            child: CustomPaint(
              painter: SignaturePainter(_signaturePath),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPreview,
                    icon: const Icon(Icons.picture_as_pdf), // アイコン変更
                    label: const Text("PDFプレビュー"), // 名称変更
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveInvoice(generatePdf: false),
                    icon: const Icon(Icons.save),
                    label: const Text("保存のみ"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _saveInvoice(generatePdf: true),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("確定してPDF生成"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isDraft ? Colors.black26 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDraft ? Colors.orangeAccent : Colors.orange, width: 2),
      ),
      child: Row(
        children: [
          Icon(_isDraft ? Icons.drafts : Icons.check_circle, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isDraft ? "下書き (保存のみ・PDF未生成)" : "正式発行 (PDF生成)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isDraft ? Colors.white70 : Colors.orange.shade900),
            ),
          ),
          Switch(
            value: _isDraft,
            activeColor: Colors.orangeAccent,
            onChanged: (val) => setState(() => _isDraft = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("案件名 / 件名", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "例：事務所改修工事 / 〇〇月分リース料",
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            filled: true,
            fillColor: _isDraft ? Colors.white12 : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
