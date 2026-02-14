import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'customer_picker_modal.dart';

/// 請求書の初期入力（ヘッダー部分）を管理するウィジェット
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
  final _clientController = TextEditingController();
  final _amountController = TextEditingController(text: "250000");
  final _repository = InvoiceRepository();
  String _status = "取引先を選択してPDFを生成してください";

  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 起動時に不要なPDFを掃除する
    _repository.cleanupOrphanedPdfs().then((count) {
      if (count > 0) {
        debugPrint('Cleaned up $count orphaned PDF files.');
      }
    });

    final customerRepo = CustomerRepository();
    final customers = await customerRepo.getAllCustomers();
    if (customers.isNotEmpty) {
      setState(() {
        _selectedCustomer = customers.first;
        _clientController.text = _selectedCustomer!.formalName;
      });
    } else {
      // マスターが空の場合は、デフォルトのサンプルを登録しておく
      final defaultCustomer = Customer(
        id: const Uuid().v4(),
        displayName: "佐々木製作所",
        formalName: "株式会社 佐々木製作所",
      );
      await customerRepo.saveCustomer(defaultCustomer);
      setState(() {
        _selectedCustomer = defaultCustomer;
        _clientController.text = _selectedCustomer!.formalName;
      });
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _openCustomerPicker() async {
    setState(() => _status = "顧客マスターを開いています...");

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: CustomerPickerModal(
          onCustomerSelected: (customer) {
            setState(() {
              _selectedCustomer = customer;
              _clientController.text = customer.formalName;
              _status = "「${customer.formalName}」を選択しました";
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _handleInitialGenerate() async {
    if (_selectedCustomer == null) {
      setState(() => _status = "取引先を選択してください");
      return;
    }

    final unitPrice = int.tryParse(_amountController.text) ?? 0;

    final initialItems = [
      InvoiceItem(
        description: "ご請求分",
        quantity: 1,
        unitPrice: unitPrice,
      )
    ];

    final invoice = Invoice(
      customer: _selectedCustomer!,
      date: DateTime.now(),
      items: initialItems,
    );

    setState(() => _status = "A4請求書を生成中...");
    final path = await generateInvoicePdf(invoice);

    if (path != null) {
      final updatedInvoice = invoice.copyWith(filePath: path);

      // オリジナルDBに保存
      await _repository.saveInvoice(updatedInvoice);

      widget.onInvoiceGenerated(updatedInvoice, path);
      setState(() => _status = "PDFを生成しDBに登録しました。");
    } else {
      setState(() => _status = "PDFの生成に失敗しました");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(children: [
          const Text(
            "ステップ1: 宛先と基本金額の設定",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _clientController,
                readOnly: true,
                onTap: _openCustomerPicker,
                decoration: const InputDecoration(
                  labelText: "取引先名 (タップして選択)",
                  hintText: "電話帳から取り込むか、マスターから選択",
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: Colors.indigo, size: 40),
              onPressed: _openCustomerPicker,
              tooltip: "顧客を選択・登録",
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "基本金額 (税抜)",
              hintText: "明細の1行目として登録されます",
              prefixIcon: Icon(Icons.currency_yen),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleInitialGenerate,
            icon: const Icon(Icons.description),
            label: const Text("A4請求書を作成して詳細編集へ"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _status,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }
}
