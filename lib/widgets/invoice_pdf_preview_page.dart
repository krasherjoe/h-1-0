import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

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
    Key? key,
    required this.invoice,
    this.allowFormalIssue = true,
    this.isUnlocked = false,
    this.isLocked = false,
    this.onFormalIssue,
    this.showShare = true,
    this.showEmail = true,
    this.showPrint = true,
  }) : super(key: key);

  Future<Uint8List> _buildPdfBytes() async {
    final doc = await buildInvoiceDocument(invoice);
    return Uint8List.fromList(await doc.save());
  }

  Future<void> _sendEmail(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString('smtp_host') ?? '';
      final portStr = prefs.getString('smtp_port') ?? '587';
      final user = prefs.getString('smtp_user') ?? '';
      final pass = prefs.getString('smtp_pass') ?? '';
      final useTls = prefs.getBool('smtp_tls') ?? true;
      final bccRaw = prefs.getString('smtp_bcc') ?? '';
      final bccList = bccRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      if (host.isEmpty || user.isEmpty || pass.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMTP設定を先に保存してください')));
        }
        return;
      }

      final port = int.tryParse(portStr) ?? 587;
      final smtpServer = SmtpServer(host, port: port, username: user, password: pass, ignoreBadCertificate: false, ssl: !useTls, allowInsecure: !useTls);

      final toEmail = invoice.contactEmailSnapshot ?? invoice.customer.email;
      if (toEmail == null || toEmail.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('送信先メールアドレスがありません（顧客にメールを登録してください）')));
        }
        return;
      }

      final bytes = await _buildPdfBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/invoice.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final message = Message()
        ..from = Address(user)
        ..recipients = [toEmail]
        ..bccRecipients = bccList
        ..subject = '請求書送付'
        ..text = '請求書をお送りします。ご確認ください。'
        ..attachments = [FileAttachment(file)..fileName = 'invoice.pdf'..contentType = 'application/pdf'];

      await send(message, smtpServer);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('メール送信しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('メール送信に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = invoice.isDraft;
    return Scaffold(
      appBar: AppBar(title: const Text("PDFプレビュー")),
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
                      onPressed: (allowFormalIssue && isDraft && isUnlocked && !isLocked && onFormalIssue != null)
                          ? () async {
                              final ok = await onFormalIssue!();
                              if (ok && context.mounted) Navigator.pop(context, true);
                            }
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("正式発行"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: showShare
                          ? () async {
                              final bytes = await _buildPdfBytes();
                              await Printing.sharePdf(bytes: bytes, filename: 'invoice.pdf');
                            }
                          : null,
                      icon: const Icon(Icons.share),
                      label: const Text("共有"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: showEmail
                          ? () async {
                              await _sendEmail(context);
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
                              await Printing.layoutPdf(onLayout: (format) async => await _buildPdfBytes());
                            }
                          : null,
                      icon: const Icon(Icons.print),
                      label: const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
