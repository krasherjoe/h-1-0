/// アプリ全体のバージョンと機能フラグを集中管理する設定クラス。
/// - バージョンや機能フラグは --dart-define で上書き可能。
/// - プレイストア公開やベータ配信時の切り替えを容易にする。
class AppConfig {
  /// アプリのバージョン（ビルド時に --dart-define=APP_VERSION=... で上書き可能）。
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// 機能フラグ（ビルド時に --dart-define で上書き可能）。
  static const bool enableBillingDocs = bool.fromEnvironment('ENABLE_BILLING_DOCS', defaultValue: true);
  static const bool enableSalesManagement = bool.fromEnvironment('ENABLE_SALES_MANAGEMENT', defaultValue: false);

  /// APIエンドポイント（必要に応じて dart-define で注入）。
  static const String apiEndpoint = String.fromEnvironment('API_ENDPOINT', defaultValue: '');

  /// 機能フラグの一覧（UIなどで表示する用途向け）。
  static Map<String, bool> get features => {
        'enableBillingDocs': enableBillingDocs,
        'enableSalesManagement': enableSalesManagement,
      };

  /// 機能キーで有効/無効を判定するヘルパー。
  static bool isFeatureEnabled(String key) => features[key] ?? false;

  /// 有効なダッシュボードルート一覧（動的に増える場合はここで管理）。
  static Set<String> get enabledRoutes {
    final routes = <String>{'settings'};
    if (enableBillingDocs) {
      routes.addAll({'invoice_history', 'invoice_input', 'master_hub', 'customer_master', 'product_master'});
    }
    if (enableSalesManagement) {
      routes.add('sales_management');
    }
    return routes;
  }
}
