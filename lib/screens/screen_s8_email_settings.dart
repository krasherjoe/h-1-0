// ignore_for_file: dangling_library_doc_comments
import 'package:flutter/material.dart';

import '../services/app_settings_repository.dart';
import '../services/device_account_service.dart';
import '../constants/mail_templates.dart';

class ScreenS8EmailSettings extends StatefulWidget {
  const ScreenS8EmailSettings({super.key});

  @override
  State<ScreenS8EmailSettings> createState() => _ScreenS8EmailSettingsState();
}

class _ScreenS8EmailSettingsState extends State<ScreenS8EmailSettings> {
  final _appSettingsRepo = AppSettingsRepository();

  final _smtpBccCtrl = TextEditingController();
  final _mailHeaderCtrl = TextEditingController();
  final _mailFooterCtrl = TextEditingController();

  bool _selectingBccFromDevice = false;
  String _mailHeaderTemplateId = kMailTemplateIdDefault;
  String _mailFooterTemplateId = kMailTemplateIdDefault;
  String? _selectedDeviceBcc;

  static const _kSmtpBcc = 'smtp_bcc';
  static const _kMailHeaderTemplate = kMailHeaderTemplateKey;
  static const _kMailFooterTemplate = kMailFooterTemplateKey;
  static const _kMailHeaderText = kMailHeaderTextKey;
  static const _kMailFooterText = kMailFooterTextKey;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _smtpBccCtrl.dispose();
    _mailHeaderCtrl.dispose();
    _mailFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    // BCC 設定の読み込み（AppSettingsRepository を使用）
    final smtpBcc = await _appSettingsRepo.getString(_kSmtpBcc) ?? '';
    setState(() {
      _smtpBccCtrl.text = smtpBcc;
    });

    // メールテンプレートの読み込み（AppSettingsRepository を使用）
    final headerTemplateId =
        await _appSettingsRepo.getString(_kMailHeaderTemplate) ??
        kMailTemplateIdDefault;
    final footerTemplateId =
        await _appSettingsRepo.getString(_kMailFooterTemplate) ??
        kMailTemplateIdDefault;

    setState(() {
      _mailHeaderTemplateId = headerTemplateId;
      _mailFooterTemplateId = footerTemplateId;
    });

    // メールヘッダー/フッター本文の読み込み（AppSettingsRepository を使用）
    final headerText = await _appSettingsRepo.getString(_kMailHeaderText) ?? '';
    final footerText = await _appSettingsRepo.getString(_kMailFooterText) ?? '';

    setState(() {
      _mailHeaderCtrl.text = headerText;
      _mailFooterCtrl.text = footerText;
    });
  }

  Future<void> _saveAll() async {
    final bcc = _smtpBccCtrl.text.trim();

    await _appSettingsRepo.setString(_kSmtpBcc, bcc);
    await _appSettingsRepo.setString(
      _kMailHeaderTemplate,
      _mailHeaderTemplateId,
    );
    await _appSettingsRepo.setString(
      _kMailFooterTemplate,
      _mailFooterTemplateId,
    );
    await _appSettingsRepo.setString(_kMailHeaderText, _mailHeaderCtrl.text);
    await _appSettingsRepo.setString(_kMailFooterText, _mailFooterCtrl.text);

    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定を保存しました')));
      Navigator.pop(context);
    }
  }

  Future<void> _pickBccFromDeviceAccount() async {
    setState(() {
      _selectingBccFromDevice = true;
    });

    try {
      // 端末のメールアカウントから BCC 用メールアドレスを選択
      final result = await _showDeviceAccountPicker();
      if (result != null && mounted) {
        setState(() {
          _selectedDeviceBcc = result;
          _smtpBccCtrl.text = result;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingBccFromDevice = false;
        });
      }
    }
  }

  Future<String?> _showDeviceAccountPicker() async {
    return DeviceAccountService.pickGoogleAccount();
  }

  void _showBccHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BCC 設定ガイド'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BCC（Blind Carbon Copy）は、送信控えを自分宛てに自動で保存するための機能です。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '【なぜ必要？】',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '• 取引先にメールを送信した際、自分宛てにもコピーが送られる\n'
                '• 後から「いつ誰に何を送ったか」を確認できる\n'
                '• 紛争時の証拠として残せる',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '【設定方法】',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '• 自分のメールアドレスを入力\n'
                '• 複数のアドレスをカンマ区切りで入力可能\n'
                '• 例：me@gmail.com,backup@company.com',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showMailTemplateHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メールテンプレート設定'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '請求書を送信する際に、自動的に本文に追加されるテキストを設定します。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '【ヘッダー】',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'メールの件名・本文の冒頭に表示されます。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              TextField(
                controller: _mailHeaderCtrl,
                decoration: const InputDecoration(
                  labelText: 'ヘッダーテキスト',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                '【フッター】',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text('メールの末尾に表示されます。', style: TextStyle(fontSize: 13)),
              ),
              TextField(
                controller: _mailFooterCtrl,
                decoration: const InputDecoration(
                  labelText: 'フッターテキスト',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('S8: メール設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAll,
            tooltip: '保存',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BCC 設定セクション
            _buildSectionHeader('BCC 設定（必須）'),
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'メール送信時の控え用メールアドレス',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            TextField(
              controller: _smtpBccCtrl,
              decoration: InputDecoration(
                labelText: 'BCC *必須',
                hintText: '未設定',
                helperText: '自分のメールアドレスを入力。カンマ区切りで複数指定可能',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  onPressed: _showBccHelpDialog,
                  tooltip: 'BCC 設定ガイドを表示',
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 18.0,
                ),
              ),
              textAlignVertical: TextAlignVertical.center,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectingBccFromDevice
                        ? null
                        : _pickBccFromDeviceAccount,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(
                      _selectingBccFromDevice ? '取得中...' : '📧 端末のメールアカウントから選択',
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedDeviceBcc != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '選択済み：$_selectedDeviceBcc',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
                ),
              ),
            const Divider(height: 32),

            // メールテンプレート設定セクション
            _buildSectionHeader('メールテンプレート設定'),
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '請求書送信時に自動で追加される本文',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showMailTemplateHelpDialog,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('ヘルプ・設定ガイド'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              'ヘッダー（冒頭）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _mailHeaderCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 4,
            ),

            const SizedBox(height: 16),
            const Text(
              'フッター（末尾）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _mailFooterCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 4,
            ),

            const SizedBox(height: 32),

            // 注意事項
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📱 送信方法について',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '請求書詳細画面の「メールで共有」ボタンを押すと、\n'
                    'スマホ標準のメールアプリが起動し、PDF を添付した状態で\n'
                    'BCC に設定したメールアドレスにも自動で送信されます。',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
