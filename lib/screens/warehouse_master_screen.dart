import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/warehouse_model.dart';
import '../services/warehouse_repository.dart';

class WarehouseMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const WarehouseMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<WarehouseMasterScreen> createState() => _WarehouseMasterScreenState();
}

class _WarehouseMasterScreenState extends State<WarehouseMasterScreen> {
  final WarehouseRepository _repo = WarehouseRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Warehouse> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.fetchWarehouses(includeHidden: widget.showHidden);
    if (!mounted) return;
    setState(() {
      _warehouses = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _warehouses.where((w) {
        return w.name.toLowerCase().contains(query) ||
            (w.location?.toLowerCase().contains(query) ?? false);
      }).toList();
      if (!widget.showHidden) {
        _filtered = _filtered.where((w) => !w.isHidden).toList();
      }
    });
  }

  Future<void> _showEditDialog({Warehouse? warehouse}) async {
    final isEdit = warehouse != null;
    final nameController = TextEditingController(text: warehouse?.name ?? '');
    final locationController = TextEditingController(text: warehouse?.location ?? '');
    final notesController = TextEditingController(text: warehouse?.notes ?? '');

    final result = await showDialog<Warehouse>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inset = MediaQuery.of(context).viewInsets.bottom;
          return MediaQuery.removeViewInsets(
            removeBottom: true,
            context: context,
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(isEdit ? '倉庫を編集' : '倉庫を新規登録'),
              content: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: inset + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '倉庫名',
                        hintText: '例: 第1倉庫',
                      ),
                    ),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: '所在地',
                        hintText: '例: ○○市△△町1-2-3',
                      ),
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
                        const SnackBar(content: Text('倉庫名は必須です')),
                      );
                      return;
                    }
                    final newWarehouse = Warehouse(
                      id: warehouse?.id ?? const Uuid().v4(),
                      name: nameController.text.trim(),
                      location: locationController.text.trim().isEmpty
                          ? null
                          : locationController.text.trim(),
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    Navigator.pop(context, newWarehouse);
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
      await _repo.saveWarehouse(result);
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
        title: const Text('WH:倉庫マスター'),
        backgroundColor: Colors.brown,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '倉庫名・所在地で検索',
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
                ? const Center(child: Text('倉庫が見つかりません'))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final w = _filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.brown.shade100,
                          child: const Icon(Icons.warehouse, color: Colors.brown),
                        ),
                        title: Text(
                          w.name + (w.isHidden ? ' (非表示)' : ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: w.isHidden ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: w.location != null ? Text(w.location!) : null,
                        onTap: () {
                          if (widget.selectionMode) {
                            if (w.isHidden) return;
                            Navigator.pop(context, w);
                          } else {
                            _showEditDialog(warehouse: w);
                          }
                        },
                        trailing: widget.selectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(warehouse: w),
                              ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
