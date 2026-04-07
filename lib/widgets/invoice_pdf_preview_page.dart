import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';

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

  /// 端末標準のメールアプリで共有（share_plus を使用）
  ///
  /// SMTP や flutter_email_sender は使用せず、
  /// Android/iOS の標準メールアプリを起動して手動送信を促す方式に切り替えました。
  Future<void> _shareMail(BuildContext context) async {
    try {
      final bytes = await _buildPdfBytes();
      final fileName = invoice.mailAttachmentFileName;

      // 一時的なファイルに保存して共有
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // share_plus を使用して端末標準のメールアプリを起動
      await share_plus.Share.shareXFiles(
        [share_plus.XFile(file.path)],
        subject: '請求書 ${invoice.invoiceNumber}',
        text: '請求書の PDF を添付します。',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メールアプリが起動しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('共有に失敗しました：$e')));
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
