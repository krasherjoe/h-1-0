import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_settings_repository.dart';
import '../services/auto_backup_service.dart';
import '../services/database_helper.dart';
import '../services/drive_backup_service.dart';
import '../services/google_account_service.dart';
import 'drive_backup_screen.dart';
import 'restore_screen.dart';

/// SB:バックアップ・リストア設定画面
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

enum BackupDestination {
  localOnly,
  driveOnly,
  both,
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _autoBackupEnabled = true;
  BackupDestination _backupDestination = BackupDestination.both;
  bool _googleFeaturesEnabled = false;
  bool _googleAuthLoading = false;
  bool _backingUp = false;
  String _localBackupStatus = '確認中...';
  String _driveBackupStatus = '確認中...';
  Map<String, dynamic>? _currentGoogleAccount;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
    // Google連携設定はSQLiteから読み込み（S1設定画面と同じ）
    final repo = AppSettingsRepository();
    _googleFeaturesEnabled = await repo.getGoogleFeaturesEnabled();
    await _loadBackupStatus();
    await _loadGoogleAccountInfo();
    setState(() {});
  }

  Future<void> _loadBackupStatus() async {
    try {
      final localService = LocalBackupService();
      final lastLocal = await localService.getLastBackupTime();

      setState(() {
        _localBackupStatus = lastLocal != null
            ? '${lastLocal.year}/${lastLocal.month.toString().padLeft(2, '0')}/${lastLocal.day.toString().padLeft(2, '0')}'
            : '未バックアップ';
      });
    } catch (e) {
      setState(() => _localBackupStatus = 'エラー');
    }

    if (_googleFeaturesEnabled) {
      try {
        final driveService = DriveBackupService();
        final backups = await driveService.listBackupFiles();
        final lastBackup = backups.isNotEmpty ? backups.first : null;

        if (mounted) {
          setState(() {
            _driveBackupStatus = lastBackup?.modifiedTime != null
                ? '${lastBackup!.modifiedTime!.year}/${lastBackup.modifiedTime!.month.toString().padLeft(2, '0')}/${lastBackup.modifiedTime!.day.toString().padLeft(2, '0')}'
                : '未バックアップ';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _driveBackupStatus = 'エラー');
        }
      }
    }
  }

  Future<void> _loadGoogleAccountInfo() async {
    try {
      final googleService = GoogleAccountService();
      final isSignedIn = await googleService.isSignedIn();

      if (!isSignedIn) {
        if (mounted) {
          setState(() => _currentGoogleAccount = null);
        }
        return;
      }

      final userInfo = await googleService.getCurrentUser();
      if (mounted) {
        setState(() => _currentGoogleAccount = userInfo);
      }
    } catch (e) {
      print('[BackupSettings] Google アカウント情報の取得に失敗：$e');
      if (mounted) {
        setState(() => _currentGoogleAccount = null);
      }
    }
  }

  Future<void> _setAutoBackup(bool enabled) async {
    final prefs = AppSettingsRepository();
    await prefs.setAutoBackupEnabled(enabled);
    setState(() => _autoBackupEnabled = enabled);
  }

  Future<void> _setGoogleFeatures(bool enabled) async {
    final prefs = AppSettingsRepository();
    await prefs.setGoogleFeaturesEnabled(enabled);
    setState(() => _googleFeaturesEnabled = enabled);
    if (!enabled) {
      await _loadBackupStatus();
    }
  }

  Future<void> _handleManualBackup() async {
    if (_googleFeaturesEnabled && _currentGoogleAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Google Drive バックアップを使用するには、先に Google アカウントにサインインしてください'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DriveBackupScreen(initialMode: DriveBackupMode.backup),
      ),
    );

    await _loadBackupStatus();
  }

  Future<void> _handleRestore() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('ローカルバックアップからリストア'),
              subtitle: const Text('端末内のバックアップファイルを選択'),
              onTap: () => Navigator.pop(context, 'local'),
            ),
            if (_googleFeaturesEnabled && _currentGoogleAccount != null)
              ListTile(
                leading: Icon(Icons.cloud, color: Theme.of(context).colorScheme.tertiary),
                title: const Text('Google Driveからリストア'),
                subtitle: const Text('クラウド上のバックアップを選択'),
                onTap: () => Navigator.pop(context, 'drive'),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('キャンセル'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (action == 'local') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RestoreScreen()),
      );
    } else if (action == 'drive') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DriveBackupScreen(initialMode: DriveBackupMode.restore),
        ),
      );
    }

    await _loadBackupStatus();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_googleAuthLoading) return;
    setState(() => _googleAuthLoading = true);

    try {
      final googleService = GoogleAccountService();
      final isAlreadySignedIn = await googleService.isSignedIn();
      if (isAlreadySignedIn) {
        await googleService.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      final signedIn = await googleService.signIn();

      if (!mounted) return;

      if (signedIn) {
        await _loadGoogleAccountInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Google アカウントにサインインしました'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('サインインをキャンセルしました'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      }
    } catch (e) {
      print('[BackupSettings] Google サインイン失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ サインインに失敗しました：$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _googleAuthLoading = false);
    }
  }

  Future<void> _handleGoogleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サインアウト確認'),
        content: const Text('Google アカウントからサインアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('サインアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final googleService = GoogleAccountService();
        await googleService.signOut();
        setState(() => _currentGoogleAccount = null);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google アカウントからサインアウトしました'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('サインアウトエラー：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SB:バックアップ・リストア'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // バックアップ状況カード
            _buildStatusCard(),
            const SizedBox(height: 24),

            // Googleアカウント設定
            _buildGoogleAccountSection(),
            const SizedBox(height: 24),

            // 自動バックアップ設定
            _buildAutoBackupSection(),
            const SizedBox(height: 24),

            // 手動操作
            _buildManualActionsSection(),
            const SizedBox(height: 24),

            // Google Drive バックアップ管理
            if (_googleFeaturesEnabled && _currentGoogleAccount != null)
              _buildDriveManagementSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.backup, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'バックアップ状況',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.storage, 'ローカル', _localBackupStatus, Theme.of(context).colorScheme.secondary),
          if (_googleFeaturesEnabled) ...[
            const SizedBox(height: 8),
            _buildStatusRow(Icons.cloud, 'Google Drive', _driveBackupStatus, Theme.of(context).colorScheme.tertiary),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String status, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Text(
          status,
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildGoogleAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Google 連携設定',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Google 連携機能を有効化'),
          subtitle: const Text('Google Drive へのバックアップなどが利用可能になります'),
          value: _googleFeaturesEnabled,
          onChanged: _setGoogleFeatures,
        ),
        if (_googleFeaturesEnabled) ...[
          const SizedBox(height: 8),
          if (_currentGoogleAccount != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle, color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentGoogleAccount!['name'] ?? '不明',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _currentGoogleAccount!['email'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleGoogleSignOut,
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('サインアウト'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleGoogleSignIn,
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: const Text('アカウント切り替え'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _googleAuthLoading ? null : _handleGoogleSignIn,
              icon: _googleAuthLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(_googleAuthLoading ? '処理中...' : 'Google アカウントにサインイン'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAutoBackupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自動バックアップ設定',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自動バックアップを有効化'),
          subtitle: const Text('毎日起動時に自動実行（24時間経過後）'),
          value: _autoBackupEnabled,
          onChanged: _setAutoBackup,
        ),
      ],
    );
  }

  Widget _buildManualActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手動操作',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _backingUp ? null : _handleManualBackup,
                icon: _backingUp
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.backup),
                label: Text(_backingUp ? 'バックアップ中...' : '今すぐバックアップ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleRestore,
                icon: Icon(Icons.restore, color: Theme.of(context).colorScheme.secondary),
                label: const Text('バックアップからリストア'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriveManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Google Drive バックアップ管理',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
          title: const Text('バックアップ一覧・管理'),
          subtitle: const Text('Google Drive上のバックアップを確認・削除'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriveBackupScreen()),
            );
            await _loadBackupStatus();
          },
        ),
      ],
    );
  }
}
