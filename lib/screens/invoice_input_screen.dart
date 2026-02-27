import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import 'invoice_detail_page.dart';
import '../services/gps_service.dart';
import 'customer_master_screen.dart';
import 'product_picker_modal.dart';
import '../widgets/keyboard_inset_wrapper.dart';

class InvoiceInputForm extends StatefulWidget {
  final Function(Invoice invoice, String filePath) onInvoiceGenerated;
  final Invoice? existingInvoice; // 追加: 編集時の既存伝票

  const InvoiceInputForm({
    super.key,
    required this.onInvoiceGenerated,
    this.existingInvoice, // 追加
  });

  @override
  State<InvoiceInputForm> createState() => _InvoiceInputFormState();
}

class _InvoiceInputFormState extends State<InvoiceInputForm> {
  final _repository = InvoiceRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  Customer? _selectedCustomer;
  final List<InvoiceItem> _items = [];
  double _taxRate = 0.10;
  bool _includeTax = false;
  DocumentType _documentType = DocumentType.invoice; // 追加
  DateTime _selectedDate = DateTime.now(); // 追加: 伝票日付
  bool _isDraft = true; // デフォルトは下書き
  final TextEditingController _subjectController = TextEditingController(); // 追加
  bool _isSaving = false; // 保存中フラグ
  
  // 署名用の実験的パス
  final List<Offset?> _signaturePath = [];

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
    
    setState(() {
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
        _taxRate = 0;
        _includeTax = false;
        _isDraft = true;
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
    try {
      // PDF生成有無に関わらず、まずは保存
      if (generatePdf) {
        final path = await generateInvoicePdf(invoice);
        if (path != null) {
          final updatedInvoice = invoice.copyWith(filePath: path);
          await _repository.saveInvoice(updatedInvoice);
          if (mounted) widget.onInvoiceGenerated(updatedInvoice, path);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を保存し、PDFを生成しました")));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF生成に失敗しました")));
        }
      } else {
        await _repository.saveInvoice(invoice);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を保存しました（PDF未生成）")));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoicePdfPreviewPage(
          invoice: invoice,
          isUnlocked: true,
          isLocked: false,
          allowFormalIssue: widget.existingInvoice != null && !(widget.existingInvoice?.isLocked ?? false),
          onFormalIssue: (widget.existingInvoice != null)
              ? () async {
                  final promoted = invoice.copyWith(isDraft: false);
                  await _invoiceRepo.saveInvoice(promoted);
                  final newPath = await generateInvoicePdf(promoted);
                  final saved = newPath != null ? promoted.copyWith(filePath: newPath) : promoted;
                  await _invoiceRepo.saveInvoice(saved);
                  if (!context.mounted) return false;
                  Navigator.pop(context); // close preview
                  Navigator.pop(context); // exit edit screen
                  if (!context.mounted) return false;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceDetailPage(
                        invoice: saved,
                        isUnlocked: true,
                      ),
                    ),
                  );
                  return true;
                }
              : null,
          showShare: false,
          showEmail: false,
          showPrint: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");
    final themeColor = Colors.white;
    final textColor = Colors.black87;

    return Scaffold(
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("A1:伝票入力"),
      ),
      body: Stack(
        children: [
          KeyboardInsetWrapper(
            basePadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            extraBottom: 24,
            child: InteractiveViewer(
              panEnabled: false,
              minScale: 0.8,
              maxScale: 2.5,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateSection(),
                          const SizedBox(height: 16),
                          _buildCustomerSection(),
                          const SizedBox(height: 16),
                          _buildSubjectSection(textColor),
                          const SizedBox(height: 20),
                          _buildItemsSection(fmt),
                          const SizedBox(height: 20),
                          _buildSummarySection(fmt),
                          const SizedBox(height: 20),
                          _buildSignatureSection(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActionBar(),
                ],
              ),
            ),
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

  Widget _buildDateSection() {
    final fmt = DateFormat('yyyy/MM/dd');
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.indigo),
            const SizedBox(width: 8),
            Text("伝票日付: ${fmt.format(_selectedDate)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: Colors.indigo),
          ],
        ),
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
          final Customer? picked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerMasterScreen(selectionMode: true),
              fullscreenDialog: true,
            ),
          );
          if (picked != null) {
            setState(() => _selectedCustomer = picked);
          }
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
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
              });
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, idx) {
              final item = _items[idx];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('item_${idx}_${item.description}'),
                index: idx,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.description),
                    subtitle: Text("￥${fmt.format(item.unitPrice)} x ${item.quantity}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("￥${fmt.format(item.unitPrice * item.quantity)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
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
                ),
              );
            },
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
            _buildSummaryRow("小計", "￥${fmt.format(_subTotal)}", Colors.white70),
            const Divider(color: Colors.white24),
            _buildSummaryRow("合計金額", "￥${fmt.format(_subTotal)}", Colors.white, fontSize: 24),
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
                    onPressed: _items.isEmpty ? null : _showPreview,
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
                    label: const Text("保存"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            hintStyle: TextStyle(color: textColor.withAlpha((0.5 * 255).round())),
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
