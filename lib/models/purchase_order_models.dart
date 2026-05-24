import 'package:flutter/foundation.dart';

enum PurchaseOrderStatus { draft, approved, partiallyReceived, received, cancelled }

extension PurchaseOrderStatusDisplay on PurchaseOrderStatus {
  String get displayName {
    switch (this) {
      case PurchaseOrderStatus.draft:
        return '下書き';
      case PurchaseOrderStatus.approved:
        return '承認済み';
      case PurchaseOrderStatus.partiallyReceived:
        return '一部入荷';
      case PurchaseOrderStatus.received:
        return '入荷完了';
      case PurchaseOrderStatus.cancelled:
        return 'キャンセル';
    }
  }
}

@immutable
class PurchaseOrderItem {
  const PurchaseOrderItem({
    required this.id,
    required this.orderId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productId,
    this.taxRate = 0,
    this.isTaxInclusive = false,
    this.subject,
    this.projectId,
  });

  final String id;
  final String orderId;
  final String? productId;
  final String description;
  final int quantity;
  final int unitPrice;
  final double taxRate;
  final int lineTotal;
  final bool isTaxInclusive;
  final String? subject;
  final String? projectId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'line_total': lineTotal,
        'is_tax_inclusive': isTaxInclusive ? 1 : 0,
        'subject': subject,
        'project_id': projectId,
      };

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) => PurchaseOrderItem(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        productId: map['product_id'] as String?,
        description: map['description'] as String,
        quantity: map['quantity'] as int? ?? 0,
        unitPrice: map['unit_price'] as int? ?? 0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        lineTotal: map['line_total'] as int? ?? 0,
        isTaxInclusive: (map['is_tax_inclusive'] ?? 0) == 1,
        subject: map['subject'] as String?,
        projectId: map['project_id'] as String?,
      );
}

@immutable
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.documentNumber,
    required this.orderDate,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.supplierSnapshot,
    this.expectedDate,
    this.notes,
    this.subject,
    this.projectId,
    this.paymentMethod,
    this.representativeId,
    this.representativeName,
    this.reimbursementStatus,
    this.items = const [],
  });

  final String id;
  final String documentNumber;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final PurchaseOrderStatus status;
  final int subtotal;
  final int taxAmount;
  final int total;
  final String? supplierId;
  final String? supplierSnapshot;
  final String? notes;
  final String? subject;
  final String? projectId;
  final String? paymentMethod;
  final String? representativeId;
  final String? representativeName;
  final String? reimbursementStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseOrderItem> items;

  bool get isRepresentativeCard => representativeId != null;

  PurchaseOrder copyWith({
    String? id,
    String? documentNumber,
    DateTime? orderDate,
    DateTime? expectedDate,
    PurchaseOrderStatus? status,
    int? subtotal,
    int? taxAmount,
    int? total,
    String? supplierId,
    String? supplierSnapshot,
    String? notes,
    String? subject,
    String? projectId,
    String? paymentMethod,
    String? representativeId,
    String? representativeName,
    String? reimbursementStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PurchaseOrderItem>? items,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      orderDate: orderDate ?? this.orderDate,
      expectedDate: expectedDate ?? this.expectedDate,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      supplierId: supplierId ?? this.supplierId,
      supplierSnapshot: supplierSnapshot ?? this.supplierSnapshot,
      notes: notes ?? this.notes,
      subject: subject ?? this.subject,
      projectId: projectId ?? this.projectId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      representativeId: representativeId ?? this.representativeId,
      representativeName: representativeName ?? this.representativeName,
      reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_number': documentNumber,
        'order_date': orderDate.toIso8601String(),
        'expected_date': expectedDate?.toIso8601String(),
        'status': status.name,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total': total,
        'supplier_id': supplierId,
        'supplier_snapshot': supplierSnapshot,
        'notes': notes,
        'subject': subject,
        'payment_method': paymentMethod,
        'representative_id': representativeId,
        'representative_name': representativeName,
        'reimbursement_status': reimbursementStatus,
        'project_id': projectId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, {List<PurchaseOrderItem> items = const []}) => PurchaseOrder(
        id: map['id'] as String,
        documentNumber: map['document_number'] as String,
        orderDate: DateTime.parse(map['order_date'] as String),
        expectedDate: map['expected_date'] != null ? DateTime.parse(map['expected_date'] as String) : null,
        paymentMethod: map['payment_method'] as String?,
        representativeId: map['representative_id'] as String?,
        representativeName: map['representative_name'] as String?,
        reimbursementStatus: map['reimbursement_status'] as String?,
        status: PurchaseOrderStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => PurchaseOrderStatus.draft,
        ),
        subtotal: map['subtotal'] as int? ?? 0,
        taxAmount: map['tax_amount'] as int? ?? 0,
        total: map['total'] as int? ?? 0,
        supplierId: map['supplier_id'] as String?,
        supplierSnapshot: map['supplier_snapshot'] as String?,
        notes: map['notes'] as String?,
        subject: map['subject'] as String?,
        projectId: map['project_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        items: items,
      );

  PurchaseOrder recalcTotals() {
    int newSubtotal = 0;
    int newTax = 0;
    for (final item in items) {
      final lineTotal = item.lineTotal;
      if (item.isTaxInclusive) {
        final rate = item.taxRate;
        final ex = (lineTotal / (1 + rate)).round();
        newSubtotal += ex;
        newTax += lineTotal - ex;
      } else {
        newSubtotal += lineTotal;
        newTax += (lineTotal * item.taxRate).round();
      }
    }
    return copyWith(subtotal: newSubtotal, taxAmount: newTax, total: newSubtotal + newTax);
  }
}

enum PurchaseReturnStatus { draft, pendingApproval, processed, cancelled }

extension PurchaseReturnStatusDisplay on PurchaseReturnStatus {
  String get displayName {
    switch (this) {
      case PurchaseReturnStatus.draft:
        return '下書き';
      case PurchaseReturnStatus.pendingApproval:
        return '承認待ち';
      case PurchaseReturnStatus.processed:
        return '処理済み';
      case PurchaseReturnStatus.cancelled:
        return 'キャンセル';
    }
  }
}

@immutable
class PurchaseReturnItem {
  const PurchaseReturnItem({
    required this.id,
    required this.returnId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productId,
    this.taxRate = 0,
  });

  final String id;
  final String returnId;
  final String? productId;
  final String description;
  final int quantity;
  final int unitPrice;
  final double taxRate;
  final int lineTotal;

  Map<String, dynamic> toMap() => {
        'id': id,
        'return_id': returnId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'line_total': lineTotal,
      };

  factory PurchaseReturnItem.fromMap(Map<String, dynamic> map) => PurchaseReturnItem(
        id: map['id'] as String,
        returnId: map['return_id'] as String,
        productId: map['product_id'] as String?,
        description: map['description'] as String,
        quantity: map['quantity'] as int? ?? 0,
        unitPrice: map['unit_price'] as int? ?? 0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        lineTotal: map['line_total'] as int? ?? 0,
      );
}

@immutable
class PurchaseReturn {
  const PurchaseReturn({
    required this.id,
    required this.documentNumber,
    required this.returnDate,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.supplierSnapshot,
    this.notes,
    this.items = const [],
  });

  final String id;
  final String documentNumber;
  final DateTime returnDate;
  final PurchaseReturnStatus status;
  final int subtotal;
  final int taxAmount;
  final int total;
  final String? supplierId;
  final String? supplierSnapshot;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseReturnItem> items;

  PurchaseReturn copyWith({
    String? id,
    String? documentNumber,
    DateTime? returnDate,
    PurchaseReturnStatus? status,
    int? subtotal,
    int? taxAmount,
    int? total,
    String? supplierId,
    String? supplierSnapshot,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PurchaseReturnItem>? items,
  }) {
    return PurchaseReturn(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      supplierId: supplierId ?? this.supplierId,
      supplierSnapshot: supplierSnapshot ?? this.supplierSnapshot,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_number': documentNumber,
        'return_date': returnDate.toIso8601String(),
        'status': status.name,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total': total,
        'supplier_id': supplierId,
        'supplier_snapshot': supplierSnapshot,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PurchaseReturn.fromMap(Map<String, dynamic> map, {List<PurchaseReturnItem> items = const []}) => PurchaseReturn(
        id: map['id'] as String,
        documentNumber: map['document_number'] as String,
        returnDate: DateTime.parse(map['return_date'] as String),
        status: PurchaseReturnStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => PurchaseReturnStatus.draft,
        ),
        subtotal: map['subtotal'] as int? ?? 0,
        taxAmount: map['tax_amount'] as int? ?? 0,
        total: map['total'] as int? ?? 0,
        supplierId: map['supplier_id'] as String?,
        supplierSnapshot: map['supplier_snapshot'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        items: items,
      );

  PurchaseReturn recalcTotals() {
    final newSubtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    final newTax = items.fold<double>(0, (sum, item) => sum + item.lineTotal * item.taxRate).round();
    return copyWith(subtotal: newSubtotal, taxAmount: newTax, total: newSubtotal + newTax);
  }
}

enum PurchasePaymentStatus { scheduled, paid, cancelled }

extension PurchasePaymentStatusDisplay on PurchasePaymentStatus {
  String get displayName {
    switch (this) {
      case PurchasePaymentStatus.scheduled:
        return '予定';
      case PurchasePaymentStatus.paid:
        return '支払済';
      case PurchasePaymentStatus.cancelled:
        return 'キャンセル';
    }
  }
}

@immutable
class PurchasePayment {
  const PurchasePayment({
    required this.id,
    required this.paymentDate,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.purchaseOrderId,
    this.supplierId,
    this.method,
    this.notes,
    this.representativeId,
    this.representativeName,
    this.reimbursementStatus,
    this.reimbursementDate,
  });

  final String id;
  final String? purchaseOrderId;
  final String? supplierId;
  final DateTime paymentDate;
  final int amount;
  final String? method;
  final PurchasePaymentStatus status;
  final String? notes;
  final String? representativeId;
  final String? representativeName;
  final String? reimbursementStatus;
  final DateTime? reimbursementDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAdvancePayment => method == '代表者立替';
  bool get isReimbursed => reimbursementStatus == 'paid';

  PurchasePayment copyWith({
    String? id,
    String? purchaseOrderId,
    String? supplierId,
    DateTime? paymentDate,
    int? amount,
    String? method,
    PurchasePaymentStatus? status,
    String? notes,
    String? representativeId,
    String? representativeName,
    String? reimbursementStatus,
    DateTime? reimbursementDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchasePayment(
      id: id ?? this.id,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      supplierId: supplierId ?? this.supplierId,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      representativeId: representativeId ?? this.representativeId,
      representativeName: representativeName ?? this.representativeName,
      reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
      reimbursementDate: reimbursementDate ?? this.reimbursementDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_order_id': purchaseOrderId,
        'supplier_id': supplierId,
        'payment_date': paymentDate.toIso8601String(),
        'amount': amount,
        'method': method,
        'status': status.name,
        'notes': notes,
        'representative_id': representativeId,
        'representative_name': representativeName,
        'reimbursement_status': reimbursementStatus,
        'reimbursement_date': reimbursementDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PurchasePayment.fromMap(Map<String, dynamic> map) => PurchasePayment(
        id: map['id'] as String,
        purchaseOrderId: map['purchase_order_id'] as String?,
        supplierId: map['supplier_id'] as String?,
        paymentDate: DateTime.parse(map['payment_date'] as String),
        amount: map['amount'] as int? ?? 0,
        method: map['method'] as String?,
        status: PurchasePaymentStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => PurchasePaymentStatus.scheduled,
        ),
        notes: map['notes'] as String?,
        representativeId: map['representative_id'] as String?,
        representativeName: map['representative_name'] as String?,
        reimbursementStatus: map['reimbursement_status'] as String?,
        reimbursementDate: map['reimbursement_date'] != null
            ? DateTime.tryParse(map['reimbursement_date'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
