import 'customer_model.dart';
import 'package:intl/intl.dart';

class InvoiceItem {
  final String description;
  final num quantity;
  final int unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  int get subtotal => (quantity * unitPrice).floor();
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

  String get invoiceNumber => "INV-${DateFormat('yyyyMMdd').format(date)}-${id.substring(id.length - 4)}";

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  int get tax => (subtotal * 0.1).floor();
  int get totalAmount => subtotal + tax;

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
      items: items ?? this.items,
      notes: notes ?? this.notes,
      filePath: filePath ?? this.filePath,
    );
  }
}
