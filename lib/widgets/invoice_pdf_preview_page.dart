import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/mail_send_method.dart';
import '../constants/mail_templates.dart';
import '../models/invoice_models.dart';
import '../services/company_profile_service.dart';
import '../services/email_sender.dart';
import '../services/pdf_generator.dart';

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

  Future<Uint8List> _buildPdfBytes() async {
    final doc = await buildInvoiceDocument(invoice);
    return Uint8List.fromList(await doc.save());
  }

  Future<void> _sendEmail(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mailMethod = normalizeMailSendMethod(prefs.getString(kMailSendMethodPrefKey));
      final bccRaw = prefs.getString('smtp_bcc') ?? '';
      final bccList = EmailSender.parseBcc(bccRaw);

      if (bccList.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BCCは必須項目です（設定画面で登録してください）')));
        }
        return;
      }

      final toEmail = invoice.contactEmailSnapshot ?? invoice.customer.email;
      if (toEmail == null || toEmail.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('送信先メールアドレスがありません（顧客にメールを登録してください）')));
        }
        return;
      }

      final bytes = await _buildPdfBytes();
      final fileName = invoice.mailAttachmentFileName;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      final hash = sha256.convert(bytes).toString();
      final headerTemplate = prefs.getString(kMailHeaderTextKey) ?? kMailHeaderTemplateDefault;
      final footerTemplate = prefs.getString(kMailFooterTextKey) ?? kMailFooterTemplateDefault;
      final placeholderMap = await CompanyProfileService().buildMailPlaceholderMap(filename: fileName, hash: hash);
      final header = applyMailTemplate(headerTemplate, placeholderMap);
      final footer = applyMailTemplate(footerTemplate, placeholderMap);
      final bodyCore = invoice.mailBodyText;
      final body = [header, bodyCore, footer].where((section) => section.trim().isNotEmpty).join('\n\n');

      if (mailMethod == kMailSendMethodDeviceMailer) {
        final email = Email(
          body: body,
          subject: fileName,
          recipients: [toEmail],
          bcc: bccList,
          attachmentPaths: [file.path],
          isHTML: false,
        );
        try {
          await FlutterEmailSender.send(email);
          await EmailSender.logDeviceMailer(success: true, toEmail: toEmail, bcc: bccList);
        } catch (e) {
          await EmailSender.logDeviceMailer(success: false, toEmail: toEmail, bcc: bccList, error: '$e');
          rethrow;
        }
      } else {
        final host = prefs.getString('smtp_host') ?? '';
        final portStr = prefs.getString('smtp_port') ?? '587';
        final user = prefs.getString('smtp_user') ?? '';
        final passEncrypted = prefs.getString('smtp_pass') ?? '';
        final pass = EmailSender.decrypt(passEncrypted);
        final useTls = prefs.getBool('smtp_tls') ?? true;
        final ignoreBadCert = prefs.getBool('smtp_ignore_bad_cert') ?? false;

        if (host.isEmpty || user.isEmpty || pass.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMTP設定を先に保存してください')));
          }
          return;
        }

        final port = int.tryParse(portStr) ?? 587;
        final smtpConfig = EmailSenderConfig(
          host: host,
          port: port,
          username: user,
          password: pass,
          useTls: useTls,
          ignoreBadCert: ignoreBadCert,
          bcc: bccList,
        );

        await EmailSender.sendInvoiceEmail(
          config: smtpConfig,
          toEmail: toEmail,
          pdfFile: file,
          subject: fileName,
          attachmentFileName: fileName,
          body: body,
        );
      }
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("PDFプレビュー"),
            Text("ScreenID: 02", style: TextStyle(fontSize: 11, color: Colors.white70)),
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
                      onPressed: (allowFormalIssue && isDraft && isUnlocked && !isLocked && onFormalIssue != null)
                          ? () async {
                              final ok = await onFormalIssue!();
                              if (ok && context.mounted) Navigator.pop(context, true);
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
                              child: Icon(Icons.lock, size: 16, color: Colors.white70),
                            ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (showShare && (!isDraft || isLocked))
                          ? () async {
                              final bytes = await _buildPdfBytes();
                              final fileName = invoice.mailAttachmentFileName;
                              await Printing.sharePdf(bytes: bytes, filename: fileName);
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
