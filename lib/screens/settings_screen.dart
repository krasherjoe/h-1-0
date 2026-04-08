import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/invoice_list_style.dart';
import '../models/sync_preferences.dart';
import '../services/app_settings_repository.dart';
import '../services/google_account_service.dart';
import '../services/theme_controller.dart';
import 'screen_s8_email_settings.dart';
import 'master_hub_page.dart';
import 'company_info_screen.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import 'dashboard_menu_settings_screen.dart';
import 'mothership_discovery_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/drive_backup_service.dart';
import '../services/auto_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AppSettingsRepository();
  final GoogleAccountService _googleAccountService =
      GoogleAccountService.instance;
  String _theme = 'system';
  String _summaryTheme = 'white';
  InvoiceListStyle _invoiceListStyle = InvoiceListStyle.legacy;
  String _homeMode = 'invoice_history';
  final TextEditingController _statusTextController = TextEditingController();
  bool _showCategoryDescriptions = true;
  GmailEnvelopeEncoding _encodingMode = GmailEnvelopeEncoding.gzipBase64;
  SyncTransportMode _transportMode = SyncTransportMode.gmailOnly;
  GoogleSignInAccount? _googleAccount;
  bool _linkingAccount = false;
  StreamSubscription<GoogleSignInAccount?>? _accountSubscription;
  bool _backingUp = false;
  bool _restoring = false;
  String? _lastBackupTime;
  bool _autoBackupEnabled = false;

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

  Future<void> _restoreFromGoogleDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ復元確認'),
        content: const Text(
          '現在のデータベースをGoogle Driveの最新バックアップで上書きします。\n\n'
          '※現在のデータは失われます。続けますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('復元する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;

      print('[Restore] DB パス: $dbPath');
      await db.close();
      print('[Restore] DB をクローズしました');

      final driveService = DriveBackupService();
      print('[Restore] バックアップファイル一覧を取得中...');
      final backups = await driveService.listBackupFiles();
      print('[Restore] バックアップファイル数: ${backups.length}');
      
      if (backups.isEmpty) {
        throw Exception('復元可能なバックアップが見つかりません');
      }

      // DB ファイルを探す
      final dbBackup = backups.firstWhere(
        (f) => f.name?.endsWith('.db') ?? false,
        orElse: () => throw Exception('DB ファイルが見つかりません'),
      );
      
      print('[Restore] DB バックアップ: ${dbBackup.name} (ID: ${dbBackup.id})');
      
      final success = await driveService.restoreLatestBackup(dbPath);

      if (!success) {
        throw Exception('復元に失敗しました');
      }

      print('[Restore] 復元完了');

      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ データを復元しました。アプリを再起動してください。')),
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
      }
    } catch (e, st) {
      print('[Restore] エラー: $e');
      print('[Restore] スタックトレース: $st');
      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ 復元失敗: $e')));
      }
    }
  }

  Future<void> _backupToGoogleDrive() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('データベースファイルが見つかりません');
      }

      final driveService = DriveBackupService();
      await driveService.uploadDatabaseSnapshot(
        dbFile,
        description: 'Manual backup - ${DateTime.now().toIso8601String()}',
      );

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      await prefs.setString('last_backup_time', now);

      if (mounted) {
        setState(() => _lastBackupTime = now);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Google Driveにバックアップしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ バックアップ失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);
      }
    }
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
        SnackBar(content: Text('❌ エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
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
      setState(() => _transportMode = transport);
      final account = await _googleAccountService.recoverAccount();
      if (!mounted) return;
      setState(() => _googleAccount = account);
    });
    _accountSubscription = _googleAccountService.accountStream.listen((
      account,
    ) {
      if (!mounted) return;
      setState(() => _googleAccount = account);
    });
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _statusTextController.dispose();
    super.dispose();
  }

  Future<void> _selectGoogleAccount() async {
    setState(() => _linkingAccount = true);
    try {
      final account = await _googleAccountService.pickAccount();
      if (account == null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('アカウント選択がキャンセルされました')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google連携に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _linkingAccount = false);
      }
    }
  }

  Future<void> _disconnectGoogleAccount() async {
    setState(() => _linkingAccount = true);
    try {
      await _googleAccountService.disconnect();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('連携解除に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _linkingAccount = false);
      }
    }
  }

  String _googleAccountSummary() {
    if (_googleAccount == null) {
      return '未連携（Googleアカウントを選択してください）';
    }
    final name = _googleAccount!.displayName;
    final email = _googleAccount!.email;
    return name == null || name.isEmpty ? email : '$name / $email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S1:設定')),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(20)),
          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: const Text('ダッシュボード設定'),
            subtitle: const Text('表示するメニューのON/OFFと順序を管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DashboardMenuSettingsScreen(),
              ),
            ),
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
                    labelText: 'IV / Q1 一覧UI',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InvoiceListStyle.legacy,
                      child: Text('従来レイアウト（ステータスチップ表示）'),
                    ),
                    DropdownMenuItem(
                      value: InvoiceListStyle.a2,
                      child: Text('A2スタイル（淡色カード＋長押し確定）'),
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
                  '設定変更後はIV/Q1画面を再表示すると反映されます。',
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
                  subtitle: const Text('ダッシュボードの見出し・各項目の説明テキストをON/OFF'),
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
                    const Icon(Icons.cloud_sync, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Googleアカウント連携',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _googleAccountSummary(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _linkingAccount
                            ? null
                            : _selectGoogleAccount,
                        icon: const Icon(Icons.account_circle),
                        label: Text(
                          _googleAccount == null ? 'アカウントを選択' : '別アカウントに切替',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: (_googleAccount == null || _linkingAccount)
                          ? null
                          : _disconnectGoogleAccount,
                      icon: const Icon(Icons.logout),
                      label: const Text('連携解除'),
                    ),
                  ],
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
                  title: const Text('SM:メール設定'),
                  subtitle: const Text('SMTP/BCC設定、Gmailアカウント選択'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScreenS8EmailSettings(),
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
                        onPressed: _backingUp ? null : _backupToGoogleDrive,
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
                  child: const Text(
                    '📌 ローカルバックアップは起動時に即座に実行されます。'
                    'Google Drive バックアップはバックグラウンドで実行されるため、'
                    'アプリの起動時間に影響しません。',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
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
                        'ローカルバックアップ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '端末内に毎日自動バックアップ（過去 3 件保持）',
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _restoring ? null : _restoreFromGoogleDrive,
                  icon: _restoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore),
                  label: Text(_restoring ? '復元中...' : 'バックアップから復元'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Google Drive連携が必要です。上記「Googleアカウント連携」で設定してください。',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _resetRestoreCheck,
                  icon: const Icon(Icons.refresh),
                  label: const Text('復元ダイアログを再表示'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
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
                      child: Text('JSON平文'),
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
                    helperText: 'LAN/VPN直通が使える場合は直接通信を優先できます',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SyncTransportMode.gmailOnly,
                      child: Text('Gmail のみ'),
                    ),
                    DropdownMenuItem(
                      value: SyncTransportMode.directOnly,
                      child: Text('直接通信のみ (母艦API)'),
                    ),
                    DropdownMenuItem(
                      value: SyncTransportMode.auto,
                      child: Text('自動切替 (LAN優先/Gmailフォールバック)'),
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
                  subtitle: const Text('GPS位置ベースの自動検出と記憶された場所の管理'),
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
                        MaterialPageRoute(builder: (_) => const CompanyInfoScreen()),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
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
                        MaterialPageRoute(builder: (_) => const CustomerMasterScreen()),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
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
                        MaterialPageRoute(builder: (_) => const ProductMasterScreen()),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
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
                  title: const Text('M1:マスター管理'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MasterHubPage()),
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

                setState(() => _restoring = true);
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
                  setState(() => _restoring = false);
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
