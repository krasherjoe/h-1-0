import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'customer_picker_modal.dart';
import 'product_picker_modal.dart';

class InvoiceInputForm extends StatefulWidget {
  final Function(Invoice invoice, String filePath) onInvoiceGenerated;

  const InvoiceInputForm({
    Key? key,
    required this.onInvoiceGenerated,
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
  int get _tax => _includeTax ? (_subTotal * _taxRate).round() : 0;
  int get _total => _subTotal + _tax;

  Future<void> _handleGenerate() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("取引先を選択してください")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("明細を1件以上入力してください")));
      return;
    }

    final invoice = Invoice(
      customer: _selectedCustomer!,
      date: DateTime.now(),
      items: _items,
      taxRate: _includeTax ? _taxRate : 0.0,
      customerFormalNameSnapshot: _selectedCustomer!.formalName, // 追加
      notes: _includeTax ? "（消費税 ${(_taxRate * 100).toInt()}% 込み）" : "（非課税）",
    );

    setState(() => _status = "PDFを生成中...");
    final path = await generateInvoicePdf(invoice);
    if (path != null) {
      final updatedInvoice = invoice.copyWith(filePath: path);
      await _repository.saveInvoice(updatedInvoice);
      widget.onInvoiceGenerated(updatedInvoice, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerSection(),
                const SizedBox(height: 20),
                _buildItemsSection(fmt),
                const SizedBox(height: 20),
                _buildExperimentalSection(),
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
        subtitle: const Text("請求先マスターから選択"),
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
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => setState(() => _items.removeAt(idx)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildExperimentalSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("実験的オプション", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("消費税: "),
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

  Widget _buildSummarySection(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.indigo.shade900, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSummaryRow("小計", "￥${fmt.format(_subTotal)}", Colors.white70),
          _buildSummaryRow("消費税", "￥${fmt.format(_tax)}", Colors.white70),
          const Divider(color: Colors.white24),
          _buildSummaryRow("合計金額", "￥${fmt.format(_total)}", Colors.white, fontSize: 24),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton.icon(
        onPressed: _handleGenerate,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("伝票を確定してPDF生成"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
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
