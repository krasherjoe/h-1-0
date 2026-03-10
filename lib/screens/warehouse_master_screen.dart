import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/warehouse_model.dart';
import '../services/warehouse_repository.dart';
import '../widgets/generic_master_edit_dialog.dart';
import '../widgets/master_field_config.dart';

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
    final result = await showMasterEditDialog<Warehouse>(
      context: context,
      titleNew: '倉庫を新規登録',
      titleEdit: '倉庫を編集',
      existing: warehouse,
      fields: [
        MasterFieldConfig(
          key: 'name',
          label: '倉庫名',
          hint: '例: 第1倉庫',
          required: true,
        ),
        MasterFieldConfig(
          key: 'location',
          label: '所在地',
          hint: '例: ○○市△△町1-2-3',
        ),
        MasterFieldConfig(
          key: 'notes',
          label: '備考',
          maxLines: 3,
        ),
      ],
      initialValues: (w) => {
        'name': w?.name ?? '',
        'location': w?.location ?? '',
        'notes': w?.notes ?? '',
      },
      buildModel: (values) => Warehouse(
        id: warehouse?.id ?? const Uuid().v4(),
        name: values['name'],
        location: values['location']?.isEmpty ? null : values['location'],
        notes: values['notes']?.isEmpty ? null : values['notes'],
        updatedAt: DateTime.now(),
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
