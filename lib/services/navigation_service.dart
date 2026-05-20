import 'package:flutter/material.dart';
import '../screens/performance_optimization_screen.dart';
import '../screens/fast_search_screen.dart';
import '../screens/sensor_utilization_screen.dart';
import '../screens/advanced_search_screen.dart';
import '../screens/enhanced_sensor_screen.dart';
import '../screens/ui_performance_screen.dart';

/// メイン画面プレースホルダー
class MainScreenPlaceholder extends StatelessWidget {
  const MainScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('画面実装準備中'),
      ),
    );
  }
}

/// メインナビゲーションサービス
class NavigationService {
  static NavigationService? _instance;
  static NavigationService get instance => _instance ??= NavigationService._();
  
  NavigationService._();
  
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// 画面遷移を実行
  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }
  
  /// 画面遷移を置換
  Future<dynamic> replaceTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
  }
  
  /// 画面を戻る
  void goBack() {
    navigatorKey.currentState!.pop();
  }
  
  /// すべての画面をクリアして遷移
  Future<dynamic> navigateAndClear(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }
}

/// アプリケーションルート定義
class AppRoutes {
  static const String home = '/';
  static const String invoiceList = '/invoices';
  static const String customerList = '/customers';
  static const String productList = '/products';
  static const String supplierList = '/suppliers';
  static const String performanceOptimization = '/performance';
  static const String fastSearch = '/search';
  static const String sensorUtilization = '/sensor';
  static const String advancedSearch = '/advanced-search';
  static const String enhancedSensor = '/enhanced-sensor';
  static const String uiPerformance = '/ui-performance';
  
  /// ルートマップを取得
  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const MainScreenPlaceholder(),
    invoiceList: (context) => const MainScreenPlaceholder(),
    customerList: (context) => const MainScreenPlaceholder(),
    productList: (context) => const MainScreenPlaceholder(),
    supplierList: (context) => const MainScreenPlaceholder(),
    performanceOptimization: (context) => const PerformanceOptimizationScreen(),
    fastSearch: (context) => const FastSearchScreen(),
    sensorUtilization: (context) => const SensorUtilizationScreen(),
    advancedSearch: (context) => const AdvancedSearchScreen(),
    enhancedSensor: (context) => const EnhancedSensorScreen(),
    uiPerformance: (context) => const UIPerformanceScreen(),
  };
  
  /// ルート名から画面タイトルを取得
  static String getScreenTitle(String routeName) {
    switch (routeName) {
      case home:
      case invoiceList:
        return 'I1:請求書一覧';
      case customerList:
        return 'C1:顧客一覧';
      case productList:
        return 'P1:製品一覧';
      case supplierList:
        return 'S1:仕入先一覧';
      case performanceOptimization:
        return 'P1:パフォーマンス最適化';
      case fastSearch:
        return 'S1:高速検索';
      case sensorUtilization:
        return 'S2:センサー活用';
      case advancedSearch:
        return 'S3:高度検索';
      case enhancedSensor:
        return 'S4:拡張センサー';
      case uiPerformance:
        return 'P2:UIパフォーマンス最適化';
      default:
        return '不明な画面';
    }
  }
  
  /// 画面IDを取得
  static String getScreenId(String routeName) {
    switch (routeName) {
      case home:
      case invoiceList:
        return 'I1';
      case customerList:
        return 'C1';
      case productList:
        return 'P1';
      case supplierList:
        return 'S1';
      case performanceOptimization:
        return 'P1';
      case fastSearch:
        return 'S1';
      case sensorUtilization:
        return 'S2';
      case advancedSearch:
        return 'S3';
      case enhancedSensor:
        return 'S4';
      case uiPerformance:
        return 'P2';
      default:
        return 'XX';
    }
  }
  
  /// すべての利用可能なルートを取得
  static List<RouteInfo> getAllRoutes() {
    return [
      RouteInfo(
        name: invoiceList,
        title: getScreenTitle(invoiceList),
        id: getScreenId(invoiceList),
        icon: Icons.receipt,
        description: '請求書の管理',
        category: '基本機能',
      ),
      RouteInfo(
        name: customerList,
        title: getScreenTitle(customerList),
        id: getScreenId(customerList),
        icon: Icons.people,
        description: '顧客情報の管理',
        category: '基本機能',
      ),
      RouteInfo(
        name: productList,
        title: getScreenTitle(productList),
        id: getScreenId(productList),
        icon: Icons.inventory,
        description: '製品情報の管理',
        category: '基本機能',
      ),
      RouteInfo(
        name: supplierList,
        title: getScreenTitle(supplierList),
        id: getScreenId(supplierList),
        icon: Icons.business,
        description: '仕入先情報の管理',
        category: '基本機能',
      ),
      RouteInfo(
        name: performanceOptimization,
        title: getScreenTitle(performanceOptimization),
        id: getScreenId(performanceOptimization),
        icon: Icons.speed,
        description: 'アプリのパフォーマンス最適化',
        category: 'パフォーマンス',
      ),
      RouteInfo(
        name: fastSearch,
        title: getScreenTitle(fastSearch),
        id: getScreenId(fastSearch),
        icon: Icons.search,
        description: '高速全文検索',
        category: '検索',
      ),
      RouteInfo(
        name: sensorUtilization,
        title: getScreenTitle(sensorUtilization),
        id: getScreenId(sensorUtilization),
        icon: Icons.sensors,
        description: 'センサー機能の活用',
        category: 'センサー',
      ),
      RouteInfo(
        name: advancedSearch,
        title: getScreenTitle(advancedSearch),
        id: getScreenId(advancedSearch),
        icon: Icons.manage_search,
        description: '高度な検索機能',
        category: '検索',
      ),
      RouteInfo(
        name: enhancedSensor,
        title: getScreenTitle(enhancedSensor),
        id: getScreenId(enhancedSensor),
        icon: Icons.sensors_rounded,
        description: '拡張センサー機能',
        category: 'センサー',
      ),
      RouteInfo(
        name: uiPerformance,
        title: getScreenTitle(uiPerformance),
        id: getScreenId(uiPerformance),
        icon: Icons.monitor_heart,
        description: 'UIパフォーマンスの最適化',
        category: 'パフォーマンス',
      ),
    ];
  }
  
  /// カテゴリ別にルートを取得
  static Map<String, List<RouteInfo>> getRoutesByCategory() {
    final allRoutes = getAllRoutes();
    final categorized = <String, List<RouteInfo>>{};
    
    for (final route in allRoutes) {
      categorized.putIfAbsent(route.category, () => []).add(route);
    }
    
    return categorized;
  }
}

/// ルート情報クラス
class RouteInfo {
  final String name;
  final String title;
  final String id;
  final IconData icon;
  final String description;
  final String category;
  
  RouteInfo({
    required this.name,
    required this.title,
    required this.id,
    required this.icon,
    required this.description,
    required this.category,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'id': id,
      'icon': icon.codePoint,
      'description': description,
      'category': category,
    };
  }
}

/// ナビゲーション drawer ウィジェット
class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});
  
  @override
  Widget build(BuildContext context) {
    final categorizedRoutes = AppRoutes.getRoutesByCategory();
    final navigationService = NavigationService.instance;
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.account_balance,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 16),
                Text(
                  '会計管理アプリ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'スマートフォンパフォーマンス最適化版',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ...categorizedRoutes.entries.map((entry) {
            return ExpansionTile(
              leading: Icon(_getCategoryIcon(entry.key)),
              title: Text(entry.key),
              children: entry.value.map((route) {
                return ListTile(
                  leading: Icon(route.icon),
                  title: Text(route.title),
                  subtitle: Text(route.description),
                  onTap: () {
                    Navigator.pop(context);
                    navigationService.navigateTo(route.name);
                  },
                );
              }).toList(),
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            onTap: () {
              Navigator.pop(context);
              // 設定画面への遷移（実装予定）
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('について'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '基本機能':
        return Icons.home;
      case 'パフォーマンス':
        return Icons.speed;
      case '検索':
        return Icons.search;
      case 'センサー':
        return Icons.sensors;
      default:
        return Icons.category;
    }
  }
  
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '会計管理アプリ',
      applicationVersion: '3.0.0',
      applicationIcon: const Icon(Icons.account_balance, size: 48),
      children: [
        const Text('スマートフォンのパフォーマンスを最大限に活用する会計管理アプリ'),
        const SizedBox(height: 16),
        const Text('主な機能:'),
        const Text('• 高速全文検索'),
        const Text('• パフォーマンス最適化'),
        const Text('• センサー機能活用'),
        const Text('• UI/UX最適化'),
      ],
    );
  }
}

/// ボトムナビゲーションバー
class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  
  static const List<BottomNavigationBarItem> items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt),
      label: '請求書',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.search),
      label: '検索',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.speed),
      label: 'パフォーマンス',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.sensors),
      label: 'センサー',
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: items,
    );
  }
}
