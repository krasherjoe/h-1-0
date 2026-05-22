import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/supplier_model.dart';
import '../services/supplier_repository.dart';
import '../widgets/keyboard_inset_wrapper.dart';

class SupplierPickerModal extends StatefulWidget {
  const SupplierPickerModal({super.key, required this.onSupplierSelected});

  final ValueChanged<Supplier> onSupplierSelected;

  @override
  State<SupplierPickerModal> createState() => _SupplierPickerModalState();
}

class _SupplierPickerModalState extends State<SupplierPickerModal> {
  final SupplierRepository _repository = SupplierRepository();
  final TextEditingController _searchController = TextEditingController();
  final Uuid _uuid = const Uuid();

  List<Supplier> _suppliers = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers([String keyword = '']) async {
    setState(() => _isLoading = true);
    final all = await _repository.fetchSuppliers(includeHidden: true);
    final filtered = keyword.trim().isEmpty
        ? all
        : all.where((s) => s.name.toLowerCase().contains(keyword.toLowerCase())).toList();
    if (!mounted) return;
    setState(() {
      _suppliers = filtered;
      _isLoading = false;
    });
  }

  Future<void> _openEditor({Supplier? supplier}) async {
    final result = await showDialog<Supplier>(
      context: context,
      builder: (ctx) => _SupplierFormDialog(supplier: supplier, onSubmit: (data) => Navigator.of(ctx).pop(data)),
    );
    if (result == null) return;
    final saving = result.copyWith(id: result.id.isEmpty ? _uuid.v4() : result.id, updatedAt: DateTime.now());
    await _repository.saveSupplier(saving);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仕入先を保存しました')));
    await _loadSuppliers(_searchController.text);
    if (!mounted) return;
    widget.onSupplierSelected(saving);
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('仕入先を削除'),
        content: Text('${supplier.name} を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')), 
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteSupplier(supplier.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仕入先を削除しました')));
    await _loadSuppliers(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12 + (topPad > 0 ? topPad : 0), 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                const SizedBox(width: 8),
                const Text('仕入先を選択', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => _openEditor(), icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '仕入先名で検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadSuppliers('');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: _loadSuppliers,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _suppliers.isEmpty
                      ? const Center(child: Text('仕入先が見つかりません。右上の + から追加できます。'))
                      : ListView.builder(
                          itemCount: _suppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = _suppliers[index];
                            return Card(
                              child: ListTile(
                                title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (supplier.contactPerson?.isNotEmpty == true) Text('担当: ${supplier.contactPerson}'),
                                    if (supplier.tel?.isNotEmpty == true) Text('TEL: ${supplier.tel}'),
                                  ],
                                ),
                                onTap: () {
                                  widget.onSupplierSelected(supplier);
                                },
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _openEditor(supplier: supplier);
                                        break;
                                      case 'delete':
                                        _deleteSupplier(supplier);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'edit', child: Text('編集')),
                                    PopupMenuItem(value: 'delete', child: Text('削除')), 
                                  ],
                                ),
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

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({required this.onSubmit, this.supplier});

  final Supplier? supplier;
  final ValueChanged<Supplier> onSubmit;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _telController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    _nameController = TextEditingController(text: supplier?.name ?? '');
    _contactController = TextEditingController(text: supplier?.contactPerson ?? '');
    _telController = TextEditingController(text: supplier?.tel ?? '');
    _emailController = TextEditingController(text: supplier?.email ?? '');
    _notesController = TextEditingController(text: supplier?.notes ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? '仕入先を追加' : '仕入先を編集'),
      content: KeyboardInsetWrapper(
        basePadding: const EdgeInsets.only(bottom: 8),
        extraBottom: 24,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '仕入先名 *'),
                  validator: (value) => value == null || value.trim().isEmpty ? '必須項目です' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _contactController, decoration: const InputDecoration(labelText: '担当者')),
                const SizedBox(height: 12),
                TextFormField(controller: _telController, decoration: const InputDecoration(labelText: '電話番号')),
                const SizedBox(height: 12),
                TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'メール')),
                const SizedBox(height: 12),
                TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: '備考'), maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            widget.onSubmit(
              Supplier(
                id: widget.supplier?.id ?? '',
                displayName: _nameController.text.trim(),
        formalName: _nameController.text.trim(),
                contactPerson: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
                tel: _telController.text.trim().isEmpty ? null : _telController.text.trim(),
                email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                updatedAt: DateTime.now(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
