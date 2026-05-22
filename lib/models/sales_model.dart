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
    this.invoiceIds,
    this.paymentDueDate,
    this.paymentMethod,
    required super.createdAt,
    required super.updatedAt,
  });

  final List<String>? invoiceIds; // 紐づく請求書IDリスト（複数対応）
  final DateTime? paymentDueDate; // 入金予定日
  final String? paymentMethod; // 支払方法
  int? grossProfit; // 粗利額（計算済み）

  @override
  Color getStatusColor(ColorScheme cs) {
    switch (status) {
      case DocumentStatus.draft:
        return cs.secondary;
      case DocumentStatus.confirmed:
        return cs.tertiary;
      case DocumentStatus.cancelled:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Color getThemeColor(ColorScheme cs) {
    return cs.tertiary;
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
      'invoice_ids': invoiceIds != null ? invoiceIds!.join(',') : null,
      'payment_due_date': paymentDueDate?.toIso8601String(),
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Sales.fromMap(Map<String, dynamic> map, Customer? customer) {
    final invoiceIdsStr = map['invoice_ids'] as String?;
    List<String>? invoiceIds;
    if (invoiceIdsStr?.isNotEmpty ?? false) {
      invoiceIds = invoiceIdsStr!.split(',');
    }

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
      invoiceIds: invoiceIds,
      paymentDueDate: map['payment_due_date'] != null ? DateTime.parse(map['payment_due_date'] as String) : null,
      paymentMethod: map['payment_method'] as String?,
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
    List<String>? invoiceIds,
    DateTime? paymentDueDate,
    String? paymentMethod,
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
      invoiceIds: invoiceIds ?? this.invoiceIds,
      paymentDueDate: paymentDueDate ?? this.paymentDueDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
