import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';

/// 顧客マスターからの選択、登録、編集、削除を行うモーダル
class CustomerPickerModal extends StatefulWidget {
  final List<Customer> existingCustomers;
  final Function(Customer) onCustomerSelected;
  final Function(Customer)? onCustomerDeleted; // 削除通知用（オプション）

  const CustomerPickerModal({
    Key? key,
    required this.existingCustomers,
    required this.onCustomerSelected,
    this.onCustomerDeleted,
  }) : super(key: key);

  @override
  State<CustomerPickerModal> createState() => _CustomerPickerModalState();
}

class _CustomerPickerModalState extends State<CustomerPickerModal> {
  String _searchQuery = "";
  List<Customer> _filteredCustomers = [];
  bool _isImportingFromContacts = false;

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.existingCustomers;
  }

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredCustomers = widget.existingCustomers.where((customer) {
        return customer.formalName.toLowerCase().contains(_searchQuery) ||
            customer.displayName.toLowerCase().contains(_searchQuery);
      }).toList();
    });
  }

  /// 電話帳から取り込んで新規顧客として登録・編集するダイアログ
  Future<void> _importFromPhoneContacts() async {
    setState(() => _isImportingFromContacts = true);
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contacts = await FlutterContacts.getContacts();
        if (!mounted) return;
        setState(() => _isImportingFromContacts = false);

        final Contact? selectedContact = await showModalBottomSheet<Contact>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _PhoneContactListSelector(contacts: contacts),
        );

        if (selectedContact != null) {
          _showCustomerEditDialog(
            displayName: selectedContact.displayName,
            initialFormalName: selectedContact.displayName,
          );
        }
      }
    } catch (e) {
      setState(() => _isImportingFromContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("電話帳の取得に失敗しました: $e")),
      );
    }
  }

  /// 顧客情報の編集・登録ダイアログ
  void _showCustomerEditDialog({
    required String displayName,
    required String initialFormalName,
    Customer? existingCustomer,
  }) {
    final formalNameController = TextEditingController(text: initialFormalName);
    final departmentController = TextEditingController(text: existingCustomer?.department ?? "");
    final addressController = TextEditingController(text: existingCustomer?.address ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingCustomer == null ? "顧客の新規登録" : "顧客情報の編集"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("電話帳名: $displayName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: formalNameController,
                decoration: const InputDecoration(
                  labelText: "請求書用 正式名称",
                  hintText: "株式会社 〇〇 など",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: "部署名",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: "住所",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
          ElevatedButton(
            onPressed: () {
              final updatedCustomer = existingCustomer?.copyWith(
                    formalName: formalNameController.text.trim(),
                    department: departmentController.text.trim(),
                    address: addressController.text.trim(),
                  ) ??
                  Customer(
                    id: const Uuid().v4(),
                    displayName: displayName,
                    formalName: formalNameController.text.trim(),
                    department: departmentController.text.trim(),
                    address: addressController.text.trim(),
                  );
              Navigator.pop(context);
              widget.onCustomerSelected(updatedCustomer);
            },
            child: const Text("保存して確定"),
          ),
        ],
      ),
    );
  }

  /// 削除確認ダイアログ
  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("顧客の削除"),
        content: Text("「${customer.formalName}」をマスターから削除しますか？\n(過去の請求書ファイルは削除されません)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onCustomerDeleted != null) {
                widget.onCustomerDeleted!(customer);
                setState(() {
                  _filterCustomers(_searchQuery); // リスト更新
                });
              }
            },
            child: const Text("削除する", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("顧客マスター管理", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: "登録済み顧客を検索...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: _filterCustomers,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isImportingFromContacts ? null : _importFromPhoneContacts,
                    icon: _isImportingFromContacts
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.contact_phone),
                    label: const Text("電話帳から新規取り込み"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _filteredCustomers.isEmpty
                ? const Center(child: Text("該当する顧客がいません"))
                : ListView.builder(
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.business)),
                        title: Text(customer.formalName),
                        subtitle: Text(customer.department?.isNotEmpty == true ? customer.department! : "部署未設定"),
                        onTap: () => widget.onCustomerSelected(customer),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                              onPressed: () => _showCustomerEditDialog(
                                displayName: customer.displayName,
                                initialFormalName: customer.formalName,
                                existingCustomer: customer,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDelete(customer),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 電話帳から一人選ぶための内部ウィジェット
class _PhoneContactListSelector extends StatefulWidget {
  final List<Contact> contacts;
  const _PhoneContactListSelector({required this.contacts});

  @override
  State<_PhoneContactListSelector> createState() => _PhoneContactListSelectorState();
}

class _PhoneContactListSelectorState extends State<_PhoneContactListSelector> {
  List<Contact> _filtered = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = widget.contacts
          .where((c) => c.displayName.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: "電話帳から検索...", prefixIcon: Icon(Icons.search)),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_filtered[index].displayName),
                onTap: () => Navigator.pop(context, _filtered[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
