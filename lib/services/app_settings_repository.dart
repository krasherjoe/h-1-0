import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class AppSettingsRepository {
  static const _kHomeMode = 'home_mode'; // 'invoice_history' or 'dashboard'
  static const _kDashboardStatusEnabled = 'dashboard_status_enabled';
  static const _kDashboardStatusText = 'dashboard_status_text';
  static const _kDashboardMenu = 'dashboard_menu';
  static const _kDashboardHistoryUnlocked = 'dashboard_history_unlocked';
  static const _kTheme = 'app_theme'; // light / dark / system
  static const _kSummaryTheme = 'summary_theme'; // 'white' or 'blue'

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
    if (v == null) return true; // デフォルト表示ON
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

  Future<List<DashboardMenuItem>> getDashboardMenu() async {
    final raw = await _getValue(_kDashboardMenu);
    if (raw == null || raw.isEmpty) {
      return [DashboardMenuItem(id: 'a2', title: '伝票一覧', route: 'invoice_history', iconName: 'list_alt')];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => DashboardMenuItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [DashboardMenuItem(id: 'a2', title: '伝票一覧', route: 'invoice_history', iconName: 'list_alt')];
  }

  Future<void> setDashboardMenu(List<DashboardMenuItem> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _setValue(_kDashboardMenu, raw);
  }

  Future<bool> getDashboardHistoryUnlocked() async => getBool(_kDashboardHistoryUnlocked, defaultValue: false);
  Future<void> setDashboardHistoryUnlocked(bool unlocked) async => setBool(_kDashboardHistoryUnlocked, unlocked);

  Future<String> getTheme() async => await getString(_kTheme) ?? 'system';
  Future<void> setTheme(String theme) async => setString(_kTheme, theme);

  Future<String> getSummaryTheme() async => await getString(_kSummaryTheme) ?? 'white';
  Future<void> setSummaryTheme(String theme) async => setString(_kSummaryTheme, theme);

  // Generic helpers
  Future<String?> getString(String key) async => _getValue(key);
  Future<void> setString(String key, String value) async => _setValue(key, value);

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await _getValue(key);
    if (v == null) return defaultValue;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setBool(String key, bool value) async => _setValue(key, value ? '1' : '0');

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
}

class DashboardMenuItem {
  final String id;
  final String title;
  final String route;
  final String? iconName; // Material icon name
  final String? customIconPath; // optional local file path

  DashboardMenuItem({required this.id, required this.title, required this.route, this.iconName, this.customIconPath});

  DashboardMenuItem copyWith({String? id, String? title, String? route, String? iconName, String? customIconPath}) {
    return DashboardMenuItem(
      id: id ?? this.id,
      title: title ?? this.title,
      route: route ?? this.route,
      iconName: iconName ?? this.iconName,
      customIconPath: customIconPath ?? this.customIconPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'route': route,
        'iconName': iconName,
        'customIconPath': customIconPath,
      };

  factory DashboardMenuItem.fromJson(Map<String, dynamic> json) {
    return DashboardMenuItem(
      id: json['id'] as String,
      title: json['title'] as String,
      route: json['route'] as String,
      iconName: json['iconName'] as String?,
      customIconPath: json['customIconPath'] as String?,
    );
  }
}
