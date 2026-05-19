import 'package:flutter/material.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import 'settings_screen.dart';
import 'supplier_master_screen.dart';
import 'staff_master_screen.dart';
import 'warehouse_master_screen.dart';

class MasterHubPage extends StatelessWidget {
  const MasterHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <MasterEntry>[
      MasterEntry(
        title: '顧客マスター',
        description: '顧客情報の管理・編集',
        icon: Icons.people,
        builder: (_) => const CustomerMasterScreen(),
      ),
      MasterEntry(
        title: '商品マスター',
        description: '商品情報の管理・編集',
        icon: Icons.inventory_2,
        builder: (_) => const ProductMasterScreen(),
      ),
      MasterEntry(
        title: '仕入先マスター',
        description: '仕入先情報の管理・編集',
        icon: Icons.business,
        builder: (_) => const SupplierMasterScreen(),
      ),
      MasterEntry(
        title: '担当者マスター',
        description: '社内担当者の管理・編集',
        icon: Icons.badge,
        builder: (_) => const StaffMasterScreen(),
      ),
      MasterEntry(
        title: '倉庫マスター',
        description: '倉庫・拠点情報の管理・編集',
        icon: Icons.warehouse,
        builder: (_) => const WarehouseMasterScreen(),
      ),
      MasterEntry(
        title: '設定',
        description: 'アプリ設定・メニュー管理',
        icon: Icons.settings,
        builder: (_) => const SettingsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('マスター管理'),
            Text('ScreenID: M1', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(item.icon),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: item.builder)),
            ),
          );
        },
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }
}

class MasterEntry {
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
  const MasterEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });
}
