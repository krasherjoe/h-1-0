/// アプリ全体のバージョンと機能フラグを集中管理する設定クラス。
/// - バージョンや機能フラグは --dart-define で上書き可能。
/// - プレイストア公開やベータ配信時の切り替えを容易にする。
class AppConfig {
  /// アプリのバージョン（ビルド時に --dart-define=APP_VERSION=... で上書き可能）。
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// 機能フラグ（ビルド時に --dart-define で上書き可能）。
  static const bool enableBillingDocs = bool.fromEnvironment('ENABLE_BILLING_DOCS', defaultValue: true);
  static const bool enableSalesManagement = bool.fromEnvironment('ENABLE_SALES_MANAGEMENT', defaultValue: false);

  /// デバッグ機能フラグ（ビルド時に --dart-define=ENABLE_DEBUG_FEATURES=true で有効化）。
  static const bool enableDebugFeatures = bool.fromEnvironment('ENABLE_DEBUG_FEATURES', defaultValue: false);

  /// API エンドポイント（必要に応じて dart-define で注入）。
  static const String apiEndpoint = String.fromEnvironment('API_ENDPOINT', defaultValue: '');

  /// 機能フラグの一覧（UI で表示する用途向け）。
  static Map<String, bool> get features => {
        'enableBillingDocs': enableBillingDocs,
        'enableSalesManagement': enableSalesManagement,
        'enableDebugFeatures': enableDebugFeatures,
      };

  /// 機能キーで有効/無効を判定するヘルパー。デバッグモードでは全て true に。
  static bool isFeatureEnabled(String key) => features[key] ?? (enableDebugFeatures ? true : false);

  /// 有効なダッシュボードルート一覧（動的に増える場合はここで管理）。
  static Set<String> get enabledRoutes {
    final routes = <String>{'settings'};
    
    if (enableDebugFeatures) {
      // デバッグモード：全機能有効化
      routes.addAll({'invoice_history', 'invoice_input', 'master_hub', 'customer_master', 'product_master'});
      routes.addAll({'sales_entries', 'purchase_entries', 'inventory_list', 'sales_report'});
    } else if (enableBillingDocs) {
      routes.addAll({'invoice_history', 'invoice_input', 'master_hub', 'customer_master', 'product_master'});
    }
    
    if (enableSalesManagement || enableDebugFeatures) {
      routes.add('sales_management');
    }
    
    return routes;
  }
}