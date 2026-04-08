import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/menu_catalog.dart';
import '../models/dashboard_menu_item.dart';
import '../models/invoice_list_style.dart';
import '../models/sync_preferences.dart';
import 'database_helper.dart';

class AppSettingsRepository {
  static const _kHomeMode = 'home_mode';
  static const _kDashboardStatusEnabled = 'dashboard_status_enabled';
  static const _kDashboardStatusText = 'dashboard_status_text';
  static const _kDashboardMenu = 'dashboard_menu';
  static const _kDashboardHistoryUnlocked = 'dashboard_history_unlocked';
  static const _kDashboardShowCategoryDescriptions = 'dashboard_show_category_desc';
  static const _kTheme = 'app_theme';
  static const _kSummaryTheme = 'summary_theme';
  static const _kInvoiceListStyle = 'invoice_list_style';
  static const _kForceInvoiceTaxInclusiveLabels = 'invoice_force_tax_inclusive_labels';
  static const _kShowInvoiceTaxExceptionNote = 'invoice_show_tax_exception_note';
  static const _kGmailSyncBccAddress = 'gmail_sync_bcc_address';
  static const _kGmailSyncLabelName = 'gmail_sync_label_name';
  static const _kGmailSyncLabelId = 'gmail_sync_label_id';
  static const _kGmailSyncHistoryId = 'gmail_sync_history_id';
  static const _kGmailSyncSequence = 'gmail_sync_sequence';
  static const _kGmailSyncEncodingMode = 'gmail_sync_encoding_mode';
  static const _kSyncTransportMode = 'sync_transport_mode';

  static final StreamController<String> _homeModeController = StreamController<String>.broadcast();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  SharedPreferences? _prefs;

  // Webプラットフォーム用のSharedPreferences初期化
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!;
  }

  Future<void> _ensureTable() async {
    if (kIsWeb) return; // Webでは不要
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

  Stream<String> watchHomeMode() => _homeModeController.stream;

  Future<void> setHomeMode(String mode) async {
    await _setValue(_kHomeMode, mode);
    _homeModeController.add(mode);
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

  Future<bool> getDashboardShowCategoryDescriptions() async => getBool(_kDashboardShowCategoryDescriptions, defaultValue: true);

  Future<void> setDashboardShowCategoryDescriptions(bool value) async => setBool(_kDashboardShowCategoryDescriptions, value);

  List<DashboardMenuItem> getDefaultDashboardMenu() {
    return kMenuDefinitions.map((def) => def.toMenuItem()).toList(growable: false);
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

  Future<String> getTheme() async => await getString(_kTheme) ?? 'light';
  Future<void> setTheme(String theme) async => setString(_kTheme, theme);

  Future<String> getSummaryTheme() async => await getString(_kSummaryTheme) ?? 'white';
  Future<void> setSummaryTheme(String theme) async => setString(_kSummaryTheme, theme);

  Future<InvoiceListStyle> getInvoiceListStyle() async {
    final raw = await getString(_kInvoiceListStyle);
    return InvoiceListStyleStorage.fromStorage(raw);
  }

  Future<void> setInvoiceListStyle(InvoiceListStyle style) async => setString(_kInvoiceListStyle, style.storageValue);

  Future<bool> getForceInvoiceTaxInclusiveLabels() async => getBool(_kForceInvoiceTaxInclusiveLabels, defaultValue: false);

  Future<void> setForceInvoiceTaxInclusiveLabels(bool value) async => setBool(_kForceInvoiceTaxInclusiveLabels, value);

  Future<bool> getShowInvoiceTaxExceptionNote() async => getBool(_kShowInvoiceTaxExceptionNote, defaultValue: false);

  Future<void> setShowInvoiceTaxExceptionNote(bool value) async => setBool(_kShowInvoiceTaxExceptionNote, value);

  Future<String?> getGmailSyncBccAddress() async {
    final address = await getString(_kGmailSyncBccAddress);
    if (address != null && address.isNotEmpty) return address;
    return await getString('smtp_bcc');
  }

  Future<void> setGmailSyncBccAddress(String value) async => setString(_kGmailSyncBccAddress, value);

  Future<String> getGmailSyncLabelName() async => await getString(_kGmailSyncLabelName) ?? 'SalesAssist Sync';

  Future<void> setGmailSyncLabelName(String value) async => setString(_kGmailSyncLabelName, value);

  Future<String?> getGmailSyncLabelId() async => getString(_kGmailSyncLabelId);

  Future<void> setGmailSyncLabelId(String labelId) async => setString(_kGmailSyncLabelId, labelId);

  Future<void> clearGmailSyncLabelCache() async {
    await _remove(_kGmailSyncLabelId);
  }

  Future<String?> getGmailSyncHistoryId() async => getString(_kGmailSyncHistoryId);

  Future<void> setGmailSyncHistoryId(String historyId) async => setString(_kGmailSyncHistoryId, historyId);

  Future<int> nextGmailSequence() async {
    final current = int.tryParse(await getString(_kGmailSyncSequence) ?? '0') ?? 0;
    final next = current + 1;
    await setString(_kGmailSyncSequence, next.toString());
    return next;
  }

  Future<void> resetGmailSequence([int value = 0]) async {
    await setString(_kGmailSyncSequence, value.toString());
  }

  Future<GmailEnvelopeEncoding> getGmailEnvelopeEncoding() async {
    final raw = await _getValue(_kGmailSyncEncodingMode);
    return GmailEnvelopeEncodingExt.fromStorage(raw);
  }

  Future<void> setGmailEnvelopeEncoding(GmailEnvelopeEncoding mode) async {
    await _setValue(_kGmailSyncEncodingMode, mode.storageValue);
  }

  Future<SyncTransportMode> getSyncTransportMode() async {
    final raw = await _getValue(_kSyncTransportMode);
    return SyncTransportModeExt.fromStorage(raw);
  }

  Future<void> setSyncTransportMode(SyncTransportMode mode) async {
    await _setValue(_kSyncTransportMode, mode.storageValue);
  }

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
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.remove(key);
      return;
    }
    final db = await _dbHelper.database;
    try {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  Future<String?> _getValue(String key) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    }
    await _ensureTable();
    final db = await _dbHelper.database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (res.isEmpty) return null;
    return res.first['value'] as String?;
  }

  Future<void> _setValue(String key, String value) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
      return;
    }
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
