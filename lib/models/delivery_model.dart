import 'package:flutter/material.dart';
import 'base_document.dart';
import '../widgets/document_card.dart';
import 'customer_model.dart';

class Delivery extends BaseDocument {
  final String deliveryAddress;
  final String? deliveryNote;

  Delivery({
    required super.id,
    required super.documentNumber,
    required super.date,
    super.customer,
    required super.items,
    required super.subtotal,
    required super.taxAmount,
    required super.total,
    required super.taxRate,
    super.notes,
    super.subject,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    required this.deliveryAddress,
    this.deliveryNote,
  });

  @override
  Color getStatusColor() {
    switch (status) {
      case DocumentStatus.draft:
        return Colors.grey;
      case DocumentStatus.confirmed:
        return Colors.blue;
      case DocumentStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Color getThemeColor() => Colors.green;

  @override
  String getDocumentTypeName() => '配送';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'date': date.toIso8601String(),
      'customer_id': customer?.id,
      'delivery_address': deliveryAddress,
      'delivery_note': deliveryNote,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'tax_rate': taxRate,
      'notes': notes,
      'subject': subject,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map, Customer? customer) {
    return Delivery(
      id: map['id'] as String,
      documentNumber: map['document_number'] as String,
      date: DateTime.parse(map['date'] as String),
      customer: customer,
      items: [],
      deliveryAddress: map['delivery_address'] as String,
      deliveryNote: map['delivery_note'] as String?,
      subtotal: map['subtotal'] as int,
      taxAmount: map['tax_amount'] as int,
      total: map['total'] as int,
      taxRate: (map['tax_rate'] as num).toDouble(),
      notes: map['notes'] as String?,
      subject: map['subject'] as String?,
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DocumentStatus.draft,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
