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
import 'product_master_screen.dart';
import '../models/product_model.dart';

class InvoiceInputForm extends StatefulWidget {
  final Function(Invoice invoice, String filePath) onInvoiceGenerated;
  final Invoice? existingInvoice; // 追加: 編集時の既存伝票
  final DocumentType initialDocumentType;

  const InvoiceInputForm({
    super.key,
    required this.onInvoiceGenerated,
    this.existingInvoice, // 追加
    this.initialDocumentType = DocumentType.invoice,
  });

  @override
  State<InvoiceInputForm> createState() => _InvoiceInputFormState();
}

List<InvoiceItem> _cloneItems(List<InvoiceItem> source) {
  return source
      .map((e) => InvoiceItem(
            id: e.id,
            productId: e.productId,
            description: e.description,
            quantity: e.quantity,
            unitPrice: e.unitPrice,
          ))
      .toList(growable: true);
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
  final List<_InvoiceSnapshot> _undoStack = [];
  final List<_InvoiceSnapshot> _redoStack = [];
  bool _isApplyingSnapshot = false;
  bool get _canUndo => _undoStack.length > 1;
  bool get _canRedo => _redoStack.isNotEmpty;

  // 署名用の実験的パス
  final List<Offset?> _signaturePath = [];

  @override
  void initState() {
    super.initState();
    _subjectController.addListener(_onSubjectChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _subjectController.removeListener(_onSubjectChanged);
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _repository.cleanupOrphanedPdfs();
    final customerRepo = CustomerRepository();
    await customerRepo.getAllCustomers();

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
        _documentType = widget.initialDocumentType;
      }
    });
    _pushHistory(clearRedo: true);
  }

  void _onSubjectChanged() {
    if (_isApplyingSnapshot) return;
    _pushHistory();
  }

  void _addItem() {
    Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductMasterScreen(selectionMode: true)),
    ).then((product) {
      if (product == null) return;
      setState(() {
        _items.add(InvoiceItem(
          productId: product.id,
          description: product.name,
          quantity: 1,
          unitPrice: product.defaultUnitPrice,
        ));
      });
      _pushHistory();
    });
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

  void _pushHistory({bool clearRedo = false}) {
    setState(() {
      if (_undoStack.length >= 30) _undoStack.removeAt(0);
      _undoStack.add(_InvoiceSnapshot(
        customer: _selectedCustomer,
        items: _cloneItems(_items),
        taxRate: _taxRate,
        includeTax: _includeTax,
        documentType: _documentType,
        date: _selectedDate,
        isDraft: _isDraft,
        subject: _subjectController.text,
      ));
      if (clearRedo) _redoStack.clear();
    });
  }

  void _undo() {
    if (_undoStack.length <= 1) return; // 直前状態がない
    setState(() {
      // 現在の状態をredoへ積む
      _redoStack.add(_InvoiceSnapshot(
        customer: _selectedCustomer,
        items: _cloneItems(_items),
        taxRate: _taxRate,
        includeTax: _includeTax,
        documentType: _documentType,
        date: _selectedDate,
        isDraft: _isDraft,
        subject: _subjectController.text,
      ));
      // 一番新しい履歴を捨て、直前のスナップショットを適用
      _undoStack.removeLast();
      final snapshot = _undoStack.last;
      _isApplyingSnapshot = true;
      _selectedCustomer = snapshot.customer;
      _items
        ..clear()
        ..addAll(_cloneItems(snapshot.items));
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
      _documentType = snapshot.documentType;
      _selectedDate = snapshot.date;
      _isDraft = snapshot.isDraft;
      _subjectController.text = snapshot.subject;
      _isApplyingSnapshot = false;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_InvoiceSnapshot(
        customer: _selectedCustomer,
        items: _cloneItems(_items),
        taxRate: _taxRate,
        includeTax: _includeTax,
        documentType: _documentType,
        date: _selectedDate,
        isDraft: _isDraft,
        subject: _subjectController.text,
      ));
      final snapshot = _redoStack.removeLast();
      _isApplyingSnapshot = true;
      _selectedCustomer = snapshot.customer;
      _items
        ..clear()
        ..addAll(_cloneItems(snapshot.items));
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
      _documentType = snapshot.documentType;
      _selectedDate = snapshot.date;
      _isDraft = snapshot.isDraft;
      _subjectController.text = snapshot.subject;
      _isApplyingSnapshot = false;
    });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undo : null,
            tooltip: "元に戻す",
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _canRedo ? _redo : null,
            tooltip: "やり直す",
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 140),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          _pushHistory();
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
            _pushHistory();
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
              _pushHistory();
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
                          onPressed: () {
                            setState(() => _items.removeAt(idx));
                            _pushHistory();
                          },
                          tooltip: "削除",
                        ),
                      ],
                    ),
                    onTap: () {
                      // 簡易編集ダイアログ（キーボードでせり上げない）
                      final descCtrl = TextEditingController(text: item.description);
                      final qtyCtrl = TextEditingController(text: item.quantity.toString());
                      final priceCtrl = TextEditingController(text: item.unitPrice.toString());
                      showDialog(
                        context: context,
                        builder: (context) {
                          final inset = MediaQuery.of(context).viewInsets.bottom;
                          return MediaQuery.removeViewInsets(
                            removeBottom: true,
                            context: context,
                            child: AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              title: const Text("明細の編集"),
                              content: SingleChildScrollView(
                                padding: EdgeInsets.only(bottom: inset + 12),
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "品名 / 項目")),
                                    TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "数量"), keyboardType: TextInputType.number),
                                    TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "単価"), keyboardType: TextInputType.number),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton.icon(
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text("マスター参照"),
                                  onPressed: () async {
                                    Navigator.pop(context); // close edit dialog before jumping
                                    await Navigator.push(
                                      this.context,
                                      MaterialPageRoute(builder: (_) => const ProductMasterScreen()),
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
                                    _pushHistory();
                                    Navigator.pop(context);
                                  },
                                  child: const Text("更新"),
                                ),
                              ],
                            ),
                          );
                        },
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

  Widget _buildSummarySection(NumberFormat formatter) {
    final int subtotal = _subTotal;
    final int tax = _includeTax ? (subtotal * _taxRate).floor() : 0;
    final int total = subtotal + tax;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow("小計", "￥${formatter.format(subtotal)}", Colors.white70),
          if (tax > 0) ...[
            const Divider(color: Colors.white24),
            _buildSummaryRow("消費税", "￥${formatter.format(tax)}", Colors.white70),
          ],
          const Divider(color: Colors.white24),
          _buildSummaryRow(
            tax > 0 ? "合計金額 (税込)" : "合計金額",
            "￥${formatter.format(total)}",
            Colors.white,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color textColor, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.w600,
              color: isTotal ? Colors.white : textColor,
            ),
          ),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _subjectController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "例：事務所改修工事 / 〇〇月分リース料",
              hintStyle: TextStyle(color: textColor.withAlpha((0.5 * 255).round())),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvoiceSnapshot {
  final Customer? customer;
  final List<InvoiceItem> items;
  final double taxRate;
  final bool includeTax;
  final DocumentType documentType;
  final DateTime date;
  final bool isDraft;
  final String subject;

  _InvoiceSnapshot({
    required this.customer,
    required this.items,
    required this.taxRate,
    required this.includeTax,
    required this.documentType,
    required this.date,
    required this.isDraft,
    required this.subject,
  });
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
