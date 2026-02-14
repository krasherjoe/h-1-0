import 'customer_model.dart';
import 'package:intl/intl.dart';

class InvoiceItem {
  final String? id;
  String description;
  int quantity;
  int unitPrice;

  InvoiceItem({
    this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  int get subtotal => quantity * unitPrice;

  Map<String, dynamic> toMap(String invoiceId) {
    return {
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'invoice_id': invoiceId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      description: map['description'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
    );
  }
}

class Invoice {
  final String id;
  final Customer customer;
  final DateTime date;
  final List<InvoiceItem> items;
  final String? notes;
  final String? filePath;
  final String? odooId;
  final bool isSynced;
  final DateTime updatedAt;

  Invoice({
    String? id,
    required this.customer,
    required this.date,
    required this.items,
    this.notes,
    this.filePath,
    this.odooId,
    this.isSynced = false,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        updatedAt = updatedAt ?? DateTime.now();

  String get invoiceNumber => "INV-${DateFormat('yyyyMMdd').format(date)}-${id.substring(id.length > 4 ? id.length - 4 : 0)}";

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  int get tax => (subtotal * 0.1).floor();
  int get totalAmount => subtotal + tax;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customer.id,
      'date': date.toIso8601String(),
      'notes': notes,
      'file_path': filePath,
      'total_amount': totalAmount,
      'odoo_id': odooId,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 注: fromMap には Customer オブジェクトが必要なため、
  // リポジトリ層で構築することを想定し、ここでは factory は定義しません。

  String toCsv() {
    final dateFormatter = DateFormat('yyyy/MM/dd');
    
    StringBuffer buffer = StringBuffer();
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
    String? odooId,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      date: date ?? this.date,
      items: items ?? List.from(this.items),
      notes: notes ?? this.notes,
      filePath: filePath ?? this.filePath,
      odooId: odooId ?? this.odooId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
