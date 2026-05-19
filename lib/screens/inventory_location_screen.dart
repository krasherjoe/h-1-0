import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/inventory_location_model.dart';
import '../models/warehouse_model.dart';
import '../services/inventory_location_repository.dart';
import '../services/warehouse_repository.dart';

/// 在庫ロケーション管理画面（I4）
class InventoryLocationScreen extends StatefulWidget {
  const InventoryLocationScreen({super.key});

  @override
  State<InventoryLocationScreen> createState() => _InventoryLocationScreenState();
}

class _InventoryLocationScreenState extends State<InventoryLocationScreen> {
  final InventoryLocationRepository _locationRepo = InventoryLocationRepository();
  final WarehouseRepository _warehouseRepo = WarehouseRepository();
  
  List<InventoryLocation> _locations = [];
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  String? _selectedWarehouseId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final locations = await _locationRepo.getAllLocations();
      final warehouses = await _warehouseRepo.getAllWarehouses();
      
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _warehouses = warehouses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データ読み込みエラー: $e')),
      );
    }
  }

  Future<void> _addLocation() async {
    final result = await showDialog<InventoryLocation>(
      context: context,
      builder: (context) => LocationDialog(
        warehouses: _warehouses,
        existingLocations: _locations,
      ),
    );

    if (result != null) {
      try {
        await _locationRepo.saveLocation(result);
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ロケーションを追加しました')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加エラー: $e')),
        );
      }
    }
  }

  Future<void> _editLocation(InventoryLocation location) async {
    final result = await showDialog<InventoryLocation>(
      context: context,
      builder: (context) => LocationDialog(
        warehouses: _warehouses,
        existingLocations: _locations,
        editLocation: location,
      ),
    );

    if (result != null) {
      try {
        await _locationRepo.saveLocation(result);
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ロケーションを更新しました')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
        );
      }
    }
  }

  Future<void> _toggleLocationActive(InventoryLocation location) async {
    try {
      if (location.isActive) {
        await _locationRepo.deactivateLocation(location.id);
      } else {
        final updatedLocation = location.copyWith(isActive: true);
        await _locationRepo.saveLocation(updatedLocation);
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(location.isActive ? '非アクティブ化しました' : 'アクティブ化しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('状態変更エラー: $e')),
      );
    }
  }

  Future<void> _deleteLocation(InventoryLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('ロケーション「${location.locationName}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _locationRepo.deleteLocation(location.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ロケーションを削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除エラー: $e')),
      );
    }
  }

  List<InventoryLocation> get _filteredLocations {
    if (_selectedWarehouseId == null) return _locations;
    return _locations.where((loc) => loc.warehouseId == _selectedWarehouseId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WL:在庫ロケーション'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ウェアハウスフィルター
                Container(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedWarehouseId,
                    decoration: const InputDecoration(
                      labelText: 'ウェアハウスで絞り込み',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('すべてのウェアハウス'),
                      ),
                      ..._warehouses.map((warehouse) => DropdownMenuItem(
                        value: warehouse.id,
                        child: Text(warehouse.name),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedWarehouseId = value;
                      });
                    },
                  ),
                ),
                // ロケーション一覧
                Expanded(
                  child: _filteredLocations.isEmpty
                      ? const Center(child: Text('ロケーションがありません'))
                      : ListView.builder(
                          itemCount: _filteredLocations.length,
                          itemBuilder: (context, index) {
                            final location = _filteredLocations[index];
                            final warehouse = _warehouses.firstWhere(
                              (w) => w.id == location.warehouseId,
                              orElse: () => Warehouse(
                                id: location.warehouseId,
                                name: '不明',
                                location: '',
                                notes: '',
                                updatedAt: DateTime.now(),
                              ),
                            );

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: location.isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                title: Text(location.locationName),
                                subtitle: Text(
                                  '${warehouse.name} - ${location.locationCode}\n'
                                  '${location.description ?? ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: location.isActive,
                                      onChanged: (_) => _toggleLocationActive(location),
                                    ),
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: const Text('編集'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: const Text('削除'),
                                        ),
                                      ],
                                      onSelected: (action) {
                                        switch (action) {
                                          case 'edit':
                                            _editLocation(location);
                                            break;
                                          case 'delete':
                                            _deleteLocation(location);
                                            break;
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ロケーション追加・編集ダイアログ
class LocationDialog extends StatefulWidget {
  final List<Warehouse> warehouses;
  final List<InventoryLocation> existingLocations;
  final InventoryLocation? editLocation;

  const LocationDialog({
    super.key,
    required this.warehouses,
    required this.existingLocations,
    this.editLocation,
  });

  @override
  State<LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<LocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedWarehouseId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.editLocation != null) {
      _codeController.text = widget.editLocation!.locationCode;
      _nameController.text = widget.editLocation!.locationName;
      _descriptionController.text = widget.editLocation!.description ?? '';
      _selectedWarehouseId = widget.editLocation!.warehouseId;
      _isActive = widget.editLocation!.isActive;
    } else if (widget.warehouses.isNotEmpty) {
      _selectedWarehouseId = widget.warehouses.first.id;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isCodeDuplicate(String code) {
    if (widget.editLocation != null && widget.editLocation!.locationCode == code) {
      return false;
    }
    return widget.existingLocations.any((loc) =>
        loc.warehouseId == _selectedWarehouseId && loc.locationCode == code);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouseId == null) return;

    final location = InventoryLocation(
      id: widget.editLocation?.id ?? 'loc_${DateTime.now().millisecondsSinceEpoch}',
      warehouseId: _selectedWarehouseId!,
      locationCode: _codeController.text.trim(),
      locationName: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      isActive: _isActive,
      createdAt: widget.editLocation?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editLocation == null ? 'ロケーション追加' : 'ロケーション編集'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedWarehouseId,
                decoration: const InputDecoration(
                  labelText: 'ウェアハウス',
                  border: OutlineInputBorder(),
                ),
                items: widget.warehouses.map((warehouse) => DropdownMenuItem(
                  value: warehouse.id,
                  child: Text(warehouse.name),
                )).toList(),
                validator: (value) => value == null ? 'ウェアハウスを選択してください' : null,
                onChanged: (value) {
                  setState(() {
                    _selectedWarehouseId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'ロケーションコード',
                  border: OutlineInputBorder(),
                  hintText: '例: A-01, RACK-001',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'ロケーションコードを入力してください';
                  }
                  if (_isCodeDuplicate(value.trim())) {
                    return 'このコードは既に使用されています';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_]')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ロケーション名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'ロケーション名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明（任意）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                title: const Text('アクティブ'),
                subtitle: const Text('このロケーションを使用する'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
