import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/sync_preferences.dart';
import '../services/app_settings_repository.dart';
import '../services/google_account_service.dart';
import 'email_settings_screen.dart';
import 'master_hub_page.dart';
import 'company_info_screen.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import 'dashboard_menu_settings_screen.dart';
import 'mothership_discovery_settings_screen.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/drive_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AppSettingsRepository();
  final GoogleAccountService _googleAccountService = GoogleAccountService.instance;
  String _theme = 'system';
  String _summaryTheme = 'white';
  final TextEditingController _statusTextController = TextEditingController();
  bool _showCategoryDescriptions = true;
  GmailEnvelopeEncoding _encodingMode = GmailEnvelopeEncoding.gzipBase64;
  SyncTransportMode _transportMode = SyncTransportMode.gmailOnly;
  GoogleSignInAccount? _googleAccount;
  bool _linkingAccount = false;
  StreamSubscription<GoogleSignInAccount?>? _accountSubscription;
  bool _backingUp = false;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ バックアップ失敗: $e')),
        );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled ? '自動バックアップを有効化しました' : '自動バックアップを無効化しました')),
    );
  }

  String _formatBackupTime(String? isoTime) {
    if (isoTime == null) return '未実施';
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'たった今';
      if (diff.inHours < 1) return '${diff.inMinutes}分前';
      if (diff.inDays < 1) return '${diff.inHours}時間前';
      if (diff.inDays < 7) return '${diff.inDays}日前';
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
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
      final statusText = await _repo.getDashboardStatusText();
      setState(() => _statusTextController.text = statusText);
      final showCategoryDesc = await _repo.getDashboardShowCategoryDescriptions();
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
    _accountSubscription = _googleAccountService.accountStream.listen((account) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウント選択がキャンセルされました')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google連携に失敗しました: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('連携解除に失敗しました: $e')),
      );
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
      appBar: AppBar(
        title: const Text('S1:設定'),
      ),
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
              MaterialPageRoute(builder: (_) => const DashboardMenuSettingsScreen()),
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
                  children: [
                    const Icon(Icons.palette, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('テーマ設定', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(value: 'system', label: Text('システム'), icon: Icon(Icons.settings)),
                    ButtonSegment<String>(value: 'light', label: Text('ライト'), icon: Icon(Icons.light_mode)),
                    ButtonSegment<String>(value: 'dark', label: Text('ダーク'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {_theme},
                  onSelectionChanged: (s) async {
                    await _repo.setTheme(s.first);
                    setState(() => _theme = s.first);
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(value: 'white', label: Text('白'), icon: Icon(Icons.palette)),
                    ButtonSegment<String>(value: 'gray', label: Text('グレー'), icon: Icon(Icons.color_lens)),
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
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('ステータス設定', style: TextStyle(fontWeight: FontWeight.bold))),
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
                    const Expanded(child: Text('Googleアカウント連携', style: TextStyle(fontWeight: FontWeight.bold))),
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
                        onPressed: _linkingAccount ? null : _selectGoogleAccount,
                        icon: const Icon(Icons.account_circle),
                        label: Text(_googleAccount == null ? 'アカウントを選択' : '別アカウントに切替'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: (_googleAccount == null || _linkingAccount) ? null : _disconnectGoogleAccount,
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
                    const Expanded(child: Text('メール設定', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('SM:メール設定'),
                  subtitle: const Text('SMTP/BCC設定、Gmailアカウント選択'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailSettingsScreen())),
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
                    const Expanded(child: Text('データバックアップ', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '最終バックアップ: ${_formatBackupTime(_lastBackupTime)}',
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                  subtitle: const Text('毎日起動時に自動実行（24時間経過後）'),
                  value: _autoBackupEnabled,
                  onChanged: _setAutoBackup,
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
                    const Expanded(child: Text('同期設定', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GmailEnvelopeEncoding>(
                  value: _encodingMode,
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
                  value: _transportMode,
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
                    MaterialPageRoute(builder: (_) => const MothershipDiscoverySettingsScreen()),
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
                    const Expanded(child: Text('マスター管理', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('会社情報'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyInfoScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('顧客マスター'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerMasterScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('商品マスター'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductMasterScreen())),
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
                    const Expanded(child: Text('マスター管理（統合）', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('M1:マスター管理'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MasterHubPage())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}