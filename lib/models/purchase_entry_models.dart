import 'package:flutter/foundation.dart';

enum PurchaseEntryStatus { draft, confirmed, settled }

extension PurchaseEntryStatusDisplay on PurchaseEntryStatus {
  String get displayName {
    switch (this) {
      case PurchaseEntryStatus.draft:
        return '下書き';
      case PurchaseEntryStatus.confirmed:
        return '確定';
      case PurchaseEntryStatus.settled:
        return '支払済み';
    }
  }
}

@immutable
class PurchaseLineItem {
  const PurchaseLineItem({
    required this.id,
    required this.purchaseEntryId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productId,
    this.taxRate = 0,
  });

  final String id;
  final String purchaseEntryId;
  final String description;
  final int quantity;
  final int unitPrice;
  final int lineTotal;
  final String? productId;
  final double taxRate;

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_entry_id': purchaseEntryId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'line_total': lineTotal,
      };

  factory PurchaseLineItem.fromMap(Map<String, dynamic> map) => PurchaseLineItem(
        id: map['id'] as String,
        purchaseEntryId: map['purchase_entry_id'] as String,
        productId: map['product_id'] as String?,
        description: map['description'] as String,
        quantity: map['quantity'] as int? ?? 0,
        unitPrice: map['unit_price'] as int? ?? 0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        lineTotal: map['line_total'] as int? ?? 0,
      );

  PurchaseLineItem copyWith({
    String? id,
    String? purchaseEntryId,
    String? description,
    int? quantity,
    int? unitPrice,
    int? lineTotal,
    String? productId,
    double? taxRate,
  }) {
    return PurchaseLineItem(
      id: id ?? this.id,
      purchaseEntryId: purchaseEntryId ?? this.purchaseEntryId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      productId: productId ?? this.productId,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}

@immutable
class PurchaseEntry {
  const PurchaseEntry({
    required this.id,
    required this.issueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.supplierNameSnapshot,
    this.subject,
    this.amountTaxExcl = 0,
    this.taxAmount = 0,
    this.amountTaxIncl = 0,
    this.notes,
    this.items = const [],
  });

  final String id;
  final String? supplierId;
  final String? supplierNameSnapshot;
  final String? subject;
  final DateTime issueDate;
  final PurchaseEntryStatus status;
  final int amountTaxExcl;
  final int taxAmount;
  final int amountTaxIncl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseLineItem> items;

  PurchaseEntry copyWith({
    String? id,
    String? supplierId,
    String? supplierNameSnapshot,
    String? subject,
    DateTime? issueDate,
    PurchaseEntryStatus? status,
    int? amountTaxExcl,
    int? taxAmount,
    int? amountTaxIncl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PurchaseLineItem>? items,
  }) {
    return PurchaseEntry(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierNameSnapshot: supplierNameSnapshot ?? this.supplierNameSnapshot,
      subject: subject ?? this.subject,
      issueDate: issueDate ?? this.issueDate,
      status: status ?? this.status,
      amountTaxExcl: amountTaxExcl ?? this.amountTaxExcl,
      taxAmount: taxAmount ?? this.taxAmount,
      amountTaxIncl: amountTaxIncl ?? this.amountTaxIncl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'supplier_name_snapshot': supplierNameSnapshot,
        'subject': subject,
        'issue_date': issueDate.toIso8601String(),
        'status': status.name,
        'amount_tax_excl': amountTaxExcl,
        'tax_amount': taxAmount,
        'amount_tax_incl': amountTaxIncl,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PurchaseEntry.fromMap(Map<String, dynamic> map, {List<PurchaseLineItem> items = const []}) => PurchaseEntry(
        id: map['id'] as String,
        supplierId: map['supplier_id'] as String?,
        supplierNameSnapshot: map['supplier_name_snapshot'] as String?,
        subject: map['subject'] as String?,
        issueDate: DateTime.parse(map['issue_date'] as String),
        status: PurchaseEntryStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => PurchaseEntryStatus.draft,
        ),
        amountTaxExcl: map['amount_tax_excl'] as int? ?? 0,
        taxAmount: map['tax_amount'] as int? ?? 0,
        amountTaxIncl: map['amount_tax_incl'] as int? ?? 0,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        items: items,
      );

  PurchaseEntry recalcTotals() {
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    final tax = items.fold<double>(0, (sum, item) => sum + item.lineTotal * item.taxRate).round();
    return copyWith(
      amountTaxExcl: subtotal,
      taxAmount: tax,
      amountTaxIncl: subtotal + tax,
    );
  }
}

@immutable
class PurchaseReceiptAllocationInput {
  const PurchaseReceiptAllocationInput({required this.purchaseEntryId, required this.amount});

  final String purchaseEntryId;
  final int amount;
}

@immutable
class PurchaseReceipt {
  const PurchaseReceipt({
    required this.id,
    required this.paymentDate,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.method,
    this.notes,
  });

  final String id;
  final String? supplierId;
  final DateTime paymentDate;
  final String? method;
  final int amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'payment_date': paymentDate.toIso8601String(),
        'method': method,
        'amount': amount,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PurchaseReceipt.fromMap(Map<String, dynamic> map) => PurchaseReceipt(
        id: map['id'] as String,
        supplierId: map['supplier_id'] as String?,
        paymentDate: DateTime.parse(map['payment_date'] as String),
        method: map['method'] as String?,
        amount: map['amount'] as int? ?? 0,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  PurchaseReceipt copyWith({
    String? id,
    String? supplierId,
    DateTime? paymentDate,
    String? method,
    int? amount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseReceipt(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      paymentDate: paymentDate ?? this.paymentDate,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class PurchaseReceiptLink {
  const PurchaseReceiptLink({required this.receiptId, required this.purchaseEntryId, required this.allocatedAmount});

  final String receiptId;
  final String purchaseEntryId;
  final int allocatedAmount;

  Map<String, dynamic> toMap() => {
        'receipt_id': receiptId,
        'purchase_entry_id': purchaseEntryId,
        'allocated_amount': allocatedAmount,
      };

  factory PurchaseReceiptLink.fromMap(Map<String, dynamic> map) => PurchaseReceiptLink(
        receiptId: map['receipt_id'] as String,
        purchaseEntryId: map['purchase_entry_id'] as String,
        allocatedAmount: map['allocated_amount'] as int? ?? 0,
      );
}
