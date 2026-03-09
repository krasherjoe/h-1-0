import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/sales_flow_models.dart';

/// PDF出力サービス
class PdfExportService {
  static final PdfExportService _instance = PdfExportService._internal();
  factory PdfExportService() => _instance;
  PdfExportService._internal();
  
  // 見積書PDF生成
  Future<File> generateQuotePdf({
    required Map<String, dynamic> quote,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> client,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildQuoteContent(quote, items, client);
        },
      ),
    );
    
    final fileName = '見積書_${quote['quote_no']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('/tmp/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  // 受注書PDF生成
  Future<File> generateOrderPdf({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> client,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildOrderContent(order, items, client);
        },
      ),
    );
    
    final fileName = '受注書_${order['order_no']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('/tmp/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  // 納品書PDF生成
  Future<File> generateDeliveryPdf({
    required Map<String, dynamic> delivery,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> client,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildDeliveryContent(delivery, items, client);
        },
      ),
    );
    
    final fileName = '納品書_${delivery['delivery_no']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('/tmp/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  // 請求書PDF生成
  Future<File> generateInvoicePdf({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> client,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildInvoiceContent(invoice, items, client);
        },
      ),
    );
    
    final fileName = '請求書_${invoice['invoice_no']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('/tmp/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  // 見積書コンテンツ構築
  pw.Widget _buildQuoteContent(
    Map<String, dynamic> quote,
    List<Map<String, dynamic>> items,
    Map<String, dynamic> client,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '見積書',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('見積番号: ${quote['quote_no']}'),
              pw.Text('発行日: ${_formatDate(quote['created_at'])}'),
              pw.Text('有効期限: ${quote['valid_until'] != null ? _formatDate(quote['valid_until']) : '指定なし'}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 顧客情報
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'お客様',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(client['name'] ?? ''),
              if (client['address'] != null) pw.Text(client['address']),
              if (client['tel'] != null) pw.Text('TEL: ${client['tel']}'),
              if (client['email'] != null) pw.Text('Email: ${client['email']}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 明細
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'お見積明細',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildItemsTable(items),
              pw.SizedBox(height: 10),
              _buildTotalSection(quote),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 備考
        if (quote['notes'] != null && quote['notes'].toString().isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '備考',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(quote['notes'].toString()),
              ],
            ),
          ),
        
        // フッター
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.bottomCenter,
            child: pw.Text(
              'この見積書の有効期限は発行日から30日間です',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 受注書コンテンツ構築
  pw.Widget _buildOrderContent(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
    Map<String, dynamic> client,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '受注書',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('受注番号: ${order['order_no']}'),
              pw.Text('受注日: ${_formatDate(order['created_at'])}'),
              if (order['delivery_date'] != null)
                pw.Text('納品予定日: ${_formatDate(order['delivery_date'])}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 顧客情報
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'お客様',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(client['name'] ?? ''),
              if (client['address'] != null) pw.Text(client['address']),
              if (client['tel'] != null) pw.Text('TEL: ${client['tel']}'),
              if (client['email'] != null) pw.Text('Email: ${client['email']}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 明細
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '受注明細',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildItemsTable(items),
              pw.SizedBox(height: 10),
              _buildTotalSection(order),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 備考
        if (order['notes'] != null && order['notes'].toString().isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '備考',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(order['notes'].toString()),
              ],
            ),
          ),
        
        // フッター
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.bottomCenter,
            child: pw.Text(
              'この受注書の内容にご同意いただきありがとうございます',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 納品書コンテンツ構築
  pw.Widget _buildDeliveryContent(
    Map<String, dynamic> delivery,
    List<Map<String, dynamic>> items,
    Map<String, dynamic> client,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '納品書',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('納品番号: ${delivery['delivery_no']}'),
              pw.Text('納品日: ${_formatDate(delivery['delivered_at'] ?? delivery['created_at'])}'),
              if (delivery['tracking_number'] != null)
                pw.Text('追跡番号: ${delivery['tracking_number']}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 顧客情報
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'お客様',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(client['name'] ?? ''),
              if (delivery['delivery_address'] != null)
                pw.Text('納品先: ${delivery['delivery_address']}')
              else if (client['address'] != null)
                pw.Text(client['address']),
              if (client['tel'] != null) pw.Text('TEL: ${client['tel']}'),
              if (client['email'] != null) pw.Text('Email: ${client['email']}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 明細
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '納品明細',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildItemsTable(items),
              pw.SizedBox(height: 10),
              _buildTotalSection(delivery),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 備考
        if (delivery['notes'] != null && delivery['notes'].toString().isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '備考',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(delivery['notes'].toString()),
              ],
            ),
          ),
        
        // フッター
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.bottomCenter,
            child: pw.Text(
              'この納品書を確認の上、商品に問題がないかご確認ください',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 請求書コンテンツ構築
  pw.Widget _buildInvoiceContent(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
    Map<String, dynamic> client,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '請求書',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('請求番号: ${invoice['invoice_no']}'),
              pw.Text('発行日: ${_formatDate(invoice['created_at'])}'),
              if (invoice['due_date'] != null)
                pw.Text('お支払期限: ${_formatDate(invoice['due_date'])}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 顧客情報
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '請求先',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(client['name'] ?? ''),
              if (client['address'] != null) pw.Text(client['address']),
              if (client['tel'] != null) pw.Text('TEL: ${client['tel']}'),
              if (client['email'] != null) pw.Text('Email: ${client['email']}'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 明細
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '請求明細',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildItemsTable(items),
              pw.SizedBox(height: 10),
              _buildTotalSection(invoice),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 支払情報
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'お支払い方法',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text('銀行振込'),
              pw.Text('銀行名: XXX銀行 XXX支店'),
              pw.Text('口座番号: 普通預金 1234567'),
              pw.Text('口座名義: 株式会社XXXX'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // 備考
        if (invoice['notes'] != null && invoice['notes'].toString().isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '備考',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(invoice['notes'].toString()),
              ],
            ),
          ),
        
        // フッター
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.bottomCenter,
            child: pw.Text(
              'お支払期限までにお支払いくださいますようお願い申し上げます',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 明細テーブル
  pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // 品名
        1: const pw.FlexColumnWidth(1), // 数量
        2: const pw.FlexColumnWidth(1), // 単価
        3: const pw.FlexColumnWidth(1), // 金額
      },
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('品名', isHeader: true),
            _buildTableCell('数量', isHeader: true),
            _buildTableCell('単価', isHeader: true),
            _buildTableCell('金額', isHeader: true),
          ],
        ),
        // 明細行
        ...items.map((item) => pw.TableRow(
          children: [
            _buildTableCell(item['product_name'] ?? ''),
            _buildTableCell(item['quantity']?.toString() ?? '0'),
            _buildTableCell(_formatCurrency(item['unit_price'] ?? 0)),
            _buildTableCell(_formatCurrency(item['subtotal'] ?? 0)),
          ],
        )),
      ],
    );
  }
  
  // テーブルセル
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
  
  // 合計セクション
  pw.Widget _buildTotalSection(Map<String, dynamic> document) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('小計: ${_formatCurrency(document['subtotal'] ?? 0)}'),
          pw.Text('消費税: ${_formatCurrency(document['tax'] ?? 0)}'),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              '合計: ${_formatCurrency(document['total'] ?? 0)}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 日付フォーマット
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy年MM月dd日').format(date);
    } catch (e) {
      return dateString;
    }
  }
  
  // 通貨フォーマット
  String _formatCurrency(dynamic amount) {
    try {
      final value = double.tryParse(amount.toString()) ?? 0;
      return '¥${value.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
    } catch (e) {
      return '¥0';
    }
  }
}
