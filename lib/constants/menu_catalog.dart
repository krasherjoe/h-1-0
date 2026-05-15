import '../models/dashboard_menu_item.dart';

class MenuDefinition {
  final String id;
  final String title;
  final String route;
  final String category;
  final String iconName;
  final String description;

  const MenuDefinition({
    required this.id,
    required this.title,
    required this.route,
    required this.category,
    required this.iconName,
    required this.description,
  });

  DashboardMenuItem toMenuItem() => DashboardMenuItem(
        id: id,
        title: title,
        route: route,
        category: category,
        iconName: iconName,
        description: description,
      );
}

const List<String> kMenuCategoryOrder = [
  '01. マスタ管理',
  '02. 販売管理',
  '03. 仕入管理',
  '04. 在庫管理',
  '05. 集計分析',
  '06. システム設定',
];

const Map<String, String> kMenuCategoryDescriptions = {
  '01. マスタ管理': '商品・顧客・仕入先など基礎データを整える領域',
  '02. 販売管理': '見積〜請求までの販売プロセス',
  '03. 仕入管理': '発注・仕入・支払を含む購買プロセス',
  '04. 在庫管理': '倉庫在庫の把握と移動・棚卸・調整',
  '05. 集計分析': '日報や推移・粗利などの集計レポート',
  '06. システム設定': 'ユーザーやログなど基盤設定',
};

const List<MenuDefinition> kMenuDefinitions = [
  // 01. マスタ管理
  MenuDefinition(
    id: 'p1',
    title: '商品マスタ',
    route: 'product_master',
    category: '01. マスタ管理',
    iconName: 'product',
    description: '商品の登録・編集・在庫単位設定',
  ),
  MenuDefinition(
    id: 'c1',
    title: '得意先マスタ',
    route: 'customer_master',
    category: '01. マスタ管理',
    iconName: 'customer',
    description: '顧客・請求先や連絡先の管理',
  ),
  MenuDefinition(
    id: 'sup1',
    title: '仕入先マスタ',
    route: 'supplier_master',
    category: '01. マスタ管理',
    iconName: 'store',
    description: '仕入取引先の情報と条件を管理',
  ),
  MenuDefinition(
    id: 'w1',
    title: '倉庫マスタ',
    route: 'warehouse_master',
    category: '01. マスタ管理',
    iconName: 'warehouse',
    description: '保管場所や倉庫属性を設定',
  ),
  MenuDefinition(
    id: 'staff1',
    title: '担当者マスタ',
    route: 'staff_master',
    category: '01. マスタ管理',
    iconName: 'badge',
    description: '営業担当・部署の管理',
  ),
  MenuDefinition(
    id: 'm1',
    title: 'マスター管理',
    route: 'master_hub',
    category: '01. マスタ管理',
    iconName: 'master',
    description: '主要マスターや会社情報をまとめて管理',
  ),

  // 02. 販売管理
  MenuDefinition(
    id: 'pj1',
    title: '案件管理',
    route: 'project_list',
    category: '02. 販売管理',
    iconName: 'folder_special',
    description: '見積・請求・売上を案件単位でまとめて管理',
  ),
  MenuDefinition(
    id: 'q1',
    title: '見積入力',
    route: 'quotation_input',
    category: '02. 販売管理',
    iconName: 'request_quote',
    description: '見積作成と履歴管理',
  ),
  MenuDefinition(
    id: 'o1',
    title: '受注入力',
    route: 'order_input',
    category: '02. 販売管理',
    iconName: 'assignment_turned_in',
    description: '受注登録と進捗管理',
  ),
  MenuDefinition(
    id: 'a1',
    title: '売上入力',
    route: 'sales_entry',
    category: '02. 販売管理',
    iconName: 'point_of_sale',
    description: 'レジモード売上入力',
  ),
  MenuDefinition(
    id: 'sr1',
    title: '売上返品入力',
    route: 'sales_return_input',
    category: '02. 販売管理',
    iconName: 'assignment_return',
    description: '返品・値引処理',
  ),
  MenuDefinition(
    id: 'inv1',
    title: '請求書発行',
    route: 'invoice_issue',
    category: '02. 販売管理',
    iconName: 'picture_as_pdf',
    description: '請求書PDF生成と送付',
  ),
  MenuDefinition(
    id: 'doc1',
    title: '伝票入力',
    route: 'invoice_input',
    category: '02. 販売管理',
    iconName: 'description',
    description: '見積・納品・請求・領収の汎用伝票入力',
  ),
  MenuDefinition(
    id: 'DL',
    title: '配送記録一覧',
    route: 'delivery_list',
    category: '02. 販売管理',
    iconName: 'local_shipping',
    description: '配送記録の一覧表示と管理',
  ),
  MenuDefinition(
    id: 'a2',
    title: '伝票一覧',
    route: 'invoice_history',
    category: '02. 販売管理',
    iconName: 'list_alt',
    description: '発行済み伝票の一覧と履歴',
  ),

  // 03. 仕入管理
  MenuDefinition(
    id: 'po1',
    title: '発注入力',
    route: 'purchase_order_input',
    category: '03. 仕入管理',
    iconName: 'playlist_add_check',
    description: '仕入先への発注書作成',
  ),
  MenuDefinition(
    id: 'p2',
    title: '仕入入力',
    route: 'purchase_entries',
    category: '03. 仕入管理',
    iconName: 'shopping_cart',
    description: '仕入伝票と未入荷の管理',
  ),
  MenuDefinition(
    id: 'pr1',
    title: '仕入返品入力',
    route: 'purchase_return_input',
    category: '03. 仕入管理',
    iconName: 'undo',
    description: '仕入の返品・値引処理',
  ),
  MenuDefinition(
    id: 'p3',
    title: '支払予定管理',
    route: 'purchase_receipts',
    category: '03. 仕入管理',
    iconName: 'payments',
    description: '支払予定・実績の照会',
  ),
  MenuDefinition(
    id: 'pay1',
    title: '支払予定',
    route: 'payment_schedule',
    category: '03. 仕入管理',
    iconName: 'payment',
    description: '支払予定の一覧と管理',
  ),
  MenuDefinition(
    id: 'pay2',
    title: '支払登録',
    route: 'payment_register',
    category: '03. 仕入管理',
    iconName: 'receipt_long',
    description: '支払実績の登録',
  ),
  MenuDefinition(
    id: 'cf1',
    title: '資金繰り',
    route: 'cash_flow',
    category: '05. 集計分析',
    iconName: 'trending_up',
    description: '資金繰りの予測と分析',
  ),

  // 04. 在庫管理
  MenuDefinition(
    id: 'i1',
    title: '在庫照会',
    route: 'inventory_lookup',
    category: '04. 在庫管理',
    iconName: 'inventory',
    description: '倉庫別在庫を即時照会',
  ),
  MenuDefinition(
    id: 'IV',
    title: '在庫一覧',
    route: 'inventory_list',
    category: '04. 在庫管理',
    iconName: 'inventory_2',
    description: '商品在庫の一覧表示',
  ),
  MenuDefinition(
    id: 'i2',
    title: '在庫移動',
    route: 'stock_transfer',
    category: '04. 在庫管理',
    iconName: 'compare_arrows',
    description: '倉庫間の移動伝票を登録',
  ),
  MenuDefinition(
    id: 'i3',
    title: '棚卸入力',
    route: 'stocktake_input',
    category: '04. 在庫管理',
    iconName: 'fact_check',
    description: '棚卸リストを入力・確定',
  ),
  MenuDefinition(
    id: 'i4',
    title: '在庫調整',
    route: 'stock_adjustment',
    category: '04. 在庫管理',
    iconName: 'tune',
    description: 'ロス・評価替えの調整伝票',
  ),

  // 05. 集計分析
  MenuDefinition(
    id: 'analytics_dashboard',
    title: '集計ダッシュボード',
    route: 'analytics_dashboard',
    category: '05. 集計分析',
    iconName: 'analytics',
    description: '売上・仕入・在庫の集計ダッシュボード',
  ),
  MenuDefinition(
    id: 'r1',
    title: '売上日報',
    route: 'sales_report',
    category: '05. 集計分析',
    iconName: 'analytics',
    description: '日別売上・資金のサマリ',
  ),
  MenuDefinition(
    id: 'r2',
    title: '得意先別売上推移',
    route: 'customer_sales_report',
    category: '05. 集計分析',
    iconName: 'stacked_line_chart',
    description: '得意先別の推移グラフ',
  ),
  MenuDefinition(
    id: 'SA',
    title: '売上分析',
    route: 'sales_analysis',
    category: '05. 集計分析',
    iconName: 'analytics',
    description: '売上データの分析とレポート',
  ),
  MenuDefinition(
    id: 'r3',
    title: '商品別粗利分析',
    route: 'product_margin_report',
    category: '05. 集計分析',
    iconName: 'show_chart',
    description: '粗利率・粗利額を分析',
  ),
  MenuDefinition(
    id: 'r4',
    title: '在庫評価額一覧',
    route: 'inventory_valuation_report',
    category: '05. 集計分析',
    iconName: 'account_balance_wallet',
    description: '在庫金額や評価差額の確認',
  ),

  // 06. システム設定
  MenuDefinition(
    id: 's1',
    title: 'システム設定',
    route: 'settings',
    category: '06. システム設定',
    iconName: 'settings',
    description: '端末や同期・テーマなどを設定',
  ),
  MenuDefinition(
    id: 's2',
    title: 'ユーザー権限設定',
    route: 'user_permissions',
    category: '06. システム設定',
    iconName: 'admin_panel_settings',
    description: '利用者アカウントと権限の管理',
  ),
  MenuDefinition(
    id: 's3',
    title: 'ログ管理',
    route: 'log_management',
    category: '06. システム設定',
    iconName: 'article',
    description: '操作ログや監査ログの閲覧',
  ),
  MenuDefinition(
    id: 'sup',
    title: 'サポート窓口管理',
    route: 'support_desk',
    category: '06. システム設定',
    iconName: 'support_agent',
    description: '顧客サポートチケットの管理と対応',
  ),
  MenuDefinition(
    id: 'wh',
    title: '倉庫ダッシュボード',
    route: 'warehouse_dashboard',
    category: '04. 在庫管理',
    iconName: 'warehouse',
    description: '倉庫別在庫状況の可視化と分析',
  ),
  MenuDefinition(
    id: 'st',
    title: 'スタッフ管理',
    route: 'staff_management',
    category: '06. システム設定',
    iconName: 'badge',
    description: 'スタッフ情報と権限の管理',
  ),

  // 07. 業種設定
  MenuDefinition(
    id: 'b1',
    title: '業種設定',
    route: 'business_profile',
    category: '07. 業種設定',
    iconName: 'business',
    description: '業種別の業務フローと機能設定',
  ),
  MenuDefinition(
    id: 'i4',
    title: '在庫ロケーション',
    route: 'inventory_location',
    category: '04. 在庫管理',
    iconName: 'location_on',
    description: '倉庫内ロケーションの管理',
  ),
  MenuDefinition(
    id: 'i5',
    title: '在庫移動・棚卸',
    route: 'inventory_movement',
    category: '04. 在庫管理',
    iconName: 'swap_horiz',
    description: '在庫移動と棚卸の記録',
  ),
];

final Map<String, MenuDefinition> kMenuDefinitionMap = {for (final def in kMenuDefinitions) def.id: def};

MenuDefinition? menuDefinitionById(String id) => kMenuDefinitionMap[id];

final Map<String, MenuDefinition> kMenuDefinitionByRoute = {for (final def in kMenuDefinitions) def.route: def};

MenuDefinition? menuDefinitionByRoute(String route) => kMenuDefinitionByRoute[route];
