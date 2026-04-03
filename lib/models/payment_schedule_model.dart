import 'package:flutter/material.dart';
import 'purchase_model.dart';

/// 支払予定モデル
class PaymentSchedule {
  final String id;
  final Purchase purchase;       // 対象仕入
  final DateTime dueDate;         // 支払期日
  final int amount;              // 支払金額
  final PaymentStatus status;     // 支払ステータス
  final DateTime? paidDate;      // 支払日
  final String? paymentId;       // 支払実績ID
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentSchedule({
    required this.id,
    required this.purchase,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidDate,
    this.paymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// MapからPaymentScheduleを生成
  factory PaymentSchedule.fromMap(Map<String, dynamic> map, Purchase purchase) {
    return PaymentSchedule(
      id: map['id'] as String,
      purchase: purchase,
      dueDate: DateTime.parse(map['due_date'] as String),
      amount: map['amount'] as int,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      paidDate: map['paid_date'] != null ? DateTime.parse(map['paid_date']) : null,
      paymentId: map['payment_id'],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// PaymentScheduleをMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchase.id,
      'due_date': dueDate.toIso8601String(),
      'amount': amount,
      'status': status.name,
      'paid_date': paidDate?.toIso8601String(),
      'payment_id': paymentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// PaymentScheduleをコピー
  PaymentSchedule copyWith({
    String? id,
    Purchase? purchase,
    DateTime? dueDate,
    int? amount,
    PaymentStatus? status,
    DateTime? paidDate,
    String? paymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentSchedule(
      id: id ?? this.id,
      purchase: purchase ?? this.purchase,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 表示用金額
  String get displayAmount => '¥${amount.toString().replaceAllMapped(
    RegExp(r'(?=(?!^)(\d{3})+$)'),
    (Match m) => ',',
  )}';

  /// ステータスの表示名
  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.unpaid:
        return '未払';
      case PaymentStatus.partial:
        return '部分支払';
      case PaymentStatus.paid:
        return '支払済';
      case PaymentStatus.overdue:
        return '延滞';
    }
  }

  /// 表示用タイトル
  String get displayTitle => '${purchase.documentNumber} - ${purchase.supplier?.displayName ?? '不明'}';

  /// 表示用サブタイトル
  String get displaySubtitle => '期日: ${dueDate.year}/${dueDate.month}/${dueDate.day} - ${statusDisplayName}';

  /// 期日までの日数
  int get daysUntilDue {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    return difference;
  }

  /// 延滞かどうか
  bool get isOverdue {
    final now = DateTime.now();
    return now.isAfter(dueDate) && status != PaymentStatus.paid;
  }

  /// 期日が近いかどうか（7日以内）
  bool get isDueSoon {
    final days = daysUntilDue;
    return days >= 0 && days <= 7 && status != PaymentStatus.paid;
  }

  /// ステータスに応じた色
  Color getStatusColor() {
    switch (status) {
      case PaymentStatus.unpaid:
        if (isOverdue) return Colors.red;
        if (isDueSoon) return Colors.orange;
        return Colors.blue;
      case PaymentStatus.partial:
        return Colors.amber;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.overdue:
        return Colors.red;
    }
  }

  /// テーマカラー
  Color getThemeColor() {
    return getStatusColor();
  }
}

/// 支払ステータス
enum PaymentStatus {
  unpaid,     // 未払
  partial,    // 部分支払
  paid,       // 支払済
  overdue,    // 延滞
}
