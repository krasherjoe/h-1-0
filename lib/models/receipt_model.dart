/// 入金実績モデル（得意先入金）
class Receipt {
  final String id;
  final String invoiceId; // 紐づく請求書ID
  final int amount; // 入金金額
  final DateTime receiptDate; // 入金日
  final String? paymentMethod; // 入金方法（振込、現金、手形等）
  final String? notes; // 備考
  final DateTime createdAt;
  final DateTime updatedAt;

  Receipt({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.receiptDate,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'amount': amount,
      'receipt_date': receiptDate.toIso8601String(),
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as String,
      invoiceId: map['invoice_id'] as String,
      amount: map['amount'] as int,
      receiptDate: DateTime.parse(map['receipt_date'] as String),
      paymentMethod: map['payment_method'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Receipt copyWith({
    String? id,
    String? invoiceId,
    int? amount,
    DateTime? receiptDate,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      receiptDate: receiptDate ?? this.receiptDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
