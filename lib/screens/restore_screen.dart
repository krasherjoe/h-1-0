import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart' show DatabaseHelper, LocalBackupService;

/// M1:リストア画面
/// バックアップからのリストアをステップバイステップで表示
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

enum RestoreStep {
  initial,      // 初期状態
  selecting,    // ファイル選択中
  validating,   // バックアップ検証中
  confirming,   // 確認待ち
  restoring,    // リストア実行中
  success,      // 成功
  error,        // エラー
}

class _RestoreScreenState extends State<RestoreScreen> {
  RestoreStep _currentStep = RestoreStep.initial;
  String? _selectedFilePath;
  String? _selectedFileName;
  int? _backupVersion;
  int? _backupDbVersion;
  String? _errorMessage;
  double _progress = 0.0;
  String _statusMessage = 'バックアップファイルを選択してください';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DB:データベースリストア'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 24),
              _buildStatusCard(),
              const SizedBox(height: 24),
              Expanded(child: _buildDetailPanel()),
              const SizedBox(height: 16),
              // システムナビゲーションバー分のスペースを確保
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      ('1', '選択', RestoreStep.selecting),
      ('2', '検証', RestoreStep.validating),
      ('3', '確認', RestoreStep.confirming),
      ('4', '実行', RestoreStep.restoring),
      ('5', '完了', RestoreStep.success),
    ];

    int currentIndex = -1;
    for (int i = 0; i < steps.length; i++) {
      if (_currentStep == steps[i].$3 || 
          (_currentStep.index > steps[i].$3.index && _currentStep != RestoreStep.error)) {
        currentIndex = i;
      }
    }
    if (_currentStep == RestoreStep.error) {
      currentIndex = -2;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final (number, label, step) = entry.value;
                final isActive = index <= currentIndex;
                final isCurrent = _currentStep == step;

                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? (isCurrent ? Colors.orange : Colors.green)
                              : Colors.grey.shade300,
                          border: isCurrent
                              ? Border.all(color: Colors.orange.shade700, width: 3)
                              : null,
                        ),
                        child: Center(
                          child: isActive && !isCurrent
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : Text(
                                  number,
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent
                              ? Colors.orange.shade700
                              : (isActive ? Colors.black : Colors.grey),
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (_currentStep) {
      case RestoreStep.initial:
        icon = Icons.folder_open;
        color = Colors.blue;
        title = '待機中';
        subtitle = 'バックアップファイルを選択してください';
        break;
      case RestoreStep.selecting:
        icon = Icons.search;
        color = Colors.blue;
        title = 'ファイル選択中';
        subtitle = 'ファイルを探しています...';
        break;
      case RestoreStep.validating:
        icon = Icons.verified_user;
        color = Colors.orange;
        title = '検証中';
        subtitle = 'バックアップファイルを検証しています...';
        break;
      case RestoreStep.confirming:
        icon = Icons.warning_amber;
        color = Colors.orange;
        title = '確認が必要';
        subtitle = 'このバックアップでリストアしますか？';
        break;
      case RestoreStep.restoring:
        icon = Icons.restore;
        color = Colors.orange;
        title = 'リストア中';
        subtitle = 'データを復元しています...';
        break;
      case RestoreStep.success:
        icon = Icons.check_circle;
        color = Colors.green;
        title = 'リストア完了';
        subtitle = 'データが正常に復元されました';
        break;
      case RestoreStep.error:
        icon = Icons.error;
        color = Colors.red;
        title = 'エラー';
        subtitle = _errorMessage ?? '不明なエラーが発生しました';
        break;
    }

    // MaterialColor の shade を取得
    Color shade50;
    Color shade100;
    Color shade700;
    if (color == Colors.blue) {
      shade50 = Colors.blue.shade50;
      shade100 = Colors.blue.shade100;
      shade700 = Colors.blue.shade700;
    } else if (color == Colors.orange) {
      shade50 = Colors.orange.shade50;
      shade100 = Colors.orange.shade100;
      shade700 = Colors.orange.shade700;
    } else if (color == Colors.green) {
      shade50 = Colors.green.shade50;
      shade100 = Colors.green.shade100;
      shade700 = Colors.green.shade700;
    } else if (color == Colors.red) {
      shade50 = Colors.red.shade50;
      shade100 = Colors.red.shade100;
      shade700 = Colors.red.shade700;
    } else {
      shade50 = color.withOpacity(0.1);
      shade100 = color.withOpacity(0.2);
      shade700 = color;
    }

    return Card(
      color: shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: shade700, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: shade700.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'バックアップ情報',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            if (_selectedFilePath == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        '「ファイルを選択」ボタンから\nバックアップファイル(.db)を選んでください',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ダウンロードフォルダにある\n「販売アシスト 1 号_backup_*.db」\nというファイルを選びます',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildInfoRow('ファイル名', _selectedFileName ?? '不明'),
              _buildInfoRow('ファイルパス', _selectedFilePath!),
              if (File(_selectedFilePath!).existsSync()) ...[
                _buildInfoRow('ファイルサイズ', _formatFileSize(File(_selectedFilePath!).lengthSync())),
                _buildInfoRow('更新日時', _formatDateTime(File(_selectedFilePath!).lastModifiedSync())),
              ],
              if (_backupDbVersion != null)
                _buildInfoRow('DBバージョン', 'v$_backupDbVersion'),
              const Spacer(),
              if (_currentStep == RestoreStep.restoring) ...[
                Text('復元進捗', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              if (_currentStep == RestoreStep.success) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'リストアが完了しました',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'アプリを再起動してください',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_currentStep) {
      case RestoreStep.initial:
      case RestoreStep.error:
        return ElevatedButton.icon(
          onPressed: _selectFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('バックアップファイルを選択'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
      case RestoreStep.selecting:
        return const ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('ファイルを開いています...'),
            ],
          ),
        );
      case RestoreStep.validating:
        return const ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('検証中...'),
            ],
          ),
        );
      case RestoreStep.confirming:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = RestoreStep.initial),
                child: const Text('キャンセル'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _executeRestore,
                icon: const Icon(Icons.restore),
                label: const Text('リストア実行'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        );
      case RestoreStep.restoring:
        return const ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('リストア中...'),
            ],
          ),
        );
      case RestoreStep.success:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('完了'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = RestoreStep.initial;
                  _selectedFilePath = null;
                  _selectedFileName = null;
                  _backupDbVersion = null;
                  _progress = 0.0;
                });
              },
              child: const Text('別のバックアップからリストア'),
            ),
          ],
        );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectFile() async {
    setState(() => _currentStep = RestoreStep.selecting);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        initialDirectory: Platform.isAndroid 
          ? '/storage/emulated/0/Download'
          : (await getApplicationDocumentsDirectory()).path,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _currentStep = RestoreStep.initial;
          _statusMessage = 'ファイルが選択されませんでした';
        });
        return;
      }

      final path = result.files.first.path;
      if (path == null) {
        setState(() {
          _currentStep = RestoreStep.error;
          _errorMessage = 'ファイルパスを取得できませんでした';
        });
        return;
      }

      setState(() {
        _selectedFilePath = path;
        _selectedFileName = result.files.first.name;
        _currentStep = RestoreStep.validating;
      });

      await _validateBackup();
    } catch (e) {
      setState(() {
        _currentStep = RestoreStep.error;
        _errorMessage = 'ファイル選択エラー: $e';
      });
    }
  }

  Future<void> _validateBackup() async {
    try {
      final file = File(_selectedFilePath!);
      if (!await file.exists()) {
        setState(() {
          _currentStep = RestoreStep.error;
          _errorMessage = 'ファイルが存在しません';
        });
        return;
      }

      // DBファイルの検証
      try {
        final db = await openDatabase(_selectedFilePath!, readOnly: true);
        final version = await db.getVersion();
        await db.close();

        setState(() {
          _backupDbVersion = version;
          _currentStep = RestoreStep.confirming;
        });
      } catch (e) {
        setState(() {
          _currentStep = RestoreStep.error;
          _errorMessage = '無効なデータベースファイルです: $e';
        });
      }
    } catch (e) {
      setState(() {
        _currentStep = RestoreStep.error;
        _errorMessage = '検証エラー: $e';
      });
    }
  }

  Future<void> _executeRestore() async {
    setState(() {
      _currentStep = RestoreStep.restoring;
      _statusMessage = 'バックアップを復元しています...';
      _progress = 0.2;
    });

    try {
      // データベースのリストアを実行
      final localBackupService = LocalBackupService();
      
      setState(() {
        _progress = 0.5;
        _statusMessage = 'データベースをコピーしています...';
      });

      // データベースパスを取得
      final dbHelper = DatabaseHelper();
      final dbPath = await dbHelper.getDatabasePath();
      
      await localBackupService.restoreFromBackup(_selectedFilePath!, dbPath);

      setState(() {
        _progress = 1.0;
        _statusMessage = 'リストア完了';
        _currentStep = RestoreStep.success;
      });
    } catch (e) {
      setState(() {
        _currentStep = RestoreStep.error;
        _errorMessage = 'リストア失敗: $e';
      });
    }
  }
}
