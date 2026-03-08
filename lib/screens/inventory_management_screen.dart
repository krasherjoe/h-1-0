/// 在庫管理画面
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/inventory_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/base_document.dart';
import '../models/inventory_model.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = InventoryRepository();

    return GenericListScreen<Inventory>(
      screenId: 'I1',
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
                _showAdjustmentDialog(inventory, onRefresh);
              },
            ),
            CardAction(
              label: '引当',
              icon: Icons.inventory_2,
              onPressed: () {
                if (!mounted) return;
                _showReservationDialog(inventory, onRefresh);
              },
            ),
          ],
        );
      },

      // フィルタ
      filters: [
        FilterOption(
          label: '全て',
          value: 'all',
          filter: (inventory) => inventory,
        ),
        FilterOption(
          label: '適正在庫',
          value: 'normal',
          filter: (inventories) => inventories.where((i) => i.quantity > (i.reorderPoint ?? 0)).toList(),
        ),
        FilterOption(
          label: '要発注',
          value: 'low',
          filter: (inventories) => inventories.where((i) => i.isLowStock && !i.isOutOfStock).toList(),
        ),
        FilterOption(
          label: '欠品',
          value: 'out',
          filter: (inventories) => inventories.where((i) => i.isOutOfStock).toList(),
        ),
      ],

      // 新規作成
      onCreateNew: () async {
        if (!mounted) return;
        _showAddInventoryDialog();
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.inventory,
        title: '在庫がありません',
        subtitle: '新しい在庫を登録してください',
        actionLabel: '在庫登録',
        iconColor: Colors.purple,
        onAction: () {
          if (!mounted) return;
          _showAddInventoryDialog();
        },
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
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('在庫を調整しました')),
                );
                onRefresh();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('調整に失敗しました: $e')),
                );
              }
            },
            child: const Text('調整'),
          ),
        ],
      ),
    );
  }

  void _showReservationDialog(Inventory inventory, VoidCallback onRefresh) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${inventory.productName} - 引当調整'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('現在在庫: ${inventory.quantity}個'),
            Text('現在引当: ${inventory.reservedQuantity}個'),
            Text('利用可能: ${inventory.availableQuantity}個'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '引当調整数量（+で増加、-で減少）',
                hintText: '例: +5 または -3',
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
                await repo.adjustReservation(inventory.productId, value);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('引当を調整しました')),
                );
                onRefresh();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('調整に失敗しました: $e')),
                );
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
              decoration: const InputDecoration(labelText: '場所（任意）'),
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
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text);
              final location = locationController.text.trim();
              
              if (name.isEmpty || quantity == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('商品名と数量を入力してください')),
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
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('在庫を登録しました')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('登録に失敗しました: $e')),
                );
              }
            },
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }
}
