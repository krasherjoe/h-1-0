import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'company_info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Company
  final _companyNameCtrl = TextEditingController();
  final _companyZipCtrl = TextEditingController();
  final _companyAddrCtrl = TextEditingController();
  final _companyTelCtrl = TextEditingController();
  final _companyRegCtrl = TextEditingController();
  final _companyFaxCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyUrlCtrl = TextEditingController();

  // Staff
  final _staffNameCtrl = TextEditingController();
  final _staffMailCtrl = TextEditingController();

  // SMTP
  final _smtpHostCtrl = TextEditingController();
  final _smtpPortCtrl = TextEditingController(text: '587');
  final _smtpUserCtrl = TextEditingController();
  final _smtpPassCtrl = TextEditingController();
  final _smtpBccCtrl = TextEditingController();
  bool _smtpTls = true;

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

  // SharedPreferences keys
  static const _kCompanyName = 'company_name';
  static const _kCompanyZip = 'company_zip';
  static const _kCompanyAddr = 'company_addr';
  static const _kCompanyTel = 'company_tel';
  static const _kCompanyReg = 'company_reg';
  static const _kCompanyFax = 'company_fax';
  static const _kCompanyEmail = 'company_email';
  static const _kCompanyUrl = 'company_url';

  static const _kStaffName = 'staff_name';
  static const _kStaffMail = 'staff_mail';

  static const _kSmtpHost = 'smtp_host';
  static const _kSmtpPort = 'smtp_port';
  static const _kSmtpUser = 'smtp_user';
  static const _kSmtpPass = 'smtp_pass';
  static const _kSmtpTls = 'smtp_tls';
  static const _kSmtpBcc = 'smtp_bcc';

  static const _kExternalHost = 'external_host';
  static const _kExternalPass = 'external_pass';

  static const _kCryptKey = 'test';

  static const _kBackupPath = 'backup_path';

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyZipCtrl.dispose();
    _companyAddrCtrl.dispose();
    _companyTelCtrl.dispose();
    _companyRegCtrl.dispose();
    _companyFaxCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyUrlCtrl.dispose();
    _staffNameCtrl.dispose();
    _staffMailCtrl.dispose();
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPassCtrl.dispose();
    _smtpBccCtrl.dispose();
    _externalHostCtrl.dispose();
    _externalPassCtrl.dispose();
    _backupPathCtrl.dispose();
    _kanaKeyCtrl.dispose();
    _kanaValCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadKanaMap();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyNameCtrl.text = prefs.getString(_kCompanyName) ?? '';
      _companyZipCtrl.text = prefs.getString(_kCompanyZip) ?? '';
      _companyAddrCtrl.text = prefs.getString(_kCompanyAddr) ?? '';
      _companyTelCtrl.text = prefs.getString(_kCompanyTel) ?? '';
      _companyRegCtrl.text = prefs.getString(_kCompanyReg) ?? '';
      _companyFaxCtrl.text = prefs.getString(_kCompanyFax) ?? '';
      _companyEmailCtrl.text = prefs.getString(_kCompanyEmail) ?? '';
      _companyUrlCtrl.text = prefs.getString(_kCompanyUrl) ?? '';

      _staffNameCtrl.text = prefs.getString(_kStaffName) ?? '';
      _staffMailCtrl.text = prefs.getString(_kStaffMail) ?? '';

      _smtpHostCtrl.text = prefs.getString(_kSmtpHost) ?? '';
      _smtpPortCtrl.text = prefs.getString(_kSmtpPort) ?? '587';
      _smtpUserCtrl.text = prefs.getString(_kSmtpUser) ?? '';
      _smtpPassCtrl.text = _decryptWithFallback(prefs.getString(_kSmtpPass) ?? '');
      _smtpTls = prefs.getBool(_kSmtpTls) ?? true;
      _smtpBccCtrl.text = prefs.getString(_kSmtpBcc) ?? '';

      _externalHostCtrl.text = prefs.getString(_kExternalHost) ?? '';
      _externalPassCtrl.text = prefs.getString(_kExternalPass) ?? '';

      _backupPathCtrl.text = prefs.getString(_kBackupPath) ?? '';
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

  Future<void> _saveCompany() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompanyName, _companyNameCtrl.text);
    await prefs.setString(_kCompanyZip, _companyZipCtrl.text);
    await prefs.setString(_kCompanyAddr, _companyAddrCtrl.text);
    await prefs.setString(_kCompanyTel, _companyTelCtrl.text);
    await prefs.setString(_kCompanyReg, _companyRegCtrl.text);
    await prefs.setString(_kCompanyFax, _companyFaxCtrl.text);
    await prefs.setString(_kCompanyEmail, _companyEmailCtrl.text);
    await prefs.setString(_kCompanyUrl, _companyUrlCtrl.text);
    _showSnackbar('自社情報を保存しました');
  }

  Future<void> _saveStaff() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStaffName, _staffNameCtrl.text);
    await prefs.setString(_kStaffMail, _staffMailCtrl.text);
    _showSnackbar('担当者情報を保存しました');
  }

  Future<void> _saveSmtp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSmtpHost, _smtpHostCtrl.text);
    await prefs.setString(_kSmtpPort, _smtpPortCtrl.text);
    await prefs.setString(_kSmtpUser, _smtpUserCtrl.text);
    await prefs.setString(_kSmtpPass, _encrypt(_smtpPassCtrl.text));
    await prefs.setBool(_kSmtpTls, _smtpTls);
    await prefs.setString(_kSmtpBcc, _smtpBccCtrl.text);
    _showSnackbar('SMTP設定を保存しました');
  }

  Future<void> _saveExternalSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExternalHost, _externalHostCtrl.text);
    await prefs.setString(_kExternalPass, _externalPassCtrl.text);
    _showSnackbar('外部同期設定を保存しました');
  }

  Future<void> _saveBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackupPath, _backupPathCtrl.text);
    _showSnackbar('バックアップ設定を保存しました');
  }

  void _pickBackupPath() => _showSnackbar('バックアップ先の選択は後で実装');

  Future<void> _loadKanaMap() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('customKanaMap');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customKanaMap', jsonEncode(_customKanaMap));
    _showSnackbar('かなインデックスを保存しました');
  }

  String _encrypt(String plain) {
    if (plain.isEmpty) return '';
    final pb = utf8.encode(plain);
    final kb = utf8.encode(_kCryptKey);
    final ob = List<int>.generate(pb.length, (i) => pb[i] ^ kb[i % kb.length]);
    return base64Encode(ob);
  }

  String _decryptWithFallback(String cipher) {
    if (cipher.isEmpty) return '';
    try {
      final ob = base64Decode(cipher);
      final kb = utf8.encode(_kCryptKey);
      final pb = List<int>.generate(ob.length, (i) => ob[i] ^ kb[i % kb.length]);
      return utf8.decode(pb);
    } catch (_) {
      return cipher; // 旧プレーンテキストも許容
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSnackbar('設定はテンプレ実装です。実際の保存は未実装'),
          )
        ],
      ),
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _section(
                title: '自社情報',
                subtitle: '会社名・住所・登録番号など',
                child: Column(
                  children: [
                    TextField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: '会社名')),
                    TextField(controller: _companyZipCtrl, decoration: const InputDecoration(labelText: '郵便番号')),
                    TextField(controller: _companyAddrCtrl, decoration: const InputDecoration(labelText: '住所')),
                    TextField(controller: _companyTelCtrl, decoration: const InputDecoration(labelText: '電話番号')),
                    TextField(controller: _companyFaxCtrl, decoration: const InputDecoration(labelText: 'FAX番号')),
                    TextField(controller: _companyEmailCtrl, decoration: const InputDecoration(labelText: 'メールアドレス')),
                    TextField(controller: _companyUrlCtrl, decoration: const InputDecoration(labelText: 'URL')),
                    TextField(controller: _companyRegCtrl, decoration: const InputDecoration(labelText: '登録番号 (インボイス)')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('画面で編集'),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyInfoScreen()));
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                          onPressed: _saveCompany,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _section(
                title: '担当者情報',
                subtitle: '署名や連絡先（送信者情報）',
                child: Column(
                  children: [
                    TextField(controller: _staffNameCtrl, decoration: const InputDecoration(labelText: '担当者名')),
                    TextField(controller: _staffMailCtrl, decoration: const InputDecoration(labelText: 'メールアドレス')),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('保存'),
                      onPressed: _saveStaff,
                    ),
                  ],
                ),
              ),
              _section(
                title: 'SMTP情報',
                subtitle: 'メール送信サーバ設定（テンプレ）',
                child: Column(
                  children: [
                    TextField(controller: _smtpHostCtrl, decoration: const InputDecoration(labelText: 'ホスト名')), 
                    TextField(controller: _smtpPortCtrl, decoration: const InputDecoration(labelText: 'ポート番号'), keyboardType: TextInputType.number),
                    TextField(controller: _smtpUserCtrl, decoration: const InputDecoration(labelText: 'ユーザー名')),
                    TextField(controller: _smtpPassCtrl, decoration: const InputDecoration(labelText: 'パスワード'), obscureText: true),
                    TextField(controller: _smtpBccCtrl, decoration: const InputDecoration(labelText: 'BCC (カンマ区切り可)')),
                    SwitchListTile(
                      title: const Text('STARTTLS を使用'),
                      value: _smtpTls,
                      onChanged: (v) => setState(() => _smtpTls = v),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('保存'),
                      onPressed: _saveSmtp,
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
                  children: [
                    RadioListTile<String>(
                      value: 'light',
                      groupValue: _theme,
                      title: const Text('ライト'),
                      onChanged: (v) => setState(() => _theme = v ?? 'light'),
                    ),
                    RadioListTile<String>(
                      value: 'dark',
                      groupValue: _theme,
                      title: const Text('ダーク'),
                      onChanged: (v) => setState(() => _theme = v ?? 'dark'),
                    ),
                    RadioListTile<String>(
                      value: 'system',
                      groupValue: _theme,
                      title: const Text('システムに従う'),
                      onChanged: (v) => setState(() => _theme = v ?? 'system'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('保存'),
                      onPressed: () => _showSnackbar('テーマ設定を保存（テンプレ）: $_theme'),
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
