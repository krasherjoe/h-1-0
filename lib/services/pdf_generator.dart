import 'dart:io';
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import 'company_repository.dart';
import 'activity_log_repository.dart';

/// PDFドキュメントの構築（プレビューと実保存の両方で使用）
Future<pw.Document> buildInvoiceDocument(Invoice invoice) async {
  final pdf = pw.Document();

  final fontData = await rootBundle.load("assets/fonts/ipaexg.ttf");
  final ipaex = pw.Font.ttf(fontData);
  final dateFormatter = DateFormat('yyyy年MM月dd日');
  final amountFormatter = NumberFormat("#,###");

  final companyRepo = CompanyRepository();
  final companyInfo = await companyRepo.getCompanyInfo();

  pw.MemoryImage? sealImage;
  if (companyInfo.sealPath != null) {
    final file = File(companyInfo.sealPath!);
    if (await file.exists()) {
      sealImage = pw.MemoryImage(await file.readAsBytes());
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ipaex,
          bold: ipaex,
          italic: ipaex,
          boldItalic: ipaex,
        ).copyWith(defaultTextStyle: pw.TextStyle(fontFallback: [ipaex])),
        buildBackground: (context) {
          if (!invoice.isDraft) return pw.SizedBox();
          return pw.Center(
            child: pw.Transform.rotate(
              angle: -0.5,
              child: pw.Opacity(
                opacity: 0.18,
                child: pw.Text(
                  '下書き',
                  style: pw.TextStyle(
                    fontSize: 120,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      build: (context) {
        final content = <pw.Widget>[
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(invoice.documentTypeName, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("番号: ${invoice.invoiceNumber}"),
                    pw.Text("発行日: ${dateFormatter.format(invoice.date)}"),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                      child: pw.Text(invoice.customer.invoiceName, style: const pw.TextStyle(fontSize: 18)),
                    ),
                    pw.SizedBox(height: 6),
                    if ((invoice.contactAddressSnapshot ?? invoice.customer.address) != null)
                      pw.Text(invoice.contactAddressSnapshot ?? invoice.customer.address!, style: const pw.TextStyle(fontSize: 12)),
                    if ((invoice.contactTelSnapshot ?? invoice.customer.tel) != null)
                      pw.Text("TEL: ${invoice.contactTelSnapshot ?? invoice.customer.tel}", style: const pw.TextStyle(fontSize: 12)),
                    if (invoice.contactEmailSnapshot != null)
                      pw.Text("MAIL: ${invoice.contactEmailSnapshot}", style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      invoice.documentType == DocumentType.receipt
                          ? "上記の金額を正に領収いたしました。"
                          : (invoice.documentType == DocumentType.estimation
                              ? "下記の通り、お見積り申し上げます。"
                              : "下記の通り、ご請求申し上げます。"),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Stack(
                  alignment: pw.Alignment.topRight,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(companyInfo.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        if (companyInfo.zipCode != null) pw.Text("〒${companyInfo.zipCode}"),
                        if (companyInfo.address != null) pw.Text(companyInfo.address!),
                        if (companyInfo.tel != null) pw.Text("TEL: ${companyInfo.tel}"),
                        if (companyInfo.fax != null && companyInfo.fax!.isNotEmpty) pw.Text("FAX: ${companyInfo.fax}"),
                        if (companyInfo.email != null && companyInfo.email!.isNotEmpty) pw.Text("MAIL: ${companyInfo.email}"),
                        if (companyInfo.url != null && companyInfo.url!.isNotEmpty) pw.Text("URL: ${companyInfo.url}"),
                        if (companyInfo.registrationNumber != null && companyInfo.registrationNumber!.isNotEmpty)
                          pw.Text("登録番号: ${companyInfo.registrationNumber!}", style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (sealImage != null)
                      pw.Positioned(
                        right: 10,
                        top: 0,
                        child: pw.Opacity(opacity: 0.8, child: pw.Image(sealImage, width: 40, height: 40)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  invoice.documentType == DocumentType.receipt
                      ? (companyInfo.taxDisplayMode == 'hidden' ? "領収金額" : "領収金額 (税込)")
                      : (companyInfo.taxDisplayMode == 'hidden' ? "合計金額" : "合計金額 (税込)"),
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text("￥${amountFormatter.format(invoice.totalAmount)} -", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const ["品名", "数量", "単価", "金額"],
            data: invoice.items
                .map((item) => [
                      item.description,
                      item.quantity.toString(),
                      amountFormatter.format(item.unitPrice),
                      amountFormatter.format(item.subtotal),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ipaex),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(2)},
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    pw.SizedBox(height: 10),
                    _buildSummaryRow("小計 (税抜)", amountFormatter.format(invoice.subtotal)),
                    if (companyInfo.taxDisplayMode == 'normal')
                      _buildSummaryRow("消費税 (${(invoice.taxRate * 100).toInt()}%)", amountFormatter.format(invoice.tax)),
                    if (companyInfo.taxDisplayMode == 'text_only') _buildSummaryRow("消費税", "（税別）"),
                    pw.Divider(),
                    _buildSummaryRow("合計", "￥${amountFormatter.format(invoice.totalAmount)}", isBold: true),
                  ],
                ),
              ),
            ],
          ),
          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text("備考:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Text(invoice.notes!),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Verification Hash (SHA256):", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text(invoice.contentHash, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                width: 50,
                height: 50,
                child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: invoice.contentHash, drawText: false),
              ),
            ],
          ),
        ];

        return [pw.Column(children: content)];
      },
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 16),
        child: pw.Text("Page ${context.pageNumber} / ${context.pagesCount}", style: const pw.TextStyle(color: PdfColors.grey)),
      ),
    ),
  );

  return pdf;
}

/// A4サイズのプロフェッショナルな伝票PDFを生成し、保存する
Future<String?> generateInvoicePdf(Invoice invoice) async {
  try {
    final pdf = await buildInvoiceDocument(invoice);

    final String hash = invoice.contentHash;
    final String dateStr = DateFormat('yyyyMMdd').format(invoice.date);
    final String amountStr = NumberFormat("#,###").format(invoice.totalAmount);
    // {日付}({タイプ}){顧客名}_{案件}_{金額}_{HASH下8桁}.pdf
    // 顧客名から敬称を除去
    String safeCustomerName = invoice.customerNameForDisplay
      .replaceAll('株式会社', '')
      .replaceAll('（株）', '')
      .replaceAll('(株)', '')
      .replaceAll('有限会社', '')
      .replaceAll('（有）', '')
      .replaceAll('(有)', '')
      .replaceAll('合同会社', '')
      .replaceAll('（同）', '')
      .replaceAll('(同)', '')
      .trim();

    final suffix = (invoice.subject?.isNotEmpty ?? false) ? "_${invoice.subject}" : "";
    final String fileName = "$dateStr(${invoice.documentTypeName})$safeCustomerName${suffix}_$amountStr円_$hash.pdf";

    final directory = await getExternalStorageDirectory();
    if (directory == null) return null;

    final file = File("${directory.path}/$fileName");
    final Uint8List bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    // 生成をログに記録
    final logRepo = ActivityLogRepository();
    await logRepo.logAction(
      action: "GENERATE_PDF",
      targetType: "INVOICE",
      targetId: invoice.id,
      details: "PDF生成: $fileName (${invoice.documentTypeName})",
    );

    return file.path;
  } catch (e) {
    debugPrint("PDF Generation Error: $e");
    return null;
  }
}

pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
  final style = pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : null);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    ),
  );
}
