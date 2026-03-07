import '../constants/menu_catalog.dart';

/// アプリ全体のバージョンと機能フラグを集中管理する設定クラス。
/// - バージョンや機能フラグは --dart-define で上書き可能。
/// - プレイストア公開やベータ配信時の切り替えを容易にする。
class AppConfig {
  /// アプリのバージョン（ビルド時に --dart-define=APP_VERSION=... で上書き可能）。
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// 機能フラグ（ビルド時に --dart-define で上書き可能）。
  static const bool _enableDebugFeatures = bool.fromEnvironment('ENABLE_DEBUG_FEATURES', defaultValue: false);
  static const bool _enableMasterModuleFlag = bool.fromEnvironment('ENABLE_MASTER_MODULE', defaultValue: true);
  static const bool _enableSalesModuleFlag = bool.fromEnvironment('ENABLE_SALES_MODULE', defaultValue: true);
  static const bool _enablePurchaseModuleFlag = bool.fromEnvironment('ENABLE_PURCHASE_MODULE', defaultValue: false);
  static const bool _enableInventoryModuleFlag = bool.fromEnvironment('ENABLE_INVENTORY_MODULE', defaultValue: false);
  static const bool _enableAnalyticsModuleFlag = bool.fromEnvironment('ENABLE_ANALYTICS_MODULE', defaultValue: false);
  static const bool _enableSystemModuleFlag = bool.fromEnvironment('ENABLE_SYSTEM_MODULE', defaultValue: true);

  /// デバッグ機能フラグ（ビルド時に --dart-define=ENABLE_DEBUG_FEATURES=true で有効化）。
  static bool get enableDebugFeatures => _enableDebugFeatures;
  static bool get enableMasterModule => enableDebugFeatures || _enableMasterModuleFlag;
  static bool get enableSalesModule => enableDebugFeatures || _enableSalesModuleFlag;
  static bool get enablePurchaseModule => enableDebugFeatures || _enablePurchaseModuleFlag;
  static bool get enableInventoryModule => enableDebugFeatures || _enableInventoryModuleFlag;
  static bool get enableAnalyticsModule => enableDebugFeatures || _enableAnalyticsModuleFlag;
  static bool get enableSystemModule => enableDebugFeatures || _enableSystemModuleFlag;

  /// API エンドポイント（必要に応じて dart-define で注入）。
  static const String apiEndpoint = String.fromEnvironment('API_ENDPOINT', defaultValue: '');

  /// 機能フラグの一覧（UI で表示する用途向け）。
  static Map<String, bool> get features => {
        'enableMasterModule': enableMasterModule,
        'enableSalesModule': enableSalesModule,
        'enablePurchaseModule': enablePurchaseModule,
        'enableInventoryModule': enableInventoryModule,
        'enableAnalyticsModule': enableAnalyticsModule,
        'enableSystemModule': enableSystemModule,
        'enableDebugFeatures': enableDebugFeatures,
      };

  /// 機能キーで有効/無効を判定するヘルパー。デバッグモードでは全て true に。
  static bool isFeatureEnabled(String key) => features[key] ?? (enableDebugFeatures ? true : false);

  /// 有効なダッシュボードルート一覧（動的に増える場合はここで管理）。
  static Set<String> get enabledRoutes {
    final routes = <String>{'settings'};
    final categoryEnabled = <String, bool>{
      '01. マスタ管理': enableMasterModule,
      '02. 販売管理': enableSalesModule,
      '03. 仕入管理': enablePurchaseModule,
      '04. 在庫管理': enableInventoryModule,
      '05. 集計分析': enableAnalyticsModule,
      '06. システム設定': enableSystemModule,
    };

    for (final def in kMenuDefinitions) {
      final allowed = enableDebugFeatures || (categoryEnabled[def.category] ?? false);
      if (allowed) {
        routes.add(def.route);
      }
    }

    return routes;
  }
}