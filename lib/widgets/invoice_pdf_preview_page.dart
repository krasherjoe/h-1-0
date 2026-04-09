import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
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
class InvoicePdfPreviewPage extends StatefulWidget {
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

  @override
  State<InvoicePdfPreviewPage> createState() => _InvoicePdfPreviewPageState();
}

class _InvoicePdfPreviewPageState extends State<InvoicePdfPreviewPage> {
  bool _issued = false;
  late final Future<Uint8List> Function(PdfPageFormat) _stablePdfBuilder;

  @override
  void initState() {
    super.initState();
    _stablePdfBuilder = (_) => _buildPdfBytes();
  }

  bool get _canFormalIssue =>
      widget.allowFormalIssue &&
      widget.invoice.isDraft &&
      widget.isUnlocked &&
      !widget.isLocked &&
      !_issued &&
      widget.onFormalIssue != null;

  Future<bool> _showFormalIssueWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.invoice.documentTypeName}の正式発行'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.invoice.customerNameForDisplay),
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
    final doc = await buildInvoiceDocument(widget.invoice);
    return Uint8List.fromList(await doc.save());
  }

  /// メールで共有（share_plus を使用）
  ///
  /// share_plus を使用して端末標準の共有メニューを起動し、
  /// ユーザーがメールアプリを選択できるようにする。
  Future<void> _shareMail(BuildContext context) async {
    try {
      final pdfBytes = await _buildPdfBytes();
      final fileName = widget.invoice.mailAttachmentFileName;

      // share_plus を使用して共有メニューを起動
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('共有メニューを起動しました。メールアプリを選択してください')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('メール共有エラー：$e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('共有に失敗しました')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsLocked = widget.isLocked || _issued;
    final isDraft = widget.invoice.isDraft && !_issued;
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
              build: _stablePdfBuilder,
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
                              final ok = await widget.onFormalIssue!();
                              if (ok && mounted) {
                                setState(() => _issued = true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('正式発行が完了しました'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text("正式発行"),
                          if (!isDraft || effectiveIsLocked)
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
                      onPressed:
                          (widget.showShare && (!isDraft || effectiveIsLocked))
                          ? () async {
                              final bytes = await _buildPdfBytes();
                              final fileName =
                                  widget.invoice.mailAttachmentFileName;
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
                      onPressed:
                          (widget.showEmail && (!isDraft || effectiveIsLocked))
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
                      onPressed: widget.showPrint
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
