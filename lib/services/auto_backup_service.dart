import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'drive_backup_service.dart';

class AutoBackupService {
  static const String _keyLastBackup = 'last_backup_time';
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyFirstLaunchChecked = 'first_launch_restore_checked';
  static const Duration _backupInterval = Duration(hours: 24);

  /// 自動バックアップが有効かチェック
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoBackupEnabled) ?? false;
  }

  /// 起動時チェック：24時間経過していればバックアップ実行
  static Future<void> checkAndBackupOnStartup() async {
    try {
      final enabled = await isAutoBackupEnabled();
      if (!enabled) return;

      final prefs = await SharedPreferences.getInstance();
      final lastBackupStr = prefs.getString(_keyLastBackup);

      if (lastBackupStr == null) {
        // 初回バックアップ
        await _performBackup();
        return;
      }

      final lastBackup = DateTime.parse(lastBackupStr);
      final now = DateTime.now();
      final elapsed = now.difference(lastBackup);

      if (elapsed >= _backupInterval) {
        await _performBackup();
      }
    } catch (e) {
      // エラーは無視（起動を妨げない）
      debugPrint('Auto backup failed: $e');
    }
  }

  static Future<void> _performBackup() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final dbPath = db.path;
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Database file not found');
    }

    // ローカルバックアップを実行
    final localBackupService = LocalBackupService();
    await localBackupService.createAutoBackup(dbPath);

    // Google Drive バックアップも実行
    final driveService = DriveBackupService();
    await driveService.uploadDatabaseSnapshot(
      dbFile,
      description: 'Auto backup - ${DateTime.now().toIso8601String()}',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackup, DateTime.now().toIso8601String());
  }

  /// 初回起動時のリストアチェック：DBが空でバックアップが存在する場合に提案
  static Future<bool> shouldOfferRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checked = prefs.getBool(_keyFirstLaunchChecked) ?? false;

      if (checked) {
        return false; // 既にチェック済み
      }

      // DBが新規（または小さい）かチェック
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return false; // DBファイルがない（初期化前）
      }

      final dbSize = await dbFile.length();
      final isEmpty = dbSize < 50000; // 50KB未満なら新規とみなす

      if (!isEmpty) {
        // DBにデータがある場合はチェック完了とマーク
        await prefs.setBool(_keyFirstLaunchChecked, true);
        return false;
      }

      // Google Driveにバックアップが存在するかチェック
      final driveService = DriveBackupService();
      final backups = await driveService.listBackupFiles();
      final hasBackup = backups.any((f) => f.name?.endsWith('.db') ?? false);

      // チェック完了をマーク
      await prefs.setBool(_keyFirstLaunchChecked, true);

      return hasBackup;
    } catch (e) {
      debugPrint('Restore check failed: $e');
      return false;
    }
  }

  /// リストアチェック完了フラグをリセット（テスト用）
  static Future<void> resetFirstLaunchCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFirstLaunchChecked);
  }
}
