import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../services/app_settings_repository.dart';
import '../services/theme_controller.dart';
import 'company_info_screen.dart';
import 'email_settings_screen.dart';
import 'business_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// シンプルなアイコンマップ（拡張可）
const Map<String, IconData> kIconsMap = {
  'list_alt': Icons.list_alt,
  'edit_note': Icons.edit_note,
  'history': Icons.history,
  'settings': Icons.settings,
  'invoice': Icons.receipt_long,
  'dashboard': Icons.dashboard,
  'home': Icons.home,
  'info': Icons.info,
  'mail': Icons.mail,
  'shopping_cart': Icons.shopping_cart,
};

class _SettingsScreenState extends State<SettingsScreen> {
  final _appSettingsRepo = AppSettingsRepository();

  // External sync (母艦システム「お局様」連携)
  final _externalHostCtrl = TextEditingController();
  final _externalPassCtrl = TextEditingController();

  // Backup
  final _backupPathCtrl = TextEditingController();

  String _theme = 'system';

  // Kana map (kanji -> kana head)
  Map<String, String> _customKanaMap = {};
  final _kanaKeyCtrl = TextEditingController();
  final _kanaValCtrl = TextEditingController();

  // Dashboard / Home
  bool _homeDashboard = false;
  bool _statusEnabled = true;
  final _statusTextCtrl = TextEditingController(text: '工事中');
  List<DashboardMenuItem> _menuItems = [];
  bool _loadingAppSettings = true;

  static const _kExternalHost = 'external_host';
  static const _kExternalPass = 'external_pass';

  static const _kBackupPath = 'backup_path';

  @override
  void dispose() {
    _externalHostCtrl.dispose();
    _externalPassCtrl.dispose();
    _backupPathCtrl.dispose();
    _kanaKeyCtrl.dispose();
    _kanaValCtrl.dispose();
    _statusTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadKanaMap();
    final externalHost = await _appSettingsRepo.getString(_kExternalHost) ?? '';
    final externalPass = await _appSettingsRepo.getString(_kExternalPass) ?? '';

    final backupPath = await _appSettingsRepo.getString(_kBackupPath) ?? '';
    final theme = await _appSettingsRepo.getTheme();

    setState(() {
      _externalHostCtrl.text = externalHost;
      _externalPassCtrl.text = externalPass;

      _backupPathCtrl.text = backupPath;
      _theme = theme;
    });

    final homeMode = await _appSettingsRepo.getHomeMode();
    final statusEnabled = await _appSettingsRepo.getDashboardStatusEnabled();
    final statusText = await _appSettingsRepo.getDashboardStatusText();
    final menu = await _appSettingsRepo.getDashboardMenu();
    setState(() {
      _homeDashboard = homeMode == 'dashboard';
      _statusEnabled = statusEnabled;
      _statusTextCtrl.text = statusText;
      _menuItems = menu;
      _loadingAppSettings = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveAppSettings() async {
    await _appSettingsRepo.setHomeMode(_homeDashboard ? 'dashboard' : 'invoice_history');
    await _appSettingsRepo.setDashboardStatusEnabled(_statusEnabled);
    await _appSettingsRepo.setDashboardStatusText(_statusTextCtrl.text.trim().isEmpty ? '工事中' : _statusTextCtrl.text.trim());
    await _appSettingsRepo.setDashboardMenu(_menuItems);
    _showSnackbar('ホーム/ダッシュボード設定を保存しました');
  }

  Future<void> _persistMenu() async {
    await _appSettingsRepo.setDashboardMenu(_menuItems);
  }

  void _addMenuItem() async {
    final titleCtrl = TextEditingController();
    String route = 'invoice_history';
    final iconCtrl = TextEditingController(text: 'list_alt');
    String? customIconPath;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メニューを追加'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'タイトル')),
              DropdownButtonFormField<String>(
                initialValue: route,
                decoration: const InputDecoration(labelText: '遷移先'),
                items: const [
                  DropdownMenuItem(value: 'invoice_history', child: Text('A2:伝票一覧')),
                  DropdownMenuItem(value: 'invoice_input', child: Text('A1:伝票入力')),
                  DropdownMenuItem(value: 'customer_master', child: Text('C1:顧客マスター')),
                  DropdownMenuItem(value: 'product_master', child: Text('P1:商品マスター')),
                  DropdownMenuItem(value: 'master_hub', child: Text('M1:マスター管理')),
                  DropdownMenuItem(value: 'settings', child: Text('S1:設定')),
                ],
                onChanged: (v) => route = v ?? 'invoice_history',
              ),
              TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Materialアイコン名 (例: list_alt)')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(customIconPath ?? 'カスタムアイコン: 未選択', style: const TextStyle(fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.image_search),
                    tooltip: 'ギャラリーから選択',
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setState(() {
                          customIconPath = picked.path;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              setState(() {
                _menuItems = [
                  ..._menuItems,
                  DashboardMenuItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text.trim(),
                    route: route,
                    iconName: iconCtrl.text.trim().isEmpty ? 'list_alt' : iconCtrl.text.trim(),
                    customIconPath: customIconPath,
                  ),
                ];
              });
              _persistMenu();
              Navigator.pop(ctx);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _removeMenuItem(String id) {
    setState(() {
      _menuItems = _menuItems.where((e) => e.id != id).toList();
    });
    _persistMenu();
  }

  void _reorderMenu(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _menuItems.removeAt(oldIndex);
      _menuItems.insert(newIndex, item);
    });
    _persistMenu();
  }

  String _routeLabel(String route) {
    switch (route) {
      case 'invoice_history':
        return 'A2:伝票一覧';
      case 'invoice_input':
        return 'A1:伝票入力';
      case 'customer_master':
        return 'C1:顧客マスター';
      case 'product_master':
        return 'P1:商品マスター';
      case 'master_hub':
        return 'M1:マスター管理';
      case 'settings':
        return 'S1:設定';
      default:
        return route;
    }
  }

  IconData _iconForName(String name) {
    return kIconsMap[name] ?? Icons.apps;
  }

  Widget _menuLeading(DashboardMenuItem item) {
    if (item.customIconPath != null && File(item.customIconPath!).existsSync()) {
      return CircleAvatar(backgroundImage: FileImage(File(item.customIconPath!)));
    }
    return Icon(item.iconName != null ? _iconForName(item.iconName!) : Icons.apps);
  }

  Future<void> _saveExternalSync() async {
    await _appSettingsRepo.setString(_kExternalHost, _externalHostCtrl.text);
    await _appSettingsRepo.setString(_kExternalPass, _externalPassCtrl.text);
    _showSnackbar('外部同期設定を保存しました');
  }

  Future<void> _saveBackup() async {
    await _appSettingsRepo.setString(_kBackupPath, _backupPathCtrl.text);
    _showSnackbar('バックアップ設定を保存しました');
  }

  void _pickBackupPath() => _showSnackbar('バックアップ先の選択は後で実装');

  Future<void> _loadKanaMap() async {
    final json = await _appSettingsRepo.getString('customKanaMap');
    if (json != null && json.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(json);
        setState(() => _customKanaMap = decoded.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _saveKanaMap() async {
    await _appSettingsRepo.setString('customKanaMap', jsonEncode(_customKanaMap));
    _showSnackbar('かなインデックスを保存しました');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final listBottomPadding = 24 + bottomInset;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('S1:設定'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSnackbar('設定はテンプレ実装です。実際の保存は未実装'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: listBottomPadding),
          children: [
            _section(
              title: 'ホームモード / ダッシュボード',
              subtitle: 'ダッシュボードをホームにする・ステータス表示・メニュー管理 (設定はDB保存)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('ホームをダッシュボードにする'),
                    value: _homeDashboard,
                    onChanged: _loadingAppSettings ? null : (v) => setState(() => _homeDashboard = v),
                  ),
                  SwitchListTile(
                    title: const Text('ステータスを表示する'),
                    value: _statusEnabled,
                    onChanged: _loadingAppSettings ? null : (v) => setState(() => _statusEnabled = v),
                  ),
                  TextField(
                    controller: _statusTextCtrl,
                    enabled: !_loadingAppSettings && _statusEnabled,
                    decoration: const InputDecoration(labelText: 'ステータス文言', hintText: '例: 工事中'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('メニューを追加'),
                        onPressed: _loadingAppSettings ? null : _addMenuItem,
                      ),
                      const SizedBox(width: 12),
                      Text('ドラッグで並べ替え / ゴミ箱で削除', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _loadingAppSettings
                      ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _menuItems.length,
                          onReorder: _reorderMenu,
                          itemBuilder: (ctx, index) {
                            final item = _menuItems[index];
                            return ListTile(
                              key: ValueKey(item.id),
                              leading: _menuLeading(item),
                              title: Text(item.title),
                              subtitle: Text(_routeLabel(item.route)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                onPressed: () => _removeMenuItem(item.id),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('ホーム設定を保存'),
                      onPressed: _loadingAppSettings ? null : _saveAppSettings,
                    ),
                  ),
                ],
              ),
            ),
            _section(
              title: '自社情報',
              subtitle: '会社・担当者・振込口座・電話帳取り込み',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('自社/担当者情報、振込口座設定、メールフッタをまとめて編集できます。'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.info_outline),
                        label: const Text('旧画面 (税率/印影)'),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyInfoScreen()));
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.business),
                          label: const Text('自社情報ページを開く'),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => const BusinessProfileScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              title: 'メール設定（SM画面へ）',
              subtitle: 'SMTP・端末メーラー・BCC必須・ログ閲覧など',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('メール送信に関する設定は専用画面でまとめて編集できます。'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('メール設定を開く'),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EmailSettingsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            _section(
              title: '外部同期（母艦システム「お局様」連携）',
              subtitle: '実行ボタンなし。ホストドメインとパスワードを入力してください。',
              child: Column(
                children: [
                  TextField(controller: _externalHostCtrl, decoration: const InputDecoration(labelText: 'ホストドメイン')),
                  TextField(controller: _externalPassCtrl, decoration: const InputDecoration(labelText: 'パスワード'), obscureText: true),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                    onPressed: _saveExternalSync,
                  ),
                ],
              ),
            ),
            _section(
              title: 'バックアップドライブ',
              subtitle: 'バックアップ先のクラウド/ローカル',
              child: Column(
                children: [
                  TextField(controller: _backupPathCtrl, decoration: const InputDecoration(labelText: '保存先パス/URL')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('参照'),
                        onPressed: _pickBackupPath,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('保存'),
                        onPressed: _saveBackup,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              title: 'テーマ選択',
              subtitle: '配色や見た目を切り替え（テンプレ）',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _theme,
                    decoration: const InputDecoration(labelText: 'テーマを選択'),
                    items: const [
                      DropdownMenuItem(value: 'light', child: Text('ライト')),
                      DropdownMenuItem(value: 'dark', child: Text('ダーク')),
                      DropdownMenuItem(value: 'system', child: Text('システムに従う')),
                    ],
                    onChanged: (v) => setState(() => _theme = v ?? 'system'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                    onPressed: () async {
                      await _appSettingsRepo.setTheme(_theme);
                      await AppThemeController.instance.setTheme(_theme);
                      if (!mounted) return;
                      _showSnackbar('テーマ設定を保存しました');
                    },
                  ),
                ],
              ),
            ),
            _section(
              title: 'かなインデックス追加',
              subtitle: '漢字→行（1文字ずつ）を追加して索引を補強',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kanaKeyCtrl,
                          maxLength: 1,
                          decoration: const InputDecoration(labelText: '漢字1文字', counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _kanaValCtrl,
                          maxLength: 1,
                          decoration: const InputDecoration(labelText: '行(例: さ)', counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final k = _kanaKeyCtrl.text.trim();
                          final v = _kanaValCtrl.text.trim();
                          if (k.isEmpty || v.isEmpty) return;
                          setState(() {
                            _customKanaMap[k] = v;
                          });
                        },
                        child: const Text('追加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _customKanaMap.entries
                        .map((e) => Chip(
                              label: Text('${e.key}: ${e.value}'),
                              onDeleted: () => setState(() => _customKanaMap.remove(e.key)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                    onPressed: _saveKanaMap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required String subtitle, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
