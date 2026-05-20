import 'package:flutter/material.dart';
import 'app_settings_repository.dart';

class AppThemeController {
  AppThemeController._internal();
  static final AppThemeController instance = AppThemeController._internal();

  final AppSettingsRepository _repo = AppSettingsRepository();
  final ValueNotifier<String> notifier = ValueNotifier<String>('system');

  /// カスタムテーマ用の色マップ。テーマが 'custom' のときに使用される。
  /// キー: 'primary', 'onPrimary', 'secondary', 'surface', 'onSurface', 'error', 'scaffoldBg'
  final ValueNotifier<Map<String, int>> customColorsNotifier =
      ValueNotifier<Map<String, int>>(<String, int>{});

  /// デフォルトのカスタムカラー（ライトテーマ準拠）
  static Map<String, int> defaultCustomColors() => <String, int>{
        'primary': 0xFF303F9F, // indigo.shade700
        'onPrimary': 0xFFFFFFFF,
        'secondary': 0xFFFF7043, // deepOrange.shade400
        'surface': 0xFFF5F5F5,
        'onSurface': 0xFF263238, // blueGrey.shade900
        'error': 0xFFB00020,
        'scaffoldBg': 0xFFF5F5F5,
      };

  Future<void> load() async {
    final theme = await _repo.getTheme();
    notifier.value = theme;
    final colors = await _repo.getCustomThemeColors();
    customColorsNotifier.value =
        colors.isEmpty ? defaultCustomColors() : colors;
  }

  Future<void> setTheme(String theme) async {
    await _repo.setTheme(theme);
    notifier.value = theme;
  }

  Future<void> setCustomColors(Map<String, int> colors) async {
    await _repo.setCustomThemeColors(colors);
    customColorsNotifier.value = Map<String, int>.from(colors);
  }
}
