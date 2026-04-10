import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 外部ストレージアクセス権限管理サービス
///
/// Android 13+ では Storage Access Framework を使用し、
/// 古いバージョンでは legacy storage permission を使用します。
class StoragePermissionService {
  static const String _storagePath = '/storage/emulated/0/販売アシスト 1 号';

  /// 権限ステータス確認
  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      // Android 13+ (API 33+) では MANAGE_EXTERNAL_STORAGE を要求
      if (sdkVersion >= 33) {
        final status = await Permission.manageExternalStorage.status;
        debugPrint('Manage External Storage 権限：$status');
        return status.isGranted;
      }

      // Android 10-12 (API 29-32) では READ/WRITE_STORAGE を要求
      if (sdkVersion >= 29) {
        final readStatus = await Permission.storage.status;
        debugPrint('Storage 権限（読み取り）：$readStatus');
        return readStatus.isGranted;
      }

      // Android 9 以下でも storage permission を確認
      final legacyStatus = await Permission.storage.status;
      debugPrint('Legacy Storage 権限：$legacyStatus');
      return legacyStatus.isGranted;
    }

    // iOS/他のプラットフォームでは常に許可（内部ストレージを使用）
    return true;
  }

  /// 権限リクエスト
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    try {
      if (sdkVersion >= 33) {
        // Android 13+ - MANAGE_EXTERNAL_STORAGE
        debugPrint('Android 13+ 用の権限をリクエスト中...');

        // まず試みる
        final status = await Permission.manageExternalStorage.request();
        debugPrint('Manage External Storage リクエスト結果：$status');

        if (status.isGranted) {
          return true;
        }

        // 拒否された場合、設定画面へ誘導
        debugPrint('権限が拒否されました。設定画面を開きます...');
        await openAppSettings();
        return false;
      } else {
        // Android 10-12 - READ/WRITE_STORAGE
        debugPrint('Android 10-12 用の権限をリクエスト中...');
        final status = await Permission.storage.request();
        debugPrint('Storage リクエスト結果：$status');
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('権限リクエストエラー：$e');
      // エラー時はフォールバックとして true を返す（内部ストレージを使用）
      return true;
    }
  }

  /// バックアップディレクトリ作成（権限確保後）
  Future<String> ensureBackupDirectory() async {
    final hasPermission = await checkPermission();

    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('ストレージ権限が拒否されました。バックアップ機能を使用できません。');
      }
    }

    // ディレクトリ作成
    final dir = Directory(_storagePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return _storagePath;
  }

  /// バックアップディレクトリ存在確認と自動作成
  Future<bool> ensureDirectoryExists() async {
    try {
      final dir = Directory(_storagePath);
      if (!await dir.exists()) {
        // 権限がない場合はエラーをスローせず false を返す
        await ensureBackupDirectory();
      }
      return true;
    } catch (e) {
      debugPrint('ディレクトリ作成エラー：$e');
      return false;
    }
  }
}
