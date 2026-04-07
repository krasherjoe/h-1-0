import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../constants/mail_templates.dart';
import '../services/company_profile_service.dart';

/// BCC 自動送信用サービス
///
/// flutter_email_sender を使用して、BCC 自動追加機能を提供する。
class BccEmailService {
  /// BCC アドレスの解析
  static List<String> parseBcc(String raw) {
    return raw
        .split(RegExp('[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// メール本文の生成
  static Future<String> generateMailBody({
    required String filename,
    required String hash,
  }) async {
    final profileService = CompanyProfileService();
    final placeholderMap = await profileService.buildMailPlaceholderMap(
      filename: filename,
      hash: hash,
    );

    // ヘッダーテンプレートの適用（デフォルト）
    String body = kMailHeaderTemplateDefault;
    for (var entry in placeholderMap.entries) {
      body = body.replaceAll(entry.key, entry.value);
    }

    // フッターを追加
    body += '\n\n---\n';
    body += kMailFooterTemplateDefault;
    for (var entry in placeholderMap.entries) {
      body = body.replaceAll(entry.key, entry.value);
    }

    return body;
  }

  /// メール送信（BCC 自動追加付き）
  static Future<bool> sendWithBcc({
    required File pdfFile,
    required String toEmail,
    required List<String> bccAddresses,
    required String filename,
    required String hash,
    required String attachmentFileName,
    String? subject,
  }) async {
    try {
      final mailBody = await generateMailBody(filename: filename, hash: hash);

      // 添付ファイルを一時的に保存
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$attachmentFileName');
      await tempFile.writeAsBytes(await pdfFile.readAsBytes(), flush: true);

      final email = Email(
        body: mailBody,
        subject: subject ?? '書類送付のご案内（$filename）',
        recipients: toEmail.isNotEmpty ? [toEmail] : [],
        bcc: bccAddresses,
        attachmentPaths: [tempFile.path],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      return true;
    } catch (e) {
      debugPrint('BCC メール送信エラー：$e');
      rethrow;
    }
  }
}
