import 'package:flutter/material.dart';
import 'base_document.dart';
import 'supplier_model.dart';
import '../widgets/document_card.dart';

/// 仕入モデル
class Purchase extends BaseDocument {
  final Supplier? supplier;
  final DateTime? dueDate;
  final PurchaseStatus purchaseStatus;
  final PaymentStatus paymentStatus;
  final String? invoiceNumber;
  final String? deliveryLocation;

  Purchase({
    required super.id,
    required super.documentNumber,
    required super.date,
    this.supplier,
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
    this.dueDate,
    this.purchaseStatus = PurchaseStatus.draft,
    this.paymentStatus = PaymentStatus.unpaid,
    this.invoiceNumber,
    this.deliveryLocation,
  });

  @override
  Color getStatusColor(ColorScheme cs) {
    switch (purchaseStatus) {
      case PurchaseStatus.draft:
        return cs.secondary;
      case PurchaseStatus.confirmed:
        return cs.primary;
      case PurchaseStatus.received:
        return cs.tertiary;
      case PurchaseStatus.cancelled:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Color getThemeColor(ColorScheme cs) {
    return cs.secondary;
  }

  @override
  String getDocumentTypeName() {
    return '仕入';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'date': date.toIso8601String(),
      'supplier_id': supplier?.id,
      'due_date': dueDate?.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'tax_rate': taxRate,
      'notes': notes,
      'subject': subject,
      'status': status.name,
      'purchase_status': purchaseStatus.name,
      'payment_status': paymentStatus.name,
      'invoice_number': invoiceNumber,
      'delivery_location': deliveryLocation,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, Supplier? supplier) {
    return Purchase(
      id: map['id'] as String,
      documentNumber: map['document_number'] as String,
      date: DateTime.parse(map['date'] as String),
      supplier: supplier,
      items: [], // 明細は別途読み込み
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
      purchaseStatus: PurchaseStatus.values.firstWhere(
        (e) => e.name == map['purchase_status'],
        orElse: () => PurchaseStatus.draft,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['payment_status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      invoiceNumber: map['invoice_number'] as String?,
      deliveryLocation: map['delivery_location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Purchase copyWith({
    String? id,
    String? documentNumber,
    DateTime? date,
    Supplier? supplier,
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
    DateTime? dueDate,
    PurchaseStatus? purchaseStatus,
    PaymentStatus? paymentStatus,
    String? invoiceNumber,
    String? deliveryLocation,
  }) {
    return Purchase(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      date: date ?? this.date,
      supplier: supplier ?? this.supplier,
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
      dueDate: dueDate ?? this.dueDate,
      purchaseStatus: purchaseStatus ?? this.purchaseStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
    );
  }

  @override
  String getDisplayTitle() {
    return supplier?.displayName ?? '未設定';
  }

  @override
  String getDisplaySubtitle() {
    final parts = <String>[];
    if (subject != null) parts.add(subject!);
    if (invoiceNumber != null) parts.add('請求書番号: $invoiceNumber');
    if (dueDate != null) parts.add('支払期日: ${_formatDate(dueDate!)}');
    return parts.join(' | ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String getPaymentStatusText() {
    switch (paymentStatus) {
      case PaymentStatus.unpaid:
        return '未払';
      case PaymentStatus.partial:
        return '一部支払';
      case PaymentStatus.paid:
        return '支払済';
    }
  }

  Color getPaymentStatusColor() {
    switch (paymentStatus) {
      case PaymentStatus.unpaid:
        return Colors.red;
      case PaymentStatus.partial:
        return Colors.orange;
      case PaymentStatus.paid:
        return Colors.green;
    }
  }
}

/// 仕入ステータス
enum PurchaseStatus {
  draft,      // 下書き
  confirmed,  // 確定
  received,   // 入庫済
  cancelled,  // キャンセル
}

/// 支払ステータス
enum PaymentStatus {
  unpaid,     // 未払
  partial,    // 部分支払
  paid,       // 支払済
}
