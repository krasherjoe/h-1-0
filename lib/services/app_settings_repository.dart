import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class AppSettingsRepository {
  static const _kHomeMode = 'home_mode';
  static const _kDashboardStatusEnabled = 'dashboard_status_enabled';
  static const _kDashboardStatusText = 'dashboard_status_text';
  static const _kDashboardMenu = 'dashboard_menu';
  static const _kDashboardHistoryUnlocked = 'dashboard_history_unlocked';
  static const _kTheme = 'app_theme';
  static const _kSummaryTheme = 'summary_theme';

  static const List<DashboardMenuItem> _defaultDashboardMenu = [
    DashboardMenuItem(id: 'a1', title: '伝票入力', route: 'invoice_input', iconName: 'edit_note'),
    DashboardMenuItem(id: 'a2', title: '伝票一覧', route: 'invoice_history', iconName: 'list_alt'),
    DashboardMenuItem(id: 'c1', title: '顧客マスター', route: 'customer_master', iconName: 'customer'),
    DashboardMenuItem(id: 'p1', title: '商品マスター', route: 'product_master', iconName: 'product'),
    DashboardMenuItem(id: 'm1', title: 'マスター管理', route: 'master_hub', iconName: 'master'),
    DashboardMenuItem(id: 'r1', title: '売上・資金管理レポート', route: 'sales_report', iconName: 'analytics'),
    DashboardMenuItem(id: 's1', title: '設定', route: 'settings', iconName: 'settings'),
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> _ensureTable() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<String> getHomeMode() async {
    final v = await _getValue(_kHomeMode);
    return v ?? 'invoice_history';
  }

  Future<void> setHomeMode(String mode) async {
    await _setValue(_kHomeMode, mode);
  }

  Future<bool> getDashboardStatusEnabled() async {
    final v = await _getValue(_kDashboardStatusEnabled);
    if (v == null) return true;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setDashboardStatusEnabled(bool enabled) async {
    await _setValue(_kDashboardStatusEnabled, enabled ? '1' : '0');
  }

  Future<String> getDashboardStatusText() async {
    return await _getValue(_kDashboardStatusText) ?? '工事中';
  }

  Future<void> setDashboardStatusText(String text) async {
    await _setValue(_kDashboardStatusText, text);
  }

  List<DashboardMenuItem> getDefaultDashboardMenu() {
    return _defaultDashboardMenu.map((item) => item.copyWith()).toList(growable: false);
  }

  Future<List<DashboardMenuItem>> getDashboardMenu() async {
    final defaults = getDefaultDashboardMenu();
    final raw = await _getValue(_kDashboardMenu);
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final stored = decoded.map((e) => DashboardMenuItem.fromJson(e as Map<String, dynamic>)).toList();
        return _mergeMenu(defaults, stored);
      }
    } catch (_) {}
    return defaults;
  }

  Future<void> setDashboardMenu(List<DashboardMenuItem> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _setValue(_kDashboardMenu, raw);
  }

  Future<void> resetDashboardMenu() async {
    await _remove(_kDashboardMenu);
  }

  Future<bool> getDashboardHistoryUnlocked() async => getBool(_kDashboardHistoryUnlocked, defaultValue: false);
  Future<void> setDashboardHistoryUnlocked(bool unlocked) async => setBool(_kDashboardHistoryUnlocked, unlocked);

  Future<String> getTheme() async => await getString(_kTheme) ?? 'system';
  Future<void> setTheme(String theme) async => setString(_kTheme, theme);

  Future<String> getSummaryTheme() async => await getString(_kSummaryTheme) ?? 'white';
  Future<void> setSummaryTheme(String theme) async => setString(_kSummaryTheme, theme);

  Future<String?> getString(String key) async => _getValue(key);
  Future<void> setString(String key, String value) async => _setValue(key, value);

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await _getValue(key);
    if (v == null) return defaultValue;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setBool(String key, bool value) async => _setValue(key, value ? '1' : '0');

  /// DEBUG スイッチ - デバッグ機能のオン/オフ
  /// true の場合：ダッシュボードで全機能一覧を表示（メニュー制限を解除）
  /// デフォルトは false。DEBUG モードにするには設定から有効化する。
  Future<bool> getEnableDebugFeatures() async {
    final raw = await _getValue('debug_keyboard_mapping');
    // データが存在しない場合はデフォルト false
    if (raw == null) return false;
    // '1' または 'true' の場合は有効
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  Future<void> setEnableDebugFeatures(bool? enabled) async {
    if (enabled == null) {
      await _remove('debug_keyboard_mapping');
      return;
    }
    await _setValue('debug_keyboard_mapping', enabled ? '1' : '0');
  }

  /// DEBUG キーマップをリストとして取得・設定
  Future<List<String>> getDebugKeyboardMapping() async {
    final raw = await _getValue('debug_keyboard_mapping');
    if (raw == null) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      // リスト型で全て String の場合のみ返却
      if (decoded is List && decoded.every((e) => e is String)) {
        return decoded.map<String>((e) => e as String).toList();
      }
    } catch (_) {}
    return const <String>[];
  }

  Future<void> setDebugKeyboardMapping(List<String> mapping) async {
    final raw = jsonEncode(mapping);
    await _setValue('debug_keyboard_mapping', raw);
  }

  /// ヘルパー: 存在しないキーを削除する
  Future<void> _remove(String key) async {
    final db = await _dbHelper.database;
    try {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  Future<String?> _getValue(String key) async {
    await _ensureTable();
    final db = await _dbHelper.database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (res.isEmpty) return null;
    return res.first['value'] as String?;
  }

  Future<void> _setValue(String key, String value) async {
    await _ensureTable();
    final db = await _dbHelper.database;
    await db.insert('app_settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  List<DashboardMenuItem> _mergeMenu(List<DashboardMenuItem> defaults, List<DashboardMenuItem>? stored) {
    if (stored == null || stored.isEmpty) {
      return defaults;
    }
    final defaultMap = {for (final item in defaults) item.id: item};
    final seen = <String>{};
    final merged = <DashboardMenuItem>[];

    for (final item in stored) {
      final defaultItem = defaultMap[item.id];
      if (defaultItem != null) {
        merged.add(defaultItem.copyWith(
          enabled: item.enabled,
          iconName: item.iconName ?? defaultItem.iconName,
          customIconPath: item.customIconPath ?? defaultItem.customIconPath,
        ));
        seen.add(item.id);
      } else {
        merged.add(item);
        seen.add(item.id);
      }
    }

    for (final item in defaults) {
      if (!seen.contains(item.id)) {
        merged.add(item);
      }
    }

    return merged;
  }
}

class DashboardMenuItem {
  final String id;
  final String title;
  final String route;
  final bool enabled; // 有効/無効フラグ (デフォルト true)
  final String? iconName; // Material icon name
  final String? customIconPath; // optional local file path

  const DashboardMenuItem({required this.id, required this.title, required this.route, this.enabled = true, this.iconName, this.customIconPath});

  DashboardMenuItem copyWith({String? id, String? title, String? route, bool? enabled, String? iconName, String? customIconPath}) {
    return DashboardMenuItem(
      id: id ?? this.id,
      title: title ?? this.title,
      route: route ?? this.route,
      enabled: enabled ?? this.enabled,
      iconName: iconName ?? this.iconName,
      customIconPath: customIconPath ?? this.customIconPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'route': route,
        'enabled': enabled,
        'iconName': iconName,
        'customIconPath': customIconPath,
      };

  factory DashboardMenuItem.fromJson(Map<String, dynamic> json) {
    return DashboardMenuItem(
      id: json['id'] as String,
      title: json['title'] as String,
      route: json['route'] as String,
      enabled: (json['enabled'] as bool?) ?? true, // デフォルト true で互換性確保
      iconName: json['iconName'] as String?,
      customIconPath: json['customIconPath'] as String?,
    );
  }
}