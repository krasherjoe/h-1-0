import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/customer_repository.dart';
import '../widgets/keyboard_inset_wrapper.dart';
import '../widgets/contact_picker_sheet.dart';

/// 顧客マスターからの選択、登録、編集、削除を行うモーダル
class CustomerPickerModal extends StatefulWidget {
  final Function(Customer) onCustomerSelected;

  const CustomerPickerModal({super.key, required this.onCustomerSelected});

  @override
  State<CustomerPickerModal> createState() => _CustomerPickerModalState();
}

class _CustomerPickerModalState extends State<CustomerPickerModal> {
  final CustomerRepository _repository = CustomerRepository();
  String _searchQuery = "";
  List<Customer> _filteredCustomers = [];
  bool _isImportingFromContacts = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _onSearch(""); // 初期表示
  }

  Future<void> _onSearch(String query) async {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });
    final customers = await _repository.searchCustomers(query);
    if (!context.mounted) return;
    setState(() {
      _filteredCustomers = customers;
      _isLoading = false;
    });
  }

  /// 電話帳から取り込んで新規顧客として登録・編集するダイアログ
  Future<void> _importFromPhoneContacts() async {
    if (!mounted) return;
    setState(() => _isImportingFromContacts = true);
    try {
      // パーミッション拒否時は即座にスピナーを解除して終了
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (!mounted) return;
        setState(() => _isImportingFromContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連絡先の権限がありません')));
        return;
      }
      if (!mounted) return;
      final contacts = await FlutterContacts.getContacts(withProperties: true, withAccounts: true, withPhoto: false);
      if (!mounted) return;
      setState(() => _isImportingFromContacts = false);

      final Contact? selectedContact = await showModalBottomSheet<Contact?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ContactPickerSheet(contacts: contacts, title: '電話帳から顧客候補を選択'),
      );

      if (!context.mounted) return;

      if (selectedContact != null) {
        final orgCompany = selectedContact.organizations.isNotEmpty ? selectedContact.organizations.first.company : '';
        final personName = selectedContact.displayName;
        final display = orgCompany.isNotEmpty ? orgCompany : personName;
        final formal = orgCompany.isNotEmpty ? orgCompany : personName;
        _showCustomerEditDialog(
          displayName: display,
          initialFormalName: formal,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImportingFromContacts = false);
      if (!context.mounted) return;
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
        content: KeyboardInsetWrapper(
          basePadding: const EdgeInsets.only(bottom: 12),
          extraBottom: 16,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
          ElevatedButton(
            onPressed: () async {
              final formal = formalNameController.text.trim();
              if (formal.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正式名称を入力してください')));
                return;
              }
              String normalize(String s) {
                var n = s.replaceAll(RegExp(r"\s+|\u3000"), "");
                for (final token in ["株式会社", "（株）", "(株)", "有限会社", "（有）", "(有)", "合同会社", "（同）", "(同)"]) {
                  n = n.replaceAll(token, "");
                }
                return n.toLowerCase();
              }

              final normalizedFormal = normalize(formal);
              final duplicates = await _repository.getAllCustomers();
              if (!context.mounted) return;
              final hasDuplicate = duplicates.any((c) {
                final target = normalize(c.formalName);
                return target == normalizedFormal && (existingCustomer == null || c.id != existingCustomer.id);
              });
              if (hasDuplicate) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同一顧客名が存在します')));
                return;
              }

              final updatedCustomer = existingCustomer?.copyWith(
                    formalName: formal,
                    department: departmentController.text.trim(),
                    address: addressController.text.trim(),
                    updatedAt: DateTime.now(),
                    isSynced: false,
                  ) ??
                  Customer(
                    id: const Uuid().v4(),
                    displayName: displayName,
                    formalName: formal,
                    department: departmentController.text.trim(),
                    address: addressController.text.trim(),
                  );

              await _repository.saveCustomer(updatedCustomer);
              if (!context.mounted) return;
              Navigator.pop(context); // エディットダイアログを閉じる
              _onSearch(_searchQuery); // リスト再読込
              if (existingCustomer == null) {
                widget.onCustomerSelected(updatedCustomer);
              }
            },
            child: const Text("保存してマスターに登録"),
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
            onPressed: () async {
              await _repository.deleteCustomer(customer.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              _onSearch("");
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
      child: KeyboardInsetWrapper(
        basePadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        extraBottom: 32,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                      onChanged: _onSearch,
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
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredCustomers.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text("該当する顧客がいません")),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: SliverList.builder(
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
      ),
    );
  }
}

