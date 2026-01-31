import 'package:intl/intl.dart';

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
}

/// 請求書全体を管理するモデル
class Invoice {
  String clientName;
  DateTime date;
  List<InvoiceItem> items;
  String? filePath; // 保存されたPDFのパス
  String invoiceNumber; // 請求書番号
  String? notes; // 備考

  Invoice({
    required this.clientName,
    required this.date,
    required this.items,
    this.filePath,
    String? invoiceNumber,
    this.notes,
  }) : invoiceNumber = invoiceNumber ?? DateFormat('yyyyMMdd-HHmm').format(date);

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
    String? clientName,
    DateTime? date,
    List<InvoiceItem>? items,
    String? filePath,
    String? invoiceNumber,
    String? notes,
  }) {
    return Invoice(
      clientName: clientName ?? this.clientName,
      date: date ?? this.date,
      items: items ?? this.items,
      filePath: filePath ?? this.filePath,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
    );
  }

  // CSV形式への変換 (将来的なCSV編集用)
  String toCsv() {
    StringBuffer sb = StringBuffer();
    sb.writeln("Description,Quantity,UnitPrice,Subtotal");
    for (var item in items) {
      sb.writeln("${item.description},${item.quantity},${item.unitPrice},${item.subtotal}");
    }
    return sb.toString();
  }
}
