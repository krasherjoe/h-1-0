import 'dart:convert';
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailSenderConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useTls;
  final bool ignoreBadCert;
  final List<String> bcc;

  const EmailSenderConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.useTls = true,
    this.ignoreBadCert = false,
    this.bcc = const [],
  });

  bool get isValid => host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
}

class EmailSender {
  static const _kCryptKey = 'test';
  static const _kLogsKey = 'smtp_logs';
  static const int _kMaxLogLines = 1000;

  static List<String> parseBcc(String raw) {
    return raw
        .split(RegExp('[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String decrypt(String cipher) {
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

  static Future<void> _appendLog(String line) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    final entry = '[$now] $line';
    final existing = List<String>.from(prefs.getStringList(_kLogsKey) ?? const <String>[]);
    existing.add(entry);
    if (existing.length > _kMaxLogLines) {
      final dropCount = existing.length - _kMaxLogLines;
      existing.removeRange(0, dropCount);
    }
    await prefs.setStringList(_kLogsKey, existing);
  }

  static Future<List<String>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kLogsKey) ?? <String>[];
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLogsKey);
  }

  static Future<bool> _checkPortOpen(String host, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      await _appendLog('[TEST][PORT][OK] $host:$port reachable');
      return true;
    } catch (e) {
      await _appendLog('[TEST][PORT][NG] $host:$port err=$e');
      return false;
    }
  }

  static Future<bool> _checkAndLogConfig({required EmailSenderConfig config, required String channel}) async {
    final checks = <String, bool>{
      'host': config.host.isNotEmpty,
      'port': config.port > 0,
      'user': config.username.isNotEmpty,
      'pass': config.password.isNotEmpty,
      'bcc': config.bcc.isNotEmpty,
    };

    String valMask(String key) {
      switch (key) {
        case 'host':
          return config.host;
        case 'port':
          return config.port.toString();
        case 'user':
          return config.username;
        case 'pass':
          return config.password.isNotEmpty ? '***' : '';
        case 'bcc':
          return config.bcc.join(',');
        default:
          return '';
      }
    }

    final summary = checks.entries
        .map((e) => '${e.key}=${valMask(e.key)} (${e.value ? 'OK' : 'NG'})')
        .join(' | ');
    final tail = 'tls=${config.useTls} ignoreBadCert=${config.ignoreBadCert}';
    await _appendLog('[$channel][CFG] $summary | $tail');

    return checks.values.every((v) => v);
  }

  static SmtpServer _serverFromConfig(EmailSenderConfig config) {
    return SmtpServer(
      config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      ssl: !config.useTls,
      allowInsecure: config.ignoreBadCert || !config.useTls,
      ignoreBadCertificate: config.ignoreBadCert,
    );
  }

  static Future<EmailSenderConfig?> loadConfigFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final host = (prefs.getString('smtp_host') ?? '').trim();
    final portStr = (prefs.getString('smtp_port') ?? '587').trim();
    final user = (prefs.getString('smtp_user') ?? '').trim();
    final passEncrypted = prefs.getString('smtp_pass') ?? '';
    final pass = decrypt(passEncrypted).trim();
    final useTls = prefs.getBool('smtp_tls') ?? true;
    final ignoreBadCert = prefs.getBool('smtp_ignore_bad_cert') ?? false;
    final bccRaw = prefs.getString('smtp_bcc') ?? '';
    final bccList = parseBcc(bccRaw);
    final port = int.tryParse(portStr) ?? 587;

    final config = EmailSenderConfig(
      host: host,
      port: port,
      username: user,
      password: pass,
      useTls: useTls,
      ignoreBadCert: ignoreBadCert,
      bcc: bccList,
    );
    if (!config.isValid) {
      await _appendLog('[CFG][NG] host/user/pass が未入力の可能性があります');
      return null;
    }
    return config;
  }

  static Future<void> sendTest({required EmailSenderConfig config}) async {
    final server = _serverFromConfig(config);
    final message = Message()
      ..from = Address(config.username)
      ..bccRecipients = config.bcc
      ..subject = 'SMTPテスト送信'
      ..text = 'これはテストメールです（BCC送信）';

    final configOk = await _checkAndLogConfig(config: config, channel: 'TEST');
    if (!configOk) {
      throw StateError('SMTP設定が不足しています');
    }

    await _checkPortOpen(config.host, config.port);

    try {
      await send(message, server);
      await _appendLog('[TEST][OK] bcc: ${config.bcc.join(',')}');
    } catch (e) {
      await _appendLog('[TEST][NG] err=$e (認証/暗号化設定を確認してください)');
      rethrow;
    }
  }

  static Future<void> sendInvoiceEmail({
    required EmailSenderConfig config,
    required String toEmail,
    required File pdfFile,
    String? subject,
    String? attachmentFileName,
    String? body,
  }) async {
    final server = _serverFromConfig(config);
    final message = Message()
      ..from = Address(config.username)
      ..recipients = [toEmail]
      ..bccRecipients = config.bcc
      ..subject = subject ?? '請求書送付'
      ..text = body ?? '請求書をお送りします。ご確認ください。'
      ..attachments = [
        FileAttachment(pdfFile)
          ..fileName = attachmentFileName ?? 'invoice.pdf'
          ..contentType = 'application/pdf'
      ];

    final configOk = await _checkAndLogConfig(config: config, channel: 'INVOICE');
    if (!configOk) {
      throw StateError('SMTP設定が不足しています');
    }

    try {
      await send(message, server);
      await _appendLog('[INVOICE][OK] to: $toEmail bcc: ${config.bcc.join(',')}');
    } catch (e) {
      await _appendLog('[INVOICE][NG] to: $toEmail err: $e');
      rethrow;
    }
  }

  static Future<void> logDeviceMailer({
    required bool success,
    required String toEmail,
    required List<String> bcc,
    String? error,
  }) async {
    final status = success ? 'OK' : 'NG';
    final buffer = StringBuffer('[DEVICE][$status] to: $toEmail bcc: ${bcc.join(',')}');
    if (error != null && error.isNotEmpty) {
      buffer.write(' err: $error');
    }
    await _appendLog(buffer.toString());
  }
}
