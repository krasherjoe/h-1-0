import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Google Drive 連携によるクラウドバックアップサービス
///
/// 機能：
/// - SQLite データベースの自動バックアップ
/// - バックアップファイルのリストア
/// - バックアップ履歴の管理
class CloudBackupService {
  static const _databaseName = 'gemi_invoice.db';
  static const _backupFolderName = 'GemiInvoiceBackups';

  // Google Drive API スコープ
  static final List<String> _scopes = [drive.DriveApi.driveFileScope];

  // Firebase project ID（google-services.json から取得）
  static const _projectId = 'hanai-app-bbedf';
  static const _storageBucket = 'hanai-app-bbedf.firebasestorage.app';

  final http.Client _client;
  drive.DriveApi? _driveApi;
  Database? _database;

  CloudBackupService(this._client);

  /// データベース設定
  void setDatabase(Database db) {
    _database = db;
  }

  /// Google Drive API の初期化（OAuth 認証）
  ///
  /// [authRepository] - 認証リポジトリ（OAuth トークン取得用）
  Future<void> authenticate({AuthRepository? authRepository}) async {
    if (_driveApi != null) return; // 既に認証済

    final credentials = await _getCredentials(authRepository: authRepository);
    _driveApi = drive.DriveApi(credentials);
  }

  /// OAuth クレデンシャルの取得
  Future<BaseAuthClient> _getCredentials({
    AuthRepository? authRepository,
  }) async {
    // TODO: Firebase Auth と連携した認証を実装
    // 現在はダミー実装（後で本番対応）
    throw UnimplementedError('OAuth 認証は後続の実装が必要です');
  }

  /// バックアップ先フォルダの取得（なければ作成）
  Future<drive.Directory?> _getBackupFolder() async {
    if (_driveApi == null) {
      throw StateError(
        'Google Drive API が初期化されていません。authenticate() を呼び出してください',
      );
    }

    // 既存のバックアップフォルダを検索
    final searchResult = await _driveApi!.files.list(
      q: "name equals '$_backupFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
      fields: 'files(id, name)',
    );

    if (searchResult.files != null && searchResult.files!.isNotEmpty) {
      return searchResult.files!.first;
    }

    // フォルダが存在しない場合は作成
    final folder = drive.Directory()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = ['root'];

    return await _driveApi!.files.create(folder);
  }

  /// データベースのバックアップ
  ///
  /// [includeTimestamp] が true の場合、ファイル名にタイムスタンプを追加
  Future<String> backupDatabase({bool includeTimestamp = true}) async {
    if (_database == null) {
      throw StateError('データベースが初期化されていません');
    }

    // バックアップ用ファイルを作成
    final dbPath = await getDatabasesPath();
    final sourceFile = File(join(dbPath, _databaseName));

    if (!await sourceFile.exists()) {
      throw FileNotFoundException('バックアップ対象のデータベースが見つかりません：$dbPath');
    }

    // バックアップファイル名
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final fileName = includeTimestamp
        ? 'gemi_invoice_backup_$timestamp.db'
        : _databaseName;

    // ファイルサイズを確認（Google Drive 制限：5TB）
    final fileSize = await sourceFile.length();
    if (fileSize > 5 * 1024 * 1024 * 1024 * 1024) {
      throw StateError('データベースが大きすぎます（最大 5TB）');
    }

    // Google Drive API の認証
    await authenticate();

    if (_driveApi == null) {
      throw StateError('Google Drive API の認証に失敗しました');
    }

    // バックアップ先フォルダの取得
    final folder = await _getBackupFolder();
    final uploadParents = folder != null ? [folder.id!] : ['root'];

    // ファイルをアップロード
    final file = drive.File()
      ..name = fileName
      ..parents = uploadParents;

    final uploadedFile = await _driveApi!.files.create(
      file,
      uploadMedia: drive.Media(sourceFile.openRead(), fileSize),
      supportsAllDrives: true,
      fields: 'id, name, createdTime, size',
    );

    return uploadedFile.id!;
  }

  /// バックアップ履歴の取得
  Future<List<BackupInfo>> getBackupHistory() async {
    if (_driveApi == null) {
      throw StateError('Google Drive API が初期化されていません');
    }

    final folder = await _getBackupFolder();
    if (folder == null) {
      return [];
    }

    final result = await _driveApi!.files.list(
      q: "'${folder.id}' in parents and name contains '.db' and trashed=false",
      spaces: 'drive',
      sortBy: 'createdTime desc',
      fields: 'files(id, name, createdTime, modifiedTime, size)',
    );

    if (result.files == null || result.files!.isEmpty) {
      return [];
    }

    return result.files!.map((file) => BackupInfo.fromDriveFile(file)).toList();
  }

  /// バックアップファイルのダウンロード（リストア用）
  Future<File> downloadBackup(String fileId, {String? localName}) async {
    if (_driveApi == null) {
      throw StateError('Google Drive API が初期化されていません');
    }

    final file = await _driveApi!.files.get(fileId, supportsAllDrives: true);

    if (file.downloadUrl == null) {
      throw StateError('ダウンロード URL が取得できません');
    }

    // ダウンロード実行
    final response = await _client.get(Uri.parse(file.downloadUrl!));

    if (response.statusCode != 200) {
      throw IOException('ダウンロードに失敗しました：${response.statusCode}');
    }

    // ローカルファイルとして保存
    final dbPath = await getDatabasesPath();
    final localFileName = localName ?? file.name!;
    final localPath = join(dbPath, localFileName);

    final localFile = File(localPath);
    await localFile.writeAsBytes(response.bodyBytes);

    return localFile;
  }

  /// バックアップファイルの削除
  Future<void> deleteBackup(String fileId) async {
    if (_driveApi == null) {
      throw StateError('Google Drive API が初期化されていません');
    }

    await _driveApi!.files.delete(fileId, supportsAllDrives: true);
  }

  /// バックアップからリストア
  ///
  /// [fileId] - Google Drive のファイル ID
  /// [confirmOverwrite] - 既存データを上書きするかの確認（デフォルト：true）
  Future<void> restoreFromBackup(
    String fileId, {
    bool confirmOverwrite = true,
  }) async {
    if (_database == null) {
      throw StateError('データベースが初期化されていません');
    }

    if (confirmOverwrite) {
      // 既存のデータベースをバックアップ（上書き前に）
      await backupDatabase(includeTimestamp: false);
    }

    // バックアップファイルをダウンロード
    final backupFile = await downloadBackup(fileId, localName: _databaseName);

    // 現在のデータベースをクローズ
    if (_database!.isOpen) {
      await _database!.close();
    }

    // 既存の DB ファイルを削除
    final currentDbPath = await getDatabasesPath();
    final currentDbFile = File(join(currentDbPath, _databaseName));
    if (await currentDbFile.exists()) {
      await currentDbFile.delete();
    }

    // バックアップファイルを現在の DB ファイルにリネーム
    await backupFile.rename(currentDbFile.path);

    // 新しいデータベースをオープン
    _database = await openDatabase(
      currentDbFile.path,
      version: 43,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 自動バックアップスケジュールの設定
  ///
  /// [interval] - バックアップ間隔（デフォルト：1 日）
  Future<void> scheduleAutoBackup({
    Duration interval = const Duration(days: 1),
  }) async {
    // TODO: Flutter の Timer または WorkManager を使用して自動バックアップを実装
    print('自動バックアップスケジュール設定：${interval.inDays}日間隔');
  }

  /// _onCreate はデータベース作成時の処理（ダミー実装）
  Future<void> _onCreate(Database db, int version) async {}

  /// _onUpgrade はデータベースマイグレーション時の処理（ダミー実装）
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}
}

/// バックアップ情報のデータモデル
class BackupInfo {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime modifiedTime;
  final int size;

  BackupInfo({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.modifiedTime,
    required this.size,
  });

  factory BackupInfo.fromDriveFile(drive.File file) {
    return BackupInfo(
      id: file.id!,
      name: file.name!,
      createdTime: DateTime.parse(file.createdTime!),
      modifiedTime: DateTime.parse(file.modifiedTime ?? file.createdTime!),
      size: int.tryParse(file.size ?? '0') ?? 0,
    );
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024)
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    return '${createdTime.year}-${createdTime.month.toString().padLeft(2, '0')}-${createdTime.day.toString().padLeft(2, '0')} ${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';
  }
}

/// バックアップ関連の例外クラス
class CloudBackupException implements Exception {
  final String message;
  final String? errorCode;

  CloudBackupException(this.message, [this.errorCode]);

  @override
  String toString() =>
      'CloudBackupException: $message${errorCode != null ? ' ($errorCode)' : ''}';
}

class FileNotFoundException implements Exception {
  final String path;

  FileNotFoundException(this.path);

  @override
  String toString() => 'FileNotFoundException: $path';
}
