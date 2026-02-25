import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/invoice_models.dart';
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
                              final bytes = await _buildPdfBytes();
                              await Printing.sharePdf(bytes: bytes, filename: 'invoice.pdf', subject: '請求書送付');
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
