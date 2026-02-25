import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/customer_repository.dart';

class CustomerMasterScreen extends StatefulWidget {
  const CustomerMasterScreen({Key? key}) : super(key: key);

  @override
  State<CustomerMasterScreen> createState() => _CustomerMasterScreenState();
}

class _CustomerMasterScreenState extends State<CustomerMasterScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _isLoading = true;
  String _sortKey = 'name_asc';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _showContactUpdateDialog(Customer customer) async {
    final emailController = TextEditingController(text: customer.email ?? "");
    final telController = TextEditingController(text: customer.tel ?? "");
    final addressController = TextEditingController(text: customer.address ?? "");

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('連絡先を更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'メール')),
            TextField(controller: telController, decoration: const InputDecoration(labelText: '電話番号'), keyboardType: TextInputType.phone),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: '住所')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              await _customerRepo.updateContact(
                customerId: customer.id,
                email: emailController.text.isEmpty ? null : emailController.text,
                tel: telController.text.isEmpty ? null : telController.text,
                address: addressController.text.isEmpty ? null : addressController.text,
              );
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (updated == true) {
      _loadCustomers();
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepo.getAllCustomers();
    setState(() {
      _customers = customers;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    List<Customer> list = _customers.where((c) {
      return c.displayName.toLowerCase().contains(query) || c.formalName.toLowerCase().contains(query);
    }).toList();
    switch (_sortKey) {
      case 'name_desc':
        list.sort((a, b) => b.displayName.compareTo(a.displayName));
        break;
      default:
        list.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    _filtered = list;
  }

  Future<void> _addOrEditCustomer({Customer? customer}) async {
    final isEdit = customer != null;
    final displayNameController = TextEditingController(text: customer?.displayName ?? "");
    final formalNameController = TextEditingController(text: customer?.formalName ?? "");
    final departmentController = TextEditingController(text: customer?.department ?? "");
    final addressController = TextEditingController(text: customer?.address ?? "");
    final telController = TextEditingController(text: customer?.tel ?? "");
    String selectedTitle = customer?.title ?? "様";

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "顧客を編集" : "顧客を新規登録"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(labelText: "表示名（略称）", hintText: "例: 佐々木製作所"),
                ),
                TextField(
                  controller: formalNameController,
                  decoration: const InputDecoration(labelText: "正式名称", hintText: "例: 株式会社 佐々木製作所"),
                ),
                DropdownButtonFormField<String>(
                  value: selectedTitle,
                  decoration: const InputDecoration(labelText: "敬称"),
                  items: ["様", "御中", "殿", "貴社"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => selectedTitle = val ?? "様",
                ),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(labelText: "部署名", hintText: "例: 営業部"),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: "住所"),
                ),
                TextField(
                  controller: telController,
                  decoration: const InputDecoration(labelText: "電話番号"),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
            TextButton(
              onPressed: () {
                if (displayNameController.text.isEmpty || formalNameController.text.isEmpty) {
                  return;
                }
                final newCustomer = Customer(
                  id: customer?.id ?? const Uuid().v4(),
                  displayName: displayNameController.text,
                  formalName: formalNameController.text,
                  title: selectedTitle,
                  department: departmentController.text.isEmpty ? null : departmentController.text,
                  address: addressController.text.isEmpty ? null : addressController.text,
                  tel: telController.text.isEmpty ? null : telController.text,
                  odooId: customer?.odooId,
                  isSynced: false,
                );
                Navigator.pop(context, newCustomer);
              },
              child: const Text("保存"),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _customerRepo.saveCustomer(result);
      _loadCustomers();
    }
  }

  Future<void> _showPhonebookImport() async {
    // 疑似電話帳データ（会社名/氏名/複数住所）
    final phonebook = [
      {
        'company': '佐々木製作所',
        'person': '佐々木 太郎',
        'addresses': ['大阪府大阪市北区1-1-1', '東京都千代田区丸の内2-2-2'],
        'tel': '06-1234-5678',
        'emails': ['info@sasaki.co.jp', 'taro@sasaki.co.jp'],
      },
      {
        'company': 'Gemini Solutions',
        'person': 'John Smith',
        'addresses': ['1 Infinite Loop, CA', '1600 Amphitheatre Pkwy, CA'],
        'tel': '03-9876-5432',
        'emails': ['contact@gemini.com', 'john.smith@gemini.com'],
      },
    ];

    String selectedEntryId = '0';
    String selectedNameSource = 'company';
    int selectedAddressIndex = 0;
    int selectedEmailIndex = 0;

    final imported = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final entry = phonebook[int.parse(selectedEntryId)];
          final addresses = (entry['addresses'] as List<String>);
          final emails = (entry['emails'] as List<String>);
          final displayName = selectedNameSource == 'company' ? entry['company'] as String : entry['person'] as String;
          final formalName = selectedNameSource == 'company'
              ? '株式会社 ${entry['company']}'
              : '${entry['person']} 様';
          final addressText = addresses[selectedAddressIndex];
          final emailText = emails.isNotEmpty ? emails[selectedEmailIndex] : '';

          final displayController = TextEditingController(text: displayName);
          final formalController = TextEditingController(text: formalName);
          final addressController = TextEditingController(text: addressText);
          final emailController = TextEditingController(text: emailText);

          return AlertDialog(
            title: const Text('電話帳から取り込む'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedEntryId,
                  decoration: const InputDecoration(labelText: '電話帳エントリ'),
                  items: phonebook
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(value: e.key.toString(), child: Text(e.value['company'] as String)))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedEntryId = v ?? '0';
                      selectedAddressIndex = 0;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text('顧客名の取り込み元'),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        title: const Text('会社名'),
                        value: 'company',
                        groupValue: selectedNameSource,
                        onChanged: (v) => setDialogState(() => selectedNameSource = v ?? 'company'),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        title: const Text('氏名'),
                        value: 'person',
                        groupValue: selectedNameSource,
                        onChanged: (v) => setDialogState(() => selectedNameSource = v ?? 'person'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedAddressIndex,
                  decoration: const InputDecoration(labelText: '住所を選択'),
                  items: addresses
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedAddressIndex = v ?? 0),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedEmailIndex,
                  decoration: const InputDecoration(labelText: 'メールを選択'),
                  items: emails
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedEmailIndex = v ?? 0),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayController,
                  decoration: const InputDecoration(labelText: '表示名（編集可）'),
                ),
                TextField(
                  controller: formalController,
                  decoration: const InputDecoration(labelText: '正式名称（編集可）'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: '住所（編集可）'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'メール（編集可）'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(
                onPressed: () {
                  final newCustomer = Customer(
                    id: const Uuid().v4(),
                    displayName: displayController.text,
                    formalName: formalController.text,
                    title: selectedNameSource == 'company' ? '御中' : '様',
                    address: addressController.text,
                    tel: entry['tel'] as String?,
                    email: emailController.text.isEmpty ? null : emailController.text,
                    isSynced: false,
                  );
                  Navigator.pop(context, newCustomer);
                },
                child: const Text('取り込む'),
              ),
            ],
          );
        },
      ),
    );

    if (imported != null) {
      await _customerRepo.saveCustomer(imported);
      _loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("顧客マスター"),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortKey,
              icon: const Icon(Icons.sort, color: Colors.white),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'name_asc', child: Text('名前昇順')),
                DropdownMenuItem(value: 'name_desc', child: Text('名前降順')),
              ],
              onChanged: (v) {
                setState(() {
                  _sortKey = v ?? 'name_asc';
                  _applyFilter();
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "名前で検索 (電話帳参照ボタンは詳細で)",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(_applyFilter),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text("顧客が登録されていません"))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c.isLocked ? Colors.grey.shade300 : Colors.indigo.shade100,
                              child: Stack(
                                children: [
                                  const Align(alignment: Alignment.center, child: Icon(Icons.person, color: Colors.indigo)),
                                  if (c.isLocked)
                                    const Align(alignment: Alignment.bottomRight, child: Icon(Icons.lock, size: 14, color: Colors.redAccent)),
                                ],
                              ),
                            ),
                            title: Text(c.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: c.isLocked ? Colors.grey : Colors.black87)),
                            subtitle: Text("${c.formalName} ${c.title}"),
                            onTap: () => _showDetailPane(c),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: c.isLocked ? null : () => _addOrEditCustomer(customer: c),
                              tooltip: c.isLocked ? "ロック中" : "編集",
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPhonebookImport,
        icon: const Icon(Icons.add),
        label: const Text('電話帳から取り込む'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showDetailPane(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Icon(c.isLocked ? Icons.lock : Icons.person, color: c.isLocked ? Colors.redAccent : Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.formalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("電話帳参照は端末連絡先連携が必要です")));
                    },
                    tooltip: "電話帳参照",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (c.address != null) Text("住所: ${c.address}") else const SizedBox.shrink(),
              if (c.tel != null) Text("TEL: ${c.tel}") else const SizedBox.shrink(),
              if (c.email != null) Text("メール: ${c.email}") else const SizedBox.shrink(),
              Text("敬称: ${c.title}"),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: c.isLocked
                        ? null
                        : () {
                            Navigator.pop(context);
                            _addOrEditCustomer(customer: c);
                          },
                    icon: const Icon(Icons.edit),
                    label: const Text("編集"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showContactUpdateDialog(c);
                    },
                    icon: const Icon(Icons.contact_mail),
                    label: const Text("連絡先を更新"),
                  ),
                  const SizedBox(width: 8),
                  if (!c.isLocked)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("削除確認"),
                            content: Text("「${c.displayName}」を削除しますか？"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _customerRepo.deleteCustomer(c.id);
                          if (!mounted) return;
                          Navigator.pop(context);
                          _loadCustomers();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      label: const Text("削除", style: TextStyle(color: Colors.redAccent)),
                    ),
                  if (c.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(label: const Text("ロック中"), avatar: const Icon(Icons.lock, size: 16)),
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
