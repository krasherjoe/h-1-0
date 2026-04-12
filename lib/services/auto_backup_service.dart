import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'drive_backup_service.dart';
import 'backup_progress_notifier.dart';

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

    // バックアップ（ローカル・Google Drive）をバックグラウンド実行
    // 起動時の待機時間を完全に排除
    _performBackupInBackground(dbPath, dbFile);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackup, DateTime.now().toIso8601String());
  }

  /// ローカル・Google Drive バックアップをバックグラウンド実行
  /// 起動時の待機時間を排除するため、非同期で実行し await しない
  static void _performBackupInBackground(String dbPath, File dbFile) {
    final notifier = BackupProgressNotifier();

    Future.microtask(() async {
      try {
        notifier.startBackup();

        // ローカルバックアップを実行
        final localBackupService = LocalBackupService();
        notifier.updateLocalBackupProgress('ローカルバックアップを実行中...');
        await localBackupService.createAutoBackup(dbPath);
        debugPrint('[AutoBackup] ローカルバックアップ完了（バックグラウンド）');

        // Google Drive バックアップも実行
        final driveService = DriveBackupService();
        notifier.updateDriveBackupProgress('Google Drive にアップロード中...');
        await driveService.uploadDatabaseSnapshot(
          dbFile,
          description: 'Auto backup - ${DateTime.now().toIso8601String()}',
        );
        debugPrint('[AutoBackup] Google Drive バックアップ完了（バックグラウンド）');

        notifier.completeBackup();
      } catch (e) {
        // エラーは無視（ユーザーに通知しない、起動を妨げない）
        debugPrint('[AutoBackup] バックアップ失敗（バックグラウンド）: $e');
        notifier.failBackup(e.toString());
      }
    });
  }

  /// 初回起動時のリストアチェック：DBが空でバックアップが存在する場合に提案
  static Future<bool> shouldOfferRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checked = prefs.getBool(_keyFirstLaunchChecked) ?? false;

      debugPrint('[Restore Check] チェック済みフラグ: $checked');

      if (checked) {
        debugPrint('[Restore Check] 既にチェック済みのため、スキップ');
        return false; // 既にチェック済み
      }

      // DBが新規（または小さい）かチェック
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;
      final dbFile = File(dbPath);

      debugPrint('[Restore Check] DB パス: $dbPath');

      if (!await dbFile.exists()) {
        debugPrint('[Restore Check] DB ファイルが存在しません');
        return false; // DBファイルがない（初期化前）
      }

      final dbSize = await dbFile.length();
      final isEmpty = dbSize < 50000; // 50KB未満なら新規とみなす

      debugPrint('[Restore Check] DB サイズ: $dbSize bytes, 新規: $isEmpty');

      if (!isEmpty) {
        // DBにデータがある場合はチェック完了とマーク
        debugPrint('[Restore Check] DB にデータがあるため、復元不要');
        await prefs.setBool(_keyFirstLaunchChecked, true);
        return false;
      }

      // Google Driveにバックアップが存在するかチェック
      debugPrint('[Restore Check] Google Drive のバックアップを検索中...');
      final driveService = DriveBackupService();
      final backups = await driveService.listBackupFiles();

      debugPrint('[Restore Check] バックアップファイル数: ${backups.length}');
      for (final backup in backups) {
        debugPrint('[Restore Check] - ${backup.name} (ID: ${backup.id})');
      }

      final hasBackup = backups.any((f) => f.name?.endsWith('.db') ?? false);
      debugPrint('[Restore Check] DB バックアップ存在: $hasBackup');

      // チェック完了をマーク
      await prefs.setBool(_keyFirstLaunchChecked, true);

      return hasBackup;
    } catch (e, st) {
      debugPrint('[Restore Check] エラー: $e');
      debugPrint('[Restore Check] スタックトレース: $st');
      return false;
    }
  }

  /// リストアチェック完了フラグをリセット（テスト用）
  static Future<void> resetFirstLaunchCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFirstLaunchChecked);
  }
}
