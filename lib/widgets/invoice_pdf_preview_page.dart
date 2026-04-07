import 'dart:io';

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/email_sender.dart';
import 'bcc_email_service.dart';

/// 請求書 PDF プレビューウィジェット
///
/// ScreenID: 02
///
/// 機能：
/// - PDF プレビュー表示
/// - 正式発行（ドラフト状態の伝票を確定）
/// - 共有（share_plus を使用した端末標準アプリ共有）
/// - メール送信（share_plus を使用した端末メールアプリ起動）
/// - 印刷（printing パッケージを使用）
class InvoicePdfPreviewPage extends StatelessWidget {
  final Invoice invoice;
  final bool allowFormalIssue;
  final bool isUnlocked;
  final bool isLocked;
  final Future<bool> Function()? onFormalIssue;
  final bool showShare;
  final bool showEmail;
  final bool showPrint;

  const InvoicePdfPreviewPage({
    super.key,
    required this.invoice,
    this.allowFormalIssue = true,
    this.isUnlocked = false,
    this.isLocked = false,
    this.onFormalIssue,
    this.showShare = true,
    this.showEmail = true,
    this.showPrint = true,
  });

  bool get _canFormalIssue =>
      allowFormalIssue &&
      invoice.isDraft &&
      isUnlocked &&
      !isLocked &&
      onFormalIssue != null;

  Future<bool> _showFormalIssueWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${invoice.documentTypeName}の正式発行'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invoice.customerNameForDisplay),
            const SizedBox(height: 8),
            const Text(
              'この伝票を正式発行すると、\n電子帳簿保存法により二度と編集できなくなります。\n\n確定してよろしいですか？',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('正式発行する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = await buildInvoiceDocument(invoice);
    return Uint8List.fromList(await doc.save());
  }

  /// メール送信（Gmail 起動・BCC 自動追加付き）
  ///
  /// FlutterEmailSender を使用して Gmail（端末の既定メールアプリ）を起動する。
  /// 宛先：顧客メール、BCC：S8 設定値、件名：伝票種別＋番号
  Future<void> _shareMail(BuildContext context) async {
    try {
      final pdfBytes = await _buildPdfBytes();
      final fileName = invoice.mailAttachmentFileName;

      // PDF ファイルを一時的に保存
      final tempDir = await getTemporaryDirectory();
      final pdfFile = File('${tempDir.path}/$fileName');
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      // 請求書のハッシュを生成
      final hash = sha256.convert(pdfBytes).toString();

      // BCC アドレスを取得（S8 設定）
      final prefs = await SharedPreferences.getInstance();
      final bccRaw = prefs.getString('smtp_bcc') ?? '';
      final bccAddresses = EmailSender.parseBcc(bccRaw);

      // 宛先メールアドレス（顧客のメール）
      final toEmail = invoice.customer.email ?? '';

      if (toEmail.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('顧客のメールアドレスが設定されていません')),
          );
        }
        return;
      }

      // 件名：伝票種別 + 伝票番号
      final subject =
          '${invoice.documentTypeName}送付のご案内（${invoice.invoiceNumber}）';

      // Gmail（端末の既定メールアプリ）を起動
      await BccEmailService.sendWithBcc(
        pdfFile: pdfFile,
        toEmail: toEmail,
        bccAddresses: bccAddresses,
        filename: fileName,
        hash: hash,
        attachmentFileName: fileName,
        subject: subject,
      );

      if (context.mounted) {
        final bccMsg =
            bccAddresses.isNotEmpty ? '（BCC：${bccAddresses.length}件）' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メールアプリを起動しました$bccMsg')),
        );
      }
    } catch (e) {
      debugPrint('_shareMail エラー：$e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メール起動に失敗しました：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = invoice.isDraft;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("PDF プレビュー"),
            Text(
              "ScreenID: 02",
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) async => await _buildPdfBytes(),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              actions: const [],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canFormalIssue
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('正式発行するには長押ししてください'),
                                ),
                              );
                            }
                          : null,
                      onLongPress: _canFormalIssue
                          ? () async {
                              final confirmed = await _showFormalIssueWarning(
                                context,
                              );
                              if (!confirmed) return;
                              final ok = await onFormalIssue!();
                              if (ok && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text("正式発行"),
                          if (!isDraft || isLocked)
                            const Positioned(
                              right: 0,
                              child: Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (showShare && (!isDraft || isLocked))
                          ? () async {
                              final bytes = await _buildPdfBytes();
                              final fileName = invoice.mailAttachmentFileName;
                              await Printing.sharePdf(
                                bytes: bytes,
                                filename: fileName,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.share),
                      label: const Text("共有"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (showEmail && (!isDraft || isLocked))
                          ? () async {
                              await _shareMail(context);
                            }
                          : null,
                      icon: const Icon(Icons.mail_outline),
                      label: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: showPrint
                          ? () async {
                              await Printing.layoutPdf(
                                onLayout: (format) async =>
                                    await _buildPdfBytes(),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.print),
                      label: const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
