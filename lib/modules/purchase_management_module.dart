import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../modules/feature_module.dart';
import '../screens/purchase_entries_screen.dart';
import '../screens/purchase_receipts_screen.dart';

class PurchaseManagementModule extends FeatureModule {
  PurchaseManagementModule();

  @override
  String get key => 'purchase_management';

  @override
  bool get isEnabled => AppConfig.enablePurchaseModule;

  @override
  List<ModuleDashboardCard> get dashboardCards => [
        ModuleDashboardCard(
          id: 'purchase_entries',
          route: 'purchase_entries',
          title: '仕入伝票',
          description: 'P1/P2:仕入伝票の一覧と編集',
          iconName: 'shopping_cart',
          onTap: (context) async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseEntriesScreen()));
          },
        ),
        ModuleDashboardCard(
          id: 'purchase_receipts',
          route: 'purchase_receipts',
          title: '支払管理',
          description: 'P3/P4:支払登録と割当',
          iconName: 'payments',
          onTap: (context) async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseReceiptsScreen()));
          },
        ),
      ];
}
