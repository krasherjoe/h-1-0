import 'package:flutter/material.dart';
import 'app_settings_repository.dart';

class AppThemeController {
  AppThemeController._internal();
  static final AppThemeController instance = AppThemeController._internal();

  final AppSettingsRepository _repo = AppSettingsRepository();
  final ValueNotifier<String> notifier = ValueNotifier<String>('system');

  Future<void> load() async {
    final theme = await _repo.getTheme();
    notifier.value = theme;
  }

  Future<void> setTheme(String theme) async {
    await _repo.setTheme(theme);
    notifier.value = theme;
  }
}
