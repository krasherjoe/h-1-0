import 'package:flutter/material.dart';
import 'base_document.dart';
import 'customer_model.dart';
import '../widgets/document_card.dart';

/// 売上モデル
class Sales extends BaseDocument {
  Sales({
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
  });

  @override
  Color getStatusColor() {
    switch (status) {
      case DocumentStatus.draft:
        return Colors.orange;
      case DocumentStatus.confirmed:
        return Colors.green;
      case DocumentStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Color getThemeColor() {
    return Colors.green;
  }

  @override
  String getDocumentTypeName() {
    return '売上';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'date': date.toIso8601String(),
      'customer_id': customer?.id,
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

  factory Sales.fromMap(Map<String, dynamic> map, Customer? customer) {
    return Sales(
      id: map['id'] as String,
      documentNumber: map['document_number'] as String,
      date: DateTime.parse(map['date'] as String),
      customer: customer,
      items: [],
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

  Sales copyWith({
    String? id,
    String? documentNumber,
    DateTime? date,
    Customer? customer,
    List<DocumentItem>? items,
    int? subtotal,
    int? taxAmount,
    int? total,
    double? taxRate,
    String? notes,
    String? subject,
    DocumentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sales(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      taxRate: taxRate ?? this.taxRate,
      notes: notes ?? this.notes,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
