import 'package:flutter/material.dart';
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

  // Staff
  final _staffNameCtrl = TextEditingController();
  final _staffMailCtrl = TextEditingController();

  // SMTP
  final _smtpHostCtrl = TextEditingController();
  final _smtpPortCtrl = TextEditingController(text: '587');
  final _smtpUserCtrl = TextEditingController();
  final _smtpPassCtrl = TextEditingController();
  bool _smtpTls = true;

  // Backup
  final _backupPathCtrl = TextEditingController();

  String _theme = 'system';

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyZipCtrl.dispose();
    _companyAddrCtrl.dispose();
    _companyTelCtrl.dispose();
    _companyRegCtrl.dispose();
    _staffNameCtrl.dispose();
    _staffMailCtrl.dispose();
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPassCtrl.dispose();
    _backupPathCtrl.dispose();
    super.dispose();
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _saveCompany() => _showSnackbar('自社情報を保存（テンプレ）');
  void _saveStaff() => _showSnackbar('担当者情報を保存（テンプレ）');
  void _saveSmtp() => _showSnackbar('SMTP設定を保存（テンプレ）');
  void _saveBackup() => _showSnackbar('バックアップ設定を保存（テンプレ）');

  void _pickBackupPath() => _showSnackbar('バックアップ先の選択は後で実装');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSnackbar('設定はテンプレ実装です。実際の保存は未実装'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
        ],
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
