import 'package:flutter/material.dart';
import 'supplier_model.dart';

/// 支払実績モデル
class Payment {
  final String id;
  final String paymentNumber;    // 支払番号
  final DateTime paymentDate;      // 支払日
  final Supplier supplier;        // 仕入先
  final int amount;              // 支払金額
  final PaymentMethod paymentMethod; // 支払方法
  final String? bankAccount;     // 振込口座
  final List<String> purchaseIds; // 対象仕入IDリスト
  final String? notes;           // 備考
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.paymentNumber,
    required this.paymentDate,
    required this.supplier,
    required this.amount,
    required this.paymentMethod,
    this.bankAccount,
    this.purchaseIds = const [],
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// MapからPaymentを生成
  factory Payment.fromMap(Map<String, dynamic> map, Supplier supplier) {
    return Payment(
      id: map['id'] as String,
      paymentNumber: map['payment_number'] as String,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      supplier: supplier,
      amount: map['amount'] as int,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.bankTransfer,
      ),
      bankAccount: map['bank_account'],
      purchaseIds: (map['purchase_ids'] as String?)?.split(',') ?? [],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// PaymentをMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payment_number': paymentNumber,
      'payment_date': paymentDate.toIso8601String(),
      'supplier_id': supplier.id,
      'amount': amount,
      'payment_method': paymentMethod.name,
      'bank_account': bankAccount,
      'purchase_ids': purchaseIds.join(','),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Paymentをコピー
  Payment copyWith({
    String? id,
    String? paymentNumber,
    DateTime? paymentDate,
    Supplier? supplier,
    int? amount,
    PaymentMethod? paymentMethod,
    String? bankAccount,
    List<String>? purchaseIds,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      paymentDate: paymentDate ?? this.paymentDate,
      supplier: supplier ?? this.supplier,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankAccount: bankAccount ?? this.bankAccount,
      purchaseIds: purchaseIds ?? this.purchaseIds,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 表示用金額
  String get displayAmount => '¥${amount.toString().replaceAllMapped(
    RegExp(r'(?=(?!^)(\d{3})+$)'),
    (Match m) => ',',
  )}';

  /// 支払方法の表示名
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case PaymentMethod.bankTransfer:
        return '銀行振込';
      case PaymentMethod.cash:
        return '現金';
      case PaymentMethod.creditCard:
        return 'クレジットカード';
      case PaymentMethod.other:
        return 'その他';
    }
  }

  /// 表示用タイトル
  String get displayTitle => '$paymentNumber - ${supplier.displayName}';

  /// 表示用サブタイトル
  String get displaySubtitle => '${paymentDate.year}/${paymentDate.month}/${paymentDate.day} ${paymentMethodDisplayName}';

  /// テーマカラー
  Color getThemeColor(ColorScheme cs) {
    switch (paymentMethod) {
      case PaymentMethod.bankTransfer:
        return cs.primary;
      case PaymentMethod.cash:
        return cs.tertiary;
      case PaymentMethod.creditCard:
        return cs.secondary;
      case PaymentMethod.other:
        return cs.onSurfaceVariant;
    }
  }
}

/// 支払方法
enum PaymentMethod {
  bankTransfer,  // 銀行振込
  cash,          // 現金
  creditCard,    // クレジットカード
  other,         // その他
}
