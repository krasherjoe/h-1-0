import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice_list_style.dart';
import '../models/sync_preferences.dart';
import '../services/app_settings_repository.dart';
import '../services/auto_backup_service.dart';
import '../services/database_helper.dart';
import '../services/drive_backup_service.dart';
import '../services/google_account_service.dart';
import '../services/theme_controller.dart';
import 'company_info_screen.dart';
import 'customer_master_screen.dart';
import 'dashboard_menu_settings_screen.dart';
import 'master_hub_page.dart';
import 'mothership_discovery_settings_screen.dart';
import 'product_master_screen.dart';
import 'screen_s8_email_settings.dart';
import 'db_debug_screen.dart' show DatabaseDebugScreen;
import 'drive_backup_screen.dart';

/// バックアップ先タイプ（ローカル / Google Drive）
enum BackupLocationType {
  local('ローカル'),
  googleDrive('Google Drive');

  final String displayName;
  const BackupLocationType(this.displayName);
}

/// バックアップ先選択（ローカル / Google Drive / 両方）
enum BackupDestination {
  localOnly('ローカルのみのバックアップ'),
  driveOnly('Google Drive のみ'),
  both('両方にバックアップ');

  final String displayName;
  const BackupDestination(this.displayName);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AppSettingsRepository();
  String _theme = 'system';
  String _summaryTheme = 'white';
  InvoiceListStyle _invoiceListStyle = InvoiceListStyle.legacy;
  String _homeMode = 'invoice_history';
  final TextEditingController _statusTextController = TextEditingController();
  bool _showCategoryDescriptions = true;
  GmailEnvelopeEncoding _encodingMode = GmailEnvelopeEncoding.gzipBase64;
  SyncTransportMode _transportMode = SyncTransportMode.gmailOnly;
  bool _backingUp = false;
  String? _lastBackupTime;
  bool _autoBackupEnabled = false;
  bool _googleFeaturesEnabled = false;
  GoogleSignInAccount? _currentGoogleAccount;
  bool _googleAuthLoading = false;

  /// バックアップ先タイプ
  BackupDestination _backupDestination = BackupDestination.both;

  /// バックアップ状況情報（表示用）
  String _localBackupStatus = '未実施';
  String _driveBackupStatus = '未認証';

  /// アプリバージョン情報
  String _appVersion = '';
  String _buildNumber = '';

  Future<void> _loadBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup_time');
    final autoBackup = prefs.getBool('auto_backup_enabled') ?? false;
    if (mounted) {
      setState(() {
        _lastBackupTime = lastBackup;
        _autoBackupEnabled = autoBackup;
      });
    }
  }

  Future<void> _loadGoogleSettings() async {
    final enabled = await _repo.getGoogleFeaturesEnabled();
    if (mounted) {
      setState(() {
        _googleFeaturesEnabled = enabled;
      });
    }
    // Google アカウント情報を取得
    await _loadGoogleAccountInfo();
  }

  Future<void> _loadGoogleAccountInfo() async {
    try {
      final account = await GoogleAccountService().getCurrentAccount();
      if (mounted) {
        setState(() {
          _currentGoogleAccount = account;
        });
      }
    } catch (e) {
      print('[Settings] Google アカウント情報の取得に失敗：$e');
      if (mounted) {
        setState(() {
          _currentGoogleAccount = null;
        });
      }
    }
  }

  Future<void> _backupToGoogleDrive() async {
    if (_backingUp || _currentGoogleAccount == null) return;
    setState(() => _backingUp = true);
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('データベースファイルが見つかりません');
      }

      // Google Drive バックアップを実行
      final driveService = DriveBackupService();
      await driveService.uploadDatabaseSnapshot(
        dbFile,
        description: '手動バックアップ - ${DateTime.now().toIso8601String()}',
      );

      if (!mounted) return;

      // バックアップ状況を更新
      await _loadBackupStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Google Drive にバックアップしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ バックアップ失敗：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);
      }
    }
  }

  /// 手動バックアップを実行（選択された先に応じて）
  Future<void> _performManualBackup() async {
    if (_backingUp) return;

    // Google アカウントが必要（Drive のみまたは両方の場合）
    if (_backupDestination != BackupDestination.localOnly &&
        _currentGoogleAccount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Google Drive バックアップを選択していますが、アカウントが認証されていません。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _backingUp = true);

    try {
      switch (_backupDestination) {
        case BackupDestination.localOnly:
          await _performLocalBackup();
          break;
        case BackupDestination.driveOnly:
          await _backupToGoogleDrive();
          break;
        case BackupDestination.both:
          // 両方にバックアップ
          final dbHelper = DatabaseHelper();
          final db = await dbHelper.database;
          final dbPath = db.path;

          // ローカルバックアップ
          final localService = LocalBackupService();
          await localService.createAutoBackup(dbPath);

          // Google Drive バックアップ
          final driveService = DriveBackupService();
          await driveService.uploadDatabaseSnapshot(
            File(dbPath),
            description: '手動バックアップ - ${DateTime.now().toIso8601String()}',
          );

          if (!mounted) return;

          // バックアップ状況を更新
          await _loadBackupStatus();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ ローカルと Google Drive の両方にバックアップしました'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ バックアップ失敗：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);
      }
    }
  }

  /// ローカルバックアップを実行
  Future<void> _performLocalBackup() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;

      final localService = LocalBackupService();
      await localService.createAutoBackup(dbPath);

      if (!mounted) return;

      // バックアップ状況を更新
      await _loadBackupStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ローカルバックアップしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ バックアップ失敗：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);
      }
    }
  }

  /// バックアップ状況を読み込み
  Future<void> _loadBackupStatus() async {
    try {
      final dbHelper = DatabaseHelper();

      // ローカルバックアップ状況
      final localService = LocalBackupService();
      final db = await dbHelper.database;
      final dbPath = db.path;
      final localBackups = await localService.getBackupList(dbPath);
      final latestLocal = localBackups.isNotEmpty ? localBackups.first : null;

      setState(() {
        if (latestLocal != null) {
          _localBackupStatus =
              '${latestLocal.path.split('/').last} (${_formatDateTime(latestLocal.createdTime)})';
        } else {
          _localBackupStatus = '未実施';
        }
      });

      // Google Drive バックアップ状況
      final driveService = DriveBackupService();
      final driveBackups = await driveService.listBackupFiles();
      final latestDrive = driveBackups.isNotEmpty ? driveBackups.first : null;

      setState(() {
        if (latestDrive != null) {
          _driveBackupStatus =
              '最新：${_formatDateTime(latestDrive.modifiedTime)}';
        } else {
          _driveBackupStatus = '未認証';
        }
      });
    } catch (e) {
      print('[Settings] バックアップ状況の読み込みに失敗：$e');
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '不明';
    try {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'たった今';
      if (diff.inHours < 1) return '${diff.inMinutes}分前';
      if (diff.inDays < 1) return '${diff.inHours}時間前';
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt.toString().substring(0, 16);
    }
  }

  /// バックアップ先を変更
  Future<void> _setBackupDestination(BackupDestination newDestination) async {
    final prefs = await SharedPreferences.getInstance();
    // バックアップ先タイプを保存（'local', 'drive', 'both'）
    await prefs.setString('backup_destination_type', newDestination.name);

    setState(() => _backupDestination = newDestination);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newDestination.displayName}に設定しました')),
    );
  }

  /// バックアップ先を読み込み
  Future<void> _loadBackupDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final destinationName =
        prefs.getString('backup_destination_type') ?? 'both';
    setState(() {
      _backupDestination = BackupDestination.values.firstWhere(
        (d) => d.name == destinationName,
        orElse: () => BackupDestination.both,
      );
    });
  }

  Future<void> _setAutoBackup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
    setState(() => _autoBackupEnabled = enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? '自動バックアップを有効化しました' : '自動バックアップを無効化しました'),
      ),
    );
  }

  Future<void> _setGoogleFeaturesEnabled(bool enabled) async {
    await _repo.setGoogleFeaturesEnabled(enabled);
    setState(() => _googleFeaturesEnabled = enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? 'Google 連携機能を有効化しました' : 'Google 連携機能を無効化しました'),
      ),
    );
  }

  Future<void> _handleGoogleSignIn({bool switchAccount = false}) async {
    if (_googleAuthLoading) return;

    setState(() => _googleAuthLoading = true);

    try {
      final googleService = GoogleAccountService();
      
      // アカウント切り替え時は一度サインアウトしてから再度サインイン
      if (switchAccount) {
        debugPrint('[Settings] アカウント切り替え → サインアウトしてから再サインイン');
        await googleService.signOut();
        // 少し待機して状態をリセット
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // サインイン実行（切り替え時はアカウント選択強制）
      await googleService.signIn(forceAccountPicker: switchAccount);

      // 認証後のアカウント情報を再取得
      await _loadGoogleAccountInfo();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Google アカウントにサインインしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('[Settings] Google サインイン失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ サインインに失敗しました：$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _googleAuthLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サインアウト確認'),
        content: const Text(
          'Google アカウントからサインアウトします。\n\nバックアップ・同期機能は使用できなくなります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('サインアウト'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _googleAuthLoading = true);

    try {
      final googleService = GoogleAccountService();
      await googleService.signOut();

      // アカウント情報をクリア
      if (mounted) {
        setState(() {
          _currentGoogleAccount = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google アカウントからサインアウトしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('[Settings] Google サインアウト失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ サインアウトに失敗しました：$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _googleAuthLoading = false);
      }
    }
  }

  String _formatBackupTime(String? isoTime) {
    if (isoTime == null) return '未実施';
    try {
      final dt = DateTime.parse(isoTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'たった今';
      if (diff.inHours < 1) return '${diff.inMinutes}分前';
      if (diff.inDays < 1) return '${diff.inHours}時間前';
      if (diff.inDays < 7) return '${diff.inDays}日前';
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  Future<void> _resetRestoreCheck() async {
    try {
      await AutoBackupService.resetFirstLaunchCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 復元ダイアログをリセットしました。アプリを再起動してください。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ エラー：$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Google API サービスを初期化
      GoogleAccountService().init();

      // アプリバージョン情報を取得
      await _loadAppVersion();

      final theme = await _repo.getTheme();
      setState(() => _theme = theme);
      final summaryTheme = await _repo.getSummaryTheme();
      setState(() => _summaryTheme = summaryTheme);
      final listStyle = await _repo.getInvoiceListStyle();
      setState(() => _invoiceListStyle = listStyle);
      final homeMode = await _repo.getHomeMode();
      setState(() => _homeMode = homeMode);
      final statusText = await _repo.getDashboardStatusText();
      setState(() => _statusTextController.text = statusText);
      final showCategoryDesc = await _repo
          .getDashboardShowCategoryDescriptions();
      setState(() => _showCategoryDescriptions = showCategoryDesc);
      final encoding = await _repo.getGmailEnvelopeEncoding();
      setState(() => _encodingMode = encoding);
      final transport = await _repo.getSyncTransportMode();
      await _loadBackupSettings();
      await _loadBackupDestination();
      await _loadGoogleSettings();
      setState(() => _transportMode = transport);
    });
  }

  /// アプリバージョン情報を取得
  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
        });
      }
    } catch (e) {
      print('[Settings] バージョン情報の取得に失敗：$e');
      if (mounted) {
        setState(() {
          _appVersion = 'unknown';
          _buildNumber = 'unknown';
        });
      }
    }
  }

  @override
  void dispose() {
    _statusTextController.dispose();
    super.dispose();
  }

  /// バージョン情報ダイアログを表示
  Future<void> _showVersionInfoDialog(
    BuildContext context,
    String value,
  ) async {
    if (value != 'version') return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('バージョン情報'),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'アプリバージョン',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text('v${_appVersion} ($_buildNumber)'),
                ),
                if (_appVersion.isNotEmpty && _buildNumber.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '詳細情報',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 4.0)),
                  Text('バージョン：${_appVersion}'),
                  Text('ビルド番号：${_buildNumber}'),
                  Text('パッケージ名：h_1'),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // バージョン文字列を生成（例：v1.5.09+154）
    final versionTitle = 'S1:設定 v${_appVersion}($_buildNumber)';

    return Scaffold(
      appBar: AppBar(
        title: Text(versionTitle),
        actions: [
          // three-dot menu ボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              _showVersionInfoDialog(context, value);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'version',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text('バージョン情報'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(20)),
          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: const Text('ダッシュボード設定'),
            subtitle: const Text('表示するメニューの ON/OFF と順序を管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DashboardMenuSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          /// バックアップ状況表示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'バックアップ状況',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.storage, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ローカル：${_localBackupStatus}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (_googleFeaturesEnabled) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Google Drive: ${_driveBackupStatus}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DriveBackupScreen(),
                          ),
                        ),
                        tooltip: 'Google Drive バックアップ管理',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自動バックアップ'),
            subtitle: const Text('毎日起動時に自動実行（24 時間経過後）'),
            value: _autoBackupEnabled,
            onChanged: _setAutoBackup,
          ),
          const Divider(indent: 16, endIndent: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.home_outlined, color: Colors.indigo),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ホーム画面設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'invoice_history',
                      label: Text('伝票一覧'),
                      icon: Icon(Icons.receipt_long),
                    ),
                    ButtonSegment<String>(
                      value: 'dashboard',
                      label: Text('ダッシュボード'),
                      icon: Icon(Icons.dashboard),
                    ),
                  ],
                  selected: {_homeMode},
                  onSelectionChanged: (selection) async {
                    final mode = selection.first;
                    await _repo.setHomeMode(mode);
                    if (!mounted) return;
                    setState(() => _homeMode = mode);
                    final message = mode == 'dashboard'
                        ? 'ホーム画面をダッシュボードに設定しました'
                        : 'ホーム画面を伝票一覧に設定しました';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'アプリ起動時や戻る操作で開くホーム画面を選択できます。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'テーマ設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'system',
                      label: Text('システム'),
                      icon: Icon(Icons.settings),
                    ),
                    ButtonSegment<String>(
                      value: 'light',
                      label: Text('ライト'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment<String>(
                      value: 'dark',
                      label: Text('ダーク'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {_theme},
                  onSelectionChanged: (s) async {
                    await AppThemeController.instance.setTheme(s.first);
                    setState(() => _theme = s.first);
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'white',
                      label: Text('白'),
                      icon: Icon(Icons.palette),
                    ),
                    ButtonSegment<String>(
                      value: 'gray',
                      label: Text('グレー'),
                      icon: Icon(Icons.color_lens),
                    ),
                  ],
                  selected: {_summaryTheme},
                  onSelectionChanged: (s) async {
                    await _repo.setSummaryTheme(s.first);
                    setState(() => _summaryTheme = s.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.view_carousel, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '伝票一覧スタイル',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InvoiceListStyle>(
                  initialValue: _invoiceListStyle,
                  decoration: const InputDecoration(
                    labelText: 'IV / Q1 一覧 UI',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InvoiceListStyle.legacy,
                      child: Text('従来レイアウト（ステータスチップ表示）'),
                    ),
                    DropdownMenuItem(
                      value: InvoiceListStyle.a2,
                      child: Text('A2 スタイル（淡色カード＋長押し確定）'),
                    ),
                  ],
                  onChanged: (style) async {
                    if (style == null) return;
                    await _repo.setInvoiceListStyle(style);
                    setState(() => _invoiceListStyle = style);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '※将来的にその他のスタイルを追加予定です。'
                  '設定変更後は IV/Q1 画面を再表示すると反映されます。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ステータス設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _statusTextController,
                  decoration: const InputDecoration(
                    labelText: 'ステータステキスト（例：営業中、休業中、工事中）',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) async {
                    await _repo.setDashboardStatusText(v);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('カテゴリ説明を表示'),
                  subtitle: const Text('ダッシュボードの見出し・各項目の説明テキストを ON/OFF'),
                  value: _showCategoryDescriptions,
                  onChanged: (value) async {
                    await _repo.setDashboardShowCategoryDescriptions(value);
                    setState(() => _showCategoryDescriptions = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mail, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'メール設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('SM: メール設定'),
                  subtitle: const Text('BCC 設定、メールテンプレート（ヘッダー/フッター）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScreenS8EmailSettings(),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.storage, color: Colors.red),
                  title: const Text('DB デバッグ画面'),
                  subtitle: const Text('SQLite テーブルスキーマ確認・データ照会'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatabaseDebugScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_upload, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'データバックアップ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '最終バックアップ：${_formatBackupTime(_lastBackupTime)}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _backingUp ? null : _performManualBackup,
                        icon: _backingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.backup),
                        label: Text(_backingUp ? 'バックアップ中...' : '今すぐバックアップ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadBackupStatus,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'バックアップ状況を更新',
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自動バックアップ'),
                  subtitle: const Text('毎日起動時に自動実行（24 時間経過後）'),
                  value: _autoBackupEnabled,
                  onChanged: _setAutoBackup,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📌 バックアップ設定',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'バックアップ先を選択:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RadioListTile<BackupDestination>(
                        title: const Text(
                          'ローカルのみ',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: BackupDestination.localOnly,
                        groupValue: _backupDestination,
                        onChanged: (value) {
                          if (value != null) _setBackupDestination(value);
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      RadioListTile<BackupDestination>(
                        title: const Text(
                          'Google Drive のみ',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: BackupDestination.driveOnly,
                        groupValue: _backupDestination,
                        onChanged: (value) {
                          if (value != null) _setBackupDestination(value);
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      RadioListTile<BackupDestination>(
                        title: const Text(
                          '両方にバックアップ',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: BackupDestination.both,
                        groupValue: _backupDestination,
                        onChanged: (value) {
                          if (value != null) _setBackupDestination(value);
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ローカルバックアップは起動時に自動実行（過去 3 件保持）',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      if (_googleFeaturesEnabled)
                        Text(
                          '• Google Drive バックアップは選択時に自動実行',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.storage, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ローカルバックアップ管理',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '端末内のバックアップファイルを確認・復元できます',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showLocalBackupManagement(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('バックアップ一覧・復元'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _resetRestoreCheck,
                  icon: const Icon(Icons.refresh),
                  label: const Text('復元ダイアログを再表示'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync, color: Colors.indigo),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '同期設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GmailEnvelopeEncoding>(
                  initialValue: _encodingMode,
                  decoration: const InputDecoration(
                    labelText: 'エンベロープ圧縮モード',
                    border: OutlineInputBorder(),
                    helperText: '端末が送受信するメール本文の形式（gzip / Base64 / 平文）',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: GmailEnvelopeEncoding.gzipBase64,
                      child: Text('gzip + Base64 (推奨)'),
                    ),
                    DropdownMenuItem(
                      value: GmailEnvelopeEncoding.base64Only,
                      child: Text('Base64 のみ'),
                    ),
                    DropdownMenuItem(
                      value: GmailEnvelopeEncoding.plainJson,
                      child: Text('JSON 平文'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await _repo.setGmailEnvelopeEncoding(value);
                    setState(() => _encodingMode = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SyncTransportMode>(
                  initialValue: _transportMode,
                  decoration: const InputDecoration(
                    labelText: '同期トランスポート',
                    border: OutlineInputBorder(),
                    helperText: 'LAN/VPN 直通が使える場合は直接通信を優先できます',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SyncTransportMode.gmailOnly,
                      child: Text('Gmail のみ'),
                    ),
                    DropdownMenuItem(
                      value: SyncTransportMode.directOnly,
                      child: Text('直接通信のみ (母艦 API)'),
                    ),
                    DropdownMenuItem(
                      value: SyncTransportMode.auto,
                      child: Text('自動切替 (LAN 優先/Gmail フォールバック)'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await _repo.setSyncTransportMode(value);
                    setState(() => _transportMode = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on),
                  title: const Text('お局様検出設定'),
                  subtitle: const Text('GPS 位置ベースの自動検出と記憶された場所の管理'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MothershipDiscoverySettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage, color: Colors.brown),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'マスター管理',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('会社情報'),
                  onTap: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanyInfoScreen(),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラー：$e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('顧客マスター'),
                  onTap: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerMasterScreen(),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラー：$e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('商品マスター'),
                  onTap: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductMasterScreen(),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラー：$e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'マスター管理（統合）',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('M1: マスター管理'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MasterHubPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_queue, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Google 連携機能',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Google Drive/Gmail 連携を有効化'),
                  subtitle: const Text('バックアップ・同期機能を使用可能にします'),
                  value: _googleFeaturesEnabled,
                  onChanged: _setGoogleFeaturesEnabled,
                ),
                const SizedBox(height: 12),
                if (_googleAuthLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_currentGoogleAccount != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  '✅ サインイン済み',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentGoogleAccount!.email,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleGoogleSignOut,
                              icon: const Icon(Icons.logout),
                              label: const Text('サインアウト'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _handleGoogleSignIn(switchAccount: true),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('アカウント切り替え'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Google アカウントのサインインが必要です',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _handleGoogleSignIn,
                        icon: const Icon(Icons.login),
                        label: const Text('Google アカウントにサインイン'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Google Drive へのバックアップ',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const Text(
                        '• Gmail を使用したデータ同期',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const Text(
                        '• ブラウザでの OAuth 認証（安全に実施）',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '⚠️ 重要なお知らせ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Google Drive バックアップは自動バックアップと重複します',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      Text(
                        '• ローカルバックアップを優先してご利用ください',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      Text(
                        '• Google 連携を無効にしてもデータは安全に保存されます',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// ローカルバックアップ管理画面を表示
  Future<void> _showLocalBackupManagement() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final dbPath = db.path;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return DatabaseHelper.showLocalBackupManagement(
              databasePath: dbPath,
              onRestore: (backupPath) async {
                Navigator.of(context).pop(); // ダイアログを閉じる

                if (!mounted) return;

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('リストア確認'),
                    content: Text(
                      'このバックアップからデータを復元します。\n'
                      '現在のデータは上書きされます。\n\n'
                      'パス：${backupPath}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('リストアする'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;

                try {
                  await db.close();

                  final file = File(backupPath);
                  if (!await file.exists()) {
                    throw Exception('バックアップファイルが見つかりません');
                  }

                  // データベースを削除してバックアップからコピー
                  final dbFile = File(dbPath);
                  if (await dbFile.exists()) {
                    await dbFile.delete();
                  }

                  await file.copy(dbPath);

                  // 再度データベースを開く
                  await dbHelper.database;

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ ローカルバックアップから復元しました。アプリを再起動してください。'),
                      duration: Duration(seconds: 5),
                    ),
                  );

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('復元完了'),
                      content: const Text('データベースを復元しました。\nアプリを再起動してください。'),
                      actions: [
                        ElevatedButton(
                          onPressed: () => SystemNavigator.pop(),
                          child: const Text('アプリを終了'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ リストア失敗：$e')));
                }
              },
            );
          },
        ),
      ),
    );
  }
}
