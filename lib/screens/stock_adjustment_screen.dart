import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_model.dart';
import '../models/product_model.dart';
import '../services/inventory_repository.dart';
import '../services/product_repository.dart';
import '../services/activity_log_repository.dart';

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final InventoryRepository _inventoryRepo = InventoryRepository();
  final ProductRepository _productRepo = ProductRepository();
  final ActivityLogRepository _activityLog = ActivityLogRepository();

  List<Product> _products = [];
  List<Inventory> _inventory = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedWarehouse = 'すべて';
  late List<String> _warehouses;

  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _warehouses = ['すべて'];
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAllProducts();
      final inventory = await _inventoryRepo.getAllInventory();
      final warehouseSet = <String>{'すべて'};
      for (final item in inventory) {
        if (item.warehouseName.isNotEmpty) {
          warehouseSet.add(item.warehouseName);
        }
      }
      if (!mounted) return;
      setState(() {
        _products = products;
        _inventory = inventory;
        _warehouses = warehouseSet.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データ読み込みに失敗しました: $e')),
      );
    }
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch;
    }).toList();
  }

  Inventory _getInventoryForProduct(String productId) {
    return _inventory.firstWhere(
      (item) => item.productId == productId,
      orElse: () => Inventory(
        id: '',
        productId: productId,
        productName: '未登録',
        quantity: 0,
        warehouseId: '',
        warehouseName: '',
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _showAdjustmentDialog(Product product) async {
    final inventory = _getInventoryForProduct(product.id);
    final TextEditingController quantityController = TextEditingController(
      text: inventory.quantity.toString(),
    );
    String reason = 'その他';
    String? selectedWarehouse = _selectedWarehouse == 'すべて' ? inventory.warehouseName : _selectedWarehouse;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${product.name} の在庫調整'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('現在在庫'),
                  trailing: Text('${inventory.quantity}個'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: '調整後数量',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('倉庫'),
                DropdownButton<String>(
                  value: selectedWarehouse,
                  isExpanded: true,
                  items: _warehouses.map((warehouse) {
                    return DropdownMenuItem(
                      value: warehouse,
                      child: Text(warehouse),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedWarehouse = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('調整理由'),
                DropdownButton<String>(
                  value: reason,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '破損', child: Text('破損')),
                    DropdownMenuItem(value: '紛失', child: Text('紛失')),
                    DropdownMenuItem(value: '棚卸差', child: Text('棚卸差額')),
                    DropdownMenuItem(value: '評価替え', child: Text('評価替え')),
                    DropdownMenuItem(value: 'その他', child: Text('その他')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => reason = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'quantity': quantityController.text,
                  'reason': reason,
                  'warehouse': selectedWarehouse,
                });
              },
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final newQuantity = int.tryParse(result['quantity'] as String);
      final reason = result['reason'] as String;
      final warehouse = result['warehouse'] as String? ?? '';

      if (newQuantity != null && newQuantity >= 0) {
        await _performAdjustment(
          product: product,
          newQuantity: newQuantity,
          reason: reason,
          warehouse: warehouse,
          currentInventory: inventory,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効な数量を入力してください')),
        );
      }
    }
  }

  Future<void> _performAdjustment({
    required Product product,
    required int newQuantity,
    required String reason,
    required String warehouse,
    required Inventory currentInventory,
  }) async {
    try {
      await _inventoryRepo.updateInventory(
        product.id,
        newQuantity,
      );

      final logMessage = '在庫調整: ${product.name} (${currentInventory.quantity}個 → $newQuantity個) 理由: $reason 倉庫: $warehouse';

      await _activityLog.logAction(
        action: 'stock_adjustment',
        targetType: 'inventory',
        targetId: product.id,
        details: logMessage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} を $newQuantity個に調整しました'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('調整に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IA:在庫調整'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndFilter(),
                Expanded(child: _buildProductList(filteredProducts)),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilter() {
    final filteredProducts = _filteredProducts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '商品名またはバーコード',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: DropdownButton<String>(
                  value: _selectedWarehouse,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _warehouses.map((warehouse) {
                    return DropdownMenuItem(
                      value: warehouse,
                      child: Text(warehouse),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedWarehouse = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${filteredProducts.length}件登録中',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('商品データがありません'),
        ),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final inventory = _getInventoryForProduct(product.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStockStatusColor(inventory, Theme.of(context).colorScheme),
              child: Text(
                '${inventory.quantity}',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.barcode != null)
                  Text('品番: ${product.barcode}'),
                Text('倉庫: ${inventory.warehouseName}'),
                if (inventory.isLowStock && !inventory.isOutOfStock)
                  Text('⚠ 発注必要', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                if (inventory.isOutOfStock)
                  Text('✕ 欠品', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '￥${_currencyFormat.format(product.defaultUnitPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('評価額: ￥${_currencyFormat.format(inventory.quantity * (inventory.unitCost ?? 0))}'),
              ],
            ),
            onTap: () => _showAdjustmentDialog(product),
          ),
        );
      },
    );
  }

   Color _getStockStatusColor(Inventory item, ColorScheme cs) {
    if (item.isOutOfStock) return cs.error;
    if (item.isLowStock) return cs.secondary;
    if (item.isOverReserved) return cs.tertiary;
    return cs.primary;
  }
}
