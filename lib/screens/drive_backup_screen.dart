import 'dart:io';
import 'package:flutter/material.dart';
import '../services/drive_backup_service.dart';
import '../services/google_account_service.dart';
import '../services/database_helper.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// バックアップ画面の初期モード
enum DriveBackupMode {
  normal,    // 通常（一覧表示）
  backup,    // バックアップ自動開始
  restore,   // リストアモード
}

/// SD:Google Drive バックアップ・リストア画面
class DriveBackupScreen extends StatefulWidget {
  final DriveBackupMode initialMode;

  const DriveBackupScreen({
    super.key,
    this.initialMode = DriveBackupMode.normal,
  });

  @override
  State<DriveBackupScreen> createState() => _DriveBackupScreenState();
}

enum DriveStep {
  checkingAuth,    // 認証確認中
  needsAuth,       // 認証必要
  loadingBackups,  // バックアップ一覧読み込み中
  listBackups,     // バックアップ一覧表示
  backingUp,       // バックアップ実行中
  restoring,       // リストア実行中
  success,         // 成功
  error,           // エラー
}

class _DriveBackupScreenState extends State<DriveBackupScreen> {
  DriveStep _currentStep = DriveStep.checkingAuth;
  String? _errorMessage;
  String? _currentUserEmail;
  List<drive.File> _backups = [];
  double _progress = 0.0;
  String _statusMessage = '';
  drive.File? _selectedBackup;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    setState(() => _currentStep = DriveStep.checkingAuth);

    try {
      // 認証確認
      final googleService = GoogleAccountService();
      final isSignedIn = await googleService.isSignedIn();

      if (!isSignedIn) {
        setState(() => _currentStep = DriveStep.needsAuth);
        return;
      }

      // ユーザー情報取得
      final userInfo = await googleService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUserEmail = userInfo?['email'];
        });
      }

      // バックアップモード時は自動的にバックアップを開始
      if (widget.initialMode == DriveBackupMode.backup) {
        await _handleBackup();
        return;
      }

      // 通常モード時はバックアップ一覧を読み込み
      if (mounted) {
        setState(() => _currentStep = DriveStep.loadingBackups);
      }
      await _loadBackups();
    } catch (e) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = '認証確認エラー: $e';
      });
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _currentStep = DriveStep.loadingBackups);

    try {
      final driveService = DriveBackupService();
      final backups = await driveService.listBackupFiles();

      // 日付でソート（新しい順）
      backups.sort((a, b) {
        final aTime = a.modifiedTime;
        final bTime = b.modifiedTime;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _backups = backups;
          _currentStep = DriveStep.listBackups;
        });
      }
    } catch (e) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = 'バックアップ一覧取得エラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SD:Google Drive バックアップ'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_currentStep == DriveStep.listBackups)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBackups,
              tooltip: '一覧を更新',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 認証ステータスカード
              _buildAuthStatusCard(),
              const SizedBox(height: 16),
              // メインコンテンツ
              Expanded(child: _buildMainContent()),
              const SizedBox(height: 16),
              // アクションボタン（SafeAreaで保護）
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

  Widget _buildAuthStatusCard() {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (_currentStep) {
      case DriveStep.checkingAuth:
      case DriveStep.loadingBackups:
        icon = Icons.sync;
        color = Colors.blue;
        title = '読み込み中...';
        subtitle = 'しばらくお待ちください';
        break;
      case DriveStep.needsAuth:
        icon = Icons.account_circle;
        color = Colors.orange;
        title = '認証が必要';
        subtitle = 'Google アカウントでサインインしてください';
        break;
      case DriveStep.listBackups:
      case DriveStep.backingUp:
      case DriveStep.restoring:
        icon = Icons.cloud_done;
        color = Colors.green;
        title = '認証済み';
        subtitle = _currentUserEmail ?? 'アカウント情報なし';
        break;
      case DriveStep.success:
        icon = Icons.check_circle;
        color = Colors.green;
        title = '完了';
        subtitle = _statusMessage;
        break;
      case DriveStep.error:
        icon = Icons.error;
        color = Colors.red;
        title = 'エラー';
        subtitle = _errorMessage ?? '不明なエラー';
        break;
    }

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
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
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentStep) {
      case DriveStep.checkingAuth:
      case DriveStep.loadingBackups:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _currentStep == DriveStep.checkingAuth
                    ? '認証を確認中...'
                    : 'バックアップ一覧を読み込み中...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      case DriveStep.needsAuth:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Google Drive にアクセスするには\nサインインが必要です',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      case DriveStep.listBackups:
        return _buildBackupList();
      case DriveStep.backingUp:
      case DriveStep.restoring:
        return _buildProgressPanel();
      case DriveStep.success:
        return _buildSuccessPanel();
      case DriveStep.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'エラーが発生しました',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBackupList() {
    if (_backups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Google Drive にバックアップがありません',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '「今すぐバックアップ」ボタンから\n新規バックアップを作成できます',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'バックアップ一覧 (${_backups.length}件)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _loadBackups,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('更新'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _backups.length,
            itemBuilder: (context, index) {
              final backup = _backups[index];
              final isSelected = _selectedBackup?.id == backup.id;
              final modifiedTime = backup.modifiedTime;
              final size = backup.size;

              return Card(
                color: isSelected ? Colors.green.shade50 : null,
                child: ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.backup,
                    color: isSelected ? Colors.green : Colors.grey,
                  ),
                  title: Text(
                    backup.name ?? '不明',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_formatDateTime(modifiedTime)}${_formatFileSize(size)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        ElevatedButton(
                          onPressed: () => _showRestoreConfirm(backup),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('リストア'),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedBackup = backup);
                          },
                          child: const Text('選択'),
                        ),
                    ],
                  ),
                  onTap: () {
                    setState(() => _selectedBackup = backup);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressPanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              strokeWidth: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _currentStep == DriveStep.backingUp
                ? 'Google Drive にバックアップ中...'
                : 'Google Drive からリストア中...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_progress > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessPanel() {
    final isBackup = _statusMessage.contains('バックアップ');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green.shade400),
          const SizedBox(height: 24),
          Text(
            isBackup ? 'バックアップ完了' : 'リストア完了',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.initialMode == DriveBackupMode.backup) {
                // バックアップモード時は前の画面に戻る
                Navigator.pop(context);
              } else {
                // 通常モード時は一覧に戻る
                setState(() {
                  _currentStep = DriveStep.loadingBackups;
                  _selectedBackup = null;
                  _progress = 0.0;
                });
                _loadBackups();
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('確認'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_currentStep) {
      case DriveStep.checkingAuth:
      case DriveStep.loadingBackups:
        return const SizedBox.shrink();
      case DriveStep.needsAuth:
        return ElevatedButton.icon(
          onPressed: _handleSignIn,
          icon: const Icon(Icons.login),
          label: const Text('Google アカウントでサインイン'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
      case DriveStep.listBackups:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('サインアウト', style: TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _handleBackup,
                icon: const Icon(Icons.backup),
                label: const Text('今すぐバックアップ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        );
      case DriveStep.backingUp:
      case DriveStep.restoring:
        return const SizedBox.shrink();
      case DriveStep.success:
        return ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = DriveStep.listBackups;
              _selectedBackup = null;
              _progress = 0.0;
            });
            _loadBackups();
          },
          icon: const Icon(Icons.check),
          label: const Text('完了'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
      case DriveStep.error:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = DriveStep.checkingAuth;
                    _errorMessage = null;
                  });
                  _checkAuthAndLoad();
                },
                child: const Text('再試行'),
              ),
            ),
          ],
        );
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '日時不明';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(String? size) {
    if (size == null) return '';
    final bytes = int.tryParse(size);
    if (bytes == null) return '';
    if (bytes < 1024) return ' ($bytes B)';
    if (bytes < 1024 * 1024) return ' (${(bytes / 1024).toStringAsFixed(1)} KB)';
    return ' (${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB)';
  }

  Future<void> _handleSignIn() async {
    try {
      final googleService = GoogleAccountService();
      final success = await googleService.signIn(forceAccountPicker: true);

      if (success && mounted) {
        _checkAuthAndLoad();
      }
    } catch (e) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = 'サインインエラー: $e';
      });
    }
  }

  Future<void> _handleSignOut() async {
    try {
      final googleService = GoogleAccountService();
      await googleService.signOut();

      if (mounted) {
        setState(() {
          _currentStep = DriveStep.needsAuth;
          _currentUserEmail = null;
          _backups = [];
          _selectedBackup = null;
        });
      }
    } catch (e) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = 'サインアウトエラー: $e';
      });
    }
  }

  Future<void> _handleBackup() async {
    setState(() {
      _currentStep = DriveStep.backingUp;
      _progress = 0.0;
      _statusMessage = 'データベースファイルを準備中...';
    });

    try {
      // データベースパスを取得
      final dbHelper = DatabaseHelper();
      final dbPath = await dbHelper.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        setState(() {
          _currentStep = DriveStep.error;
          _errorMessage = 'データベースファイルが見つかりません';
        });
        return;
      }

      setState(() {
        _progress = 0.2;
        _statusMessage = 'Google Drive にアップロード中...';
      });

      // Drive にアップロード
      final driveService = DriveBackupService();
      await driveService.uploadDatabaseSnapshot(
        dbFile,
        description: '手動バックアップ - ${DateTime.now().toIso8601String()}',
      );

      setState(() {
        _progress = 1.0;
        _statusMessage = 'バックアップが完了しました';
        _currentStep = DriveStep.success;
      });
    } catch (e) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = 'バックアップエラー: $e';
      });
    }
  }

  Future<void> _showRestoreConfirm(drive.File backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('リストア確認'),
        content: Text(
          '以下のバックアップからリストアします：\n\n'
          'ファイル名: ${backup.name}\n'
          '更新日時: ${_formatDateTime(backup.modifiedTime)}\n\n'
          '⚠️ 現在のデータは上書きされます',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('リストア実行'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeRestore(backup);
    }
  }

  Future<void> _executeRestore(drive.File backup) async {
    if (backup.id == null) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = 'バックアップIDが無効です';
      });
      return;
    }

    setState(() {
      _currentStep = DriveStep.restoring;
      _progress = 0.0;
      _statusMessage = 'バックアップをダウンロード中...';
    });

    try {
      // データベースパスを取得
      final dbHelper = DatabaseHelper();
      final dbPath = await dbHelper.getDatabasePath();

      setState(() {
        _progress = 0.3;
        _statusMessage = 'ダウンロード中...';
      });

      // Drive から選択したバックアップをダウンロードして復元
      final driveService = DriveBackupService();
      final success = await driveService.restoreBackupById(backup.id!, dbPath);

      if (success) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'リストアが完了しました。アプリを再起動してください。';
          _currentStep = DriveStep.success;
        });
      } else {
        setState(() {
          _currentStep = DriveStep.error;
          _errorMessage = 'リストアに失敗しました';
        });
      }
    } catch (e) {
      setState(() {
        _currentStep = DriveStep.error;
        _errorMessage = 'リストアエラー: $e';
      });
    }
  }
}
