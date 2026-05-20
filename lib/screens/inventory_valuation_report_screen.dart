import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_model.dart';
import '../services/inventory_repository.dart';

class InventoryValuationReportScreen extends StatefulWidget {
  const InventoryValuationReportScreen({super.key});

  @override
  State<InventoryValuationReportScreen> createState() =>
      _InventoryValuationReportScreenState();
}

class _InventoryValuationReportScreenState
    extends State<InventoryValuationReportScreen> {
  final InventoryRepository _inventoryRepo = InventoryRepository();
  List<Inventory> _inventory = [];
  bool _isLoading = true;
  String _selectedWarehouse = 'すべて';
  List<String> _warehouses = ['すべて'];

  final NumberFormat _currencyFormat = NumberFormat('#,###');
  final NumberFormat _decimalFormat = NumberFormat('#,###.00');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final inventory = await _inventoryRepo.getAllInventory();
      final warehouseSet = <String>{'すべて'};
      for (final item in inventory) {
        if (item.warehouseName.isNotEmpty) {
          warehouseSet.add(item.warehouseName);
        }
      }
      setState(() {
        _inventory = inventory;
        _warehouses = warehouseSet.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データ読み込みに失敗しました: $e')),
      );
    }
  }

  List<Inventory> get _filteredInventory {
    if (_selectedWarehouse == 'すべて') return _inventory;
    return _inventory
        .where((item) => item.warehouseName == _selectedWarehouse)
        .toList();
  }

  double get _totalValue {
    return _filteredInventory.fold(
      0.0,
      (sum, item) => sum + (item.quantity * (item.unitCost ?? 0)),
    );
  }

  int get _totalQuantity {
    return _filteredInventory.fold(0, (sum, item) => sum + item.quantity);
  }

  double get _totalReservedValue {
    return _filteredInventory.fold(
      0.0,
      (sum, item) =>
          sum + (item.reservedQuantity * (item.unitCost ?? 0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInventory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('R4:在庫評価額一覧'),
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
                _buildSummaryCards(),
                _buildWarehouseFilter(),
                Expanded(child: _buildInventoryList(filtered)),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('総数量', '$_totalQuantity個'),
              _summaryItem('評価額', '￥${_currencyFormat.format(_totalValue)}'),
              _summaryItem('引当中', '￥${_currencyFormat.format(_totalReservedValue)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('倉庫:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
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
    );
  }

  Widget _buildInventoryList(List<Inventory> items) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('在庫データがありません'),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final value = item.quantity * (item.unitCost ?? 0);
        final reservedValue =
            item.reservedQuantity * (item.unitCost ?? 0);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStockStatusColor(item, Theme.of(context).colorScheme),
              child: Text(
                '${item.quantity}',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            title: Text(
              item.productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '在庫: ${item.quantity}個 | 評価額: ￥${_currencyFormat.format(value)}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('商品ID', item.productId),
                    _detailRow('倉庫', item.warehouseName),
                    _detailRow('保管場所', item.location ?? '-'),
                    _detailRow('単価 (仕入)',
                        '￥${_decimalFormat.format(item.unitCost ?? 0)}'),
                    _detailRow('在庫数', '${item.quantity}個'),
                    _detailRow('引当数', '${item.reservedQuantity}個'),
                    _detailRow('評価額', '￥${_currencyFormat.format(value)}'),
                    _detailRow('引当評価額',
                        '￥${_currencyFormat.format(reservedValue)}'),
                    if (item.reorderPoint != null)
                      _detailRow(
                          '発注点', '${item.reorderPoint}個'),
                    if (item.safetyStock != null)
                      _detailRow(
                          '安全在庫', '${item.safetyStock}個'),
                    _detailRow('状態', item.getStockStatus()),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.unitCost != null && item.unitCost! > 0
                          ? reservedValue / value.clamp(0.01, double.infinity)
                          : 0,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '引当比率: ${value > 0 ? (reservedValue / value * 100).toStringAsFixed(1) : '0.0'}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

   Color _getStockStatusColor(Inventory item, ColorScheme cs) {
    if (item.isOutOfStock) return cs.error;
    if (item.isLowStock) return cs.secondary;
    if (item.isOverReserved) return cs.tertiary;
    return cs.primary;
  }
}
