import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/inventory_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/inventory_model.dart';
import 'inventory_location_screen.dart';
import 'inventory_movement_screen.dart';

/// 在庫管理画面
class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = InventoryRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('IQ:在庫照会'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryLocationScreen()),
              );
            },
            icon: const Icon(Icons.location_on),
            tooltip: 'ロケーション管理',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryMovementScreen()),
              );
            },
            icon: const Icon(Icons.swap_horiz),
            tooltip: '移動・棚卸',
          ),
        ],
      ),
      body: GenericListScreen<Inventory>(
        screenId: 'IQ',
        title: '在庫管理',
        icon: Icons.inventory,
        themeColor: Colors.purple,

        // データ取得
        fetchData: () => repo.getAllInventory(),

        // カード表示
        buildCard: (context, inventory, onRefresh) {
          return DocumentCard(
            title: inventory.productName,
            subtitle: _buildSubtitle(inventory),
            amount: '${inventory.quantity}個',
            date: inventory.updatedAt,
            status: _getDocumentStatus(inventory),
            themeColor: inventory.getStockStatusColor(),
            onTap: () {
              if (!mounted) return;
              _showInventoryDialog(inventory);
            },
            actions: [
              CardAction(
                label: '調整',
                icon: Icons.edit,
                onPressed: () {
                  if (!mounted) return;
                  _showAdjustmentDialog(inventory, () {});
                },
              ),
            ],
          );
        },

        // 空状態
        emptyWidget: const EmptyStateWidget(
          icon: Icons.inventory_outlined,
          title: '在庫データがありません',
          subtitle: '在庫を登録して管理を開始しましょう',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddInventoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _buildSubtitle(Inventory inventory) {
    final parts = <String>[];
    if (inventory.location != null) parts.add('場所: ${inventory.location}');
    if (inventory.reservedQuantity > 0) {
      parts.add('引当: ${inventory.reservedQuantity}個');
    }
    parts.add('利用可能: ${inventory.availableQuantity}個');
    if (inventory.reorderPoint != null) {
      parts.add('発注点: ${inventory.reorderPoint}個');
    }
    return parts.join(' | ');
  }

  DocumentStatus _getDocumentStatus(Inventory inventory) {
    if (inventory.isOutOfStock) return DocumentStatus.cancelled;
    if (inventory.isLowStock) return DocumentStatus.draft;
    return DocumentStatus.confirmed;
  }

  void _showInventoryDialog(Inventory inventory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(inventory.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在在庫: ${inventory.quantity}個'),
            Text('引当数: ${inventory.reservedQuantity}個'),
            Text('利用可能在庫: ${inventory.availableQuantity}個'),
            const SizedBox(height: 8),
            Text('状態: ${inventory.getStockStatus()}'),
            if (inventory.location != null) Text('場所: ${inventory.location}'),
            if (inventory.unitCost != null) Text('単価: ¥${inventory.unitCost}'),
            if (inventory.reorderPoint != null) Text('発注点: ${inventory.reorderPoint}個'),
            if (inventory.safetyStock != null) Text('安全在庫: ${inventory.safetyStock}個'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDialog(Inventory inventory, VoidCallback onRefresh) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${inventory.productName} - 在庫調整'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('現在在庫: ${inventory.quantity}個'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '調整数量（+で増加、-で減少）',
                hintText: '例: +10 または -5',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final value = int.tryParse(controller.text);
              if (value == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('有効な数値を入力してください')),
                );
                return;
              }
              
              try {
                final repo = InventoryRepository();
                await repo.adjustInventory(inventory.productId, value);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('在庫を調整しました')),
                  );
                }
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('調整に失敗しました: $e')),
                  );
                }
              }
            },
            child: const Text('調整'),
          ),
        ],
      ),
    );
  }

  void _showAddInventoryDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final locationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新規在庫登録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '商品名'),
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: '数量'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: '保管場所'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text;
              final quantity = int.tryParse(quantityController.text) ?? 0;
              final location = locationController.text;
              
              if (name.isEmpty || quantity <= 0) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('有効な情報を入力してください')),
                );
                return;
              }
              
              try {
                final repo = InventoryRepository();
                final inventory = Inventory(
                  id: Uuid().v4(),
                  productId: Uuid().v4(),
                  productName: name,
                  quantity: quantity,
                  location: location.isEmpty ? null : location,
                  warehouseId: 'WH-001',
                  warehouseName: '主倉庫',
                  updatedAt: DateTime.now(),
                );
                await repo.saveInventory(inventory);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('在庫を登録しました')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('登録に失敗しました: $e')),
                  );
                }
              }
            },
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }
}
