// lib/screens/invoice_input_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';

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
  final _clientController = TextEditingController(text: "佐々木製作所");
  final _amountController = TextEditingController(text: "250000");
  String _status = "取引先と基本金額を入力してPDFを生成してください";

  @override
  void dispose() {
    _clientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // 連絡先を選択する処理
  Future<void> _pickContact() async {
    setState(() => _status = "連絡先をスキャン中...");
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final List<Contact> contacts = await FlutterContacts.getContacts(
          withProperties: false,
          withThumbnail: false,
        );

        if (!mounted) return;

        if (contacts.isEmpty) {
          setState(() => _status = "連絡先が空、または取得できませんでした。");
          return;
        }

        contacts.sort((a, b) => a.displayName.compareTo(b.displayName));

        final Contact? selected = await showModalBottomSheet<Contact>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext modalContext) => FractionallySizedBox(
            heightFactor: 0.8,
            child: ContactPickerModal(
              contacts: contacts,
              onContactSelected: (selectedContact) {
                Navigator.pop(modalContext, selectedContact);
              },
            ),
          ),
        );

        if (selected != null) {
          setState(() {
            _clientController.text = selected.displayName;
            _status = "「${selected.displayName}」をセットしました";
          });
        }
      } else {
        setState(() => _status = "電話帳の権限が拒否されています。");
      }
    } catch (e) {
      setState(() => _status = "エラーが発生しました: $e");
    }
  }

  // 初期PDFを生成して保存する処理（ここから詳細ページへ遷移する）
  Future<void> _handleInitialGenerate() async {
    final clientName = _clientController.text.trim();
    final unitPrice = int.tryParse(_amountController.text) ?? 0;

    if (clientName.isEmpty) {
      setState(() => _status = "取引先名を入力してください");
      return;
    }

    // 初期の1行明細を作成
    final initialItems = [
      InvoiceItem(
        description: "ご請求分",
        quantity: 1,
        unitPrice: unitPrice,
      )
    ];

    final invoice = Invoice(
      clientName: clientName,
      date: DateTime.now(),
      items: initialItems,
    );

    setState(() => _status = "A4請求書を生成中...");
    final path = await generateInvoicePdf(invoice);

    if (path != null) {
      final updatedInvoice = invoice.copyWith(filePath: path);
      widget.onInvoiceGenerated(updatedInvoice, path);
      setState(() => _status = "PDFを生成しました。詳細ページで表編集が可能です。");
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
          Row(children: [
            Expanded(
              child: TextField(
                controller: _clientController,
                decoration: const InputDecoration(
                  labelText: "取引先名",
                  hintText: "会社名や個人名",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.person_search, color: Colors.blue, size: 40),
              onPressed: _pickContact,
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "基本金額 (税抜)",
              hintText: "後で詳細ページで変更・追加できます",
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
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
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

// 連絡先選択用のモーダルウィジェット
class ContactPickerModal extends StatefulWidget {
  final List<Contact> contacts;
  final Function(Contact) onContactSelected;

  const ContactPickerModal({
    Key? key,
    required this.contacts,
    required this.onContactSelected,
  }) : super(key: key);

  @override
  State<ContactPickerModal> createState() => _ContactPickerModalState();
}

class _ContactPickerModalState extends State<ContactPickerModal> {
  String _searchQuery = "";
  List<Contact> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredContacts = widget.contacts
          .where((c) => c.displayName.toLowerCase().contains(_searchQuery))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "取引先を選択 (${_filteredContacts.length}件)",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: "名前で検索...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onChanged: _filterContacts,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (c, i) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_filteredContacts[i].displayName),
                onTap: () => widget.onContactSelected(_filteredContacts[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
