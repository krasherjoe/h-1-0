import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:intl/intl.dart';
import '../models/sales_flow_models.dart';

/// メール通知サービス
class EmailNotificationService {
  static final EmailNotificationService _instance = EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();
  
  // SMTPサーバー設定（実際には設定ファイルから読み込む）
  late final SmtpServer _smtpServer;
  
  void initialize() {
    // 開発環境用のダミー設定
    _smtpServer = SmtpServer(
      'smtp.example.com',
      username: 'noreply@example.com',
      password: 'password',
      port: 587,
      ignoreBadCertificate: true,
    );
  }
  
  // 見積提出通知
  Future<bool> sendQuoteSubmittedNotification({
    required Map<String, dynamic> quote,
    required Map<String, dynamic> client,
    required File quotePdf,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '見積管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '見積書のご提出【${quote['quote_no']}】'
        ..html = _buildQuoteSubmittedHtml(quote, client)
        ..attachments = [FileAttachment(quotePdf)];
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('見積提出メール送信エラー: $e');
      return false;
    }
  }
  
  // 見積承認通知
  Future<bool> sendQuoteApprovedNotification({
    required Map<String, dynamic> quote,
    required Map<String, dynamic> client,
    required File quotePdf,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '見積管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '見積書の承認【${quote['quote_no']}】'
        ..html = _buildQuoteApprovedHtml(quote, client)
        ..attachments = [FileAttachment(quotePdf)];
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('見積承認メール送信エラー: $e');
      return false;
    }
  }
  
  // 受注確定通知
  Future<bool> sendOrderConfirmedNotification({
    required Map<String, dynamic> order,
    required Map<String, dynamic> client,
    required File orderPdf,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '受注管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '受注確定のお知らせ【${order['order_no']}】'
        ..html = _buildOrderConfirmedHtml(order, client)
        ..attachments = [FileAttachment(orderPdf)];
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('受注確定メール送信エラー: $e');
      return false;
    }
  }
  
  // 配送開始通知
  Future<bool> sendDeliveryShippedNotification({
    required Map<String, dynamic> delivery,
    required Map<String, dynamic> client,
    String? trackingUrl,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '配送管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '商品発送のお知らせ【${delivery['delivery_no']}】'
        ..html = _buildDeliveryShippedHtml(delivery, client, trackingUrl);
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('配送開始メール送信エラー: $e');
      return false;
    }
  }
  
  // 配送完了通知
  Future<bool> sendDeliveryCompletedNotification({
    required Map<String, dynamic> delivery,
    required Map<String, dynamic> client,
    required File deliveryPdf,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '配送管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '商品配送完了のお知らせ【${delivery['delivery_no']}】'
        ..html = _buildDeliveryCompletedHtml(delivery, client)
        ..attachments = [FileAttachment(deliveryPdf)];
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('配送完了メール送信エラー: $e');
      return false;
    }
  }
  
  // 請求書発行通知
  Future<bool> sendInvoiceIssuedNotification({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> client,
    required File invoicePdf,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '請求管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '請求書発行のお知らせ【${invoice['invoice_no']}】'
        ..html = _buildInvoiceIssuedHtml(invoice, client)
        ..attachments = [FileAttachment(invoicePdf)];
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('請求書発行メール送信エラー: $e');
      return false;
    }
  }
  
  // 請求期限通知
  Future<bool> sendInvoiceDueNotification({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> client,
    required File invoicePdf,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '請求管理システム')
        ..recipients.add(client['email'] ?? '')
        ..subject = '【重要】お支払期限のお知らせ【${invoice['invoice_no']}】'
        ..html = _buildInvoiceDueHtml(invoice, client)
        ..attachments = [FileAttachment(invoicePdf)];
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('請求期限メール送信エラー: $e');
      return false;
    }
  }
  
  // 在庫不足通知（内部通知）
  Future<bool> sendStockShortageNotification({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> shortageItems,
  }) async {
    try {
      final message = Message()
        ..from = Address('noreply@example.com', '在庫管理システム')
        ..recipients.add('inventory@example.com') // 在庫管理者宛
        ..subject = '【警告】在庫不足のお知らせ【${order['order_no']}】'
        ..html = _buildStockShortageHtml(order, shortageItems);
      
      final sendReport = await send(message, _smtpServer);
      return sendReport.success;
    } catch (e) {
      print('在庫不足メール送信エラー: $e');
      return false;
    }
  }
  
  // 見積提出HTML
  String _buildQuoteSubmittedHtml(Map<String, dynamic> quote, Map<String, dynamic> client) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #f5f5f5; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
            .button { background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>見積書のご提出</h1>
            <p>お世話になっております。<br>見積書を作成いたしましたので、ご確認ください。</p>
          </div>
          
          <div class="content">
            <h2>見積情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>見積番号</td><td>${quote['quote_no']}</td></tr>
              <tr><td>発行日</td><td>${_formatDate(quote['created_at'])}</td></tr>
              <tr><td>有効期限</td><td>${quote['valid_until'] != null ? _formatDate(quote['valid_until']) : '指定なし'}</td></tr>
              <tr><td>合計金額</td><td>${_formatCurrency(quote['total'])}</td></tr>
            </table>
            
            <h3>お客様情報</h3>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>お名前</td><td>${client['name'] ?? ''}</td></tr>
              <tr><td>住所</td><td>${client['address'] ?? ''}</td></tr>
              <tr><td>電話番号</td><td>${client['tel'] ?? ''}</td></tr>
            </table>
          </div>
          
          <div class="footer">
            <p>詳細は添付のPDFファイルをご確認ください。</p>
            <p>ご不明な点がございましたら、お気軽にお問い合わせください。</p>
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 見積承認HTML
  String _buildQuoteApprovedHtml(Map<String, dynamic> quote, Map<String, dynamic> client) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #28a745; color: white; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>見積書が承認されました</h1>
            <p>お世話になっております。<br>見積書が承認されました。</p>
          </div>
          
          <div class="content">
            <h2>見積情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>見積番号</td><td>${quote['quote_no']}</td></tr>
              <tr><td>承認日</td><td>${_formatDate(DateTime.now().toIso8601String())}</td></tr>
              <tr><td>合計金額</td><td>${_formatCurrency(quote['total'])}</td></tr>
            </table>
            
            <p>承認された見積書を添付いたします。</p>
            <p>今後の流れにつきましては、別途ご連絡いたします。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 受注確定HTML
  String _buildOrderConfirmedHtml(Map<String, dynamic> order, Map<String, dynamic> client) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #007bff; color: white; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>受注が確定いたしました</h1>
            <p>お世話になっております。<br>受注が確定いたしました。</p>
          </div>
          
          <div class="content">
            <h2>受注情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>受注番号</td><td>${order['order_no']}</td></tr>
              <tr><td>受注日</td><td>${_formatDate(order['created_at'])}</td></tr>
              <tr><td>納品予定日</td><td>${order['delivery_date'] != null ? _formatDate(order['delivery_date']) : '未定'}</td></tr>
              <tr><td>合計金額</td><td>${_formatCurrency(order['total'])}</td></tr>
            </table>
            
            <p>確定した受注書を添付いたします。</p>
            <p>商品の準備が整いましたら、配送についてご連絡いたします。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 配送開始HTML
  String _buildDeliveryShippedHtml(Map<String, dynamic> delivery, Map<String, dynamic> client, String? trackingUrl) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #ffc107; color: black; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
            .button { background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>商品を発送いたしました</h1>
            <p>お世話になっております。<br>商品を発送いたしました。</p>
          </div>
          
          <div class="content">
            <h2>配送情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>配送番号</td><td>${delivery['delivery_no']}</td></tr>
              <tr><td>発送日</td><td>${_formatDate(delivery['created_at'])}</td></tr>
              ${delivery['tracking_number'] != null ? '<tr><td>追跡番号</td><td>${delivery['tracking_number']}</td></tr>' : ''}
            </table>
            
            ${trackingUrl != null ? '<p><a href="$trackingUrl" class="button">配送状況を確認</a></p>' : ''}
            
            <p>商品の到着まで今しばらくお待ちください。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 配送完了HTML
  String _buildDeliveryCompletedHtml(Map<String, dynamic> delivery, Map<String, dynamic> client) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #28a745; color: white; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>商品が配送完了いたしました</h1>
            <p>お世話になっております。<br>商品が配送完了いたしました。</p>
          </div>
          
          <div class="content">
            <h2>配送情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>配送番号</td><td>${delivery['delivery_no']}</td></tr>
              <tr><td>配送完了日</td><td>${_formatDate(delivery['delivered_at'] ?? DateTime.now().toIso8601String())}</td></tr>
              ${delivery['tracking_number'] != null ? '<tr><td>追跡番号</td><td>${delivery['tracking_number']}</td></tr>' : ''}
            </table>
            
            <p>商品が無事に届きましたら、ご確認をお願いいたします。</p>
            <p>納品書を添付いたしますので、ご確認ください。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 請求書発行HTML
  String _buildInvoiceIssuedHtml(Map<String, dynamic> invoice, Map<String, dynamic> client) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #6f42c1; color: white; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
            .important { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 5px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>請求書を発行いたしました</h1>
            <p>お世話になっております。<br>請求書を発行いたしました。</p>
          </div>
          
          <div class="content">
            <h2>請求情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>請求番号</td><td>${invoice['invoice_no']}</td></tr>
              <tr><td>発行日</td><td>${_formatDate(invoice['created_at'])}</td></tr>
              <tr><td>お支払期限</td><td>${invoice['due_date'] != null ? _formatDate(invoice['due_date']) : '未定'}</td></tr>
              <tr><td>請求金額</td><td>${_formatCurrency(invoice['total'])}</td></tr>
            </table>
            
            <div class="important">
              <h3>お支払い方法</h3>
              <p>銀行振込</p>
              <p>銀行名: XXX銀行 XXX支店</p>
              <p>口座番号: 普通預金 1234567</p>
              <p>口座名義: 株式会社XXXX</p>
            </div>
            
            <p>請求書を添付いたしますので、お支払期限までにお支払いくださいますようお願い申し上げます。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 請求期限HTML
  String _buildInvoiceDueHtml(Map<String, dynamic> invoice, Map<String, dynamic> client) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #dc3545; color: white; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
            .urgent { background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 10px; border-radius: 5px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>【重要】お支払期限のお知らせ</h1>
            <p>お世話になっております。<br>お支払期限が近づいております。</p>
          </div>
          
          <div class="content">
            <div class="urgent">
              <h2>お支払期限が迫っています</h2>
              <p>請求番号: ${invoice['invoice_no']}</p>
              <p>お支払期限: ${invoice['due_date'] != null ? _formatDate(invoice['due_date']) : '未定'}</p>
              <p>請求金額: ${_formatCurrency(invoice['total'])}</p>
            </div>
            
            <p>お支払期限までにお支払いくださいますようお願い申し上げます。</p>
            <p>既にお支払い済みの場合は、お手数ですが本メールを破棄してください。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            株式会社XXXX<br>
            住所: XXXX<br>
            電話: XXXX<br>
            Email: XXXX</p>
          </div>
        </body>
      </html>
    ''';
  }
  
  // 在庫不足HTML
  String _buildStockShortageHtml(Map<String, dynamic> order, List<Map<String, dynamic>> shortageItems) {
    return '''
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #dc3545; color: white; padding: 20px; border-radius: 5px; }
            .content { margin: 20px 0; }
            .footer { background-color: #f5f5f5; padding: 20px; border-radius: 5px; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>【警告】在庫不足のお知らせ</h1>
            <p>受注に対して在庫が不足しています。</p>
          </div>
          
          <div class="content">
            <h2>受注情報</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><td>受注番号</td><td>${order['order_no']}</td></tr>
              <tr><td>受注日</td><td>${_formatDate(order['created_at'])}</td></tr>
            </table>
            
            <h2>在庫不足商品</h2>
            <table border="1" style="border-collapse: collapse;">
              <tr><th>商品名</th><th>必要数量</th><th>在庫数量</th></tr>
              ${shortageItems.map((item) => '''
                <tr>
                  <td>${item['product_name']}</td>
                  <td>${item['required_quantity']}</td>
                  <td>${item['available_quantity']}</td>
                </tr>
              ''').join('')}
            </table>
            
            <p>速やかに在庫補充をご検討ください。</p>
          </div>
          
          <div class="footer">
            <p>─────────────────────<br>
            在庫管理システム</p>
          </div>
        </body>
      </html>
    ''';
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
