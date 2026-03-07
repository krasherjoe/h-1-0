import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import 'app_settings_repository.dart';
import 'google_api_service_base.dart';
import 'mothership_client.dart';

/// Google Drive 上にノード別バックアップフォルダを作成し、
/// SQLite やログファイルをアップロードするサービス。
class DriveBackupService extends GoogleApiServiceBase {
  DriveBackupService({
    AppSettingsRepository? settingsRepository,
    MothershipClient? nodeIdProvider,
  })  : _settingsRepository = settingsRepository ?? AppSettingsRepository(),
        _nodeIdProvider = nodeIdProvider ?? MothershipClient();

  static const String _rootFolderName = 'SalesAssist Backups';

  final AppSettingsRepository _settingsRepository;
  final MothershipClient _nodeIdProvider;

  Future<void> uploadDatabaseSnapshot(File databaseFile, {String? description}) async {
    if (!await databaseFile.exists()) {
      throw ArgumentError('Database file not found: ${databaseFile.path}');
    }
    await _uploadFile(databaseFile, description: description ?? 'SQLite backup');
  }

  Future<void> uploadErrorReport(File logFile, {String? description}) async {
    if (!await logFile.exists()) {
      throw ArgumentError('Log file not found: ${logFile.path}');
    }
    await _uploadFile(logFile, description: description ?? 'Error report');
  }

  Future<void> _uploadFile(File file, {required String description}) async {
    await withClient((client) async {
      final api = drive.DriveApi(client);
      final folderId = await _ensureNodeFolder(api);
      final fileName = _buildFileName(file);
      final driveFile = drive.File()
        ..name = fileName
        ..description = description
        ..parents = [folderId];
      final media = drive.Media(file.openRead(), await file.length());
      await api.files.create(
        driveFile,
        uploadMedia: media,
      );
    });
  }

  Future<String> _ensureNodeFolder(drive.DriveApi api) async {
    final rootId = await _ensureFolder(api, name: _rootFolderName);
    final nodeId = await _nodeIdProvider.ensureClientId();
    return _ensureFolder(
      api,
      name: nodeId,
      parentId: rootId,
    );
  }

  Future<String> _ensureFolder(drive.DriveApi api, {required String name, String? parentId}) async {
    final qBuffer = StringBuffer("mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed = false");
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
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final ext = p.extension(base);
    final nameWithoutExt = base.replaceAll(ext, '');
    final label = _settingsRepository.getGmailSyncLabelName();
    return '${nameWithoutExt}_$timestamp$ext';
  }
}
