import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/supplier_model.dart';
import '../services/supplier_repository.dart';

class SupplierMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const SupplierMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<SupplierMasterScreen> createState() => _SupplierMasterScreenState();
}

class _SupplierMasterScreenState extends State<SupplierMasterScreen> {
  final SupplierRepository _repo = SupplierRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Supplier> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.fetchSuppliers(includeHidden: widget.showHidden);
    if (!mounted) return;
    setState(() {
      _suppliers = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _suppliers.where((s) {
        return s.name.toLowerCase().contains(query) ||
            (s.contactPerson?.toLowerCase().contains(query) ?? false) ||
            (s.tel?.toLowerCase().contains(query) ?? false);
      }).toList();
      if (!widget.showHidden) {
        _filtered = _filtered.where((s) => !s.isHidden).toList();
      }
    });
  }

  Future<void> _showEditDialog({Supplier? supplier}) async {
    final isEdit = supplier != null;
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final contactController = TextEditingController(text: supplier?.contactPerson ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final telController = TextEditingController(text: supplier?.tel ?? '');
    final addressController = TextEditingController(text: supplier?.address ?? '');
    final closingDayController = TextEditingController(
      text: supplier?.closingDay != null ? supplier!.closingDay.toString() : '',
    );
    final paymentSiteController = TextEditingController(
      text: supplier?.paymentSiteDays.toString() ?? '30',
    );
    final notesController = TextEditingController(text: supplier?.notes ?? '');

    final result = await showDialog<Supplier>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inset = MediaQuery.of(context).viewInsets.bottom;
          return MediaQuery.removeViewInsets(
            removeBottom: true,
            context: context,
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(isEdit ? '仕入先を編集' : '仕入先を新規登録'),
              content: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: inset + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '仕入先名',
                        hintText: '例: ○○商事',
                      ),
                    ),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(labelText: '担当者名'),
                    ),
                    TextField(
                      controller: telController,
                      decoration: const InputDecoration(labelText: '電話番号'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'メールアドレス'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: '住所'),
                    ),
                    TextField(
                      controller: closingDayController,
                      decoration: const InputDecoration(
                        labelText: '締日',
                        hintText: '例: 末日は空欄、20日締めは20',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: paymentSiteController,
                      decoration: const InputDecoration(
                        labelText: '支払サイト（日数）',
                        hintText: '例: 30',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: '備考'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('仕入先名は必須です')),
                      );
                      return;
                    }
                    final newSupplier = Supplier(
                      id: supplier?.id ?? const Uuid().v4(),
                      name: nameController.text.trim(),
                      contactPerson: contactController.text.trim().isEmpty
                          ? null
                          : contactController.text.trim(),
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                      tel: telController.text.trim().isEmpty
                          ? null
                          : telController.text.trim(),
                      address: addressController.text.trim().isEmpty
                          ? null
                          : addressController.text.trim(),
                      closingDay: closingDayController.text.trim().isEmpty
                          ? null
                          : int.tryParse(closingDayController.text.trim()),
                      paymentSiteDays: int.tryParse(paymentSiteController.text.trim()) ?? 30,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    Navigator.pop(context, newSupplier);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      await _repo.saveSupplier(result);
      if (widget.selectionMode && mounted) {
        Navigator.pop(context, result);
      } else {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('SI:仕入先マスター'),
        backgroundColor: Colors.orange,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '仕入先名・担当者・電話番号で検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const Center(child: Text('仕入先が見つかりません'))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final s = _filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.business, color: Colors.orange),
                        ),
                        title: Text(
                          s.name + (s.isHidden ? ' (非表示)' : ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: s.isHidden ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (s.contactPerson != null) s.contactPerson!,
                            if (s.tel != null) s.tel!,
                            '支払: ${s.paymentSiteDays}日',
                          ].join(' / '),
                        ),
                        onTap: () {
                          if (widget.selectionMode) {
                            if (s.isHidden) return;
                            Navigator.pop(context, s);
                          } else {
                            _showEditDialog(supplier: s);
                          }
                        },
                        trailing: widget.selectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(supplier: s),
                              ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
