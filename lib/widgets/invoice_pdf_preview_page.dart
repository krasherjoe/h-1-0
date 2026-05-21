import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/invoice_models.dart';
import '../services/app_settings_repository.dart';
import '../services/invoice_email_sender.dart';
import '../services/pdf_generator.dart';
import '../utils/theme_utils.dart';

/// 請求書 PDF プレビューウィジェット
///
/// ScreenID: PP
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
    _stablePdfBuilder = (format) => _buildPdfBytes(format);
  }

  bool get _canFormalIssue =>
      widget.allowFormalIssue &&
      widget.invoice.isDraft &&
      widget.isUnlocked &&
      !widget.isLocked &&
      !_issued &&
      widget.onFormalIssue != null;

  /// PP 内で正式発行済みになった場合、widget.invoice は古い下書き状態のまま
  /// なので、PDF 生成・共有・メール送信・印刷では `_issued` を反映した
  /// 確定済みインスタンスを使う。
  Invoice get _effectiveInvoice => _issued
      ? widget.invoice.copyWith(isDraft: false, isLocked: true)
      : widget.invoice;

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

  Future<bool> _showDraftSendWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 下書きの送信'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.invoice.customerNameForDisplay),
            const SizedBox(height: 8),
            const Text(
              'この伝票は下書き状態です。\n正式発行されていません。\n\n下書きのまま送信してよろしいですか？',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('下書きのまま送信'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<Uint8List> _buildPdfBytes([PdfPageFormat? format]) async {
    final doc = await buildInvoiceDocument(
      _effectiveInvoice,
      pageFormat: format ?? kSealPreviewPageFormat,
    );
    return Uint8List.fromList(await doc.save());
  }

  /// メールで送信（直接メールアプリを起動）
  ///
  /// `InvoiceEmailSender` を使用して、端末標準のメールアプリを直接起動します。
  /// - 件名：請求書の mailTitleCore
  /// - 本文：請求書の mailBodyText
  /// - BCC: 設定から取得したアドレス
  /// - アタッチメント：PDF ファイル
  Future<void> _sendMail(BuildContext context) async {
    // メール送信サービスを作成
    final settingsRepo = AppSettingsRepository();
    final emailSender = InvoiceEmailSender(settingsRepo);

    try {
      // メール送信を実行
      final result = await emailSender.sendEmail(invoice: _effectiveInvoice);

      if (!mounted) return;

      if (result == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メールアプリを起動しました')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メール送信がキャンセルされました')));
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      debugPrint('メール送信エラー：$e');
      debugPrint('スタックトレース：$stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メール送信に失敗しました')));
    }
  }

  Widget _ppButton({
    required IconData icon,
    required String label,
    required bool enabled,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? cs.primary;
    return Expanded(
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        onLongPress: enabled ? onLongPress : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? bg : null,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final effectiveIsLocked = widget.isLocked || _issued;
    final isDraft = widget.invoice.isDraft && !_issued;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docColor = documentTypeColor(widget.invoice.documentType, cs, isDark);
    final docFg = appBarForeground(docColor);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: docColor,
        foregroundColor: docFg,
        titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: docFg),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PP:PDF プレビュー"),
            Text(
              "拡大する時はダブルタップしてからピンチインしてください",
              style: TextStyle(fontSize: 11, color: docFg.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    initialPageFormat: kSealPreviewPageFormat,
                    build: _stablePdfBuilder,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    actions: const [],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '拡大する時はダブルタップしてからピンチインしてください',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Row(
                    children: [
                      _ppButton(
                        icon: Icons.check_circle_outline,
                        label: (!isDraft || effectiveIsLocked) ? '正式発行🔒' : '正式発行',
                        color: Theme.of(context).colorScheme.secondary,
                        enabled: _canFormalIssue,
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
                                final confirmed =
                                    await _showFormalIssueWarning(context);
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
                      ),
                      const SizedBox(width: 8),
                      _ppButton(
                        icon: Icons.share,
                        label: '共有',
                        enabled: widget.showShare,
                        onPressed: widget.showShare
                            ? () async {
                                if (isDraft && !effectiveIsLocked) {
                                  final confirmed = await _showDraftSendWarning(context);
                                  if (!confirmed) return;
                                }
                                final bytes = await _buildPdfBytes();
                                await Printing.sharePdf(
                                  bytes: bytes,
                                  filename: _effectiveInvoice.mailAttachmentFileName,
                                );
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _ppButton(
                        icon: Icons.mail_outline,
                        label: 'メール',
                        enabled: widget.showEmail,
                        onPressed: widget.showEmail
                            ? () async {
                                if (isDraft && !effectiveIsLocked) {
                                  final confirmed = await _showDraftSendWarning(context);
                                  if (!confirmed) return;
                                }
                                await _sendMail(context);
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _ppButton(
                        icon: Icons.print,
                        label: '印刷',
                        enabled: widget.showPrint,
                        onPressed: widget.showPrint
                            ? () async {
                                await Printing.layoutPdf(
                                   onLayout: (format) async => _buildPdfBytes(format),
                                 );
                              }
                            : null,
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
