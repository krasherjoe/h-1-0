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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCustomer(),
        child: const Icon(Icons.person_add),
        backgroundColor: Colors.indigo,
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
              Text("敬称: ${c.title}"),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _addOrEditCustomer(customer: c);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("編集"),
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
