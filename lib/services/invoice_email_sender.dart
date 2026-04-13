/// 請求書メール送信サービス
///
/// `flutter_email_sender` パッケージを使用して、
/// Gmail API を経由せずに端末標準のメールアプリを起動します。
///
/// 機能:
/// - 件名：請求書の mailTitleCore を使用
/// - 本文：請求書の mailBodyText を使用
/// - BCC: 設定から取得したアドレスを使用（未設定の場合は空）
/// - アタッチメント：PDF ファイルをパス形式で渡す（Base64 エンコード不要）
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';
import '../services/app_settings_repository.dart';
import '../services/pdf_generator.dart';

/// 請求書メール送信サービス
///
/// 依頼された請求書データを元に、端末標準のメールアプリを起動します。
/// Base64 エンコードは不要で、ファイルパスを直接使用します。
class InvoiceEmailSender {
  final AppSettingsRepository _settingsRepository;

  InvoiceEmailSender(this._settingsRepository);

  /// 請求書をメールで送信
  ///
  /// 端末標準のメールアプリを起動し、ユーザーが送信先を設定できます。
  /// - 件名：[invoice.mailTitleCore] を使用
  /// - 本文：[invoice.mailBodyText] を使用
  /// - BCC: 設定から取得したアドレス（未設定の場合は空）
  /// - アタッチメント：PDF ファイルを一時保存してパスを渡す
  Future<String> sendEmail({required Invoice invoice}) async {
    try {
      // 1. PDF ファイルを一時ディレクトリに保存
      final pdfFilePath = await _savePdfToTemp(invoice);

      // 2. メール設定の構築（BCC 含む）
      final email = await _buildEmailWithBcc(invoice, pdfFilePath);

      // 3. メール送信（端末標準アプリを起動）
      // flutter_email_sender は void を返すので、例外がない限り成功とみなす
      await FlutterEmailSender.send(email);

      debugPrint('メール送信：成功');
      return 'success';
    } catch (e, stackTrace) {
      debugPrint('メール送信エラー：$e');
      debugPrint('スタックトレース：$stackTrace');
      return 'failure';
    }
  }

  /// メールオブジェクトを構築（BCC あり）
  Future<Email> _buildEmailWithBcc(Invoice invoice, String pdfFilePath) async {
    // 件名：請求書の mailTitleCore を使用
    final subject = invoice.mailTitleCore;

    // 本文：請求書の mailBodyText を使用
    final body = invoice.mailBodyText;

    // BCC: 設定から取得（未設定の場合は空リスト）
    final bccAddress = await _settingsRepository.getGmailSyncBccAddress();
    final bcc = bccAddress != null && bccAddress.isNotEmpty
        ? [bccAddress]
        : <String>[];

    // アタッチメント：PDF ファイルパス（リスト形式）
    final attachmentPaths = [pdfFilePath];

    // デバッグログ：メール設定を確認
    debugPrint('===== メール送信設定 =====');
    debugPrint('件名 (subject): $subject');
    debugPrint('本文 (body): $body');
    debugPrint('BCC アドレス：$bccAddress');
    debugPrint('BCC リスト：$bcc');
    debugPrint('PDF ファイルパス：$pdfFilePath');
    debugPrint('=========================');

    return Email(
      body: body,
      subject: subject,
      recipients: [], // 送信先はユーザーが設定
      bcc: bcc,
      attachmentPaths: attachmentPaths,
      isHTML: false,
    );
  }

  /// 請求書 PDF を一時ディレクトリに保存
  ///
  /// [invoice] の PDF を生成し、一時ディレクトリに保存してファイルパスを返す。
  Future<String> _savePdfToTemp(Invoice invoice) async {
    try {
      // 1. 請求書ドキュメントを生成（PDF bytes）
      final document = await buildInvoiceDocument(invoice);

      // 2. 一時ディレクトリを取得
      final tempDir = await getTemporaryDirectory();
      // mailAttachmentFileName を使用（例: "請求書_2024-04-13_001.pdf"）
      final pdfFile = File('${tempDir.path}/${invoice.mailAttachmentFileName}');

      // 3. PDF bytes をファイルに保存
      // document は pw.Document で、save() で bytes を取得
      final bytes = await document.save();
      await pdfFile.writeAsBytes(bytes);

      debugPrint('PDF 一時保存：${pdfFile.path}');
      return pdfFile.path;
    } catch (e, stackTrace) {
      debugPrint('PDF 一時保存エラー：$e');
      debugPrint('スタックトレース：$stackTrace');
      rethrow;
    }
  }
}
