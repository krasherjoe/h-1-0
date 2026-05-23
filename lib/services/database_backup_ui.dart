import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// バックアップ情報クラス
class BackupInfo {
  final String path;
  final DateTime createdTime;
  final String formattedDate;
  final String formattedSize;
  final bool isLatest;

  BackupInfo({
    required this.path,
    required this.createdTime,
    required this.formattedDate,
    required this.formattedSize,
    required this.isLatest,
  });
}

/// ローカルバックアップ一覧取得
Future<List<BackupInfo>> _getLocalBackups(String databasePath) async {
  final backupDir = await _getBackupDirectory(databasePath);
  final backupDirObj = Directory(backupDir);

  if (!await backupDirObj.exists()) {
    return [];
  }

  final files = await backupDirObj
      .list()
      .where((f) => f.path.endsWith('.db'))
      .map((e) => e as File)
      .toList();

  // ファイル名からタイムスタンプを抽出してソート（新しい順）
  files.sort((a, b) {
    final aName = path.basename(a.path);
    final bName = path.basename(b.path);
    final aNum = int.tryParse(aName.replaceAll(RegExp(r'^backup_'), '')) ?? 0;
    final bNum = int.tryParse(bName.replaceAll(RegExp(r'^backup_'), '')) ?? 0;
    return bNum.compareTo(aNum);
  });

  // 最新ファイルは最新バックアップとみなす
  final latestFile = File(databasePath);
  final latestModified = await latestFile.stat();

  final backups = files.map((file) async {
    final stat = await file.stat();
    final createdTime = DateTime.fromMillisecondsSinceEpoch(
      stat.modified.millisecondsSinceEpoch,
    );
    final size = await file.length();
    final isLatest = file.path == databasePath; // DB ファイル自身は最新とみなさない

    return BackupInfo(
      path: file.path,
      createdTime: createdTime,
      formattedDate: createdTime.toString().split(' ').first,
      formattedSize: _formatFileSize(size),
      isLatest: false,
    );
  }).toList();

  return Future.wait(backups);
}

/// ローカルバックアップディレクトリ取得
/// バックアップはDownloadsフォルダに固定
Future<String> _getBackupDirectory([String? databasePath]) async {
  try {
    if (Platform.isAndroid) {
      final backupDir = Directory('/storage/emulated/0/Download');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        debugPrint('Downloadフォルダを作成：${backupDir.path}');
      }
      return backupDir.path;
    } else if (Platform.isIOS) {
      // iOSではDocumentsフォルダ内のbackupsサブフォルダ
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(dir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        debugPrint('backupsフォルダを作成：${backupDir.path}');
      }
      return backupDir.path;
    }
    // フォールバック
    final fallbackDir = Directory(path.join(await getDatabasesPath(), 'backups'));
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir.path;
  } catch (e) {
    debugPrint('バックアップディレクトリ取得エラー：$e');
    return path.join(await getDatabasesPath(), 'backups');
  }
}

/// ファイルサイズフォーマット
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// ローカルバックアップ管理ダイアログを表示
Widget showLocalBackupManagement({
  required String databasePath,
  Function(String)? onRestore,
}) {
  return StatefulBuilder(
    builder: (context, setState) {
      return FutureBuilder<List<BackupInfo>>(
        future: _getLocalBackups(databasePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('バックアップ一覧を読み込んでいます...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('エラー'),
              content: Text('読み込みエラー：${snapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          }

          final backups = snapshot.data ?? [];

          return AlertDialog(
            title: const Text('ローカルバックアップ管理'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '過去 3 件のバックアップが保持されます。',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (backups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('バックアップファイルがありません'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: backups.length,
                      itemBuilder: (context, index) {
                        final backup = backups[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              backup.isLatest
                                  ? Icons.file_present
                                  : Icons.history,
                              color: backup.isLatest ? Theme.of(context).colorScheme.tertiary : null,
                            ),
                            title: Text(
                              backup.createdTime
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('サイズ：${backup.formattedSize}'),
                                if (backup.isLatest)
                                  Text(
                                    '（最新）',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.tertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'リストア',
                              onPressed: () async {
                                if (onRestore != null) {
                                  onRestore(backup.path);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// バックアップ実行中のダイアログ表示
class BackupProgressDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<String?> Function() onBackup;
  final VoidCallback? onComplete;
  final Function(String)? onError;

  const BackupProgressDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onBackup,
    this.onComplete,
    this.onError,
  });

  @override
  State<BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<BackupProgressDialog> {
  bool _isComplete = false;
  String? _errorMessage;
  String? _statusMessage;

  Future<void> _executeBackup() async {
    setState(() {
      _statusMessage = 'バックアップを開始します...';
    });

    try {
      final result = await widget.onBackup();
      if (!mounted) return;

      setState(() {
        _isComplete = true;
        _statusMessage = result != null ? 'バックアップ完了！' : 'バックアップできませんでした';
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete?.call();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'エラー：$e';
      });

      widget.onError?.call(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeBackup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: CircularProgressIndicator(),
          ),
          Text(widget.message, style: Theme.of(context).textTheme.bodyMedium),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isComplete)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
      ],
    );
  }
}

/// バックアップ一覧表示用ダイアログ
class BackupListDialog extends StatelessWidget {
  final List<BackupFile> backups;
  final String databasePath;
  final Function(String)? onRestore;

  const BackupListDialog({
    super.key,
    required this.backups,
    required this.databasePath,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('バックアップ一覧'),
      content: SizedBox(
        width: double.maxFinite,
        child: backups.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('バックアップファイルがありません'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: backups.length,
                itemBuilder: (context, index) {
                  final backup = backups[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        backup.isLatest ? Icons.file_present : Icons.history,
                        color: backup.isLatest ? Theme.of(context).colorScheme.tertiary : null,
                      ),
                      title: Text(
                        backup.createdTime.toIso8601String().split('T').first,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('サイズ：${backup.formattedSize}'),
                          if (backup.isLatest)
                            Text(
                              '（最新）',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'リストア',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('リストア確認'),
                              content: Text(
                                'このバックアップからデータを復元します。\n現在のデータは上書きされます。\n\n${backup.formattedDate}\nサイズ：${backup.formattedSize}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                  child: const Text('リストアする'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            onRestore?.call(backup.path);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

// バックアップ関連定数
const _backupPrefix = 'backup_';
const _backupHashSuffix = '.sha256';
const _retentionDays = 365 * 7;
const _lastBackupKey = 'last_backup_timestamp';

/// 古いバックアップを隔離フォルダへ移動（完全削除はしない・人間確認必須）
///
/// 電子帳簿保存法7年保存義務＋タイムスタンプ信頼性問題対策：
/// NTP/DNS攻撃・GPSエミュレータで日付が狂った場合の誤削除を防ぐため、
/// 自動削除は行わず、隔離（quarantine）して管理者確認を待つ。
Future<List<String>> quarantineOldBackups(String backupDir) async {
  final quarantined = <String>[];
  try {
    final backupDirObj = Directory(backupDir);
    if (!await backupDirObj.exists()) return quarantined;

    final quarantineDir = Directory(path.join(backupDir, 'quarantine'));
    if (!await quarantineDir.exists()) {
      await quarantineDir.create();
    }

    final now = DateTime.now();
    final cutoffDate = now.subtract(
      const Duration(days: _retentionDays),
    );

    final files = await backupDirObj
        .list()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    for (final file in files) {
      DateTime? fileDate;

      // 1. メタデータ（.sha256）から作成日時を優先取得（誤削除防止）
      final hashFile = File('${file.path}$_backupHashSuffix');
      if (await hashFile.exists()) {
        try {
          final hashContent = await hashFile.readAsString();
          final hashMeta = jsonDecode(hashContent) as Map<String, dynamic>;
          final createdAtStr = hashMeta['createdAt'] as String?;
          if (createdAtStr != null) {
            fileDate = DateTime.parse(createdAtStr);
          }
        } catch (_) {
          // JSON解析失敗時はフォールバック
        }
      }

      // 2. メタデータ取得失敗時はファイル名タイムスタンプをフォールバック
      if (fileDate == null) {
        final fileName = file.path.split('/').last;
        final timestampStr = fileName
            .replaceAll(_backupPrefix, '')
            .replaceAll('.db', '');
        final timestamp = int.tryParse(timestampStr) ?? 0;
        fileDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }

      // 3. ファイル日付が未来の場合は「日付暴走」と判断して削除しない（安全側に倒す）
      if (fileDate.isAfter(now)) {
        print('未来日付バックアップをスキップ（日付暴走疑い）：${file.path}');
        continue;
      }

      // 4. 保存期間を超えたバックアップを隔離フォルダへ移動（削除はしない）
      if (fileDate.isBefore(cutoffDate)) {
        final fileName = file.path.split('/').last;
        final quarantinePath = path.join(quarantineDir.path, fileName);
        await (file as File).rename(quarantinePath);
        if (await hashFile.exists()) {
          await hashFile.rename(
              path.join(quarantineDir.path, '$fileName$_backupHashSuffix'));
        }
        quarantined.add(quarantinePath);
        print('保存期間満了バックアップを隔離：$quarantinePath');
      }
    }
  } catch (e) {
    print('バックアップ隔離失敗：$e');
  }
  return quarantined;
}

/// バックアップファイルの整合性を検証（SHA256ハッシュ照合）
Future<bool> verifyBackupIntegrity(String backupPath) async {
  try {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      print('バックアップファイルが見つかりません：$backupPath');
      return false;
    }

    final hashPath = '$backupPath$_backupHashSuffix';
    final hashFile = File(hashPath);
    if (!await hashFile.exists()) {
      print('ハッシュファイルが見つかりません：$hashPath');
      return false;
    }

    final hashContent = await hashFile.readAsString();
    String storedHash;
    try {
      final hashMeta = jsonDecode(hashContent) as Map<String, dynamic>;
      storedHash = hashMeta['hash'] as String;
    } catch (_) {
      // 旧フォーマット（生ハッシュ文字列）との後方互換
      storedHash = hashContent.trim();
    }
    final backupBytes = await backupFile.readAsBytes();
    final calculatedHash = crypto.sha256.convert(backupBytes).toString();

    if (storedHash != calculatedHash) {
      print('バックアップ整合性エラー: $backupPath');
      return false;
    }

    return true;
  } catch (e) {
    print('バックアップ整合性検証失敗：$e');
    return false;
  }
}

/// ダウンロードフォルダにアーカイブエクスポート（手動長期保存用）
Future<String?> exportArchiveForLongTerm(String databasePath) async {
  try {
    final dbFile = File(databasePath);
    if (!await dbFile.exists()) {
      print('DBファイルが見つかりません：$databasePath');
      return null;
    }

    final downloadDir = await _getBackupDirectory();
    final now = DateTime.now();
    final fileName =
        'gemi_invoice_archive_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.db';
    final exportPath = path.join(downloadDir, fileName);

    await dbFile.copy(exportPath);

    // ハッシュも一緒にエクスポート（作成日時記録）
    final dbBytes = await File(exportPath).readAsBytes();
    final dbHash = crypto.sha256.convert(dbBytes).toString();
    final hashMeta = jsonEncode({
      'hash': dbHash,
      'createdAt': now.toIso8601String(),
    });
    await File('$exportPath$_backupHashSuffix').writeAsString(hashMeta);

    print('長期保存用アーカイブをエクスポート：$exportPath');
    return exportPath;
  } catch (e) {
    print('アーカイブエクスポート失敗：$e');
    return null;
  }
}

/// バックアップ一覧取得
Future<List<BackupFile>> getBackupList(String databasePath) async {
  try {
    final backupDir = await _getBackupDirectory();
    final backupDirObj = Directory(backupDir);
    if (!await backupDirObj.exists()) return [];

    final files = await backupDirObj
        .list()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    // 作成時間でソート（新しい順）- ファイル名からタイムスタンプを抽出
    files.sort((a, b) {
      final aPath = (a as File).path;
      final bPath = (b as File).path;
      // backup_1234567890.db から数値部分を抽出
      final aNum =
          int.tryParse(
            aPath.replaceAll(_backupPrefix, '').replaceAll('.db', ''),
          ) ??
          0;
      final bNum =
          int.tryParse(
            bPath.replaceAll(_backupPrefix, '').replaceAll('.db', ''),
          ) ??
          0;
      return bNum.compareTo(aNum);
    });

    return files.map((f) {
      final file = f as File;
      final stat = file.statSync();
      final fileName = file.path.split('/').last;
      // backup_1234567890.db からタイムスタンプを抽出
      final timestampStr = fileName
          .replaceAll(_backupPrefix, '')
          .replaceAll('.db', '');
      final timestamp = int.tryParse(timestampStr) ?? 0;

      return BackupFile(
        path: file.path,
        size: stat.size,
        createdTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
        isLatest: files.first == file,
      );
    }).toList();
  } catch (e) {
    print('バックアップ一覧取得失敗：$e');
    return [];
  }
}

/// 最終バックアップ時間を取得
Future<DateTime?> getLastBackupTime() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastBackupKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  } catch (e) {
    print('最終バックアップ時間取得失敗：$e');
    return null;
  }
}

/// バックアップからリストア
///
/// P4: 復元前にSHA256ハッシュ整合性検証を必須化。
/// 改竄されたバックアップや.sha256が存在しないバックアップは復元を拒否する。
/// 運用上必要な場合のみ allowUnverified=true で明示的にスキップ可能。
Future<bool> restoreFromBackup(
  String backupPath,
  String databasePath, {
  bool allowUnverified = false,
}) async {
  try {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      print('バックアップファイルが見つかりません：$backupPath');
      return false;
    }

    // P4: 復元前に必ず整合性を検証
    final hashFile = File('$backupPath$_backupHashSuffix');
    if (!await hashFile.exists()) {
      if (!allowUnverified) {
        print('整合性メタデータ(.sha256)が存在しません。復元を中止します：$backupPath');
        return false;
      }
      print('警告: 整合性メタデータなしで復元を強行します（allowUnverified=true）');
    } else {
      final verified = await verifyBackupIntegrity(backupPath);
      if (!verified) {
        print('整合性検証に失敗しました。改竄の疑いがあるため復元を中止：$backupPath');
        return false;
      }
      print('整合性検証OK：$backupPath');
    }

    // 現在のデータベースをクローズ
    final dbObj = await openDatabase(
      databasePath,
      version: 45,
      readOnly: true,
    );
    await dbObj.close();

    // 現在の DB をバックアップ（上書き前）
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final currentBackupPath = '$databasePath.restore-$timestamp';
    if (await File(databasePath).exists()) {
      await File(databasePath).copy(currentBackupPath);
      print('リストア前の DB をバックアップ：$currentBackupPath');
    }

    // 現在の DB を削除
    if (await File(databasePath).exists()) {
      await File(databasePath).delete();
    }

    // バックアップからコピー
    await backupFile.copy(databasePath);
    print('リストア完了：$backupPath -> $databasePath');

    return true;
  } catch (e) {
    print('リストア失敗：$e');
    return false;
  }
}

/// 隔離フォルダ内のバックアップ一覧を取得（ユーザー確認用）
Future<List<BackupFile>> getQuarantineList() async {
  try {
    final backupDir = await _getBackupDirectory();
    final quarantineDir = Directory(path.join(backupDir, 'quarantine'));
    if (!await quarantineDir.exists()) return [];

    final files = await quarantineDir
        .list()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    // メタデータから信頼できる作成日時を取得
    final result = <BackupFile>[];
    for (final f in files) {
      final file = f as File;
      final stat = file.statSync();
      final fileName = file.path.split('/').last;
      DateTime? fileDate;

      // メタデータ（.sha256）から作成日時を優先取得
      final hashFile = File('${file.path}$_backupHashSuffix');
      if (await hashFile.exists()) {
        try {
          final hashContent = await hashFile.readAsString();
          final hashMeta = jsonDecode(hashContent) as Map<String, dynamic>;
          final createdAtStr = hashMeta['createdAt'] as String?;
          if (createdAtStr != null) {
            fileDate = DateTime.parse(createdAtStr);
          }
        } catch (_) {}
      }

      // フォールバック: ファイル名タイムスタンプ
      fileDate ??= DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(fileName.replaceAll(_backupPrefix, '').replaceAll('.db', '')) ?? 0,
      );

      result.add(BackupFile(
        path: file.path,
        size: stat.size,
        createdTime: fileDate,
        isLatest: false,
      ));
    }

    result.sort((a, b) => b.createdTime.compareTo(a.createdTime));
    return result;
  } catch (e) {
    print('隔離一覧取得失敗：$e');
    return [];
  }
}

/// 隔離バックアップを手動削除（ユーザー確認済みのみ実行）
Future<bool> deleteQuarantinedBackup(String backupPath) async {
  try {
    final file = File(backupPath);
    if (!await file.exists()) {
      print('削除対象が見つかりません：$backupPath');
      return false;
    }

    // 対応ハッシュファイルも削除
    final hashFile = File('$backupPath$_backupHashSuffix');
    if (await hashFile.exists()) {
      await hashFile.delete();
    }

    await file.delete();
    print('隔離バックアップを削除：$backupPath');
    return true;
  } catch (e) {
    print('隔離バックアップ削除失敗：$e');
    return false;
  }
}

/// バックアップファイル情報
class BackupFile {
  final String path;
  final int size;
  final DateTime createdTime;
  final bool isLatest;

  BackupFile({
    required this.path,
    required this.size,
    required this.createdTime,
    required this.isLatest,
  });

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
