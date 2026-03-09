import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/inventory_location_model.dart';
import '../models/inventory_model.dart';
import '../models/product_model.dart';
import '../models/warehouse_model.dart';
import '../services/inventory_location_repository.dart';
import '../services/inventory_repository.dart';
import '../services/product_repository.dart';
import '../services/warehouse_repository.dart';

/// 在庫移動・棚卸記録画面（I5）
class InventoryMovementScreen extends StatefulWidget {
  const InventoryMovementScreen({super.key});

  @override
  State<InventoryMovementScreen> createState() => _InventoryMovementScreenState();
}

class _InventoryMovementScreenState extends State<InventoryMovementScreen> {
  final InventoryMovementRepository _movementRepo = InventoryMovementRepository();
  final InventoryLocationRepository _locationRepo = InventoryLocationRepository();
  final ProductRepository _productRepo = ProductRepository();
  final WarehouseRepository _warehouseRepo = WarehouseRepository();
  
  List<InventoryMovement> _movements = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  List<InventoryLocation> _locations = [];
  bool _loading = true;
  String? _selectedWarehouseId;
  String? _selectedMovementType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final movements = await _movementRepo.getAllMovements();
      final products = await _productRepo.getAllProducts();
      final warehouses = await _warehouseRepo.getAllWarehouses();
      final locations = await _locationRepo.getAllLocations();
      
      if (!mounted) return;
      setState(() {
        _movements = movements;
        _products = products;
        _warehouses = warehouses;
        _locations = locations;
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

  Future<void> _addMovement() async {
    final result = await showDialog<InventoryMovementData>(
      context: context,
      builder: (context) => MovementDialog(
        products: _products,
        warehouses: _warehouses,
        locations: _locations,
      ),
    );

    if (result != null) {
      try {
        final movement = InventoryMovement(
          id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
          productId: result.productId,
          warehouseId: result.warehouseId,
          locationId: result.locationId,
          movementType: result.movementType,
          quantity: result.quantity,
          referenceId: result.referenceId,
          referenceType: result.referenceType,
          notes: result.notes,
          movementDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _movementRepo.recordMovement(movement);
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('移動を記録しました')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('記録エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteMovement(InventoryMovement movement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${movement.movementTypeName}記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _movementRepo.deleteMovement(movement.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('移動記録を削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除エラー: $e')),
      );
    }
  }

  List<InventoryLocation> get _availableLocations {
    if (_selectedWarehouseId == null) return _locations.where((loc) => loc.isActive).toList();
    return _locations.where((loc) => loc.warehouseId == _selectedWarehouseId && loc.isActive).toList();
  }

  List<InventoryMovement> get _filteredMovements {
    var filtered = _movements;

    if (_selectedWarehouseId != null) {
      filtered = filtered.where((m) => m.warehouseId == _selectedWarehouseId).toList();
    }

    if (_selectedMovementType != null) {
      filtered = filtered.where((m) => m.movementType.name == _selectedMovementType).toList();
    }

    return filtered;
  }

  String _getProductName(String productId) {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
        id: productId,
        name: '不明',
        defaultUnitPrice: 0,
      ),
    );
    return product.name;
  }

  String _getWarehouseName(String warehouseId) {
    final warehouse = _warehouses.firstWhere(
      (w) => w.id == warehouseId,
      orElse: () => Warehouse(
        id: warehouseId,
        name: '不明',
        location: '',
        notes: '',
        updatedAt: DateTime.now(),
      ),
    );
    return warehouse.name;
  }

  String _getLocationName(String? locationId) {
    if (locationId == null) return '';
    final location = _locations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => InventoryLocation(
        id: locationId,
        warehouseId: '',
        locationCode: '',
        locationName: '不明',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return location.locationName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I5:在庫移動・棚卸'),
        backgroundColor: Colors.indigo,
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
                // フィルター
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'ウェアハウス',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('すべて'),
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMovementType,
                          decoration: const InputDecoration(
                            labelText: '移動タイプ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('すべて'),
                            ),
                            ...InventoryMovementType.values.map((type) => DropdownMenuItem(
                              value: type.name,
                              child: Text(_getMovementTypeName(type)),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedMovementType = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 移動履歴一覧
                Expanded(
                  child: _filteredMovements.isEmpty
                      ? const Center(child: Text('移動記録がありません'))
                      : ListView.builder(
                          itemCount: _filteredMovements.length,
                          itemBuilder: (context, index) {
                            final movement = _filteredMovements[index];
                            final productName = _getProductName(movement.productId);
                            final warehouseName = _getWarehouseName(movement.warehouseId);
                            final locationName = _getLocationName(movement.locationId);

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(_getMovementTypeIcon(movement.movementType)),
                                  backgroundColor: _getMovementTypeColor(movement.movementType),
                                  foregroundColor: Colors.white,
                                ),
                                title: Text(productName),
                                subtitle: Text(
                                  '${movement.movementTypeName} | 数量: ${movement.quantity}\n'
                                  '${warehouseName}${locationName.isNotEmpty ? ' - $locationName' : ''}\n'
                                  '${movement.movementDate.toString().substring(0, 19)}'
                                  '${movement.notes != null ? '\n${movement.notes}' : ''}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteMovement(movement),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMovement,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getMovementTypeIcon(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.stockIn:
        return '入';
      case InventoryMovementType.stockOut:
        return '出';
      case InventoryMovementType.transfer:
        return '移';
      case InventoryMovementType.adjustment:
        return '調';
      case InventoryMovementType.stocktake:
        return '棚';
    }
  }

  Color _getMovementTypeColor(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.stockIn:
        return Colors.green;
      case InventoryMovementType.stockOut:
        return Colors.red;
      case InventoryMovementType.transfer:
        return Colors.blue;
      case InventoryMovementType.adjustment:
        return Colors.orange;
      case InventoryMovementType.stocktake:
        return Colors.purple;
    }
  }

  String _getMovementTypeName(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.stockIn:
        return '入庫';
      case InventoryMovementType.stockOut:
        return '出庫';
      case InventoryMovementType.transfer:
        return '移動';
      case InventoryMovementType.adjustment:
        return '調整';
      case InventoryMovementType.stocktake:
        return '棚卸';
    }
  }
}

/// 移動データクラス
class InventoryMovementData {
  final String productId;
  final String warehouseId;
  final String? locationId;
  final InventoryMovementType movementType;
  final int quantity;
  final String? referenceId;
  final String? referenceType;
  final String? notes;

  InventoryMovementData({
    required this.productId,
    required this.warehouseId,
    this.locationId,
    required this.movementType,
    required this.quantity,
    this.referenceId,
    this.referenceType,
    this.notes,
  });
}

/// 移動記録ダイアログ
class MovementDialog extends StatefulWidget {
  final List<Product> products;
  final List<Warehouse> warehouses;
  final List<InventoryLocation> locations;

  const MovementDialog({
    super.key,
    required this.products,
    required this.warehouses,
    required this.locations,
  });

  @override
  State<MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<MovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedProductId;
  String? _selectedWarehouseId;
  String? _selectedLocationId;
  InventoryMovementType _selectedMovementType = InventoryMovementType.stockIn;

  List<InventoryLocation> get _availableLocations {
    if (_selectedWarehouseId == null) return [];
    return widget.locations
        .where((loc) => loc.warehouseId == _selectedWarehouseId && loc.isActive)
        .toList();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null || _selectedWarehouseId == null) return;

    final data = InventoryMovementData(
      productId: _selectedProductId!,
      warehouseId: _selectedWarehouseId!,
      locationId: _selectedLocationId,
      movementType: _selectedMovementType,
      quantity: int.parse(_quantityController.text),
      referenceId: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      referenceType: _referenceController.text.trim().isEmpty ? null : 'manual',
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('移動記録'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedProductId,
                decoration: const InputDecoration(
                  labelText: '商品',
                  border: OutlineInputBorder(),
                ),
                items: widget.products.map((product) => DropdownMenuItem(
                  value: product.id,
                  child: Text(product.name),
                )).toList(),
                validator: (value) => value == null ? '商品を選択してください' : null,
                onChanged: (value) {
                  setState(() {
                    _selectedProductId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
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
                    _selectedLocationId = null; // ウェアハウス変更時にロケーションをリセット
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<InventoryMovementType>(
                initialValue: _selectedMovementType,
                decoration: const InputDecoration(
                  labelText: '移動タイプ',
                  border: OutlineInputBorder(),
                ),
                items: InventoryMovementType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_getMovementTypeName(type)),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMovementType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_availableLocations.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'ロケーション（任意）',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('指定しない'),
                    ),
                    ..._availableLocations.map((location) => DropdownMenuItem(
                      value: location.id,
                      child: Text('${location.locationCode} - ${location.locationName}'),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLocationId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '数量を入力してください';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return '正しい数量を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: '参照番号（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
          child: const Text('記録'),
        ),
      ],
    );
  }

  String _getMovementTypeName(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.stockIn:
        return '入庫';
      case InventoryMovementType.stockOut:
        return '出庫';
      case InventoryMovementType.transfer:
        return '移動';
      case InventoryMovementType.adjustment:
        return '調整';
      case InventoryMovementType.stocktake:
        return '棚卸';
    }
  }
}
