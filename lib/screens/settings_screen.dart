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
import '../services/invoice_repository.dart';
import '../services/theme_controller.dart';
import 'company_info_screen.dart';
import 'customer_master_screen.dart';
import 'dashboard_menu_settings_screen.dart';
import 'master_hub_page.dart';
import 'mothership_discovery_settings_screen.dart';
import 'product_master_screen.dart';
import 'screen_s1_theme_selection.dart';
import 'screen_s8_email_settings.dart';
import 'db_debug_screen.dart' show DatabaseDebugScreen;
import 'drive_backup_screen.dart';
import 'screen_sb_backup_settings.dart';

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

  String _getThemeLabel(String theme) {
    switch (theme) {
      case 'light':
        return 'ライト';
      case 'dark':
        return 'ダーク';
      default:
        return 'システム';
    }
  }
  SyncTransportMode _transportMode = SyncTransportMode.gmailOnly;
  bool _googleFeaturesEnabled = false;
  bool _useDashboardHome = false;
  bool _showHistoryInvoiceNumber = true;
  bool _googleAuthLoading = false;
  GoogleSignInAccount? _currentGoogleAccount;

  /// バックアップ状況情報（表示用）
  String _localBackupStatus = '未実施';
  String _driveBackupStatus = '未認証';

  /// アプリバージョン情報
  String _appVersion = '';
  String _buildNumber = '';

  /// バックアップ状況を読み込み（概要表示用）
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

  String _formatBackupTime(String? isoTime) {
    if (isoTime == null) return '不明';
    try {
      final dt = DateTime.parse(isoTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'たった今';
      if (diff.inHours < 1) return '${diff.inMinutes}分前';
      if (diff.inDays < 1) return '${diff.inHours}時間前';
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  /// バックアップ設定を読み込み
  Future<void> _loadBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final autoBackup = prefs.getBool('auto_backup_enabled') ?? false;
    // Google連携設定はSQLiteから読み込み
    final googleFeaturesEnabled = await _repo.getGoogleFeaturesEnabled();
    if (mounted) {
      setState(() {
        _googleFeaturesEnabled = googleFeaturesEnabled;
      });
    }
    await _loadGoogleAccountInfo();
  }

  /// Googleアカウント情報を読み込み
  Future<void> _loadGoogleAccountInfo() async {
    try {
      final account = await GoogleAccountService().getCurrentAccount();
      if (mounted) {
        setState(() {
          _currentGoogleAccount = account;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Google アカウント情報の取得に失敗：$e');
      if (mounted) {
        setState(() {
          _currentGoogleAccount = null;
        });
      }
    }
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
        SnackBar(
          content: Text('✅ Google アカウントにサインインしました'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      print('[Settings] Google サインイン失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ サインインに失敗しました：$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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
          SnackBar(
            content: Text('✅ Google アカウントからサインアウトしました'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      print('[Settings] Google サインアウト失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ サインアウトに失敗しました：$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _googleAuthLoading = false);
      }
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
        SnackBar(content: Text('❌ エラー：$e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _verifyHashChainTail() async {
    await _runHashChainVerify(
      title: '直近5件のハッシュチェーン検証',
      runner: () => InvoiceRepository().verifyTailN(n: 5),
    );
  }

  Future<void> _verifyHashChainAll() async {
    await _runHashChainVerify(
      title: '全ロック済み伝票のハッシュチェーン検証',
      runner: () => InvoiceRepository().verifyAllLocked(),
    );
  }

  Future<void> _runHashChainVerify({
    required String title,
    required Future<HashChainVerifyResult> Function() runner,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await runner();
      stopwatch.stop();
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.isHealthy ? Icons.check_circle : Icons.error,
                color: result.isHealthy ? cs.primary : cs.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('検証件数: ${result.checked} 件'),
              const SizedBox(height: 4),
              Text(
                result.isHealthy
                    ? '✅ 改ざんは検出されませんでした'
                    : '⚠ 改ざん検出: ${result.brokenCount} 件',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.isHealthy ? cs.primary : cs.error,
                ),
              ),
              if (!result.isHealthy) ...[
                const SizedBox(height: 8),
                Text('改ざん検出された伝票ID:', style: TextStyle(fontSize: 12)),
                ...result.brokenIds.map((id) => Text(
                      '・$id',
                      style: TextStyle(fontSize: 11, color: cs.error),
                    )),
              ],
              const SizedBox(height: 8),
              Text(
                '処理時間: ${stopwatch.elapsedMilliseconds} ms',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('検証エラー: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Google API サービスを初期化
      GoogleAccountService().init();
      await _reloadSettings();
    });
  }

  /// 設定値を再読み込み（サブ画面から戻った時に呼ぶ）
  Future<void> _reloadSettings() async {
    // アプリバージョン情報を取得
    await _loadAppVersion();

    final theme = await _repo.getTheme();
    if (!mounted) return;
    setState(() => _theme = theme);
    final summaryTheme = await _repo.getSummaryTheme();
    if (!mounted) return;
    setState(() => _summaryTheme = summaryTheme);
    final listStyle = await _repo.getInvoiceListStyle();
    if (!mounted) return;
    setState(() => _invoiceListStyle = listStyle);
    final homeMode = await _repo.getHomeMode();
    if (!mounted) return;
    setState(() => _homeMode = homeMode);
    final statusText = await _repo.getDashboardStatusText();
    if (!mounted) return;
    setState(() => _statusTextController.text = statusText);
    final showCategoryDesc = await _repo
        .getDashboardShowCategoryDescriptions();
    if (!mounted) return;
    setState(() => _showCategoryDescriptions = showCategoryDesc);
    final showInvNum = await _repo.getShowHistoryInvoiceNumber();
    if (!mounted) return;
    setState(() => _showHistoryInvoiceNumber = showInvNum);
    final encoding = await _repo.getGmailEnvelopeEncoding();
    if (!mounted) return;
    setState(() => _encodingMode = encoding);
    final transport = await _repo.getSyncTransportMode();
    await _loadBackupSettings();
    if (!mounted) return;
    setState(() => _transportMode = transport);
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
        title: Row(
 children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
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
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DashboardMenuSettingsScreen(),
                ),
              );
              if (mounted) await _reloadSettings();
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.tag),
            title: const Text('A2:伝票番号を表示'),
            subtitle: const Text('履歴リストのカードに伝票番号を表示します'),
            value: _showHistoryInvoiceNumber,
            onChanged: (v) async {
              setState(() => _showHistoryInvoiceNumber = v);
              await _repo.setShowHistoryInvoiceNumber(v);
            },
          ),
          const SizedBox(height: 12),

          // バックアップ・リストア設定（専用画面へ）
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
              );
              if (mounted) await _reloadSettings();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
              ),
              child: Row(
                children: [
                  Icon(Icons.backup, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'バックアップ・リストア設定',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ローカル: $_localBackupStatus${_googleFeaturesEnabled ? " / Drive: $_driveBackupStatus" : ""}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.secondary),
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
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'テーマ設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThemeSelectionScreen(),
                          ),
                        );
                        if (mounted) await _reloadSettings();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '現在のテーマ: ${_getThemeLabel(_theme)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '伝票リストスタイル',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<InvoiceListStyle>(
                  segments: const [
                    ButtonSegment(
                      value: InvoiceListStyle.legacy,
                      label: Text('レガシー'),
                    ),
                    ButtonSegment(
                      value: InvoiceListStyle.a2,
                      label: Text('A2'),
                    ),
                  ],
                  selected: {_invoiceListStyle},
                  onSelectionChanged: (s) async {
                    await _repo.setInvoiceListStyle(s.first);
                    setState(() => _invoiceListStyle = s.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ホーム画面',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'invoice_history',
                      label: Text('伝票履歴'),
                    ),
                    ButtonSegment(
                      value: 'dashboard',
                      label: Text('ダッシュボード'),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.view_carousel, color: Theme.of(context).colorScheme.primary),
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
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.tertiary),
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mail, color: Theme.of(context).colorScheme.primary),
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScreenS8EmailSettings(),
                      ),
                    );
                    if (mounted) await _reloadSettings();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.storage, color: Theme.of(context).colorScheme.error),
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
                ListTile(
                  leading: Icon(Icons.cleaning_services, color: Theme.of(context).colorScheme.tertiary),
                  title: const Text('顧客データの重複を整理'),
                  subtitle: const Text('同じ顧客が2つ以上表示されている場合、古い方を非表示にします'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('顧客データの重複を整理'),
                        content: const Text('同じ顧客が2つ以上表示されている場合、古い方を非表示にします。\n\nデータは削除されず、履歴として保持されます。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル'),
                          ),
ElevatedButton(
                             onPressed: () => Navigator.pop(context, true),
                             child: const Text('整理する'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Theme.of(context).colorScheme.secondary,
                             ),
                           ),
                         ],
                       ),
                     );
                     if (confirmed == true) {
                       final prefs = await SharedPreferences.getInstance();
                       await prefs.setBool('force_cleanup_forked_records', true);
                       if (!mounted) return;
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: const Text('アプリを再起動して顧客データを整理します'),
                          duration: Duration(seconds: 3),
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
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.cloud_upload, color: Theme.of(context).colorScheme.secondary),
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
                Row(
                  children: [
                    Icon(Icons.storage, color: Theme.of(context).colorScheme.secondary),
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
                Text(
                  '端末内のバックアップファイルを確認・復元できます',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showLocalBackupManagement(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('バックアップ一覧・復元'),
style: OutlinedButton.styleFrom(
                     foregroundColor: Theme.of(context).colorScheme.secondary,
                   ),
                 ),
                 const SizedBox(height: 4),

                 const SizedBox(height: 8),
                 OutlinedButton.icon(
                   onPressed: _resetRestoreCheck,
                   icon: const Icon(Icons.refresh),
                   label: const Text('復元ダイアログを再表示'),
                   style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
                 ),
               ],
             ),
           ),
           const SizedBox(height: 12),
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user, color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ハッシュチェーン整合性',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ロック済み伝票の改ざんを検出します。電子帳簿保存法対応の監査機能です。',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _verifyHashChainTail,
                  icon: const Icon(Icons.speed),
                  label: const Text('直近5件を検証（高速）'),
style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                 ),
                 const SizedBox(height: 4),
                 OutlinedButton.icon(
                   onPressed: _verifyHashChainAll,
                   icon: const Icon(Icons.fact_check),
                   label: const Text('全ロック済み伝票を検証'),
                   style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                 ),
               ],
             ),
           ),
           const SizedBox(height: 12),
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync, color: Theme.of(context).colorScheme.primary),
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MothershipDiscoverySettingsScreen(),
                      ),
                    );
                    if (mounted) await _reloadSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.storage, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  onTap: () async {
                    try {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanyInfoScreen(),
                        ),
                      );
                      if (mounted) await _reloadSettings();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラー：$e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('顧客マスター'),
                  onTap: () async {
                    try {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerMasterScreen(),
                        ),
                      );
                      if (mounted) await _reloadSettings();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラー：$e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('商品マスター'),
                  onTap: () async {
                    try {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductMasterScreen(),
                        ),
                      );
                      if (mounted) await _reloadSettings();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラー：$e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
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
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.category, color: Theme.of(context).colorScheme.secondary),
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MasterHubPage()),
                    );
                    if (mounted) await _reloadSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.cloud_queue, color: Theme.of(context).colorScheme.secondary),
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
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                SizedBox(width: 8),
                                Text(
                                  '✅ サインイン済み',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
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
                                 foregroundColor: Theme.of(context).colorScheme.error,
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
                           color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Theme.of(context).colorScheme.secondaryContainer),
                         ),
                         child: Row(
                           children: [
                             Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
                            SizedBox(width: 8),
                           Expanded(
                              child: Text(
                                  '⚠️ Google アカウントのサインインが必要です',
                                   style: TextStyle(
                                     fontSize: 13,
                                     fontWeight: FontWeight.bold,
                                     color: Theme.of(context).colorScheme.secondary,
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
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                            minimumSize: const Size(double.infinity, 40),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Google Drive へのバックアップ',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '• Gmail を使用したデータ同期',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '• ブラウザでの OAuth 認証（安全に実施）',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.secondaryContainer),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ 重要なお知らせ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Google Drive バックアップは自動バックアップと重複します',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '• ローカルバックアップを優先してご利用ください',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '• Google 連携を無効にしてもデータは安全に保存されます',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                           foregroundColor: Theme.of(context).colorScheme.error,
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
