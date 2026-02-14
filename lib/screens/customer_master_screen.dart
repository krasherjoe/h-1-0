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
  List<Customer> _customers = [];
  bool _isLoading = true;

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
      _isLoading = false;
    });
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
        title: const Text("顧客マスター管理"),
        backgroundColor: Colors.blueGrey,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(child: Text("顧客が登録されていません"))
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    return ListTile(
                      title: Text(c.displayName),
                      subtitle: Text("${c.formalName} ${c.title}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditCustomer(customer: c)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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
                                _loadCustomers();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCustomer(),
        child: const Icon(Icons.person_add),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}
