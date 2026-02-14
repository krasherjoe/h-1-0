import 'customer_model.dart';
import 'package:intl/intl.dart';

class InvoiceItem {
  String description;
  int quantity;
  int unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  int get subtotal => quantity * unitPrice;
}

class Invoice {
  final String id;
  final Customer customer;
  final DateTime date;
  final List<InvoiceItem> items;
  final String? notes;
  final String? filePath;

  Invoice({
    String? id,
    required this.customer,
    required this.date,
    required this.items,
    this.notes,
    this.filePath,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  String get invoiceNumber => "INV-${DateFormat('yyyyMMdd').format(date)}-${id.substring(id.length > 4 ? id.length - 4 : 0)}";

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  int get tax => (subtotal * 0.1).floor();
  int get totalAmount => subtotal + tax;

  String toCsv() {
    final dateFormatter = DateFormat('yyyy/MM/dd');
    final amountFormatter = NumberFormat("###");
    
    StringBuffer buffer = StringBuffer();
    // ヘッダー (例)
    buffer.writeln("日付,請求番号,取引先,合計金額,備考");
    buffer.writeln("${dateFormatter.format(date)},$invoiceNumber,${customer.formalName},$totalAmount,${notes ?? ""}");
    buffer.writeln("");
    buffer.writeln("品名,数量,単価,小計");
    
    for (var item in items) {
      buffer.writeln("${item.description},${item.quantity},${item.unitPrice},${item.subtotal}");
    }
    
    return buffer.toString();
  }

  Invoice copyWith({
    String? id,
    Customer? customer,
    DateTime? date,
    List<InvoiceItem>? items,
    String? notes,
    String? filePath,
  }) {
    return Invoice(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      date: date ?? this.date,
      items: items ?? List.from(this.items), // コピーを作成
      notes: notes ?? this.notes,
      filePath: filePath ?? this.filePath,
    );
  }
}
