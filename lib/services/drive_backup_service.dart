import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import 'google_api_service_base.dart';
import 'mothership_client.dart';

/// Google Drive 上にノード別バックアップフォルダを作成し、
/// SQLite やログファイルをアップロードするサービス。
class DriveBackupService extends GoogleApiServiceBase {
  DriveBackupService({MothershipClient? nodeIdProvider})
    : _nodeIdProvider = nodeIdProvider ?? MothershipClient();

  static const String _rootFolderName = 'SalesAssist Backups';

  final MothershipClient _nodeIdProvider;

  Future<void> uploadDatabaseSnapshot(
    File databaseFile, {
    String? description,
  }) async {
    if (!await databaseFile.exists()) {
      throw ArgumentError('Database file not found: ${databaseFile.path}');
    }
    await _uploadFile(
      databaseFile,
      description: description ?? 'SQLite backup',
    );
  }

  Future<void> uploadErrorReport(File logFile, {String? description}) async {
    if (!await logFile.exists()) {
      throw ArgumentError('Log file not found: ${logFile.path}');
    }
    await _uploadFile(logFile, description: description ?? 'Error report');
  }

  Future<void> _uploadFile(File file, {required String description}) async {
    final startTime = DateTime.now();
    final fileSize = await file.length();
    final fileName = file.path.split('/').last;

    try {
      await withClient((client) async {
        final api = drive.DriveApi(client);
        final folderId = await _ensureNodeFolder(api);
        final uploadFileName = _buildFileName(file);
        final driveFile = drive.File()
          ..name = uploadFileName
          ..description = description
          ..parents = [folderId];
        final media = drive.Media(file.openRead(), fileSize);
        await api.files.create(driveFile, uploadMedia: media);
      });

      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;
      final speedMbps = (fileSize / (1024 * 1024)) / durationSeconds;

      debugPrint(
        '[DriveBackup] ✅ アップロード完了\n'
        '  ファイル：$fileName\n'
        '  サイズ：${_formatBytes(fileSize)}\n'
        '  所要時間：${durationSeconds.toStringAsFixed(2)}秒\n'
        '  速度：${speedMbps.toStringAsFixed(2)} MB/s',
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '[DriveBackup] ❌ アップロード失敗\n'
        '  ファイル：$fileName\n'
        '  サイズ：${_formatBytes(fileSize)}\n'
        '  経過時間：${duration.inSeconds}秒\n'
        '  エラー：$e',
      );
      rethrow;
    }
  }

  /// バイト数を人間が読みやすい形式にフォーマット
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<String> _ensureNodeFolder(drive.DriveApi api) async {
    final rootId = await _ensureFolder(api, name: _rootFolderName);
    final nodeId = await _nodeIdProvider.ensureClientId();
    return _ensureFolder(api, name: nodeId, parentId: rootId);
  }

  Future<String> _ensureFolder(
    drive.DriveApi api, {
    required String name,
    String? parentId,
  }) async {
    final qBuffer = StringBuffer(
      "mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed = false",
    );
    if (parentId != null) {
      qBuffer.write(" and '$parentId' in parents");
    }
    final existing = await api.files.list(
      q: qBuffer.toString(),
      spaces: 'drive',
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    final found = existing.files?.firstWhere(
      (f) => f.id != null,
      orElse: () => drive.File(),
    );
    if (found != null && found.id != null) {
      return found.id!;
    }
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parentId != null) {
      folder.parents = [parentId];
    }
    final created = await api.files.create(folder);
    if (created.id == null) {
      throw StateError('Failed to create folder "$name"');
    }
    return created.id!;
  }

  String _buildFileName(File file) {
    final base = p.basename(file.path);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final ext = p.extension(base);
    final nameWithoutExt = base.replaceAll(ext, '');
    return '${nameWithoutExt}_$timestamp$ext';
  }

  /// Google Drive から最新のバックアップファイル一覧を取得
  Future<List<drive.File>> listBackupFiles() async {
    try {
      return await withClient((client) async {
        final api = drive.DriveApi(client);
        debugPrint('[DriveBackup] ノードフォルダを確認中...');
        final folderId = await _ensureNodeFolder(api);
        debugPrint('[DriveBackup] フォルダ ID: $folderId');

        debugPrint('[DriveBackup] バックアップファイルを検索中...');
        final response = await api.files.list(
          q: "'$folderId' in parents and trashed = false and mimeType != 'application/vnd.google-apps.folder'",
          spaces: 'drive',
          orderBy: 'modifiedTime desc',
          $fields: 'files(id,name,modifiedTime,size,description)',
          pageSize: 50,
        );

        final files = response.files ?? [];
        debugPrint('[DriveBackup] バックアップファイル数：${files.length}');
        for (final file in files) {
          debugPrint('[DriveBackup] - ${file.name} (${file.size} bytes)');
        }

        return files;
      });
    } catch (e, st) {
      debugPrint('[DriveBackup] ❌ バックアップファイル一覧取得エラー：$e');
      debugPrint('[DriveBackup] スタックトレース：$st');
      rethrow;
    }
  }

  /// 指定されたファイル ID のバックアップを取得してローカルに保存
  Future<File> downloadBackup(String fileId, String localPath) async {
    return withClient((client) async {
      final api = drive.DriveApi(client);

      final media =
          await api.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final localFile = File(localPath);
      final sink = localFile.openWrite();

      await for (final chunk in media.stream) {
        sink.add(chunk);
      }

      await sink.close();
      return localFile;
    });
  }

  /// 最新のバックアップをダウンロードして DB を復元
  Future<bool> restoreLatestBackup(String targetDbPath) async {
    try {
      debugPrint('[DriveBackup] 復元開始：$targetDbPath');
      final backups = await listBackupFiles();
      debugPrint('[DriveBackup] バックアップファイル数：${backups.length}');

      if (backups.isEmpty) {
        debugPrint('[DriveBackup] バックアップが見つかりません');
        return false;
      }

      // 最新の DB ファイルを探す（.db 拡張子）
      final dbBackup = backups.firstWhere(
        (f) => f.name?.endsWith('.db') ?? false,
        orElse: () => drive.File(),
      );

      if (dbBackup.id == null) {
        debugPrint('[DriveBackup] DB ファイルが見つかりません');
        return false;
      }

      debugPrint(
        '[DriveBackup] DB バックアップを選択：${dbBackup.name} (ID: ${dbBackup.id})',
      );

      // 一時ファイルにダウンロード
      final tempPath = '$targetDbPath.tmp';
      debugPrint('[DriveBackup] ダウンロード中：$tempPath');
      await downloadBackup(dbBackup.id!, tempPath);
      debugPrint('[DriveBackup] ダウンロード完了');

      // ダウンロードしたファイルの検証
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        throw Exception('ダウンロードしたファイルが見つかりません');
      }

      final fileSize = await tempFile.length();
      debugPrint('[DriveBackup] ダウンロードファイルサイズ：$fileSize bytes');

      if (fileSize < 10000) {
        // 10KB 未満は破損ファイルの可能性
        debugPrint('[DriveBackup] ⚠️ ファイルサイズが小さい（破損の可能性）: $fileSize bytes');
      }

      // 既存 DB をバックアップ
      final targetFile = File(targetDbPath);
      if (await targetFile.exists()) {
        debugPrint('[DriveBackup] 既存 DB をバックアップ：$targetDbPath.old');
        await targetFile.rename('$targetDbPath.old');
      }

      // 復元
      debugPrint('[DriveBackup] DB を復元中...');
      await File(tempPath).rename(targetDbPath);
      debugPrint('[DriveBackup] DB 復元完了');

      // 古いバックアップを削除
      final oldBackup = File('$targetDbPath.old');
      if (await oldBackup.exists()) {
        debugPrint('[DriveBackup] 古いバックアップを削除');
        await oldBackup.delete();
      }

      return true;
    } catch (e, st) {
      debugPrint('[DriveBackup] ❌ 復元エラー：$e');
      debugPrint('[DriveBackup] スタックトレース：$st');
      // エラー時は元に戻す
      final oldBackup = File('$targetDbPath.old');
      if (await oldBackup.exists()) {
        debugPrint('[DriveBackup] 既存 DB を復元');
        await oldBackup.rename(targetDbPath);
      }
      rethrow;
    }
  }
}
