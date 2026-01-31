import 'package:intl/intl.dart';
import 'customer_model.dart';

/// 請求書の各明細行を表すモデル
class InvoiceItem {
  String description;
  int quantity;
  int unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  // 小計 (数量 * 単価)
  int get subtotal => quantity * unitPrice;

  // 編集用のコピーメソッド
  InvoiceItem copyWith({
    String? description,
    int? quantity,
    int? unitPrice,
  }) {
    return InvoiceItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  // JSON変換
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  // JSONから復元
  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description'] as String,
      quantity: json['quantity'] as int,
      unitPrice: json['unit_price'] as int,
    );
  }
}

/// 請求書全体を管理するモデル
class Invoice {
  Customer customer; // 顧客情報
  DateTime date;
  List<InvoiceItem> items;
  String? filePath; // 保存されたPDFのパス
  String invoiceNumber; // 請求書番号
  String? notes; // 備考

  Invoice({
    required this.customer,
    required this.date,
    required this.items,
    this.filePath,
    String? invoiceNumber,
    this.notes,
  }) : invoiceNumber = invoiceNumber ?? DateFormat('yyyyMMdd-HHmm').format(date);

  // 互換性のためのゲッター
  String get clientName => customer.formalName;

  // 税抜合計金額
  int get subtotal {
    return items.fold(0, (sum, item) => sum + item.subtotal);
  }

  // 消費税 (10%固定として計算、端数切り捨て)
  int get tax {
    return (subtotal * 0.1).floor();
  }

  // 税込合計金額
  int get totalAmount {
    return subtotal + tax;
  }

  // 状態更新のためのコピーメソッド
  Invoice copyWith({
    Customer? customer,
    DateTime? date,
    List<InvoiceItem>? items,
    String? filePath,
    String? invoiceNumber,
    String? notes,
  }) {
    return Invoice(
      customer: customer ?? this.customer,
      date: date ?? this.date,
      items: items ?? this.items,
      filePath: filePath ?? this.filePath,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
    );
  }

  // CSV形式への変換
  String toCsv() {
    StringBuffer sb = StringBuffer();
    sb.writeln("Customer,${customer.formalName}");
    sb.writeln("Invoice Number,$invoiceNumber");
    sb.writeln("Date,${DateFormat('yyyy/MM/dd').format(date)}");
    sb.writeln("");
    sb.writeln("Description,Quantity,UnitPrice,Subtotal");
    for (var item in items) {
      sb.writeln("${item.description},${item.quantity},${item.unitPrice},${item.subtotal}");
    }
    return sb.toString();
  }

  // JSON変換 (データベース保存用)
  Map<String, dynamic> toJson() {
    return {
      'customer': customer.toJson(),
      'date': date.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'file_path': filePath,
      'invoice_number': invoiceNumber,
      'notes': notes,
    };
  }

  // JSONから復元 (データベース読み込み用)
  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
      date: DateTime.parse(json['date'] as String),
      items: (json['items'] as List)
          .map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      filePath: json['file_path'] as String?,
      invoiceNumber: json['invoice_number'] as String,
      notes: json['notes'] as String?,
    );
  }
}
