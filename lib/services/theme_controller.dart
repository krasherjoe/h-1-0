import 'package:flutter/material.dart';
import 'app_settings_repository.dart';

class AppThemeController {
  AppThemeController._internal();
  static final AppThemeController instance = AppThemeController._internal();

  final AppSettingsRepository _repo = AppSettingsRepository();
  final ValueNotifier<ThemeMode> notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<void> load() async {
    final theme = await _repo.getTheme();
    notifier.value = _toMode(theme);
  }

  Future<void> setTheme(String theme) async {
    await _repo.setTheme(theme);
    notifier.value = _toMode(theme);
  }

  ThemeMode _toMode(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
