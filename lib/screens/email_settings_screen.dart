import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/mail_send_method.dart';
import '../constants/mail_templates.dart';
import '../services/app_settings_repository.dart';
import '../services/email_sender.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final _appSettingsRepo = AppSettingsRepository();

  final _smtpHostCtrl = TextEditingController();
  final _smtpPortCtrl = TextEditingController(text: '587');
  final _smtpUserCtrl = TextEditingController();
  final _smtpPassCtrl = TextEditingController();
  final _smtpBccCtrl = TextEditingController();
  final _mailHeaderCtrl = TextEditingController();
  final _mailFooterCtrl = TextEditingController();

  bool _smtpTls = true;
  bool _smtpIgnoreBadCert = false;
  bool _loadingLogs = false;
  String _mailSendMethod = kMailSendMethodSmtp;
  List<String> _smtpLogs = [];
  String _mailHeaderTemplateId = kMailTemplateIdDefault;
  String _mailFooterTemplateId = kMailTemplateIdDefault;

  static const _kSmtpHost = 'smtp_host';
  static const _kSmtpPort = 'smtp_port';
  static const _kSmtpUser = 'smtp_user';
  static const _kSmtpPass = 'smtp_pass';
  static const _kSmtpTls = 'smtp_tls';
  static const _kSmtpBcc = 'smtp_bcc';
  static const _kSmtpIgnoreBadCert = 'smtp_ignore_bad_cert';
  static const _kMailSendMethod = kMailSendMethodPrefKey;
  static const _kMailHeaderTemplate = kMailHeaderTemplateKey;
  static const _kMailFooterTemplate = kMailFooterTemplateKey;
  static const _kMailHeaderText = kMailHeaderTextKey;
  static const _kMailFooterText = kMailFooterTextKey;
  static const _kCryptKey = 'test';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPassCtrl.dispose();
    _smtpBccCtrl.dispose();
    _mailHeaderCtrl.dispose();
    _mailFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final hostPref = prefs.getString(_kSmtpHost);
    final smtpHost = hostPref ?? await _appSettingsRepo.getString(_kSmtpHost) ?? '';
    final portPref = prefs.getString(_kSmtpPort);
    final smtpPort = (portPref ?? await _appSettingsRepo.getString(_kSmtpPort) ?? '587').trim().isEmpty
        ? '587'
        : (portPref ?? await _appSettingsRepo.getString(_kSmtpPort) ?? '587');
    final userPref = prefs.getString(_kSmtpUser);
    final smtpUser = userPref ?? await _appSettingsRepo.getString(_kSmtpUser) ?? '';
    final passPref = prefs.getString(_kSmtpPass);
    final smtpPassEncrypted = passPref ?? await _appSettingsRepo.getString(_kSmtpPass) ?? '';
    final smtpPass = _decryptWithFallback(smtpPassEncrypted);
    final tlsPrefExists = prefs.containsKey(_kSmtpTls);
    final smtpTls = tlsPrefExists ? (prefs.getBool(_kSmtpTls) ?? true) : await _appSettingsRepo.getBool(_kSmtpTls, defaultValue: true);
    final bccPref = prefs.getString(_kSmtpBcc);
    final smtpBcc = bccPref ?? await _appSettingsRepo.getString(_kSmtpBcc) ?? '';
    final ignorePrefExists = prefs.containsKey(_kSmtpIgnoreBadCert);
    final smtpIgnoreBadCert = ignorePrefExists
        ? (prefs.getBool(_kSmtpIgnoreBadCert) ?? false)
        : await _appSettingsRepo.getBool(_kSmtpIgnoreBadCert, defaultValue: false);

    final mailSendMethodPref = prefs.getString(_kMailSendMethod);
    final mailSendMethodDb = await _appSettingsRepo.getString(_kMailSendMethod) ?? kMailSendMethodSmtp;
    final resolvedMailSendMethod = normalizeMailSendMethod(mailSendMethodPref ?? mailSendMethodDb);

    final headerTemplatePref = prefs.getString(_kMailHeaderTemplate);
    final headerTemplateDb = await _appSettingsRepo.getString(_kMailHeaderTemplate) ?? kMailTemplateIdDefault;
    final resolvedHeaderTemplate = headerTemplatePref ?? headerTemplateDb;
    final headerTextPref = prefs.getString(_kMailHeaderText);
    final headerTextDb = await _appSettingsRepo.getString(_kMailHeaderText) ?? kMailHeaderTemplateDefault;
    final resolvedHeaderText = headerTextPref ?? headerTextDb;

    final footerTemplatePref = prefs.getString(_kMailFooterTemplate);
    final footerTemplateDb = await _appSettingsRepo.getString(_kMailFooterTemplate) ?? kMailTemplateIdDefault;
    final resolvedFooterTemplate = footerTemplatePref ?? footerTemplateDb;
    final footerTextPref = prefs.getString(_kMailFooterText);
    final footerTextDb = await _appSettingsRepo.getString(_kMailFooterText) ?? kMailFooterTemplateDefault;
    final resolvedFooterText = footerTextPref ?? footerTextDb;

    final needsPrefSync =
        hostPref == null ||
            portPref == null ||
            userPref == null ||
            passPref == null ||
            bccPref == null ||
            !tlsPrefExists ||
            !ignorePrefExists ||
            mailSendMethodPref == null ||
            headerTemplatePref == null ||
            headerTextPref == null ||
            footerTemplatePref == null ||
            footerTextPref == null;
    if (needsPrefSync) {
      await _saveSmtpPrefs(
        host: smtpHost,
        port: smtpPort,
        user: smtpUser,
        encryptedPass: smtpPassEncrypted,
        tls: smtpTls,
        bcc: smtpBcc,
        ignoreBadCert: smtpIgnoreBadCert,
        mailSendMethod: resolvedMailSendMethod,
        headerTemplate: resolvedHeaderTemplate,
        headerText: resolvedHeaderText,
        footerTemplate: resolvedFooterTemplate,
        footerText: resolvedFooterText,
      );
    }

    setState(() {
      _smtpHostCtrl.text = smtpHost;
      _smtpPortCtrl.text = smtpPort;
      _smtpUserCtrl.text = smtpUser;
      _smtpPassCtrl.text = smtpPass;
      _smtpBccCtrl.text = smtpBcc;
      _smtpTls = smtpTls;
      _smtpIgnoreBadCert = smtpIgnoreBadCert;
      _mailSendMethod = resolvedMailSendMethod;
      _mailHeaderTemplateId = resolvedHeaderTemplate;
      _mailFooterTemplateId = resolvedFooterTemplate;
      _mailHeaderCtrl.text = resolvedHeaderText;
      _mailFooterCtrl.text = resolvedFooterText;
    });

    await _loadSmtpLogs();
  }

  Future<void> _loadSmtpLogs() async {
    setState(() => _loadingLogs = true);
    final logs = await EmailSender.loadLogs();
    if (!mounted) return;
    setState(() {
      _smtpLogs = logs;
      _loadingLogs = false;
    });
  }

  Future<void> _clearSmtpLogs() async {
    await EmailSender.clearLogs();
    await _loadSmtpLogs();
  }

  Future<void> _copySmtpLogs() async {
    if (_smtpLogs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _smtpLogs.join('\n')));
    _showSnackbar('ログをクリップボードにコピーしました');
  }

  Future<void> _saveSmtp() async {
    final host = _smtpHostCtrl.text.trim();
    final port = _smtpPortCtrl.text.trim().isEmpty ? '587' : _smtpPortCtrl.text.trim();
    final user = _smtpUserCtrl.text.trim();
    final passPlain = _smtpPassCtrl.text;
    final passEncrypted = _encrypt(passPlain);
    final bcc = _smtpBccCtrl.text.trim();

    if (bcc.isEmpty) {
      _showSnackbar('BCCは必須項目です');
      return;
    }

    await _appSettingsRepo.setString(_kSmtpHost, host);
    await _appSettingsRepo.setString(_kSmtpPort, port);
    await _appSettingsRepo.setString(_kSmtpUser, user);
    await _appSettingsRepo.setString(_kSmtpPass, passEncrypted);
    await _appSettingsRepo.setBool(_kSmtpTls, _smtpTls);
    await _appSettingsRepo.setString(_kSmtpBcc, bcc);
    await _appSettingsRepo.setBool(_kSmtpIgnoreBadCert, _smtpIgnoreBadCert);
    await _appSettingsRepo.setString(_kMailSendMethod, _mailSendMethod);
    await _appSettingsRepo.setString(_kMailHeaderTemplate, _mailHeaderTemplateId);
    await _appSettingsRepo.setString(_kMailFooterTemplate, _mailFooterTemplateId);
    await _appSettingsRepo.setString(_kMailHeaderText, _mailHeaderCtrl.text);
    await _appSettingsRepo.setString(_kMailFooterText, _mailFooterCtrl.text);

    await _saveSmtpPrefs(
      host: host,
      port: port,
      user: user,
      encryptedPass: passEncrypted,
      tls: _smtpTls,
      bcc: bcc,
      ignoreBadCert: _smtpIgnoreBadCert,
      mailSendMethod: _mailSendMethod,
      headerTemplate: _mailHeaderTemplateId,
      headerText: _mailHeaderCtrl.text,
      footerTemplate: _mailFooterTemplateId,
      footerText: _mailFooterCtrl.text,
    );
    _showSnackbar('メール設定を保存しました');
  }

  Future<void> _saveSmtpPrefs({
    required String host,
    required String port,
    required String user,
    required String encryptedPass,
    required bool tls,
    required String bcc,
    required bool ignoreBadCert,
    required String mailSendMethod,
    required String headerTemplate,
    required String headerText,
    required String footerTemplate,
    required String footerText,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSmtpHost, host);
    await prefs.setString(_kSmtpPort, port);
    await prefs.setString(_kSmtpUser, user);
    await prefs.setString(_kSmtpPass, encryptedPass);
    await prefs.setBool(_kSmtpTls, tls);
    await prefs.setString(_kSmtpBcc, bcc);
    await prefs.setBool(_kSmtpIgnoreBadCert, ignoreBadCert);
    await prefs.setString(_kMailSendMethod, mailSendMethod);
    await prefs.setString(_kMailHeaderTemplate, headerTemplate);
    await prefs.setString(_kMailHeaderText, headerText);
    await prefs.setString(_kMailFooterTemplate, footerTemplate);
    await prefs.setString(_kMailFooterText, footerText);
  }

  Future<void> _testSmtp() async {
    try {
      if (_mailSendMethod != kMailSendMethodSmtp) {
        _showSnackbar('SMTPテストは送信方法を「SMTP」に設定した時のみ利用できます');
        return;
      }
      await _saveSmtp();
      final config = await EmailSender.loadConfigFromPrefs();
      if (config == null || config.bcc.isEmpty) {
        _showSnackbar('ホスト/ユーザー/パスワード/BCCを入力してください');
        return;
      }

      await EmailSender.sendTest(config: config);
      _showSnackbar('テスト送信に成功しました');
    } catch (e) {
      _showSnackbar('テスト送信に失敗しました: $e');
    }
    await _loadSmtpLogs();
  }

  Future<void> _updateMailSendMethod(String method) async {
    final normalized = normalizeMailSendMethod(method);
    setState(() => _mailSendMethod = normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMailSendMethod, normalized);
    await _appSettingsRepo.setString(_kMailSendMethod, normalized);
  }

  void _applyHeaderTemplate(String templateId) {
    setState(() => _mailHeaderTemplateId = templateId);
    if (templateId == kMailTemplateIdDefault) {
      _mailHeaderCtrl.text = kMailHeaderTemplateDefault;
    } else if (templateId == kMailTemplateIdNone) {
      _mailHeaderCtrl.clear();
    }
  }

  void _applyFooterTemplate(String templateId) {
    setState(() => _mailFooterTemplateId = templateId);
    if (templateId == kMailTemplateIdDefault) {
      _mailFooterCtrl.text = kMailFooterTemplateDefault;
    } else if (templateId == kMailTemplateIdNone) {
      _mailFooterCtrl.clear();
    }
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
      return cipher;
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final listBottomPadding = 24 + bottomInset;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SM:メール設定'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: listBottomPadding),
          children: [
            _section(
              title: '送信設定',
              subtitle: 'SMTP / 端末メーラー切り替えやBCC必須設定',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: '送信方法'),
                    initialValue: _mailSendMethod,
                    items: const [
                      DropdownMenuItem(value: kMailSendMethodSmtp, child: Text('SMTPサーバー経由')),
                      DropdownMenuItem(value: kMailSendMethodDeviceMailer, child: Text('端末メーラーで送信')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _updateMailSendMethod(value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_mailSendMethod == kMailSendMethodDeviceMailer)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '端末メーラーで送信する場合もBCCは必須です。SMTP設定は保持されますが、送信時は端末のメールアプリが起動します。',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _smtpHostCtrl,
                    decoration: const InputDecoration(labelText: 'SMTPホスト名'),
                    enabled: _mailSendMethod == kMailSendMethodSmtp,
                  ),
                  TextField(
                    controller: _smtpPortCtrl,
                    decoration: const InputDecoration(labelText: 'SMTPポート番号'),
                    keyboardType: TextInputType.number,
                    enabled: _mailSendMethod == kMailSendMethodSmtp,
                  ),
                  TextField(
                    controller: _smtpUserCtrl,
                    decoration: const InputDecoration(labelText: 'SMTPユーザー名'),
                    enabled: _mailSendMethod == kMailSendMethodSmtp,
                  ),
                  TextField(
                    controller: _smtpPassCtrl,
                    decoration: const InputDecoration(labelText: 'SMTPパスワード'),
                    obscureText: true,
                    enabled: _mailSendMethod == kMailSendMethodSmtp,
                  ),
                  TextField(
                    controller: _smtpBccCtrl,
                    decoration: const InputDecoration(labelText: 'BCC (カンマ区切り可) *必須'),
                  ),
                  SwitchListTile(
                    title: const Text('STARTTLS を使用'),
                    value: _smtpTls,
                    onChanged: _mailSendMethod == kMailSendMethodSmtp ? (v) => setState(() => _smtpTls = v) : null,
                  ),
                  SwitchListTile(
                    title: const Text('証明書検証をスキップ（開発用）'),
                    subtitle: const Text('自己署名/ホスト名不一致を許可します'),
                    value: _smtpIgnoreBadCert,
                    onChanged: _mailSendMethod == kMailSendMethodSmtp ? (v) => setState(() => _smtpIgnoreBadCert = v) : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                          onPressed: _saveSmtp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('BCC宛にテスト送信'),
                          onPressed: _mailSendMethod == kMailSendMethodSmtp ? _testSmtp : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              title: '通信ログ',
              subtitle: '最大1000行まで保持されます（SMTP/端末メーラー共通）',
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('ログ一覧', style: TextStyle(fontWeight: FontWeight.bold))),
                      IconButton(
                        tooltip: '再読込',
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadingLogs ? null : _loadSmtpLogs,
                      ),
                      IconButton(
                        tooltip: 'コピー',
                        icon: const Icon(Icons.copy),
                        onPressed: _smtpLogs.isEmpty ? null : _copySmtpLogs,
                      ),
                      IconButton(
                        tooltip: 'クリア',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _smtpLogs.isEmpty ? null : _clearSmtpLogs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _loadingLogs
                        ? const Center(child: CircularProgressIndicator())
                        : _smtpLogs.isEmpty
                            ? const Center(child: Text('ログなし'))
                            : Scrollbar(
                                child: SelectionArea(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _smtpLogs.length,
                                    itemBuilder: (context, index) => Text(
                                      _smtpLogs[index],
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
            _section(
              title: 'メール本文ヘッダ/フッタ',
              subtitle: 'テンプレを選択して編集するか、自由にテキストを入力できます（{{FILENAME}}, {{HASH}} が利用可）',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ヘッダテンプレ', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _mailHeaderTemplateId,
                          items: const [
                            DropdownMenuItem(value: kMailTemplateIdDefault, child: Text('デフォルト')), 
                            DropdownMenuItem(value: kMailTemplateIdNone, child: Text('なし / 空テンプレ')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _applyHeaderTemplate(v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _applyHeaderTemplate(_mailHeaderTemplateId),
                        child: const Text('テンプレ適用'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mailHeaderCtrl,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'メールヘッダ文…'),
                  ),
                  const SizedBox(height: 16),
                  Text('フッタテンプレ', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _mailFooterTemplateId,
                          items: const [
                            DropdownMenuItem(value: kMailTemplateIdDefault, child: Text('デフォルト')),
                            DropdownMenuItem(value: kMailTemplateIdNone, child: Text('なし / 空テンプレ')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _applyFooterTemplate(v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _applyFooterTemplate(_mailFooterTemplateId),
                        child: const Text('テンプレ適用'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mailFooterCtrl,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'メールフッタ文…'),
                  ),
                  const SizedBox(height: 8),
                  const Text('※ {{FILENAME}} と {{HASH}} は送信時に自動置換されます。'),
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
