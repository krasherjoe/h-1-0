import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../services/inventory_repository.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final InventoryRepository _repository = InventoryRepository();
  List<Inventory> _inventories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    setState(() => _isLoading = true);
    try {
      final inventories = await _repository.getAllInventory();
      if (mounted) {
        setState(() {
          _inventories = inventories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IV:在庫一覧'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inventories.isEmpty
              ? const Center(child: Text('在庫データがありません'))
              : RefreshIndicator(
                  onRefresh: _loadInventories,
                  child: ListView.builder(
                    itemCount: _inventories.length,
                    itemBuilder: (context, index) {
                      final inventory = _inventories[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.orange),
                        title: Text(inventory.productName),
                        subtitle: Text('倉庫: ${inventory.warehouseName}'),
                        trailing: Text(
                          '${inventory.quantity}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: inventory.quantity > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
