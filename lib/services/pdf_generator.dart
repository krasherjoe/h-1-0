import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import 'company_repository.dart';
import 'activity_log_repository.dart';

/// 角印プレビュー用ページフォーマット（A4, マージン32pt≒11.29mm）
/// buildInvoiceDocument の pageTheme.margin と完全に一致させるため
const kSealPreviewPageFormat = PdfPageFormat(
  210 * PdfPageFormat.mm, // width: A4 210mm
  297 * PdfPageFormat.mm, // height: A4 297mm
  marginAll: 11.29 * PdfPageFormat.mm, // 32pt ≒ 11.29mm (buildInvoiceDocument と同一)
);

/// PDFドキュメントの構築（プレビューと実保存の両方で使用）
/// [pageFormat]: printing パッケージから渡されるページフォーマット。
///               null の場合は kSealPreviewPageFormat をデフォルトとして使用。
String _formatBankAccount(String raw) {
  final parts = raw.split('|');
  if (parts.length >= 5) {
    return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]} ${parts[4]}';
  }
  return raw;
}

Future<pw.Document> buildInvoiceDocument(
  Invoice invoice, {
  PdfPageFormat? pageFormat,
  double? sealOffsetXOverride,
  double? sealOffsetYOverride,
  double? sealRotationOverride,
}) async {
  // デバッグ: PDF生成時のpageFormatと角印座標を記録
  final effectiveFormat = pageFormat ?? kSealPreviewPageFormat;
  debugPrint(
    '[buildInvoiceDocument] pageFormat=width:${effectiveFormat.width.toStringAsFixed(2)}mm '
    'height:${effectiveFormat.height.toStringAsFixed(2)}mm marginAll:${effectiveFormat.marginTop.toStringAsFixed(2)}mm '
    'sealX:${(sealOffsetXOverride ?? 0).toStringAsFixed(1)} sealY:${(sealOffsetYOverride ?? 0).toStringAsFixed(1)}',
  );

  final metaJson = invoice.metaJsonValue;
  final metaHash = invoice.metaHashValue;

  final pdf = pw.Document(
    title: '${invoice.documentTypeName} ${invoice.invoiceNumber}',
    author: 'h1-app',
    subject: 'metaHash:$metaHash',
    keywords: metaJson,
  );

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
        pageFormat: pageFormat ?? kSealPreviewPageFormat,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ipaex,
          bold: ipaex,
          italic: ipaex,
          boldItalic: ipaex,
        ).copyWith(defaultTextStyle: pw.TextStyle(fontFallback: [ipaex])),
        buildBackground: (context) {
          // 角印のみを背景に配置。透かしは別途 buildForeground で処理し、
          // Stack の子要素構成を F1（ダミー）/PP（実請求書）で完全一致させる。
          if (sealImage == null) return pw.SizedBox();
          final sealX = sealOffsetXOverride ?? companyInfo.sealOffsetX;
          final sealY = sealOffsetYOverride ?? companyInfo.sealOffsetY;
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              pw.Positioned(
                right: sealX,
                top: sealY,
                child: pw.Transform.rotate(
                  angle: (sealRotationOverride ?? companyInfo.sealRotation) * math.pi / 180,
                  child: pw.Image(sealImage!, width: 100, height: 100),
                ),
              ),
            ],
          );
        },
        buildForeground: (context) {
          if (!(invoice.isDraft && !invoice.isLocked)) return pw.SizedBox();
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
                    if (invoice.promisedDate != null && invoice.documentType == DocumentType.estimation)
                      pw.Text("有効期限: ${dateFormatter.format(invoice.promisedDate!)}"),
                    if (invoice.fulfilledDate != null && invoice.documentType == DocumentType.delivery)
                      pw.Text("納品日: ${dateFormatter.format(invoice.fulfilledDate!)}"),
                    if (invoice.linkedDeliveryId != null && invoice.documentType == DocumentType.delivery)
                      pw.Text("追跡番号: ${invoice.linkedDeliveryId!}"),
                    if (invoice.fulfilledDate != null && invoice.documentType == DocumentType.receipt)
                      pw.Text("領収日: ${dateFormatter.format(invoice.fulfilledDate!)}"),
                    if (invoice.promisedDate != null && invoice.documentType == DocumentType.invoice)
                      pw.Text("お支払期限: ${dateFormatter.format(invoice.promisedDate!)}"),
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
                      () {
                        switch (invoice.documentType) {
                          case DocumentType.receipt:
                            return "上記の金額を正に領収いたしました。";
                          case DocumentType.estimation:
                            return "下記の通り、お見積り申し上げます。";
                          case DocumentType.delivery:
                            return "下記の通り、納品いたしました。";
                          case DocumentType.order:
                            return "下記の通り、受注申し上げます。";
                          case DocumentType.invoice:
                          default:
                            return "下記の通り、ご請求申し上げます。";
                        }
                      }(),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(companyInfo.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (companyInfo.zipCode != null) pw.Text("〒${companyInfo.zipCode}"),
                    if (companyInfo.address != null) pw.Text(companyInfo.address!),
                    if (companyInfo.address2 != null && companyInfo.address2!.isNotEmpty) pw.Text(companyInfo.address2!),
                    if (companyInfo.tel != null) pw.Text("TEL: ${companyInfo.tel}"),
                    if (companyInfo.fax != null && companyInfo.fax!.isNotEmpty) pw.Text("FAX: ${companyInfo.fax}"),
                    if (companyInfo.email != null && companyInfo.email!.isNotEmpty) pw.Text(companyInfo.email!),
                    if (companyInfo.url != null && companyInfo.url!.isNotEmpty) pw.Text(companyInfo.url!),
                    if (companyInfo.registrationNumber != null && 
                        companyInfo.registrationNumber!.isNotEmpty &&
                        companyInfo.taxDisplayMode != 'hidden')
                      pw.Text("登録番号: ${companyInfo.registrationNumber!}", style: const pw.TextStyle(fontSize: 10)),
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
                  () {
                    final bool showTaxSuffix = companyInfo.taxDisplayMode != 'hidden' && invoice.tax > 0;
                    String baseLabel;
                    switch (invoice.documentType) {
                      case DocumentType.receipt:
                        baseLabel = "領収金額";
                        break;
                      case DocumentType.estimation:
                        baseLabel = "お見積り金額";
                        break;
                      case DocumentType.delivery:
                        baseLabel = "納品金額";
                        break;
                      case DocumentType.order:
                        baseLabel = "受注金額";
                        break;
                      case DocumentType.invoice:
                      default:
                        baseLabel = "ご請求金額";
                        break;
                    }
                    return showTaxSuffix ? "$baseLabel (税込)" : baseLabel;
                  }(),
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text("￥${amountFormatter.format(invoice.totalAmount)} -", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: () {
              switch (invoice.documentType) {
                case DocumentType.estimation:
                  return const ["品名・仕様", "数量", "単価", "金額"];
                case DocumentType.delivery:
                  return const ["品名", "納品数", "単価", "金額"];
                case DocumentType.order:
                  return const ["品名", "受注数", "単価", "金額"];
                case DocumentType.invoice:
                  return const ["品名", "数量", "単価", "金額"];
                case DocumentType.receipt:
                  return const ["品名", "数量", "単価", "領収金額"];
                default:
                  return const ["品名", "数量", "単価", "金額"];
              }
            }(),
            data: invoice.items
                .map((item) {
                      // 値引きがある場合は説明に追加
                      String description = item.description;
                      if (item.discountAmount != null && item.discountAmount! > 0) {
                        description += ' (値引:-¥${amountFormatter.format(item.discountAmount)})';
                      } else if (item.discountRate != null && item.discountRate! > 0) {
                        description += ' (値引:${(item.discountRate! * 100).toStringAsFixed(0)}%OFF)';
                      }
                      return [
                        description,
                        item.quantity.toString(),
                        amountFormatter.format(item.unitPrice),
                        amountFormatter.format(item.subtotal),
                      ];
                    })
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
                    _buildSummaryRow(invoice.isTaxInclusiveMode ? "税込小計" : "小計", amountFormatter.format(invoice.subtotal)),
                    if (invoice.discountAmount > 0) ...[
                      _buildSummaryRow("値引き", "-${amountFormatter.format(invoice.discountAmount)}"),
                    ],
                    if (invoice.tax > 0) ...[
                      ...(() {
                        final mode = companyInfo.taxDisplayMode.isNotEmpty ? companyInfo.taxDisplayMode : 'normal';
                        if (invoice.isTaxInclusiveMode) {
                          return [
                            _buildSummaryRow("消費税 (${(invoice.taxRate * 100).toInt()}% 逆算)", "(内 ￥${amountFormatter.format(invoice.tax)})"),
                          ];
                        }
                        return [
                          if (mode == 'normal')
                            _buildSummaryRow("消費税 (${(invoice.taxRate * 100).toInt()}%)", amountFormatter.format(invoice.tax)),
                          if (mode == 'text_only')
                            _buildSummaryRow("消費税", "（税別）"),
                        ];
                      }()),
                    ],
                    pw.Divider(),
                    _buildSummaryRow(() {
                      switch (invoice.documentType) {
                        case DocumentType.estimation:
                          return invoice.isTaxInclusiveMode ? "お見積り合計 (税込)" : "お見積り合計";
                        case DocumentType.delivery:
                          return invoice.isTaxInclusiveMode ? "納品合計 (税込)" : "納品合計";
                        case DocumentType.order:
                          return invoice.isTaxInclusiveMode ? "受注合計 (税込)" : "受注合計";
                        case DocumentType.receipt:
                          return invoice.isTaxInclusiveMode ? "領収金額合計 (税込)" : "領収金額合計";
                        case DocumentType.invoice:
                        default:
                          return invoice.isTaxInclusiveMode ? "ご請求合計 (税込)" : "ご請求合計";
                      }
                    }(), "￥${amountFormatter.format(invoice.totalAmount)}", isBold: true),
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
              child: pw.Text(invoice.notes!, textAlign: pw.TextAlign.left),
            ),
          ],
          if (invoice.bankAccount != null && invoice.bankAccount!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text("振込先:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Text(_formatBankAccount(invoice.bankAccount!), textAlign: pw.TextAlign.left),
            ),
          ],
          // 領収書の但し書き
          if (invoice.documentType == DocumentType.receipt && invoice.subject != null && invoice.subject!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text("但し書き:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Text(invoice.subject!, textAlign: pw.TextAlign.left),
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
                  if (invoice.isDraft && !invoice.isLocked) ...[
                    pw.Text("下書き下書き下書き下書き下書き下書き", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                  ] else ...[
                    pw.Text("Verification Hash (SHA256):", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text(invoice.contentHash, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ],
                ],
              ),
              if (invoice.isDraft && !invoice.isLocked)
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                )
              else
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: metaHash, drawText: false),
                ),
            ],
          ),
        ];

        return [pw.Column(children: content)];
      },
      footer: (context) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // 書類タイプ別のフッターメッセージ
          if (invoice.documentType == DocumentType.estimation)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                "この見積書の有効期限は発行日から2週間です",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
          if (invoice.documentType == DocumentType.invoice && invoice.promisedDate != null)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                "お支払期限: ${DateFormat('yyyy年MM月dd日').format(invoice.promisedDate!)}までにお支払いください",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
          if (invoice.documentType == DocumentType.receipt)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                "領収書として正式に発行済みの書類です",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
          // ページ番号
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Page ${context.pageNumber} / ${context.pagesCount}",
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          ),
        ],
      ),
    ),
  );

  return pdf;
}

/// A4サイズのプロフェッショナルな伝票PDFを生成し、保存する
Future<String?> generateInvoicePdf(Invoice invoice) async {
  try {
    final pdf = await buildInvoiceDocument(invoice);

    // メール添付用ルールに統一
    // {日付}({短縮タイプ}){案件}@{顧客名}_{金額}円.pdf
    final String fileName = invoice.mailAttachmentFileName;

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
