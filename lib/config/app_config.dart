/// アプリ全体のバージョンと機能フラグを集中管理する設定クラス。
/// - バージョンや機能フラグは --dart-define で上書き可能。
/// - プレイストア公開やベータ配信時の切り替えを容易にする。
class AppConfig {
  /// アプリのバージョン（ビルド時に --dart-define=APP_VERSION=... で上書き可能）。
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// 機能フラグ（ビルド時に --dart-define で上書き可能）。
  static const bool _enableDebugFeatures = bool.fromEnvironment('ENABLE_DEBUG_FEATURES', defaultValue: false);
  static const bool _enableBillingDocsFlag = bool.fromEnvironment('ENABLE_BILLING_DOCS', defaultValue: true);
  static const bool _enableSalesManagementFlag = bool.fromEnvironment('ENABLE_SALES_MANAGEMENT', defaultValue: false);
  static const bool _enablePurchaseManagementFlag = bool.fromEnvironment('ENABLE_PURCHASE_MANAGEMENT', defaultValue: false);

  /// デバッグ機能フラグ（ビルド時に --dart-define=ENABLE_DEBUG_FEATURES=true で有効化）。
  static bool get enableDebugFeatures => _enableDebugFeatures;
  static bool get enableBillingDocs => enableDebugFeatures || _enableBillingDocsFlag;
  static bool get enableSalesManagement => enableDebugFeatures || _enableSalesManagementFlag;
  static bool get enablePurchaseManagement => enableDebugFeatures || _enablePurchaseManagementFlag;

  /// API エンドポイント（必要に応じて dart-define で注入）。
  static const String apiEndpoint = String.fromEnvironment('API_ENDPOINT', defaultValue: '');

  /// 機能フラグの一覧（UI で表示する用途向け）。
  static Map<String, bool> get features => {
        'enableBillingDocs': enableBillingDocs,
        'enableSalesManagement': enableSalesManagement,
        'enablePurchaseManagement': enablePurchaseManagement,
        'enableDebugFeatures': enableDebugFeatures,
      };

  /// 機能キーで有効/無効を判定するヘルパー。デバッグモードでは全て true に。
  static bool isFeatureEnabled(String key) => features[key] ?? (enableDebugFeatures ? true : false);

  /// 有効なダッシュボードルート一覧（動的に増える場合はここで管理）。
  static Set<String> get enabledRoutes {
    final routes = <String>{'settings'};

    if (enableBillingDocs || enableDebugFeatures) {
      routes.addAll({'invoice_history', 'invoice_input', 'master_hub', 'customer_master', 'product_master'});
    }

    if (enableSalesManagement || enableDebugFeatures) {
      routes.addAll({'sales_management', 'sales_entries'});
    }

    if (enablePurchaseManagement || enableDebugFeatures) {
      routes.addAll({'purchase_entries', 'purchase_receipts'});
    }

    if (enableDebugFeatures) {
      routes.addAll({'inventory_list', 'sales_report'});
    }

    return routes;
  }
}